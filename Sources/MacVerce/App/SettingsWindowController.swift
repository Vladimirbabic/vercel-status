import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings, monitor: DeploymentMonitor) {
        let rootView = SettingsView(settings: settings, monitor: monitor)
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vibe Check Settings"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true {
            window?.center()
        }
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
