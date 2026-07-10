import AppKit
import Testing
@testable import walakage

@MainActor
struct AwakeSessionPowerTests {
    @Test func batteryControlsUseTheCurrentMacPowerState() {
        let monitor = FakePowerMonitor(.init(isBatteryMac: true, supply: .external, batteryPercentage: 72))
        let session = AwakeSessionController(preventer: FakeLidSleepPreventer(), powerMonitor: monitor)

        #expect(session.isBatteryMac)
        #expect(session.batteryPercentage == 72)
        #expect(session.batteryProtectionThreshold == 20)
        #expect(!session.onlyWhileCharging)
    }

    @Test func desktopMacIgnoresOnlyWhileCharging() {
        let preventer = FakeLidSleepPreventer()
        let monitor = FakePowerMonitor(.init(isBatteryMac: false, supply: .unknown, batteryPercentage: nil))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: monitor)

        session.setOnlyWhileCharging(true)
        session.setKeepAwake(true)

        #expect(!session.isBatteryMac)
        #expect(session.isAwake)
        #expect(preventer.startCount == 1)
    }

    @Test func powerDisconnectedWinsOverLowBatteryBeforeStart() {
        let preventer = FakeLidSleepPreventer()
        let monitor = FakePowerMonitor(.init(isBatteryMac: true, supply: .battery, batteryPercentage: 5))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: monitor)
        session.setOnlyWhileCharging(true)

        session.setKeepAwake(true)

        #expect(!session.isAwake)
        #expect(preventer.startCount == 0)
        #expect(session.message == "Power disconnected.")
    }

    @Test func lowBatteryBlocksBeforeStartingPrevention() {
        let preventer = FakeLidSleepPreventer()
        let monitor = FakePowerMonitor(.init(isBatteryMac: true, supply: .battery, batteryPercentage: 20))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: monitor)

        session.setKeepAwake(true)

        #expect(!session.isAwake)
        #expect(preventer.startCount == 0)
        #expect(session.message == "Battery low.")
    }

    @Test func lowPercentageDoesNotBlockWhileOnExternalPower() {
        let preventer = FakeLidSleepPreventer()
        let monitor = FakePowerMonitor(.init(isBatteryMac: true, supply: .external, batteryPercentage: 5))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: monitor)

        session.setKeepAwake(true)

        #expect(session.isAwake)
        #expect(preventer.startCount == 1)
    }

    @Test func powerChangeProtectivelyStopsAnActiveSession() {
        let preventer = FakeLidSleepPreventer()
        let monitor = FakePowerMonitor(.init(isBatteryMac: true, supply: .external, batteryPercentage: 80))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: monitor)
        session.setOnlyWhileCharging(true)
        session.setKeepAwake(true)

        monitor.state = .init(isBatteryMac: true, supply: .battery, batteryPercentage: 80)
        monitor.sendChange()

        #expect(!session.isAwake)
        #expect(preventer.stopCount == 1)
        #expect(session.message == "Power disconnected.")
    }

    @Test func clearingBlockerClearsMessageWithoutRestarting() {
        let preventer = FakeLidSleepPreventer()
        let monitor = FakePowerMonitor(.init(isBatteryMac: true, supply: .battery, batteryPercentage: 10))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: monitor)
        session.setKeepAwake(true)
        #expect(session.message == "Battery low.")

        monitor.state = .init(isBatteryMac: true, supply: .external, batteryPercentage: 10)
        monitor.sendChange()

        #expect(session.message == nil)
        #expect(!session.isAwake)
        #expect(preventer.startCount == 0)
    }

    @Test func thresholdClampsAndImmediatelyProtectsAnActiveSession() {
        let preventer = FakeLidSleepPreventer()
        let monitor = FakePowerMonitor(.init(isBatteryMac: true, supply: .battery, batteryPercentage: 70))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: monitor)
        session.setBatteryProtectionThreshold(5)
        session.setKeepAwake(true)

        #expect(session.setBatteryProtectionThreshold(0) == 5)
        #expect(session.setBatteryProtectionThreshold(100) == 80)

        #expect(session.batteryProtectionThreshold == 80)
        #expect(!session.isAwake)
        #expect(session.message == "Battery low.")
        #expect(preventer.stopCount == 1)
    }

    @Test func wakeNotificationTriggersAPowerRecheck() {
        let notificationCenter = NotificationCenter()
        let monitor = SystemPowerSourceMonitor(workspaceNotificationCenter: notificationCenter)
        var recheckCount = 0
        monitor.startMonitoring { recheckCount += 1 }

        notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)

        #expect(recheckCount == 1)
    }
}

@MainActor
final class FakePowerMonitor: PowerMonitoring {
    var state: PowerState
    private var handler: (() -> Void)?

    init(_ state: PowerState) {
        self.state = state
    }

    func currentState() -> PowerState {
        state
    }

    func startMonitoring(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func sendChange() {
        handler?()
    }
}
