import IOKit.pwr_mgt
import Security
import Testing
import Dispatch
@testable import walakage

@MainActor
struct AwakeSessionControllerTests {
    @Test func firstKeepAwakeOnStartsLidSleepPrevention() async {
        let preventer = FakeLidSleepPreventer()
        let session = makeSession(preventer: preventer)

        await session.startKeepingAwake()

        #expect(session.isAwake)
        #expect(session.message == nil)
        #expect(preventer.startCount == 1)
        #expect(preventer.stopCount == 0)
        #expect(preventer.keepDisplayAwakeRequests == [false])
    }

    @Test func keepAwakeOffRestoresLidSleep() async {
        let preventer = FakeLidSleepPreventer()
        let session = makeSession(preventer: preventer)

        await session.startKeepingAwake()
        session.stopKeepingAwake()
        await session.waitForPendingPrevention()

        #expect(!session.isAwake)
        #expect(session.message == nil)
        #expect(preventer.startCount == 1)
        #expect(preventer.stopCount == 1)
    }

    @Test func quitRestoresLidSleep() async {
        let preventer = FakeLidSleepPreventer()
        let session = makeSession(preventer: preventer)

        await session.startKeepingAwake()
        await session.quit()

        #expect(!session.isAwake)
        #expect(preventer.stopCount == 1)
    }

    @Test func failedStartLeavesKeepAwakeOff() async {
        let preventer = FakeLidSleepPreventer()
        preventer.shouldFailStart = true
        let session = makeSession(preventer: preventer)

        await session.startKeepingAwake()

        #expect(!session.isAwake)
        #expect(session.message == "Unable to keep awake.")
        #expect(preventer.startCount == 1)
        #expect(preventer.stopCount == 0)
    }

    @Test func failedAdminApprovalShowsSpecificMessage() async {
        let preventer = FakeLidSleepPreventer()
        preventer.startError = LidSleepPreventionError.commandFailed("administrator user name or password was incorrect. (-60005)")
        let session = makeSession(preventer: preventer)

        await session.startKeepingAwake()

        #expect(!session.isAwake)
        #expect(session.message == "Administrator approval failed.")
    }

    @Test func displayStartFailureLeavesKeepAwakeOffAndShowsMessage() async {
        let preventer = FakeLidSleepPreventer()
        preventer.startError = LidSleepPreventionError.commandFailed("display failed")
        let session = makeSession(preventer: preventer)

        await session.setKeepDisplayAwake(true)
        await session.startKeepingAwake()

        #expect(!session.isAwake)
        #expect(session.message == "Unable to keep awake.")
        #expect(preventer.keepDisplayAwakeRequests == [true])
    }

    @Test func keepDisplayAwakeOnStartsDisplayPrevention() async {
        let preventer = FakeLidSleepPreventer()
        let session = makeSession(preventer: preventer)

        await session.setKeepDisplayAwake(true)
        await session.startKeepingAwake()

        #expect(preventer.keepDisplayAwakeRequests == [true])
    }

    @Test func changingKeepDisplayAwakeWhileActiveRecreatesPrevention() async {
        let preventer = FakeLidSleepPreventer()
        let session = makeSession(preventer: preventer)

        await session.startKeepingAwake()
        await session.setKeepDisplayAwake(true)

        #expect(session.isAwake)
        #expect(preventer.keepDisplayAwakeRequests == [false, true])
        #expect(preventer.stopCount == 1)
    }

    @Test func keepDisplayAwakeStartsOff() throws {
        let session = makeSession(preventer: FakeLidSleepPreventer())

        #expect(!session.keepDisplayAwake)
    }

    @Test func authorizationDoesNotBlockTheMainActor() async {
        let releaseStart = DispatchSemaphore(value: 0)
        let preventer = FakeLidSleepPreventer()
        preventer.onStart = { releaseStart.wait() }
        let session = makeSession(preventer: preventer)
        let clock = ContinuousClock()
        let responsivenessDeadline = clock.now.advanced(by: .milliseconds(250))
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            releaseStart.signal()
        }

