import Combine
import Foundation
import OSLog

@MainActor
final class AwakeSessionController: ObservableObject {
    @Published private(set) var isAwake = false
    @Published private(set) var message: String?

    private let preventer: LidSleepPreventing
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "walakage", category: "AwakeSession")

    init() {
        self.preventer = PmsetLidSleepPreventer()
    }

    init(preventer: LidSleepPreventing) {
        self.preventer = preventer
    }

    func setKeepAwake(_ keepAwake: Bool) {
        if keepAwake {
            startAwakeSession()
        } else {
            stopAwakeSession()
        }
    }

    func quit() {
        stopAwakeSession()
    }

    private func startAwakeSession() {
        guard !isAwake else { return }

        do {
            try preventer.startPreventingLidSleep()
            isAwake = true
            message = nil
        } catch {
            logger.error("Unable to keep awake: \(String(describing: error), privacy: .public)")
            isAwake = false
            message = (error as? LidSleepPreventionError)?.userMessage ?? "Unable to keep awake."
        }
    }

    private func stopAwakeSession() {
        do {
            try preventer.stopPreventingLidSleep()
        } catch {
            logger.error("Unable to restore lid sleep: \(String(describing: error), privacy: .public)")
        }

        isAwake = false
        message = nil
    }
}
