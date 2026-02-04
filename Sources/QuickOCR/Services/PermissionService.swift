import Foundation
import AppKit

/// 画面収録の権限設定へのリンクを提供するサービス
/// 権限チェック自体は実際のスクリーンキャプチャ時に行い、失敗時にエラーハンドリングで対応する
final class PermissionService {
    /// システム設定のプライバシー > 画面共有を開く
    func openScreenRecordingSettings() {
        let url = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefpane")
        NSWorkspace.shared.open(url)
    }
}
