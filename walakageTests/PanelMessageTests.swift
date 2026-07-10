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
            "Administrator approval failed.",
            "Unable to launch at login."
        ])
    }

    @Test func changingASettingClearsAnOldFailure() {
        let preventer = FakeLidSleepPreventer()
        preventer.shouldFailStart = true
        let session = AwakeSessionController(preventer: preventer)
        session.setKeepAwake(true)
        #expect(session.message == "Unable to keep awake.")

        session.setTimer(.thirtyMinutes)

        #expect(session.message == nil)
    }
}
