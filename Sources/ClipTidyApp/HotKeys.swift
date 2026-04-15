import Carbon.HIToolbox
import Foundation

/// Global hotkeys through the Carbon event API. Unlike a keyboard event monitor this
/// needs no Accessibility permission, and it works while any app is in front.
final class HotKeyCenter {
    struct Binding {
        let id: UInt32
        let keyCode: Int
        let label: String
    }

    static let signature: OSType = 0x434C5444  // "CLTD"

    let onPress: () -> Void
    private var refs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    /// Registers each binding with Control+Option+Command. Returns the labels of the
    /// bindings that could not be registered, usually because another app owns them.
    func register(_ bindings: [Binding]) -> [String] {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyHandler, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        guard installed == noErr else { return bindings.map(\.label) }

        let modifiers = UInt32(cmdKey | optionKey | controlKey)
        var failed: [String] = []
        for binding in bindings {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: binding.id)
            let status = RegisterEventHotKey(UInt32(binding.keyCode), modifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
            } else {
                failed.append(binding.label)
            }
        }
        return failed
    }

    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        if let handlerRef { RemoveEventHandler(handlerRef) }
        handlerRef = nil
    }

    deinit { unregister() }
}

private func hotKeyHandler(
    _ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }
    var id = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr, id.signature == HotKeyCenter.signature else { return noErr }
    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { center.onPress() }
    return noErr
}
