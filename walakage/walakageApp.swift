import AppKit
import SwiftUI

@main
struct WalakageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var didConfirmLidSleepApproval = false
    @StateObject private var session = AwakeSessionController()

    var body: some Scene {
        MenuBarExtra {
            PanelView(session: session, setKeepAwake: setKeepAwake) {
                session.quit()
                NSApp.terminate(nil)
            }
        } label: {
            Image("StatusIcon")
                .renderingMode(.template)
                .opacity(session.isAwake ? 1 : 0.35)
                .accessibilityLabel("Walakage")
        }
        .menuBarExtraStyle(.window)
    }

    private func setKeepAwake(_ keepAwake: Bool) {
        guard keepAwake else {
            session.setKeepAwake(false)
            return
        }

        guard !session.isStartBlocked else {
            session.setKeepAwake(true)
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
