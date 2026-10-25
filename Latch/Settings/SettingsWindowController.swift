import AppKit
import SwiftUI

/// A simple NSWindowController that hosts SettingsView.
/// Bypasses SwiftUI's Settings scene internals, which are unreliable
/// for .accessory activation-policy (menu-bar-only) apps.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Latch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setFrameAutosaveName("LatchSettingsFrame")
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Opens Settings, optionally switching to a given tab (a SettingsView.Tab raw value).
    func show(tab: String? = nil) {
        if let tab { UserDefaults.standard.set(tab, forKey: SettingsView.selectedTabKey) }
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
        } else {
            showWindow(nil)
        }
    }

    // Keep window level sensible when app is a background accessory
    func windowDidBecomeKey(_ notification: Notification) {
        window?.level = .floating
    }

    func windowDidResignKey(_ notification: Notification) {
        window?.level = .normal
    }
}
