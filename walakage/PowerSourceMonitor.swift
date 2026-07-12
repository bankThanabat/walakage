import AppKit
import Foundation
import IOKit.ps

struct PowerState: Equatable {
    enum Supply: Equatable {
        case external
        case battery
        case unknown
    }

    let isBatteryMac: Bool
    let supply: Supply
    let batteryPercentage: Int?
}

@MainActor
protocol PowerMonitoring: AnyObject {
    func currentState() -> PowerState
    func startMonitoring(handler: @escaping () -> Void)
}

@MainActor
final class SystemPowerSourceMonitor: PowerMonitoring {
    private let workspaceNotificationCenter: NotificationCenter
    private var handler: (() -> Void)?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var wakeObserver: NSObjectProtocol?

    init(workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.workspaceNotificationCenter = workspaceNotificationCenter
    }

    func currentState() -> PowerState {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerState(isBatteryMac: false, supply: .unknown, batteryPercentage: nil)
        }

        let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [Any] ?? []
        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source as CFTypeRef)?
                    .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                description[kIOPSIsPresentKey] as? Bool != false
            else { continue }

            return PowerState(
                isBatteryMac: true,
                supply: Self.supply(from: description[kIOPSPowerSourceStateKey] as? String),
                batteryPercentage: Self.percentage(from: description)
            )
        }

        let providingSource = IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String
        return PowerState(
            isBatteryMac: false,
            supply: Self.supply(from: providingSource),
            batteryPercentage: nil
        )
    }

    func startMonitoring(handler: @escaping () -> Void) {
        self.handler = handler

        if powerSourceRunLoopSource == nil,
           let source = IOPSNotificationCreateRunLoopSource({ context in
               guard let context else { return }
               let monitor = Unmanaged<SystemPowerSourceMonitor>
                   .fromOpaque(context)
                   .takeUnretainedValue()
               Task { @MainActor in
                   monitor.notifyChange()
               }
           }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue() {
            powerSourceRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if wakeObserver == nil {
            wakeObserver = workspaceNotificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.notifyChange()
                }
            }
        }
    }

    deinit {
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .commonModes)
        }
        if let wakeObserver {
            workspaceNotificationCenter.removeObserver(wakeObserver)
        }
    }

    private func notifyChange() {
        handler?()
    }

    private nonisolated static func supply(from value: String?) -> PowerState.Supply {
        switch value {
        case kIOPSACPowerValue:
            return .external
        case kIOPSBatteryPowerValue:
            return .battery
        default:
            return .unknown
        }
    }

    private nonisolated static func percentage(from description: [String: Any]) -> Int? {
        guard
            let current = description[kIOPSCurrentCapacityKey] as? NSNumber,
            let maximum = description[kIOPSMaxCapacityKey] as? NSNumber,
            maximum.doubleValue > 0
        else { return nil }

        let percentage = Int((current.doubleValue * 100 / maximum.doubleValue).rounded())
        return min(100, max(0, percentage))
    }
}
