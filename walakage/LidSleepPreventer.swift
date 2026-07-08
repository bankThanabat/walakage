import Darwin
import Foundation
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

final class PmsetLidSleepPreventer: LidSleepPreventing {
    private let toolPath = "/usr/bin/pmset"
    private var isEnabled = false

    func startPreventingLidSleep() throws {
        try runPrivilegedPmset("1")
        isEnabled = true
    }

    func stopPreventingLidSleep() throws {
        guard isEnabled else { return }

        try runPrivilegedPmset("0")
        isEnabled = false
    }

    deinit {
        try? stopPreventingLidSleep()
    }

    private func runPrivilegedPmset(_ disablesleepValue: String) throws {
        let authorization = try authorizePmset()
        defer { AuthorizationFree(authorization, []) }

        let status = executePmset(disablesleepValue, authorization: authorization)
        guard status == errAuthorizationSuccess else {
            throw LidSleepPreventionError.commandFailed("pmset failed: \(status)")
        }
    }

    private func authorizePmset() throws -> AuthorizationRef {
        var authorization: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &authorization)
        guard createStatus == errAuthorizationSuccess, let authorization else {
            throw LidSleepPreventionError.commandFailed("authorization failed: \(createStatus)")
        }

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
            AuthorizationFree(authorization, [])
            throw LidSleepPreventionError.commandFailed("authorization denied: \(rightsStatus)")
        }

        return authorization
    }

    private func executePmset(_ disablesleepValue: String, authorization: AuthorizationRef) -> OSStatus {
        toolPath.withCString { tool in
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
