import Foundation
import AppKit
import SwiftUI
import UserNotifications

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    /// SwiftUI の @NSApplicationDelegateAdaptor では NSApplication.shared.delegate のキャストが
    /// 不可逆になることがある。静的参照で確実にアクセスする。
    nonisolated(unsafe) public static weak var shared: AppDelegate?

    private var hotkeyService: HotkeyService?
    private var selectionService: SelectionService?

    public override init() {
        super.init()
        AppDelegate.shared = self
    }

    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        if AppEnvironment.isAppBundle {
            UNUserNotificationCenter.current().delegate = self
        }
        setupHotkey()
        DispatchQueue.global().async { OCRService.warmUp() }

        // 初回起動チェック
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "com.quickocr.hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            showWelcomeWindow()
        }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        hotkeyService?.unregister()
        return .terminateNow
    }

    /// アプリが前面にある場合も通知バナーを表示する
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        let settings = SettingsService().load()
        let service = HotkeyService(binding: settings.shortcutKey)
        service.onHotkeyPressed = {
            Task { @MainActor in
                self.startOCRFlow()
            }
        }
        if !service.register() {
            showAccessibilityAlert()
        }
        hotkeyService = service
    }

    /// ショートカットキーを動的に変更する（設定画面から呼び出す）
    func updateHotkey(to binding: KeyBinding) {
        hotkeyService?.updateBinding(binding)
    }

    // MARK: - OCR Flow

    public func startOCRFlow() {
        guard selectionService == nil else { return }

        let service = SelectionService()
        service.onCaptured = { [weak self] image in
            self?.selectionService = nil
            self?.runOCR(on: image)
        }
        service.onCancelled = { [weak self] in
            self?.selectionService = nil
        }
        service.onError = { [weak self] error in
            self?.selectionService = nil
            let notificationService = NotificationService()
            Task {
                _ = await notificationService.requestPermission()
                try? await notificationService.showError(
                    title: "キャプチャ失敗",
                    message: error.localizedDescription
                )
            }
        }
        selectionService = service
        Task { await service.showOverlay() }
    }

    private func runOCR(on image: NSImage) {
        let ocrService = OCRService()
        let clipboardService = ClipboardService()
        let notificationService = NotificationService()

        do {
            let result = try ocrService.recognizeText(in: image)
            let settings = SettingsService().load()
            let formattedText = settings.enableTextFormatting ? TextFormatService().format(result.text) : result.text
            try clipboardService.copy(formattedText)

            if settings.enableSoundFeedback {
                SoundService().playCompletionSound()
            }

            Task {
                _ = await notificationService.requestPermission()
                try? await notificationService.showOCRComplete(text: formattedText)
            }
        } catch {
            Task {
                try? await notificationService.showError(
                    title: "OCRエラー",
                    message: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Alerts

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = (
            "QuickOCRのグローバルショートカットを使用するためには、アクセシビリティ権限が必要です。\n\n"
            + "システム設定 > プライバシーとセキュリティ > アクセシビリティで QuickOCR を許可した後、アプリを再起動してください。"
        )
        alert.addButton(withTitle: "設定を開く")
        alert.addButton(withTitle: "キャンセル")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefpane"))
        }
    }
    // MARK: - Settings Window

    private var settingsWindow: NSWindow?

    public func showSettingsWindow() {
        NSApp.activate()
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "設定"
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }


    // MARK: - Welcome Window
    
    private var welcomeWindow: NSWindow?
    
    private func showWelcomeWindow() {
        NSApp.activate()
        if let window = welcomeWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "QuickOCRへようこそ"

        let welcomeView = WelcomeView { [weak self, weak window] in
            UserDefaults.standard.set(true, forKey: "com.quickocr.hasCompletedOnboarding")
            window?.close()
            self?.welcomeWindow = nil
        }

        window.contentView = NSHostingView(rootView: welcomeView)
        window.isReleasedWhenClosed = false

        welcomeWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
