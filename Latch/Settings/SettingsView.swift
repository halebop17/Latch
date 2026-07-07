import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {

    // General
    @AppStorage("com.latch.activateOnLaunch")          private var activateOnLaunch          = false
    @AppStorage("com.latch.allowDisplaySleep")         private var allowDisplaySleep          = false
    @AppStorage("com.latch.quitOnTimerExpiry")         private var quitOnTimerExpiry          = false
    @AppStorage("com.latch.notificationsEnabled")      private var notificationsEnabled       = false
    @AppStorage("com.latch.playCrowSound")             private var playCrowSound              = false
    @AppStorage("com.latch.defaultDurationSeconds")    private var defaultDurationSeconds: Double = 0
    @AppStorage("com.latch.menuBarIconStyle")          private var menuBarIconStyle           = MenuBarIconStyle.octopus.rawValue

    // Hotkey
    @AppStorage("com.latch.hotkeyEnabled")             private var hotkeyEnabled              = true
    @AppStorage("com.latch.hotkeyDisplay")             private var hotkeyDisplay              = GlobalHotkeyService.defaultDisplay
    @State private var isRecordingHotkey = false
    @State private var hotkeyMonitor: Any?

    // Battery
    @AppStorage("com.latch.batteryThresholdEnabled")   private var batteryThresholdEnabled    = false
    @AppStorage("com.latch.batteryThreshold")          private var batteryThreshold: Double   = 20

    // Advanced
    @AppStorage("com.latch.deactivateOnLowPowerMode")  private var deactivateOnLowPowerMode   = false
    @AppStorage("com.latch.activateOnExternalDisplay") private var activateOnExternalDisplay  = false
    @AppStorage("com.latch.deactivateOnUserSwitch")    private var deactivateOnUserSwitch     = false
    @AppStorage("com.latch.deactivateOnFocus")         private var deactivateOnFocus          = false
    @ObservedObject private var focusMonitor = AwakeManager.shared.focusMonitor

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
        .frame(width: 460, height: 480)
        .padding()
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Activate when Latch launches", isOn: $activateOnLaunch)
                Toggle("Start at Login", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { newValue in
                        LoginItemManager.setEnabled(newValue)
                    }
            }

            Section("Behavior") {
                Picker("Clicking the icon activates for", selection: $defaultDurationSeconds) {
                    ForEach(ActivationDuration.allCases) { duration in
                        Text(duration.displayName).tag(duration.seconds)
                    }
                }
                Toggle("Allow display to sleep", isOn: $allowDisplaySleep)
                Toggle("Quit when timer expires", isOn: $quitOnTimerExpiry)
                Toggle("Show notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { newValue in
                        if newValue { NotificationService.shared.requestAuthorization() }
                    }
                Toggle("Play crow sound when activating", isOn: $playCrowSound)
            }

            Section("Menu Bar Icon") {
                Picker("Style", selection: $menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: menuBarIconStyle) { _ in
                    NotificationCenter.default.post(name: MenuBarIconStyle.didChangeNotification, object: nil)
                }
                HStack(spacing: 28) {
                    iconPreview(active: true, label: "Active")
                    iconPreview(active: false, label: "Inactive")
                    Spacer()
                }
                .padding(.vertical, 2)
            }

            Section("Keyboard Shortcut") {
                Toggle("Enable global shortcut", isOn: $hotkeyEnabled)
                    .onChange(of: hotkeyEnabled) { _ in
                        stopHotkeyRecording()
                        GlobalHotkeyService.shared.register()
                    }
                if hotkeyEnabled {
                    LabeledContent("Toggle Latch") {
                        HStack(spacing: 8) {
                            Button(isRecordingHotkey ? "Press keys…" : hotkeyDisplay) {
                                isRecordingHotkey ? stopHotkeyRecording() : startHotkeyRecording()
                            }
                            .font(.system(.body, design: .monospaced))
                            if !isRecordingHotkey && hotkeyDisplay != GlobalHotkeyService.defaultDisplay {
                                Button("Reset") { resetHotkey() }
                            }
                        }
                    }
                }
            }

            Section {
                Button("Quit Latch") { NSApp.terminate(nil) }
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onDisappear { stopHotkeyRecording() }
    }

    private func iconPreview(active: Bool, label: String) -> some View {
        let style = MenuBarIconStyle(rawValue: menuBarIconStyle) ?? .octopus
        let assetName = active ? style.activeAssetName : style.inactiveAssetName
        return HStack(spacing: 6) {
            if let image = NSImage(named: assetName) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Hotkey recording

    private func startHotkeyRecording() {
        guard !isRecordingHotkey else { return }
        isRecordingHotkey = true
        // Release the current combo so pressing it while recording doesn't toggle Latch.
        GlobalHotkeyService.shared.unregisterHotkey()
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {  // Escape cancels
                stopHotkeyRecording()
                return nil
            }
            if let combo = GlobalHotkeyService.capture(event) {
                AppSettings.hotkeyKeyCode = combo.keyCode
                AppSettings.hotkeyModifiers = combo.modifiers
                hotkeyDisplay = combo.display
                stopHotkeyRecording()
                return nil
            }
            return nil  // swallow keystrokes while recording
        }
    }

    private func stopHotkeyRecording() {
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
        isRecordingHotkey = false
        GlobalHotkeyService.shared.register()
    }

    private func resetHotkey() {
        AppSettings.hotkeyKeyCode = nil
        AppSettings.hotkeyModifiers = nil
        hotkeyDisplay = GlobalHotkeyService.defaultDisplay
        GlobalHotkeyService.shared.register()
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
                Text("Latch will deactivate when your battery drops to or below this level.")
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

            Section("Focus") {
                Toggle("Deactivate when a Focus mode is on", isOn: $deactivateOnFocus)
                    .onChange(of: deactivateOnFocus) { newValue in
                        if newValue { focusMonitor.probeAvailability() }
                    }
                if deactivateOnFocus && !focusMonitor.isAvailable {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latch can't see your Focus state yet. Grant it Full Disk Access under System Settings → Privacy & Security, then relaunch Latch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Privacy Settings") {
                            let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
                            if let url = URL(string: url) { NSWorkspace.shared.open(url) }
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Display") {
                Toggle("Activate when an external display is connected", isOn: $activateOnExternalDisplay)
            }

            Section("User Accounts") {
                Toggle("Deactivate while another user account is active", isOn: $deactivateOnUserSwitch)
            }
        }
        .formStyle(.grouped)
        .onAppear { focusMonitor.probeAvailability() }
    }

    private var urlSchemeTab: some View {
        Form {
            Section("Control Latch from Terminal or Apple Shortcuts") {
                urlRow(label: "Activate indefinitely",  value: "latch:///activate")
                urlRow(label: "Activate for 30 min",    value: "latch:///activate?minutes=30")
                urlRow(label: "Activate for 2 hours",   value: "latch:///activate?hours=2")
                urlRow(label: "Deactivate",              value: "latch:///deactivate")
                urlRow(label: "Toggle",                  value: "latch:///toggle")
            }

            Section("Example (Terminal)") {
                urlRow(label: "Open URL", value: "open \"latch:///activate?minutes=30\"")
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

