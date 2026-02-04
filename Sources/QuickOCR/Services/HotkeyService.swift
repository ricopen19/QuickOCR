import Foundation
import AppKit
import CoreGraphics

/// グローバルキーボードショートカットの登録・解除を管理するサービス
final class HotkeyService {
    /// ショートカット押下時に呼ばれるコールバック
    var onHotkeyPressed: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var targetKeyCode: Int
    private var targetFlags: CGEventFlags

    /// - Parameter binding: 監視するキーバインド。デフォルトは Cmd+Shift+O
    init(binding: KeyBinding = .defaultOCR) {
        self.targetKeyCode = binding.keyCode
        self.targetFlags = HotkeyService.cgFlags(for: binding.modifiers)
    }

    /// キーバインドを動的に変更する（再登録不要）
    func updateBinding(_ binding: KeyBinding) {
        targetKeyCode = binding.keyCode
        targetFlags = HotkeyService.cgFlags(for: binding.modifiers)
    }

    /// グローバルモニタを登録する
    /// - Returns: 登録に成功した場合 `true`。アクセシビリティ権限が不足の場合 `false`
    func register() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: CGEventTapPlacement(rawValue: 1)!, // tail
            options: CGEventTapOptions(rawValue: 1)!, // listenOnly
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { (_, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let ptr = userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let service = Unmanaged<HotkeyService>.fromOpaque(ptr).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    // タップが無効化された場合、再有効化を試みる
                    if let tap = service.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                
                guard type == .keyDown else {
                     return Unmanaged.passUnretained(event)
                }

                guard event.getIntegerValueField(.keyboardEventKeycode) == service.targetKeyCode else {
                    return Unmanaged.passUnretained(event)
                }

                let allModifierMask: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
                guard event.flags.intersection(allModifierMask) == service.targetFlags else {
                    return Unmanaged.passUnretained(event)
                }

                service.onHotkeyPressed?()
                return Unmanaged.passUnretained(event) // イベントを通過させる（他のアプリでも使えるようにする）
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap = tap else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source = source else { return false }

        CFRunLoopAddSource(
            CFRunLoopGetMain(), source, CFRunLoopMode.commonModes
        )
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    /// Set<ModifierKey> を CGEventFlags に変換する
    private static func cgFlags(for modifiers: Set<ModifierKey>) -> CGEventFlags {
        var flags = CGEventFlags()
        for mod in modifiers {
            switch mod {
            case .command: flags.insert(.maskCommand)
            case .shift:   flags.insert(.maskShift)
            case .option:  flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            }
        }
        return flags
    }

    /// グローバルモニタを解除する
    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(), source, CFRunLoopMode.commonModes
            )
        }
        eventTap = nil
        runLoopSource = nil
    }

}
