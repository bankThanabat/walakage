import Testing
@testable import walakage

@MainActor
struct PanelMessageTests {
    @Test func supportedMessagesMatchTheCurrentProductDecision() {
        #expect(Set(PanelMessage.allCases.map(\.rawValue)) == [
            "Time up.",
            "Battery low.",
            "Power disconnected.",
            "Unable to keep awake.",
            "Administrator approval failed."
        ])
    }

    @Test func changingASettingClearsAnOldFailure() async {
        let preventer = FakeLidSleepPreventer()
        preventer.shouldFailStart = true
        let session = AwakeSessionController(preventer: preventer)
        await session.startKeepingAwake()
        #expect(session.message == "Unable to keep awake.")

        session.setTimer(.thirtyMinutes)

        #expect(session.message == nil)
    }

    @Test func failurePersistsAcrossBackgroundPowerRefreshes() async {
        let preventer = FakeLidSleepPreventer()
        preventer.shouldFailStart = true
        let power = FakePowerMonitor(.init(
            isBatteryMac: true,
            supply: .external,
            batteryPercentage: 80
        ))
        let session = AwakeSessionController(preventer: preventer, powerMonitor: power)
        await session.startKeepingAwake()

        power.sendChange()

        #expect(session.message == "Unable to keep awake.")
    }
}
