# Rooster <img src="images/wakeup-rooster-36.png" alt="Rooster" width="28" valign="middle">

**Rooster** keeps your Mac awake — a macOS menu bar app inspired by [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake), rebuilt entirely in Swift with exclusive new features.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

---

## Features

### Core
- **One-click toggle** — click the menu bar icon to keep your Mac awake
- **Duration presets** — 5 min · 15 min · 30 min · 1 h · 2 h · 5 h · Indefinite
- **Live countdown** in the menu bar (`🐓 1:47`)
- **Allow display sleep** — keep the system awake but let the screen turn off
- **Quit on timer expiry** option

### Smart Auto-Activation
- **Crow Schedule** — define weekly time windows (e.g. Mon–Fri 9:00–18:00) where Rooster activates automatically
- **External display** — auto-activate when a monitor is connected
- **Restore on user switch** — resumes the previous session after fast-user-switching back

### Smart Auto-Deactivation
- **Battery threshold** — deactivates below a configurable % (default 20%)
- **Low Power Mode** — deactivates automatically when Low Power Mode turns on

### Developer / Power-User
- **Global hotkey** ⌥⌘K — toggle from anywhere, no Accessibility permission required
- **URL scheme** — scriptable from Terminal or Apple Shortcuts:
  ```
  open "rooster:///activate?minutes=30"
  open "rooster:///deactivate"
  open "rooster:///toggle"
  ```
- **Apple Shortcuts** — three intents: Activate, Deactivate, Toggle
- **Session log** — view the last 50 awake sessions with duration and reason
- **Start at Login** via `SMAppService` (no helper app needed)
- **Notifications** on activate/deactivate

---

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel

---

## Installation

### Direct Download
1. Download `Rooster.dmg` from the [latest release](https://github.com/YOUR_GITHUB_USER/rooster/releases/latest)
2. Open the DMG and drag **Rooster.app** to `/Applications`
3. Launch Rooster — the rooster icon appears in your menu bar

### Homebrew (coming soon)
```bash
brew install --cask rooster
```

---

## Building from Source

```bash
# Prerequisites
brew install xcodegen

# Clone and build
git clone https://github.com/YOUR_GITHUB_USER/rooster.git
cd rooster
xcodegen generate
xcodebuild -scheme Rooster -configuration Debug -derivedDataPath .build build
open .build/Build/Products/Debug/Rooster.app
```

### Package a DMG
```bash
# Optional: brew install create-dmg  (for a styled installer window)
./Distribution/build-dmg.sh
```

---

## URL Scheme Reference

| URL | Action |
|-----|--------|
| `rooster:///activate` | Activate indefinitely |
| `rooster:///activate?minutes=N` | Activate for N minutes |
| `rooster:///activate?hours=N` | Activate for N hours |
| `rooster:///activate?seconds=N` | Activate for N seconds |
| `rooster:///deactivate` | Deactivate |
| `rooster:///toggle` | Toggle current state |

---

## Architecture

Rooster is 100% Swift. No private APIs, no IOKit calls from the app — everything goes through `/usr/bin/caffeinate`, Apple's own official sleep-prevention tool, tied to the app's PID with `-w` so it auto-exits if the app crashes.

```
CaffeineService      — spawns / kills caffeinate subprocess
AwakeManager         — state machine, wires all services together
StatusItemController — NSStatusItem, icon, countdown display
CrowScheduleService  — 30s tick checks time-window schedules
GlobalHotkeyService  — Carbon RegisterEventHotKey (no Accessibility needed)
SessionLogService    — persists last 50 sessions to UserDefaults
BatteryMonitor       — IOKit.ps polling every 60s
LowPowerModeMonitor  — KVO on ProcessInfo.isLowPowerModeEnabled
DisplayMonitor       — NSApplication.didChangeScreenParametersNotification
```

---

## License

MIT — see [LICENSE](LICENSE)
