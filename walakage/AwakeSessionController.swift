import Combine
import Darwin
import Foundation
import OSLog
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
    func startPreventingLidSleep() throws
    func stopPreventingLidSleep() throws
}

// ponytail: Swift marks this unavailable; use the C symbol for the prototype,
// replace with an SMAppService helper if this survives past local validation.
@_silgen_name("AuthorizationExecuteWithPrivileges")
private func AuthorizationExecuteWithPrivilegesShim(
    _ authorization: AuthorizationRef,
    _ pathToTool: UnsafePointer<CChar>,
    _ options: AuthorizationFlags,
    _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>>,
    _ communicationsPipe: UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
) -> OSStatus

@MainActor
final class AwakeSessionController: ObservableObject {
    @Published private(set) var isAwake = false
    @Published private(set) var message: String?

    private let preventer: LidSleepPreventing
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "walakage", category: "AwakeSession")

    init() {
        self.preventer = PmsetLidSleepPreventer()
    }

    init(preventer: LidSleepPreventing) {
        self.preventer = preventer
    }

    func setKeepAwake(_ keepAwake: Bool) {
        guard keepAwake != isAwake else { return }

        if keepAwake {
            do {
                try preventer.startPreventingLidSleep()
                isAwake = true
                message = nil
            } catch {
                logger.error("Unable to keep awake: \(String(describing: error), privacy: .public)")
                isAwake = false
                message = (error as? LidSleepPreventionError)?.userMessage ?? "Unable to keep awake."
            }
        } else {
            stopAwakeSession()
        }
    }

    func quit() {
        stopAwakeSession()
    }

    private func stopAwakeSession() {
        do {
            try preventer.stopPreventingLidSleep()
        } catch {
            logger.error("Unable to restore lid sleep: \(String(describing: error), privacy: .public)")
        }

        isAwake = false
        message = nil
    }
}

final class PmsetLidSleepPreventer: LidSleepPreventing {
    private var isEnabled = false

    func startPreventingLidSleep() throws {
        try runPrivilegedPmset(disableSleep: true)
        isEnabled = true
    }

    func stopPreventingLidSleep() throws {
        guard isEnabled else { return }

        try runPrivilegedPmset(disableSleep: false)
        isEnabled = false
    }

    deinit {
        try? stopPreventingLidSleep()
    }

    private func runPrivilegedPmset(disableSleep: Bool) throws {
        let value = disableSleep ? "1" : "0"
        let toolPath = "/usr/bin/pmset"
        var authorization: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &authorization)
        guard createStatus == errAuthorizationSuccess, let authorization else {
            throw LidSleepPreventionError.commandFailed("authorization failed: \(createStatus)")
        }
        defer { AuthorizationFree(authorization, []) }

        let rightsStatus = kAuthorizationRightExecute.withCString { rightName in
            toolPath.withCString { tool in
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
            throw LidSleepPreventionError.commandFailed("authorization denied: \(rightsStatus)")
        }

        let executeStatus = toolPath.withCString { tool in
            var command = Array("disablesleep".utf8CString)
            var argument = Array(value.utf8CString)
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
        guard executeStatus == errAuthorizationSuccess else {
            throw LidSleepPreventionError.commandFailed("pmset failed: \(executeStatus)")
        }
    }
}
