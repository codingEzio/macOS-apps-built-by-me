import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var contentView: ContentView!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupPanel()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "command.square.fill",
            accessibilityDescription: "AnythingManager"
        )
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func setupPanel() {
        contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 420)
        
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.moveToActiveSpace, .transient]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            positionPanelBelowStatusItem()
            panel.makeKeyAndOrderFront(nil)
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
