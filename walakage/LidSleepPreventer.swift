import Darwin
import Foundation
import IOKit.pwr_mgt
import Security

enum LidSleepPreventionError: Error {
    case commandFailed(String)

    var userMessage: String {
        switch self {
        case .commandFailed(let output)
            where output.contains("-60005")
                || output.localizedCaseInsensitiveContains("administrator user name or password was incorrect")
                || output.contains("-128"):
            return "Administrator approval failed."
        case .commandFailed:
            return "Unable to keep awake."
        }
    }
}

protocol LidSleepPreventing: AnyObject {
    func startPreventingLidSleep(keepingDisplayAwake: Bool) throws
    func stopPreventingLidSleep() throws
}

// ponytail: Swift marks this unavailable; use the C symbol for the prototype,
// replace with an SMAppService helper if this survives past local validation.
@_silgen_name("AuthorizationExecuteWithPrivileges")
private nonisolated func AuthorizationExecuteWithPrivilegesShim(
    _ authorization: AuthorizationRef,
    _ pathToTool: UnsafePointer<CChar>,
    _ options: AuthorizationFlags,
    _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>>,
    _ communicationsPipe: UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
) -> OSStatus

final class PmsetLidSleepPreventer: LidSleepPreventing {
    private nonisolated static let toolPath = "/usr/bin/pmset"

    private let runPmsetOverride: ((String) throws -> Void)?
    private let authorize: () throws -> AuthorizationRef
    private let executePmsetCommand: (String, AuthorizationRef) -> OSStatus
    private let freeAuthorization: (AuthorizationRef) -> Void
    private let createDisplayAssertion: () throws -> IOPMAssertionID
    private let releaseDisplayAssertion: (IOPMAssertionID) -> IOReturn
    private var authorization: AuthorizationRef?
    private var isEnabled = false
    private var displayAssertion: IOPMAssertionID = 0

    convenience init() {
        self.init(
            authorize: Self.authorizePmset,
            executePmset: Self.executePmset,
            freeAuthorization: { AuthorizationFree($0, []) },
            createDisplayAssertion: Self.createNoDisplaySleepAssertion,
            releaseDisplayAssertion: IOPMAssertionRelease
        )
    }

    init(
        runPmset: @escaping (String) throws -> Void,
        createDisplayAssertion: @escaping () throws -> IOPMAssertionID,
        releaseDisplayAssertion: @escaping (IOPMAssertionID) -> IOReturn
    ) {
        self.runPmsetOverride = runPmset
        self.authorize = { throw LidSleepPreventionError.commandFailed("test authorization unexpectedly used") }
        self.executePmsetCommand = { _, _ in errAuthorizationSuccess }
        self.freeAuthorization = { _ in }
        self.createDisplayAssertion = createDisplayAssertion
        self.releaseDisplayAssertion = releaseDisplayAssertion
    }

    init(
        authorize: @escaping () throws -> AuthorizationRef,
        executePmset: @escaping (String, AuthorizationRef) -> OSStatus,
        freeAuthorization: @escaping (AuthorizationRef) -> Void,
        createDisplayAssertion: @escaping () throws -> IOPMAssertionID,
        releaseDisplayAssertion: @escaping (IOPMAssertionID) -> IOReturn
    ) {
        self.runPmsetOverride = nil
        self.authorize = authorize
        self.executePmsetCommand = executePmset
        self.freeAuthorization = freeAuthorization
        self.createDisplayAssertion = createDisplayAssertion
        self.releaseDisplayAssertion = releaseDisplayAssertion
    }

    func startPreventingLidSleep(keepingDisplayAwake: Bool) throws {
        try runPmset("1")
        isEnabled = true

        guard keepingDisplayAwake else { return }

        do {
            displayAssertion = try createDisplayAssertion()
        } catch {
            try? stopPreventingLidSleep()
            throw error
        }
    }

    func stopPreventingLidSleep() throws {
        var releaseError: Error?
        if displayAssertion != 0 {
            let assertion = displayAssertion
            displayAssertion = 0
            let status = releaseDisplayAssertion(assertion)
            if status != kIOReturnSuccess {
                releaseError = LidSleepPreventionError.commandFailed("display assertion release failed: \(status)")
            }
        }

        guard isEnabled else { return }

        try runPmset("0")
        isEnabled = false
        if let releaseError {
            throw releaseError
        }
    }

    deinit {
        try? stopPreventingLidSleep()
        if let authorization {
            freeAuthorization(authorization)
        }
    }

    private nonisolated static func createNoDisplaySleepAssertion() throws -> IOPMAssertionID {
        var assertion = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Walakage Keep Display Awake" as CFString,
            &assertion
        )
        guard status == kIOReturnSuccess else {
            throw LidSleepPreventionError.commandFailed("display assertion failed: \(status)")
        }

        return assertion
    }

    private func runPmset(_ disablesleepValue: String) throws {
        if let runPmsetOverride {
            try runPmsetOverride(disablesleepValue)
            return
        }

        let status = executePmsetCommand(disablesleepValue, try cachedAuthorization())
        guard status == errAuthorizationSuccess else {
            throw LidSleepPreventionError.commandFailed("pmset failed: \(status)")
        }
    }

    private func cachedAuthorization() throws -> AuthorizationRef {
        if let authorization {
            return authorization
        }

        let authorization = try authorize()
        self.authorization = authorization
        return authorization
    }

    private nonisolated static func authorizePmset() throws -> AuthorizationRef {
        var authorization: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &authorization)
        guard createStatus == errAuthorizationSuccess, let authorization else {
            throw LidSleepPreventionError.commandFailed("authorization failed: \(createStatus)")
        }

        let rightsStatus = kAuthorizationRightExecute.withCString { rightName in
            Self.toolPath.withCString { tool in
                var right = AuthorizationItem(
                    name: rightName,
                    valueLength: strlen(tool),
                    value: UnsafeMutableRawPointer(mutating: tool),
                    flags: 0
                )
                return withUnsafeMutablePointer(to: &right) { rightPointer in
                    var rights = AuthorizationRights(count: 1, items: rightPointer)
                    return AuthorizationCopyRights(
                        authorization,
                        &rights,
                        nil,
                        [.interactionAllowed, .extendRights],
                        nil
                    )
                }
            }
        }
        guard rightsStatus == errAuthorizationSuccess else {
            AuthorizationFree(authorization, [])
            throw LidSleepPreventionError.commandFailed("authorization denied: \(rightsStatus)")
        }

        return authorization
    }

    private nonisolated static func executePmset(_ disablesleepValue: String, authorization: AuthorizationRef) -> OSStatus {
        Self.toolPath.withCString { tool in
            var command = Array("disablesleep".utf8CString)
            var argument = Array(disablesleepValue.utf8CString)
            return command.withUnsafeMutableBufferPointer { commandBuffer in
                argument.withUnsafeMutableBufferPointer { argumentBuffer in
                    var arguments = [commandBuffer.baseAddress, argumentBuffer.baseAddress, nil]
                    let argumentCount = arguments.count
                    return arguments.withUnsafeMutableBufferPointer { argumentsBuffer in
                        argumentsBuffer.baseAddress!.withMemoryRebound(
                            to: UnsafeMutablePointer<CChar>.self,
                            capacity: argumentCount
                        ) { argumentsPointer in
                            AuthorizationExecuteWithPrivilegesShim(
                                authorization,
                                tool,
                                [],
                                argumentsPointer,
                                nil
                            )
                        }
                    }
                }
            }
        }
    }
}
