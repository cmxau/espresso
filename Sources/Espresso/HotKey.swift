import Carbon.HIToolbox
import AppKit

final class HotKey {
    static let shared = HotKey()
    var handler: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var installed = false

    func register() {
        let p = Prefs.shared
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        guard p.hotkeyEnabled else { return }
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in HotKey.shared.handler?(); return noErr },
                                1, &spec, nil, nil)
            installed = true
        }
        RegisterEventHotKey(UInt32(p.hotkeyKey), UInt32(p.hotkeyMods), EventHotKeyID(signature: 0x45535052, id: 1),
                            GetApplicationEventTarget(), 0, &ref)
    }

    /// Records a combo (needs ctrl/opt/cmd). Returns false if invalid.
    func set(from e: NSEvent) -> Bool {
        let m = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !m.intersection([.command, .option, .control]).isEmpty else { return false }
        var mods = 0, label = ""
        if m.contains(.control) { mods |= controlKey; label += "⌃" }
        if m.contains(.option) { mods |= optionKey; label += "⌥" }
        if m.contains(.shift) { mods |= shiftKey; label += "⇧" }
        if m.contains(.command) { mods |= cmdKey; label += "⌘" }
        let p = Prefs.shared
        p.hotkeyKey = Int(e.keyCode)
        p.hotkeyMods = mods
        p.hotkeyLabel = label + (e.charactersIgnoringModifiers ?? "?").uppercased()
        p.hotkeyEnabled = true
        register()
        return true
    }
}
