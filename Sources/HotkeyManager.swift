import AppKit
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onToggle: (() -> Void)?
    var onReset: (() -> Void)?

    private var showRef: EventHotKeyRef?
    private var resetRef: EventHotKeyRef?

    private init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let event = event else { return noErr }
                var hkID = EventHotKeyID()
                _ = withUnsafeMutablePointer(to: &hkID) {
                    GetEventParameter(event,
                                      EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID),
                                      nil,
                                      MemoryLayout<EventHotKeyID>.size,
                                      nil,
                                      UnsafeMutableRawPointer($0))
                }
                if hkID.id == 1 { HotkeyManager.shared.onToggle?() }
                if hkID.id == 2 { HotkeyManager.shared.onReset?() }
                return noErr
            },
            1, &spec, nil, nil
        )
    }

    func update() {
        if let r = showRef  { UnregisterEventHotKey(r) }; showRef  = nil
        if let r = resetRef { UnregisterEventHotKey(r) }; resetRef = nil

        let s = BallSettings.shared
        if s.showKeyCode >= 0 {
            let id = EventHotKeyID(signature: 0x46424C4C, id: 1)
            RegisterEventHotKey(UInt32(s.showKeyCode), carbonMods(s.showModifiers),
                                id, GetApplicationEventTarget(), 0, &showRef)
        }
        if s.resetKeyCode >= 0 {
            let id = EventHotKeyID(signature: 0x46424C4C, id: 2)
            RegisterEventHotKey(UInt32(s.resetKeyCode), carbonMods(s.resetModifiers),
                                id, GetApplicationEventTarget(), 0, &resetRef)
        }
    }
}

private func carbonMods(_ flags: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.command) { m |= UInt32(cmdKey) }
    if flags.contains(.shift)   { m |= UInt32(shiftKey) }
    if flags.contains(.option)  { m |= UInt32(optionKey) }
    if flags.contains(.control) { m |= UInt32(controlKey) }
    return m
}
