import Foundation
import Testing
@testable import walakage

@MainActor
struct SessionTimerTests {
    @Test func quickChoicesMapToExpectedDurations() {
        #expect(SessionTimerSelection.quickChoices.map(\.title) == ["Off", "15m", "30m", "1h", "2h", "4h"])
        #expect(SessionTimer.duration(for: .off, customHours: 0, customMinutes: 0) == nil)
        #expect(SessionTimer.duration(for: .fifteenMinutes, customHours: 0, customMinutes: 0) == 900.0)
        #expect(SessionTimer.duration(for: .thirtyMinutes, customHours: 0, customMinutes: 0) == 1_800.0)
        #expect(SessionTimer.duration(for: .oneHour, customHours: 0, customMinutes: 0) == 3_600.0)
        #expect(SessionTimer.duration(for: .twoHours, customHours: 0, customMinutes: 0) == 7_200.0)
        #expect(SessionTimer.duration(for: .fourHours, customHours: 0, customMinutes: 0) == 14_400.0)
    }

    @Test func customDurationClampsFieldsAndTotalToTwentyFourHours() {
        #expect(SessionTimer.clamp(hours: -3, minutes: 90) == .init(hours: 0, minutes: 59))
        #expect(SessionTimer.clamp(hours: 24, minutes: 30) == .init(hours: 24, minutes: 0))
        #expect(SessionTimer.clamp(hours: 25, minutes: 30) == .init(hours: 24, minutes: 0))
        #expect(SessionTimer.clamp(hours: 23, minutes: 59) == .init(hours: 23, minutes: 59))
    }

    @Test func zeroCustomDurationMeansTimerOff() {
        #expect(SessionTimer.duration(for: .custom, customHours: 0, customMinutes: 0) == nil)
    }

    @Test func countdownRoundsUpWithoutChangingTheDeadline() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(SessionTimer.countdown(deadline: now.addingTimeInterval(65), now: now) == "2m left")
        #expect(SessionTimer.countdown(deadline: now.addingTimeInterval(3_901), now: now) == "1h 06m left")
        #expect(SessionTimer.countdown(deadline: now, now: now) == nil)
    }

    @Test func progressMatchesTheRemainingFractionAndClampsAtTheEnds() {
        let now = Date(timeIntervalSince1970: 1_000)
        let deadline = now.addingTimeInterval(60)

        #expect(SessionTimer.progress(deadline: deadline, duration: 60, now: now) == 1)
        #expect(SessionTimer.progress(deadline: deadline, duration: 60, now: now.addingTimeInterval(30)) == 0.5)
        #expect(SessionTimer.progress(deadline: deadline, duration: 60, now: now.addingTimeInterval(90)) == 0)
        #expect(SessionTimer.progress(deadline: deadline, duration: 60, now: now.addingTimeInterval(-30)) == 1)
        #expect(SessionTimer.progress(deadline: deadline, duration: 0, now: now) == 0)
    }
}
