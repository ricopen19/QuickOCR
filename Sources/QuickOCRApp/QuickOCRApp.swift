import SwiftUI
import QuickOCR

@main
struct QuickOCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        MenuBarExtra("QuickOCR", systemImage: "text.viewfinder") {
            MenuBarMenuView()
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarMenuView: View {
    var body: some View {
        Button("OCRを実行") {
            AppDelegate.shared?.startOCRFlow()
        }

        Button("Markdown OCRを実行") {
            AppDelegate.shared?.startMarkdownOCRFlow()
        }

        Divider()

        Button("設定...") {
            AppDelegate.shared?.showSettingsWindow()
        }
        
        Toggle("ログイン時に自動起動", isOn: Binding(
            get: { LaunchAtLoginService().isEnabled },
            set: { newValue in
                do {
                    if newValue {
                        try LaunchAtLoginService().enable()
                    } else {
                        try LaunchAtLoginService().disable()
                    }
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "設定変更失敗"
                    alert.informativeText = "起動設定の変更に失敗しました。\n署名済みアプリである必要があります。"
                    alert.runModal()
                }
            }
        ))

        Divider()

        Button("QuickOCRについて") {
            let alert = NSAlert()
            alert.messageText = "QuickOCR"
            alert.informativeText = "Version 1.0.0\n\n© 2026 QuickOCR Project"
            alert.runModal()
        }

        Button("終了") {
            NSApplication.shared.terminate(nil)
        }
    }
}
