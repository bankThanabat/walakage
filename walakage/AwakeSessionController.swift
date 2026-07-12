import Combine
import Foundation
import OSLog

@MainActor
final class AwakeSessionController: ObservableObject {
    @Published private(set) var isAwake = false
    @Published private(set) var isStarting = false
    @Published private(set) var keepDisplayAwake = false
    @Published private(set) var panelMessage: PanelMessage?
    @Published private(set) var timerSelection = SessionTimerSelection.off
    @Published private(set) var customTimerHours = 0
    @Published private(set) var customTimerMinutes = 0
    @Published private(set) var timerDeadline: Date?
    @Published private(set) var isBatteryMac: Bool
    @Published private(set) var batteryPercentage: Int?
    @Published private(set) var batteryProtectionThreshold = 20
    @Published private(set) var onlyWhileCharging = false

    private let preventionWorker: LidSleepPreventionWorker
    private let now: () -> Date
    private let scheduleDeadline: (Date, @escaping () -> Void) -> () -> Void
    private let powerMonitor: PowerMonitoring?
    private let userDefaults: UserDefaults?
    private var powerState: PowerState
    private var cancelDeadline: (() -> Void)?
    private var pendingPreventionTask: Task<Void, Never>?
    private var preventionOperation = 0
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "walakage", category: "AwakeSession")

    var message: String? { panelMessage?.rawValue }
    var isStartBlocked: Bool { protectiveStopMessage != nil }

    convenience init() {
        let powerMonitor = SystemPowerSourceMonitor()
        self.init(
            preventer: PmsetLidSleepPreventer(),
            now: Date.init,
            scheduleDeadline: Self.schedule,
            powerMonitor: powerMonitor,
            userDefaults: .standard
        )
    }

    init(
        preventer: LidSleepPreventing,
        now: @escaping () -> Date = Date.init,
        scheduleDeadline: @escaping (Date, @escaping () -> Void) -> () -> Void = { _, _ in {} },
        powerMonitor: PowerMonitoring? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        let powerState = powerMonitor?.currentState()
            ?? PowerState(isBatteryMac: false, supply: .unknown, batteryPercentage: nil)
        let custom = SessionTimer.clamp(
            hours: userDefaults?.integer(forKey: DefaultsKey.customTimerHours) ?? 0,
            minutes: userDefaults?.integer(forKey: DefaultsKey.customTimerMinutes) ?? 0
        )
        var timerSelection = userDefaults
            .flatMap { $0.string(forKey: DefaultsKey.timerSelection) }
            .flatMap(SessionTimerSelection.init(rawValue:)) ?? .off
        if timerSelection == .custom, custom.hours == 0, custom.minutes == 0 {
            timerSelection = .off
        }
        self.preventionWorker = LidSleepPreventionWorker(preventer: preventer)
        self.now = now
        self.scheduleDeadline = scheduleDeadline
        self.powerMonitor = powerMonitor
        self.userDefaults = userDefaults
        self.powerState = powerState
        self.isBatteryMac = powerState.isBatteryMac
        self.batteryPercentage = powerState.batteryPercentage
        self.timerSelection = timerSelection
        self.customTimerHours = custom.hours
        self.customTimerMinutes = custom.minutes
        if let storedThreshold = userDefaults?.object(forKey: DefaultsKey.batteryThreshold) as? NSNumber {
            self.batteryProtectionThreshold = min(80, max(5, storedThreshold.intValue))
        }
        self.onlyWhileCharging = userDefaults?.bool(forKey: DefaultsKey.onlyWhileCharging) ?? false
        powerMonitor?.startMonitoring { [weak self] in
            self?.refreshPowerState()
        }
    }

    func startKeepingAwake() async {
        guard prepareToStartAwakeSession() else { return }
        let operation = nextPreventionOperation()
        isStarting = true
        let result = await preventionWorker.start(keepingDisplayAwake: keepDisplayAwake)
        guard operation == preventionOperation else { return }
        isStarting = false
        finishStartingAwakeSession(with: result)
    }

    func stopKeepingAwake() {
        stopAwakeSession()
    }

    func setKeepDisplayAwake(_ keepDisplayAwake: Bool) async {
        guard !isStarting, self.keepDisplayAwake != keepDisplayAwake else { return }

        self.keepDisplayAwake = keepDisplayAwake
        panelMessage = nil
        guard isAwake else { return }

        let operation = nextPreventionOperation()
        let result = await preventionWorker.restart(keepingDisplayAwake: keepDisplayAwake)
        guard operation == preventionOperation else { return }

        logRestoreError(result.restoreError)
        switch result.startResult {
        case .success:
            break
        case .failure(let error):
            logger.error("Unable to keep awake: \(String(describing: error), privacy: .public)")
            isAwake = false
            cancelSessionTimer()
            panelMessage = message(for: error)
        }
    }

    func setTimer(_ selection: SessionTimerSelection) {
        timerSelection = selection
        panelMessage = nil
        if selection == .custom, SessionTimer.duration(
            for: selection,
            customHours: customTimerHours,
            customMinutes: customTimerMinutes
        ) == nil {
            timerSelection = .off
        }
        userDefaults?.set(timerSelection.rawValue, forKey: DefaultsKey.timerSelection)
        if isAwake {
            restartSessionTimer()
        }
    }

    @discardableResult
    func setBatteryProtectionThreshold(_ threshold: Int) -> Int {
        batteryProtectionThreshold = min(80, max(5, threshold))
        userDefaults?.set(batteryProtectionThreshold, forKey: DefaultsKey.batteryThreshold)
        panelMessage = nil
        applyProtectiveStopIfNeeded()
        return batteryProtectionThreshold
    }

    func setOnlyWhileCharging(_ onlyWhileCharging: Bool) {
        self.onlyWhileCharging = onlyWhileCharging
        userDefaults?.set(onlyWhileCharging, forKey: DefaultsKey.onlyWhileCharging)
        panelMessage = nil
        applyProtectiveStopIfNeeded()
    }

    @discardableResult
    func setCustomTimer(hours: Int, minutes: Int) -> SessionTimer.Components {
        let custom = SessionTimer.clamp(hours: hours, minutes: minutes)
        customTimerHours = custom.hours
        customTimerMinutes = custom.minutes
        timerSelection = custom.hours == 0 && custom.minutes == 0 ? .off : .custom
        userDefaults?.set(timerSelection.rawValue, forKey: DefaultsKey.timerSelection)
        userDefaults?.set(custom.hours, forKey: DefaultsKey.customTimerHours)
        userDefaults?.set(custom.minutes, forKey: DefaultsKey.customTimerMinutes)
        panelMessage = nil
        if isAwake {
            restartSessionTimer()
        }
        return custom
    }

    func countdown(at date: Date) -> String? {
        guard isAwake, let timerDeadline else { return nil }
        return SessionTimer.countdown(deadline: timerDeadline, now: date)
    }

    func quit() async {
        let operation = beginStoppingAwakeSession()
        let error = await preventionWorker.stop()
        guard operation == preventionOperation else { return }
        logRestoreError(error)
    }

    func waitForPendingPrevention() async {
        await pendingPreventionTask?.value
    }

    private func prepareToStartAwakeSession() -> Bool {
        guard !isAwake, !isStarting else { return false }
        panelMessage = nil
        if let protectiveStopMessage {
            panelMessage = protectiveStopMessage
            return false
        }
        return true
    }

    private func finishStartingAwakeSession(
        with result: Result<Void, LidSleepPreventionError>
    ) {
        switch result {
        case .success:
            isAwake = true
            panelMessage = nil
            if let protectiveStopMessage {
                stopAwakeSession(message: protectiveStopMessage)
                return
            }
            restartSessionTimer()
        case .failure(let error):
            logger.error("Unable to keep awake: \(String(describing: error), privacy: .public)")
            isAwake = false
            panelMessage = message(for: error)
        }
    }

    private func stopAwakeSession(message: PanelMessage? = nil) {
        let operation = beginStoppingAwakeSession(message: message)
        pendingPreventionTask = Task { [weak self] in
            guard let self else { return }
            let error = await preventionWorker.stop()
            guard operation == preventionOperation else { return }
            logRestoreError(error)
        }
    }

    private func beginStoppingAwakeSession(message: PanelMessage? = nil) -> Int {
        let operation = nextPreventionOperation()
        isStarting = false
        isAwake = false
        cancelSessionTimer()
        panelMessage = message
        return operation
    }

    private func nextPreventionOperation() -> Int {
        preventionOperation &+= 1
        return preventionOperation
    }

    private func logRestoreError(_ error: LidSleepPreventionError?) {
        guard let error else { return }
        logger.error("Unable to restore lid sleep: \(String(describing: error), privacy: .public)")
    }

    private func restartSessionTimer() {
        cancelSessionTimer()
        guard let duration = SessionTimer.duration(
            for: timerSelection,
            customHours: customTimerHours,
            customMinutes: customTimerMinutes
        ) else { return }

        let deadline = now().addingTimeInterval(duration)
        timerDeadline = deadline
        cancelDeadline = scheduleDeadline(deadline) { [weak self] in
            self?.sessionTimerFired()
        }
    }

    private func sessionTimerFired() {
        cancelDeadline = nil
        guard let timerDeadline else { return }
        guard now() >= timerDeadline else {
            cancelDeadline = scheduleDeadline(timerDeadline) { [weak self] in
                self?.sessionTimerFired()
            }
            return
        }
        stopAwakeSession(message: .timeUp)
    }

    private func cancelSessionTimer() {
        cancelDeadline?()
        cancelDeadline = nil
        timerDeadline = nil
    }

    private func refreshPowerState() {
        guard let powerMonitor else { return }
        powerState = powerMonitor.currentState()
        isBatteryMac = powerState.isBatteryMac
        batteryPercentage = powerState.batteryPercentage

        if isAwake {
            applyProtectiveStopIfNeeded()
        } else if panelMessage?.isBlocking == true {
            panelMessage = protectiveStopMessage
        }
    }

    private func applyProtectiveStopIfNeeded() {
        guard isAwake, let protectiveStopMessage else { return }
        stopAwakeSession(message: protectiveStopMessage)
    }

    private var protectiveStopMessage: PanelMessage? {
        guard powerState.isBatteryMac, powerState.supply == .battery else { return nil }
        if onlyWhileCharging {
            return .powerDisconnected
        }
        if let percentage = powerState.batteryPercentage,
           percentage <= batteryProtectionThreshold {
            return .batteryLow
        }
        return nil
    }

    private func message(for error: Error) -> PanelMessage {
        guard let error = error as? LidSleepPreventionError else {
            return .unableToKeepAwake
        }
        return PanelMessage(rawValue: error.userMessage) ?? .unableToKeepAwake
    }

    private static func schedule(deadline: Date, action: @escaping () -> Void) -> () -> Void {
        let timer = Timer(fire: deadline, interval: 0, repeats: false) { _ in
            Task { @MainActor in action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return { timer.invalidate() }
    }
}

private enum DefaultsKey {
    static let timerSelection = "sessionTimerSelection"
    static let customTimerHours = "customTimerHours"
    static let customTimerMinutes = "customTimerMinutes"
    static let batteryThreshold = "batteryProtectionThreshold"
    static let onlyWhileCharging = "onlyWhileCharging"
}
