import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    let manager = ProcessManager()
    private var cancellables = Set<AnyCancellable>()
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPanel()
        bindIconState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon(isActive: false)
    }

    private func bindIconState() {
        manager.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                let active = self.manager.projects.contains { self.manager.isActive(projectId: $0.id) }
                self.updateIcon(isActive: active)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(isActive: Bool) {
        let symbol = isActive ? "bolt.fill" : "bolt"
        let color: NSColor = isActive ? .systemGreen : .labelColor
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "AnythingManager")?
            .withSymbolConfiguration(config)
        statusItem.button?.image = image
    }

    private func setupPanel() {
        let contentView = ContentView(manager: manager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 440),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.moveToActiveSpace, .transient]
        panel.hasShadow = true
        panel.backgroundColor = NSColor.windowBackgroundColor
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        positionPanelBelowStatusItem()
        panel.makeKeyAndOrderFront(nil)
        startClickMonitor()
    }

    private func hidePanel() {
        panel.orderOut(nil)
        stopClickMonitor()
    }

    /// Hides the panel when the user clicks anywhere outside it
    /// (including other apps, the desktop, or other menu-bar items).
    /// Clicks on our own status-bar button are ignored so togglePanel()
    /// can handle open/close without fighting the monitor.
    private func startClickMonitor() {
        stopClickMonitor() // prevent duplicate monitors
        clickMonitor = NSEvent.addGlobalMonitorForEventsMatchingMask([.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.panel.isVisible else { return }

            let clickLocation = NSEvent.mouseLocation

            // Ignore clicks on the status-bar button — togglePanel handles those.
            if let button = self.statusItem.button,
               let buttonWindow = button.window {
                let buttonScreenRect = buttonWindow.convertToScreen(button.frame)
                if buttonScreenRect.contains(clickLocation) {
                    return
                }
            }

            // Ignore clicks inside the panel itself.
            if self.panel.frame.contains(clickLocation) {
                return
            }

            self.hidePanel()
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func positionPanelBelowStatusItem() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let screenRect = buttonWindow.convertToScreen(button.frame)
        let x = screenRect.midX - panel.frame.width / 2
        let y = screenRect.minY - panel.frame.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
