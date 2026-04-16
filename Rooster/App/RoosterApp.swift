import SwiftUI

@main
struct RoosterApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window. Settings are opened via SettingsWindowController.shared.show().
        // We keep a hidden Settings scene so SwiftUI is satisfied with a non-empty body.
        Settings {
            EmptyView()
        }
    }
}
