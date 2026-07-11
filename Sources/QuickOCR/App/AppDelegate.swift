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
    private var markdownHotkeyService: HotkeyService?
    private var selectionService: SelectionService?
    private var statusItem: NSStatusItem?
    private var permissionWindow: NSWindow?
    /// 現在の OCR モード（ホットキーで切り替え）
    private var useMarkdownMode = false

    public override init() {
        super.init()
        AppDelegate.shared = self
    }

    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("menu bar app")
        ProcessInfo.processInfo.disableSuddenTermination()

        setupStatusItem()

        if AppEnvironment.isAppBundle {
            UNUserNotificationCenter.current().delegate = self
        }
        setupHotkey()
        DispatchQueue.global().async { OCRService.warmUp() }

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "com.quickocr.hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            showWelcomeWindow()
        }
    }

    /// quickocr://capture または quickocr://capture-md で OCR を起動
    public func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        useMarkdownMode = url.host == "capture-md"
        startOCRFlow()
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        hotkeyService?.unregister()
        markdownHotkeyService?.unregister()
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

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // macOS 26 Liquid Glass でテンプレート画像・テキスト色の問題を回避するため
            // 明示的な白黒カラーの非テンプレート画像を使用
            let img = makeStatusBarImage()
            img.isTemplate = false
            button.image = img
            button.toolTip = "QuickOCR"
        }
        statusItem?.isVisible = true
        statusItem?.menu = buildStatusMenu()
    }

    private func makeStatusBarImage() -> NSImage {
        let size = NSSize(width: 38, height: 18)
        let img = NSImage(size: size, flipped: false) { bounds in
            // 角丸背景（白）
            NSColor.white.withAlphaComponent(0.85).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 3, yRadius: 3).fill()
            // テキスト（黒）
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.black,
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .paragraphStyle: style
            ]
            let str = "OCR" as NSString
            let strSize = str.size(withAttributes: attrs)
            let origin = NSPoint(x: (bounds.width - strSize.width) / 2,
                                 y: (bounds.height - strSize.height) / 2)
            str.draw(at: origin, withAttributes: attrs)
            return true
        }
        return img
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let ocrItem = NSMenuItem(title: "OCRを実行 (Cmd+Shift+O)", action: #selector(menuOCR), keyEquivalent: "")
        ocrItem.target = self
        menu.addItem(ocrItem)

        let mdItem = NSMenuItem(title: "Markdown OCRを実行 (Cmd+Shift+M)", action: #selector(menuMarkdownOCR), keyEquivalent: "")
        mdItem.target = self
        menu.addItem(mdItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "設定...", action: #selector(menuSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let launchItem = NSMenuItem(title: "ログイン時に自動起動", action: #selector(menuToggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginService().isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "QuickOCRについて", action: #selector(menuAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "終了", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func menuOCR() {
        useMarkdownMode = false
        startOCRFlow()
    }

    @objc private func menuMarkdownOCR() {
        useMarkdownMode = true
        startOCRFlow()
    }

    @objc private func menuSettings() {
        showSettingsWindow()
    }

    @objc private func menuToggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = LaunchAtLoginService()
        do {
            if service.isEnabled {
                try service.disable()
                sender.state = .off
            } else {
                try service.enable()
                sender.state = .on
            }
        } catch {
            // コード署名なしのビルドでは有効化できない — 無視
        }
    }

    @objc private func menuAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        let settings = SettingsService().load()

        // プレーンテキスト OCR
        let service = HotkeyService(binding: settings.shortcutKey)
        service.onHotkeyPressed = {
            Task { @MainActor in
                self.useMarkdownMode = false
                self.startOCRFlow()
            }
        }
        hotkeyService = service

        // Markdown OCR
        let mdService = HotkeyService(binding: settings.shortcutKeyMarkdown)
        mdService.onHotkeyPressed = {
            Task { @MainActor in
                self.useMarkdownMode = true
                self.startOCRFlow()
            }
        }
        markdownHotkeyService = mdService

        _ = service.register()
        _ = mdService.register()
    }

    /// ショートカットキーを動的に変更する（設定画面から呼び出す）
    func updateHotkey(to binding: KeyBinding) {
        hotkeyService?.updateBinding(binding)
    }

    /// Markdown OCR のショートカットキーを動的に変更する
    func updateMarkdownHotkey(to binding: KeyBinding) {
        markdownHotkeyService?.updateBinding(binding)
    }

    // MARK: - OCR Flow

    public func startMarkdownOCRFlow() {
        useMarkdownMode = true
        startOCRFlow()
    }

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

            let formattedText: String
            if useMarkdownMode {
                formattedText = MarkdownFormatService().format(result.lines)
            } else {
                formattedText = settings.enableTextFormatting ? TextFormatService().format(result.text) : result.text
            }

            try clipboardService.copy(formattedText)

            if settings.enableSoundFeedback {
                SoundService().playCompletionSound()
            }

            let modeLabel = useMarkdownMode ? "Markdown OCR完了" : "OCR完了"
            Task {
                _ = await notificationService.requestPermission()
                try? await notificationService.showOCRComplete(text: formattedText, title: modeLabel)
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
        NSApp.activate(ignoringOtherApps: true)

        if permissionWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "QuickOCR — 権限設定が必要です"
            window.isReleasedWhenClosed = false

            let view = PermissionGuideView {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
                )
            } onClose: { [weak window] in
                window?.close()
            }
            window.contentView = NSHostingView(rootView: view)
            window.center()
            permissionWindow = window
        }
        permissionWindow?.makeKeyAndOrderFront(nil)
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
