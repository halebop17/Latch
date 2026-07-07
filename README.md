# Latch 🐙

**Latch** keeps your Mac awake — a macOS menu bar app entirely in Swift with exclusive features.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

---

## Features

### Core
- **One-click toggle** — click the menu bar icon to keep your Mac awake
- **Duration presets** — 5 min · 15 min · 30 min · 1 h · 2 h · 5 h · Indefinite
- **Until…** — stay awake until a chosen clock time, and **Extend by 15 min** on a running timer
- **Live countdown** in the menu bar (`🐙 1:47`)
- **Choice of menu bar icon** — Octopus (default), Meerkat, or Night Owl, each with an awake/asleep state
- **Allow display sleep** — keep the system awake but let the screen turn off
- **Quit on timer expiry** option

### Smart Auto-Activation
- **Schedule** — define weekly time windows (e.g. Mon–Fri 9:00–18:00) where Latch activates automatically
- **External display** — auto-activate when a monitor is connected
- **Restore on user switch** — resumes the previous session after fast-user-switching back

### Smart Auto-Deactivation
- **Battery threshold** — deactivates below a configurable % (default 20%), on battery only
- **Low Power Mode** — deactivates automatically when Low Power Mode turns on
- **Focus** — deactivates while a Focus mode is engaged (requires Full Disk Access)

### Developer / Power-User
- **Global hotkey** — toggle from anywhere (default ⌥⌘K, configurable), no Accessibility permission required
- **URL scheme** — scriptable from Terminal or Apple Shortcuts:
  ```
  open "latch:///activate?minutes=30"
  open "latch:///deactivate"
  open "latch:///toggle"
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
1. Download `Latch.dmg` from the [latest release](https://github.com/halebop17/Latch/releases/latest)
2. Open the DMG and drag **Latch.app** to `/Applications`
3. Launch Latch — the octopus icon appears in your menu bar

### Homebrew (coming soon)
```bash
brew install --cask latch
```

---

## Building from Source

```bash
# Prerequisites
brew install xcodegen

# Clone and build
git clone https://github.com/halebop17/Latch.git
cd Latch
xcodegen generate
xcodebuild -scheme Latch -configuration Debug -derivedDataPath .build build
open .build/Build/Products/Debug/Latch.app
```

### Regenerating assets
The menu bar icons, app icon, and activation sound are drawn/synthesized in code:
```bash
swift tools/make-status-icons.swift --emit   # Octopus / Meerkat / Night Owl glyphs
swift tools/make-app-icon.swift              # AppIcon
swift tools/make-crow-sound.swift            # activation chime
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
| `latch:///activate` | Activate indefinitely |
| `latch:///activate?minutes=N` | Activate for N minutes |
| `latch:///activate?hours=N` | Activate for N hours |
| `latch:///activate?seconds=N` | Activate for N seconds |
| `latch:///deactivate` | Deactivate |
| `latch:///toggle` | Toggle current state |

---

## Architecture

Latch is 100% Swift. No private APIs, no IOKit calls from the app — everything goes through `/usr/bin/caffeinate`, Apple's own official sleep-prevention tool, tied to the app's PID with `-w` so it auto-exits if the app crashes.

```
CaffeineService      — spawns / kills caffeinate subprocess
AwakeManager         — state machine, wires all services together
StatusItemController — NSStatusItem, icon, countdown display
CrowScheduleService  — 30s tick checks time-window schedules
GlobalHotkeyService  — Carbon RegisterEventHotKey (no Accessibility needed)
FocusModeMonitor     — reads the Do Not Disturb assertions file (needs Full Disk Access)
SessionLogService    — persists last 50 sessions to UserDefaults
BatteryMonitor       — IOKit.ps polling every 60s
LowPowerModeMonitor  — KVO on ProcessInfo.isLowPowerModeEnabled
DisplayMonitor       — NSApplication.didChangeScreenParametersNotification
```
