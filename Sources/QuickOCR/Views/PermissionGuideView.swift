import SwiftUI

/// 入力監視権限の取得を案内するビュー
struct PermissionGuideView: View {
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("グローバルショートカットの権限が必要です")
                .font(.headline)

            Text(
                "QuickOCR が Cmd+Shift+O などのグローバルショートカットを受け取るには、"
                + "「入力監視」権限が必要です。\n\n"
                + "システム設定 > プライバシーとセキュリティ > 入力監視 を開き、"
                + "QuickOCRApp を追加してオンにしてください。\n\n"
                + "設定後はアプリを再起動してください。"
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("後で") { onClose() }
                    .keyboardShortcut(.escape)
                Button("入力監視の設定を開く") { onOpenSettings() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
