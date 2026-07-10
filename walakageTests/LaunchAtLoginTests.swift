import Testing
@testable import walakage

@MainActor
struct LaunchAtLoginTests {
    @Test func successfulChangesApplyImmediately() {
        let loginItem = FakeLaunchAtLoginManager()
        let session = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            launchAtLoginManager: loginItem
        )

        session.setLaunchAtLogin(true)
        #expect(session.launchAtLogin)
        #expect(loginItem.requestedValues == [true])

        session.setLaunchAtLogin(false)
        #expect(!session.launchAtLogin)
        #expect(loginItem.requestedValues == [true, false])
    }

    @Test func failedEnableRevertsToActualOffState() {
        let loginItem = FakeLaunchAtLoginManager()
        loginItem.shouldFail = true
        let session = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            launchAtLoginManager: loginItem
        )

        session.setLaunchAtLogin(true)

        #expect(!session.launchAtLogin)
        #expect(session.message == "Unable to launch at login.")
    }

    @Test func failedDisableRevertsToActualOnState() {
        let loginItem = FakeLaunchAtLoginManager(isEnabled: true)
        loginItem.shouldFail = true
        let session = AwakeSessionController(
            preventer: FakeLidSleepPreventer(),
            launchAtLoginManager: loginItem
        )

        session.setLaunchAtLogin(false)

        #expect(session.launchAtLogin)
        #expect(session.message == "Unable to launch at login.")
    }

    @Test func launchRegistrationNeverStartsKeepAwake() {
        let preventer = FakeLidSleepPreventer()
        let session = AwakeSessionController(
            preventer: preventer,
            launchAtLoginManager: FakeLaunchAtLoginManager()
        )

        session.setLaunchAtLogin(true)

        #expect(!session.isAwake)
        #expect(preventer.startCount == 0)
    }
}

@MainActor
final class FakeLaunchAtLoginManager: LaunchAtLoginManaging {
    private(set) var isEnabled: Bool
    var shouldFail = false
    private(set) var requestedValues: [Bool] = []

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        requestedValues.append(enabled)
        if shouldFail {
            throw TestLoginItemError.failed
        }
        isEnabled = enabled
    }
}

private enum TestLoginItemError: Error {
    case failed
}
