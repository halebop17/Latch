import Carbon.HIToolbox
import Foundation

/// File-level global so the Carbon C-function-pointer callback can reach the service
/// without capturing context (Swift requires @convention(c) closures to be non-capturing).
private var _globalHotKeyService: GlobalHotkeyService?

/// Registers ⌥⌘K as a system-wide hotkey using Carbon's RegisterEventHotKey.
/// Unlike NSEvent.addGlobalMonitorForEvents, this does NOT require Accessibility permission.
final class GlobalHotkeyService {

    static let shared = GlobalHotkeyService()

    /// Invoked on the main thread when the hotkey is pressed.
    var onToggle: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        _globalHotKeyService = self
    }

    func register() {
        guard eventHandlerRef == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Non-capturing closure — accesses the file-level global, not captured vars.
        // InstallApplicationEventHandler is a C macro unavailable in Swift; use
        // InstallEventHandler(GetApplicationEventTarget(), …) directly.
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

        // "RSTR" = 0x52535452 as FourCharCode
        var keyID = EventHotKeyID(signature: 0x52535452, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_K),          // K
            UInt32(cmdKey | optionKey),   // ⌘⌥
            keyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    deinit { unregister() }
}
