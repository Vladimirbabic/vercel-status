import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var monitor = DeploymentMonitor(settings: settings)
    private lazy var notchController = NotchIslandController()
    private lazy var settingsWindowController = SettingsWindowController(settings: settings, monitor: monitor)
    private var statusPanelController: StatusPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusPanelController = StatusPanelController(
            settings: settings,
            monitor: monitor,
            refresh: { [weak self] in self?.monitor.refreshNow() },
            openSettings: { [weak self] in self?.settingsWindowController.showWindow(nil) },
            quit: { NSApp.terminate(nil) }
        )

        settings.onPollingPreferencesChanged = { [weak self] in
            self?.monitor.restartPolling()
        }

        monitor.onDeploymentSucceeded = { [weak self] deployment in
            self?.notchController.show(deployment: deployment)
        }

        monitor.onStateChanged = { [weak self] in
            self?.statusPanelController?.updateStatusItem()
        }

        monitor.start()
        statusPanelController?.updateStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.synchronize()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusPanelController?.showPanelWhenReady()
        return false
    }
}
