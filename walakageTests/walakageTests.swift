import Testing
@testable import walakage

@MainActor
struct AwakeSessionControllerTests {
    @Test func firstKeepAwakeOnStartsLidSleepPrevention() throws {
        let preventer = FakeLidSleepPreventer()
        let session = AwakeSessionController(preventer: preventer)

        session.setKeepAwake(true)

        #expect(session.isAwake)
        #expect(session.message == nil)
        #expect(preventer.startCount == 1)
        #expect(preventer.stopCount == 0)
    }

    @Test func keepAwakeOffRestoresLidSleep() throws {
        let preventer = FakeLidSleepPreventer()
        let session = AwakeSessionController(preventer: preventer)

        session.setKeepAwake(true)
        session.setKeepAwake(false)

        #expect(!session.isAwake)
        #expect(session.message == nil)
        #expect(preventer.startCount == 1)
        #expect(preventer.stopCount == 1)
    }

    @Test func quitRestoresLidSleep() throws {
        let preventer = FakeLidSleepPreventer()
        let session = AwakeSessionController(preventer: preventer)

        session.setKeepAwake(true)
        session.quit()

        #expect(!session.isAwake)
        #expect(preventer.stopCount == 1)
    }

    @Test func failedStartLeavesKeepAwakeOff() throws {
        let preventer = FakeLidSleepPreventer()
        preventer.shouldFailStart = true
        let session = AwakeSessionController(preventer: preventer)

        session.setKeepAwake(true)

        #expect(!session.isAwake)
        #expect(session.message == "Unable to keep awake.")
        #expect(preventer.startCount == 1)
        #expect(preventer.stopCount == 0)
    }

    @Test func failedAdminApprovalShowsSpecificMessage() throws {
        let preventer = FakeLidSleepPreventer()
        preventer.startError = LidSleepPreventionError.commandFailed("administrator user name or password was incorrect. (-60005)")
        let session = AwakeSessionController(preventer: preventer)

        session.setKeepAwake(true)

        #expect(!session.isAwake)
        #expect(session.message == "Administrator approval failed.")
    }
}

private final class FakeLidSleepPreventer: LidSleepPreventing {
    var startCount = 0
    var stopCount = 0
    var shouldFailStart = false
    var startError: Error?

    func startPreventingLidSleep() throws {
        startCount += 1
        if let startError {
            throw startError
        }
        if shouldFailStart {
            throw LidSleepPreventionError.commandFailed("failed")
        }
    }

    func stopPreventingLidSleep() throws {
        stopCount += 1
    }
}
