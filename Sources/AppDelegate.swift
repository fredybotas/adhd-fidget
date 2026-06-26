import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayPanel: NSPanel?
    private var ballView: BallView?
    private var isShowing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "FidgetBall")?
            .withSymbolConfiguration(config)
        button.image?.isTemplate = true
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit FidgetBall", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleBall()
        }
    }

    private func toggleBall() {
        if isShowing {
            overlayPanel?.orderOut(nil)
            isShowing = false
        } else {
            showBall()
        }
    }

    private func showBall() {
        guard let screen = NSScreen.main else { return }

        if overlayPanel == nil {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let anchor = anchorPoint(on: screen)
            let view = BallView(frame: screen.frame, anchor: anchor)
            panel.contentView = view
            ballView = view
            overlayPanel = panel
        }

        overlayPanel?.orderFront(nil)
        isShowing = true
    }

    private func anchorPoint(on screen: NSScreen) -> CGPoint {
        let barThickness = NSStatusBar.system.thickness
        let anchorY = screen.frame.height - barThickness / 2

        if let button = statusItem.button, let win = button.window {
            let frameInScreen = win.convertToScreen(button.frame)
            let anchorX = frameInScreen.midX - screen.frame.minX
            return CGPoint(x: anchorX, y: anchorY)
        }
        return CGPoint(x: screen.frame.width / 2, y: anchorY)
    }
}
