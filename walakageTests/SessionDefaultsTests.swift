import Foundation
import Testing
@testable import walakage

@MainActor
struct SessionDefaultsTests {
    @Test func timerAndBatterySettingsAreRestoredWithoutResumingKeepAwake() async {
        let defaults = isolatedDefaults()
        let power = FakePowerMonitor(.init(isBatteryMac: true, supply: .external, batteryPercentage: 90))
        let first = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            powerMonitor: power,
            userDefaults: defaults
        )
        first.setCustomTimer(hours: 2, minutes: 15)
        first.setBatteryProtectionThreshold(35)
        first.setOnlyWhileCharging(true)
        await first.startKeepingAwake()

        let restored = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            powerMonitor: power,
            userDefaults: defaults
        )

        #expect(restored.timerSelection == .custom)
        #expect(restored.customTimerHours == 2)
        #expect(restored.customTimerMinutes == 15)
        #expect(restored.batteryProtectionThreshold == 35)
        #expect(restored.onlyWhileCharging)
        #expect(!restored.isAwake)
        #expect(restored.timerDeadline == nil)
    }

    @Test func keepDisplayAwakeStillStartsOffOnEveryLaunch() async {
        let defaults = isolatedDefaults()
        let first = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            userDefaults: defaults
        )
        await first.setKeepDisplayAwake(true)

        let restored = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            userDefaults: defaults
        )

        #expect(!restored.keepDisplayAwake)
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "walakage-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