        let start = Task { await session.startKeepingAwake() }
        while !session.isStarting, clock.now < responsivenessDeadline {
            await Task.yield()
        }

        #expect(session.isStarting)
        #expect(clock.now < responsivenessDeadline)
        releaseStart.signal()
        await start.value
        #expect(session.isAwake)
    }

    @Test func stopWinsOverAnInFlightStart() async {
        let releaseStart = DispatchSemaphore(value: 0)
        let preventer = FakeLidSleepPreventer()
        preventer.onStart = { releaseStart.wait() }
        let session = makeSession(preventer: preventer)

        let start = Task { await session.startKeepingAwake() }
        while !session.isStarting {
            await Task.yield()
        }

        session.stopKeepingAwake()
        releaseStart.signal()
        await start.value
        await session.waitForPendingPrevention()

        #expect(!session.isAwake)
        #expect(preventer.startCount == 1)
        #expect(preventer.stopCount == 1)
    }
}

struct PmsetLidSleepPreventerTests {
    @Test func authorizationIsReusedUntilPreventerDeinitializes() throws {
        var authorizeCount = 0
        var freedCount = 0
        var pmsetValues: [String] = []
        let authorization = AuthorizationRef(bitPattern: 1)!

        do {
            let preventer = PmsetLidSleepPreventer(
                authorize: {
                    authorizeCount += 1
                    return authorization
                },
                executePmset: { value, usedAuthorization in
                    #expect(usedAuthorization == authorization)
                    pmsetValues.append(value)
                    return errAuthorizationSuccess
                },
                freeAuthorization: { usedAuthorization in
                    #expect(usedAuthorization == authorization)
                    freedCount += 1
                },
                createDisplayAssertion: { 42 },
                releaseDisplayAssertion: { _ in kIOReturnSuccess }
            )

            try preventer.startPreventingLidSleep(keepingDisplayAwake: false)
            try preventer.stopPreventingLidSleep()
            try preventer.startPreventingLidSleep(keepingDisplayAwake: false)
            try preventer.stopPreventingLidSleep()
        }

        #expect(authorizeCount == 1)
        #expect(pmsetValues == ["1", "0", "1", "0"])
        #expect(freedCount == 1)
    }

    @Test func displayAssertionIsReleasedOnStop() throws {
        var pmsetValues: [String] = []
        var releasedAssertions: [IOPMAssertionID] = []
        let preventer = PmsetLidSleepPreventer(
            runPmset: { pmsetValues.append($0) },
            createDisplayAssertion: { 42 },
            releaseDisplayAssertion: {
                releasedAssertions.append($0)
                return kIOReturnSuccess
            }
        )

        try preventer.startPreventingLidSleep(keepingDisplayAwake: true)
        try preventer.stopPreventingLidSleep()

        #expect(pmsetValues == ["1", "0"])
        #expect(releasedAssertions == [42])
    }

    @Test func displayAssertionFailureReleasesSystemAssertion() throws {
        var pmsetValues: [String] = []
        let preventer = PmsetLidSleepPreventer(
            runPmset: { pmsetValues.append($0) },
            createDisplayAssertion: { throw LidSleepPreventionError.commandFailed("display failed") },
            releaseDisplayAssertion: { _ in kIOReturnSuccess }
        )

        do {
            try preventer.startPreventingLidSleep(keepingDisplayAwake: true)
            Issue.record("Expected display assertion failure")
        } catch {}

        #expect(pmsetValues == ["1", "0"])
    }
}

final class FakeLidSleepPreventer: LidSleepPreventing, @unchecked Sendable {
    var startCount = 0
    var stopCount = 0
    var keepDisplayAwakeRequests: [Bool] = []
    var shouldFailStart = false
    var startError: Error?
    var onStart: (() -> Void)?

    func startPreventingLidSleep(keepingDisplayAwake: Bool) throws {
        startCount += 1
        keepDisplayAwakeRequests.append(keepingDisplayAwake)
        onStart?()
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

@MainActor
private func makeSession(preventer: FakeLidSleepPreventer) -> AwakeSessionController {
    AwakeSessionController(preventer: preventer)
}
