import Foundation
import Testing
@testable import walakage

@MainActor
struct AwakeSessionTimerTests {
    @Test func changingQuickTimerWhileActiveRestartsFromNow() async {
        let clock = TestClock()
        let scheduler = TestDeadlineScheduler()
        let session = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            now: { clock.now },
            scheduleDeadline: scheduler.schedule
        )
        await session.startKeepingAwake()

        session.setTimer(.fifteenMinutes)
        #expect(session.timerDeadline == clock.now.addingTimeInterval(900))

        clock.now = clock.now.addingTimeInterval(60)
        session.setTimer(.oneHour)

        #expect(session.isAwake)
        #expect(scheduler.cancelCount == 1)
        #expect(session.timerDeadline == clock.now.addingTimeInterval(3_600))
    }

    @Test func customTimerClampsAndRestartsAnActiveSession() async {
        let clock = TestClock()
        let scheduler = TestDeadlineScheduler()
        let session = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            now: { clock.now },
            scheduleDeadline: scheduler.schedule
        )
        await session.startKeepingAwake()

        let committed = session.setCustomTimer(hours: 24, minutes: 30)

        #expect(committed == .init(hours: 24, minutes: 0))
        #expect(session.timerSelection == .custom)
        #expect(session.customTimerHours == 24)
        #expect(session.customTimerMinutes == 0)
        #expect(session.timerDeadline == clock.now.addingTimeInterval(24 * 60 * 60))
    }

    @Test func zeroCustomTimerTurnsTimerOffWithoutStoppingKeepAwake() async {
        let scheduler = TestDeadlineScheduler()
        let session = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            scheduleDeadline: scheduler.schedule
        )
        session.setTimer(.fifteenMinutes)
        await session.startKeepingAwake()

        session.setCustomTimer(hours: 0, minutes: 0)

        #expect(session.isAwake)
        #expect(session.timerSelection == .off)
        #expect(session.timerDeadline == nil)
        #expect(scheduler.cancelCount == 1)
    }

    @Test func deadlineStopsKeepAwakeAtTheExactWallClockTime() async {
        let preventer = FakeLidSleepPreventer()
        let clock = TestClock()
        let scheduler = TestDeadlineScheduler()
        let session = AwakeSessionController(
            preventer: preventer,
            now: { clock.now },
            scheduleDeadline: scheduler.schedule
        )
        session.setTimer(.fifteenMinutes)
        await session.startKeepingAwake()
        let deadline = session.timerDeadline!

        clock.now = deadline
        scheduler.fireLatest()
        await session.waitForPendingPrevention()

        #expect(!session.isAwake)
        #expect(preventer.stopCount == 1)
        #expect(session.message == "Time up.")
    }

    @Test func countdownExistsOnlyForAnActiveTimedSession() async {
        let clock = TestClock()
        let session = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            now: { clock.now },
            scheduleDeadline: TestDeadlineScheduler().schedule
        )
        session.setTimer(.fifteenMinutes)

        #expect(session.countdown(at: clock.now) == nil)

        await session.startKeepingAwake()

        #expect(session.countdown(at: clock.now.addingTimeInterval(1)) == "15m left")
    }
}

@MainActor
final class TestDeadlineScheduler {
    private(set) var cancelCount = 0
    private var actions: [() -> Void] = []

    func schedule(deadline: Date, action: @escaping () -> Void) -> () -> Void {
        actions.append(action)
        return { [weak self] in self?.cancelCount += 1 }
    }

    func fireLatest() {
        actions.last?()
    }
}

@MainActor
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_000)
}
