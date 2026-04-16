import SwiftUI
import ServiceManagement

struct SettingsView: View {

    // General
    @AppStorage("com.rooster.activateOnLaunch")          private var activateOnLaunch          = false
    @AppStorage("com.rooster.allowDisplaySleep")         private var allowDisplaySleep          = false
    @AppStorage("com.rooster.quitOnTimerExpiry")         private var quitOnTimerExpiry          = false
    @AppStorage("com.rooster.notificationsEnabled")      private var notificationsEnabled       = false

    // Battery
    @AppStorage("com.rooster.batteryThresholdEnabled")   private var batteryThresholdEnabled    = false
    @AppStorage("com.rooster.batteryThreshold")          private var batteryThreshold: Double   = 20

    // Advanced
    @AppStorage("com.rooster.deactivateOnLowPowerMode")  private var deactivateOnLowPowerMode   = false
    @AppStorage("com.rooster.activateOnExternalDisplay") private var activateOnExternalDisplay  = false
    @AppStorage("com.rooster.deactivateOnUserSwitch")    private var deactivateOnUserSwitch     = false

    @State private var loginItemEnabled = LoginItemManager.isEnabled

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            batteryTab
                .tabItem { Label("Battery", systemImage: "battery.75") }

            CrowScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar.badge.clock") }

            advancedTab
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }

            SessionLogView()
                .tabItem { Label("Log", systemImage: "clock.badge.checkmark") }

            urlSchemeTab
                .tabItem { Label("URL Scheme", systemImage: "link") }
        }
        .frame(width: 460, height: 420)
        .padding()
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Activate when Rooster launches", isOn: $activateOnLaunch)
                Toggle("Start at Login", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { newValue in
                        LoginItemManager.setEnabled(newValue)
                    }
            }

            Section("Behavior") {
                Toggle("Allow display to sleep", isOn: $allowDisplaySleep)
                Toggle("Quit when timer expires", isOn: $quitOnTimerExpiry)
                Toggle("Show notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { newValue in
                        if newValue { NotificationService.shared.requestAuthorization() }
                    }
            }

            Section("Keyboard Shortcut") {
                LabeledContent("Toggle Rooster") {
                    Text("⌥⌘K")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Quit Rooster") { NSApp.terminate(nil) }
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    private var batteryTab: some View {
        Form {
            Section {
                Toggle("Auto-deactivate below battery level", isOn: $batteryThresholdEnabled)
                if batteryThresholdEnabled {
                    HStack {
                        Slider(value: $batteryThreshold, in: 5...50, step: 5)
                        Text("\(Int(batteryThreshold))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            } footer: {
                Text("Rooster will deactivate when your battery drops to or below this level.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var advancedTab: some View {
        Form {
            Section("Power") {
                Toggle("Deactivate when Low Power Mode is on", isOn: $deactivateOnLowPowerMode)
            }

            Section("Display") {
                Toggle("Activate when an external display is connected", isOn: $activateOnExternalDisplay)
            }

            Section("User Accounts") {
                Toggle("Deactivate while another user account is active", isOn: $deactivateOnUserSwitch)
            }
        }
        .formStyle(.grouped)
    }

    private var urlSchemeTab: some View {
        Form {
            Section("Control Rooster from Terminal or Apple Shortcuts") {
                urlRow(label: "Activate indefinitely",  value: "rooster:///activate")
                urlRow(label: "Activate for 30 min",    value: "rooster:///activate?minutes=30")
                urlRow(label: "Activate for 2 hours",   value: "rooster:///activate?hours=2")
                urlRow(label: "Deactivate",              value: "rooster:///deactivate")
                urlRow(label: "Toggle",                  value: "rooster:///toggle")
            }

            Section("Example (Terminal)") {
                urlRow(label: "Open URL", value: "open \"rooster:///activate?minutes=30\"")
            }
        }
        .formStyle(.grouped)
    }

    private func urlRow(label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

