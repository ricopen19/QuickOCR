import Carbon.HIToolbox
import AppKit

/// Carbon RegisterEventHotKey によるグローバルホットキー登録。
/// アクセシビリティ権限不要・イベント消費可（他アプリにキーが漏れない）。
final class HotkeyService: @unchecked Sendable {
    var onHotkeyPressed: (() -> Void)?

    private var targetKeyCode: Int
    private var targetModifiers: Set<ModifierKey>
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID: UInt32

    nonisolated(unsafe) private static var handlerInstalled = false
    nonisolated(unsafe) private static var registry: [UInt32: HotkeyService] = [:]
    nonisolated(unsafe) private static var nextID: UInt32 = 1
    private static let signature: OSType = 0x51434F43 // 'QOCR'

    init(binding: KeyBinding = .defaultOCR) {
        self.targetKeyCode = binding.keyCode
        self.targetModifiers = binding.modifiers
        self.hotKeyID = HotkeyService.nextID
        HotkeyService.nextID += 1
    }

    func updateBinding(_ binding: KeyBinding) {
        let wasRegistered = hotKeyRef != nil
        if wasRegistered { unregister() }
        targetKeyCode = binding.keyCode
        targetModifiers = binding.modifiers
        if wasRegistered { _ = register() }
    }

    @discardableResult
    func register() -> Bool {
        guard hotKeyRef == nil else { return true }
        HotkeyService.installGlobalHandlerIfNeeded()
        HotkeyService.registry[hotKeyID] = self

        var carbonModifiers: UInt32 = 0
        for mod in targetModifiers {
            switch mod {
            case .command: carbonModifiers |= UInt32(cmdKey)
            case .shift: carbonModifiers |= UInt32(shiftKey)
            case .option: carbonModifiers |= UInt32(optionKey)
            case .control: carbonModifiers |= UInt32(controlKey)
            }
        }

        let eventHotKeyID = EventHotKeyID(signature: HotkeyService.signature, id: hotKeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(targetKeyCode),
            carbonModifiers,
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            HotkeyService.registry.removeValue(forKey: hotKeyID)
            return false
        }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        hotKeyRef = nil
        HotkeyService.registry.removeValue(forKey: hotKeyID)
    }

    private static func installGlobalHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var pressedID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedID
            )
            guard status == noErr, pressedID.signature == HotkeyService.signature else { return status }
            if let service = HotkeyService.registry[pressedID.id] {
                DispatchQueue.main.async {
                    service.onHotkeyPressed?()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
