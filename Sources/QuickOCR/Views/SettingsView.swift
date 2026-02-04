import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @State private var settings: AppSettings
    @State private var isRecording = false
    @State private var conflictMessage: String?
    @State private var launchAtLoginError: String?
    
    private let settingsService = SettingsService()
    private let launchAtLoginService = LaunchAtLoginService()
    
    init() {
        _settings = State(initialValue: SettingsService().load())
    }
    
    var body: some View {
        Form {
            Section("一般") {
                Toggle("ログイン時に自動起動", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        updateLaunchAtLogin(newValue)
                    }
                ))
                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Toggle("音声フィードバック", isOn: $settings.enableSoundFeedback)
                    .onChange(of: settings.enableSoundFeedback) { _, _ in saveSettings() }
                
                Toggle("テキスト整形（改行削除など）", isOn: $settings.enableTextFormatting)
                    .onChange(of: settings.enableTextFormatting) { _, _ in saveSettings() }
            }
            
            Section("ショートカット") {
                HStack {
                    Text("起動キー:")
                    Spacer()
                    Button(action: {
                        isRecording = true
                    }, label: {
                        Text(isRecording ? "入力待機中..." : keyBindingString(settings.shortcutKey))
                            .frame(minWidth: 100)
                    })
                    .buttonStyle(.bordered)
                }
                if let message = conflictMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if !AXIsProcessTrusted() {
                    Text("グローバルショートカットにはアクセシビリティ権限が必要です。")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Text("ショートカットキーを押して設定を変更します。\nEscキーでキャンセルできます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400)
        .overlay {
            if isRecording {
                ShortcutRecorder(isRecording: $isRecording) { newBinding in
                    updateShortcut(newBinding)
                }
            }
        }
        .onAppear {
            // 起動時に実際のLaunchAtLogin状態と同期
            if settings.launchAtLogin != launchAtLoginService.isEnabled {
                settings.launchAtLogin = launchAtLoginService.isEnabled
                saveSettings()
            }
        }
    }
    
    private func saveSettings() {
        settingsService.save(settings)
    }
    
    private func updateLaunchAtLogin(_ isEnabled: Bool) {
        launchAtLoginError = nil
        do {
            if isEnabled {
                try launchAtLoginService.enable()
            } else {
                try launchAtLoginService.disable()
            }
            settings.launchAtLogin = isEnabled
            saveSettings()
        } catch {
            launchAtLoginError = "設定の変更に失敗しました（署名済みビルドが必要です）"
            // UIを元の状態に戻す
            settings.launchAtLogin = launchAtLoginService.isEnabled
        }
    }
    
    private func updateShortcut(_ binding: KeyBinding) {
        // コンフリクトチェック
        if let message = ShortcutConflictChecker.conflict(for: binding) {
            conflictMessage = message
        } else {
            conflictMessage = nil
        }
        
        settings.shortcutKey = binding
        saveSettings()
        
        // AppDelegateに通知して更新
        AppDelegate.shared?.updateHotkey(to: binding)
    }
    
    private func keyBindingString(_ binding: KeyBinding) -> String {
        var components: [String] = []
        
        // 表示順序: ⌘ -> ⇧ -> ⌥ -> ⌃
        if binding.modifiers.contains(.command) { components.append("⌘") }
        if binding.modifiers.contains(.shift) { components.append("⇧") }
        if binding.modifiers.contains(.option) { components.append("⌥") }
        if binding.modifiers.contains(.control) { components.append("⌃") }
        
        components.append(keyCodeToString(binding.keyCode))
        
        return components.joined()
    }
    
    // swiftlint:disable cyclomatic_complexity
    private func keyCodeToString(_ keyCode: Int) -> String {
        // 主要なキーコードのマッピング
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        default: return "Key(\(keyCode))"
        }
    }
}

/// ショートカット入力を監視・取得するビュー
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onRecord: (KeyBinding) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = FocusView()
        view.onKeyDown = { event in
            // Escでキャンセル
            if event.keyCode == 53 {
                isRecording = false
                return
            }

            // 修飾キーのみの場合は無視（ただし、これらが押された状態で他のキーが押されるのを待つ）
            // NSEvent.modifierFlagsは現在の全修飾キー状態を含む

            // 修飾キーの変換
            var modifiers: Set<ModifierKey> = []
            if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
            if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
            if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
            if event.modifierFlags.contains(.control) { modifiers.insert(.control) }

            let binding = KeyBinding(keyCode: Int(event.keyCode), modifiers: modifiers)
            onRecord(binding)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording {
            if let focusView = nsView as? FocusView {
                focusView.startMonitoring()
            }
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                nsView.window?.makeKeyAndOrderFront(nil)
                nsView.window?.makeFirstResponder(nsView)
            }
        } else if let focusView = nsView as? FocusView {
            focusView.stopMonitoring()
        }
    }
    
    class FocusView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?
        var onCancel: (() -> Void)?
        private var monitor: Any?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            super.keyDown(with: event)
        }

        override func mouseDown(with event: NSEvent) {
            onCancel?()
        }

        func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 53 {
                    self.onCancel?()
                    return nil
                }
                self.onKeyDown?(event)
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            MainActor.assumeIsolated { stopMonitoring() }
        }
    }
}
