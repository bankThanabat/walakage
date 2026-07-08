import AppKit
import SwiftUI

@main
struct WalakageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("didConfirmLidSleepApproval") private var didConfirmLidSleepApproval = false
    @StateObject private var session = AwakeSessionController()

    var body: some Scene {
        MenuBarExtra {
            Toggle("Keep Awake", isOn: Binding(
                get: { session.isAwake },
                set: { setKeepAwake($0) }
            ))

            if let message = session.message {
                Text(message)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit Walakage") {
                session.quit()
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: "cup.and.saucer.fill")
                .opacity(session.isAwake ? 1 : 0.35)
        }
        .menuBarExtraStyle(.menu)
    }

    private func setKeepAwake(_ keepAwake: Bool) {
        guard keepAwake else {
            session.setKeepAwake(false)
            return
        }

        guard didConfirmLidSleepApproval || confirmLidSleepApproval() else { return }

        session.setKeepAwake(true)
        if session.isAwake {
            didConfirmLidSleepApproval = true
        }
    }

    private func confirmLidSleepApproval() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Allow Walakage to prevent lid sleep?"
        alert.informativeText = "macOS will ask for an administrator password to change sleep settings. Walakage restores normal lid sleep when you turn Keep Awake off or quit."
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
