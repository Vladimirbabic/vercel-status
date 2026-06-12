import AppKit
import SwiftUI

@MainActor
final class NotchIslandController {
    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?

    func show(deployment: VercelDeployment) {
        dismissTask?.cancel()

        let content = NotchIslandView(deployment: deployment)
        let controller = NSHostingController(rootView: content)
        let islandSize = NSSize(width: 430, height: 86)

        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: islandSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.ignoresMouseEvents = false
            window = panel
        }

        guard let window else { return }
        window.contentViewController = controller
        window.setFrame(frame(for: islandSize), display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4.2))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard let window else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: { [weak window] in
            Task { @MainActor in
                window?.orderOut(nil)
            }
        }
    }

    private func frame(for size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.maxY - size.height - 10
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
