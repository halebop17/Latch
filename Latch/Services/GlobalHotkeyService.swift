import AppKit
import Carbon.HIToolbox

/// File-level global so the Carbon C-function-pointer callback can reach the service
/// without capturing context (Swift requires @convention(c) closures to be non-capturing).
private var _globalHotKeyService: GlobalHotkeyService?

/// Registers a system-wide hotkey (default ⌥⌘K, user-configurable in Settings)
/// using Carbon's RegisterEventHotKey.
/// Unlike NSEvent.addGlobalMonitorForEvents, this does NOT require Accessibility permission.
final class GlobalHotkeyService {

    static let shared = GlobalHotkeyService()

    /// Invoked on the main thread when the hotkey is pressed.
    var onToggle: (() -> Void)?

    static let defaultKeyCode = kVK_ANSI_K
    static let defaultModifiers = cmdKey | optionKey
    static let defaultDisplay = "⌥⌘K"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        _globalHotKeyService = self
    }

    /// (Re)registers the hotkey from AppSettings. Call again after the combo changes.
    func register() {
        installHandlerIfNeeded()
        unregisterHotkey()
        guard AppSettings.hotkeyEnabled else { return }

        let keyCode = AppSettings.hotkeyKeyCode ?? Self.defaultKeyCode
        let modifiers = AppSettings.hotkeyModifiers ?? Self.defaultModifiers

        // "RSTR" = 0x52535452 as FourCharCode
        let keyID = EventHotKeyID(signature: 0x52535452, id: 1)
        RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            keyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    /// Releases just the key combination (used while the Settings recorder captures keys).
    func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    func unregister() {
        unregisterHotkey()
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Non-capturing closure — accesses the file-level global, not captured vars.
        let callback: EventHandlerUPP = { (_, _, _) -> OSStatus in
            _globalHotKeyService?.onToggle?()
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            nil,
            &eventHandlerRef
        )
    }

    deinit { unregister() }

    // MARK: - Recording helpers (used by the Settings hotkey recorder)

    /// Converts a keyDown event into a persistable hotkey. Returns nil unless at
    /// least one of ⌘ ⌥ ⌃ is held — a bare key would hijack normal typing.
    static func capture(_ event: NSEvent) -> (keyCode: Int, modifiers: Int, display: String)? {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control) else {
            return nil
        }
        var carbon = 0
        var display = ""
        if flags.contains(.control) { carbon |= controlKey; display += "⌃" }
        if flags.contains(.option)  { carbon |= optionKey;  display += "⌥" }
        if flags.contains(.shift)   { carbon |= shiftKey;   display += "⇧" }
        if flags.contains(.command) { carbon |= cmdKey;     display += "⌘" }
        display += keyName(for: event)
        return (Int(event.keyCode), carbon, display)
    }

    private static func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:      return "Space"
        case kVK_Return:     return "↩"
        case kVK_Tab:        return "⇥"
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        default: break
        }
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty,
           let scalar = chars.unicodeScalars.first,
           scalar.value >= 32, scalar.value < 0xF700 {  // printable, not a function key
            return chars.uppercased()
        }
        return "Key \(event.keyCode)"
    }
}
