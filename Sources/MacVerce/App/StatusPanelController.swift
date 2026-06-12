import AppKit
import SwiftUI

@MainActor
final class StatusPanelController: NSObject, NSWindowDelegate {
    private static let panelWidth: CGFloat = 420
    private static let panelHeight: CGFloat = 540
    private static let panelScreenMargin: CGFloat = 8

    private let settings: AppSettings
    private let monitor: DeploymentMonitor
    private let appUpdater: AppUpdater
    private let refresh: () -> Void
    private let openSettings: () -> Void
    private let quit: () -> Void

    private let statusItem: NSStatusItem
    private var panel: NSPanel?
    private var clickMonitor: Any?
    private var loaderTimer: Timer?
    private var loaderTick = 0

    init(
        settings: AppSettings,
        monitor: DeploymentMonitor,
        appUpdater: AppUpdater,
        refresh: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.settings = settings
        self.monitor = monitor
        self.appUpdater = appUpdater
        self.refresh = refresh
        self.openSettings = openSettings
        self.quit = quit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.autosaveName = AppConstants.statusItemAutosaveName
        statusItem.isVisible = true
        configureButton(retriesLeft: 5)
    }

    func updateStatusItem() {
        if monitor.hasActiveDeployment {
            startLoaderTimer()
            renderLoaderTitle()
        } else {
            stopLoaderTimer()
            renderDefaultTitle()
        }
    }

    private func renderDefaultTitle() {
        guard let button = statusItem.button else { return }

        let title = NSMutableAttributedString(
            string: "● ",
            attributes: [
                .foregroundColor: monitor.menuBarColor,
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
            ]
        )
        title.append(
            NSAttributedString(
                string: "Vercel",
                attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium)
                ]
            )
        )

        button.attributedTitle = title
        button.toolTip = monitor.menuBarToolTip
        button.setAccessibilityLabel(monitor.menuBarToolTip)
    }

    private func renderLoaderTitle() {
        guard let button = statusItem.button else { return }

        let bars = 10
        let title = NSMutableAttributedString()
        for index in 0..<bars {
            let distance = (index - loaderTick + bars) % bars
            let alpha: CGFloat

            switch distance {
            case 0:
                alpha = 1
            case 1, bars - 1:
                alpha = 0.72
            case 2, bars - 2:
                alpha = 0.44
            default:
                alpha = 0.2
            }

            title.append(
                NSAttributedString(
                    string: "|",
                    attributes: [
                        .foregroundColor: monitor.menuBarColor.withAlphaComponent(alpha),
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
                    ]
                )
            )
        }

        button.attributedTitle = title
        button.toolTip = monitor.menuBarToolTip
        button.setAccessibilityLabel("Mac Verce: deployment in progress")
    }

    private func startLoaderTimer() {
        guard loaderTimer == nil else { return }

        loaderTimer = Timer.scheduledTimer(withTimeInterval: 0.14, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.loaderTick = (self.loaderTick + 1) % 10
                self.renderLoaderTitle()
            }
        }
    }

    private func stopLoaderTimer() {
        loaderTimer?.invalidate()
        loaderTimer = nil
        loaderTick = 0
    }

    func showPanelWhenReady(retriesLeft: Int = 8) {
        guard statusItem.button?.window != nil else {
            guard retriesLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.showPanelWhenReady(retriesLeft: retriesLeft - 1)
            }
            return
        }

        showPanel()
    }

    func hidePanel() {
        panel?.orderOut(nil)
        statusItem.button?.highlight(false)
        removeClickMonitor()
    }

    private func configureButton(retriesLeft: Int) {
        guard let button = statusItem.button else {
            guard retriesLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.configureButton(retriesLeft: retriesLeft - 1)
            }
            return
        }

        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.isVisible = true
        updateStatusItem()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        refresh()
        position(panel)
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        installClickMonitor()
    }

    private func makePanel() -> NSPanel {
        let rootView = DashboardView(
            settings: settings,
            monitor: monitor,
            appUpdater: appUpdater,
            refresh: refresh,
            checkForUpdates: { [weak self] in
                self?.checkForUpdates()
            },
            openSettings: { [weak self] in
                self?.hidePanel()
                self?.openSettings()
            },
            quit: quit
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: Self.panelWidth,
            height: Self.panelHeight
        )

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let buttonWindow = statusItem.button?.window else { return }

        let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? buttonWindow.frame
        let size = panel.frame.size
        let buttonFrame = buttonWindow.frame

        var x = buttonFrame.midX - size.width / 2
        x = min(max(x, visible.minX + Self.panelScreenMargin), visible.maxX - size.width - Self.panelScreenMargin)

        let y = buttonFrame.minY - 6 - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Mac Verce", action: #selector(openFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = appUpdater.canCheckForUpdates
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mac Verce", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openFromMenu() {
        showPanel()
    }

    @objc private func refreshFromMenu() {
        refresh()
    }

    @objc private func checkForUpdatesFromMenu() {
        checkForUpdates()
    }

    @objc private func settingsFromMenu() {
        hidePanel()
        openSettings()
    }

    private func checkForUpdates() {
        appUpdater.checkForUpdates()
    }

    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hidePanel()
            }
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
