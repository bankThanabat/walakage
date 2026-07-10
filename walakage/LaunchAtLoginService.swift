import ServiceManagement

@MainActor
protocol LaunchAtLoginManaging: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
final class SystemLaunchAtLoginManager: LaunchAtLoginManaging {
    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
