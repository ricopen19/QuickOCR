import Foundation
import ServiceManagement

/// ログイン時自動起動の管理サービス
public final class LaunchAtLoginService {
    public init() {}

    /// 現在の自動起動状態
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 自動起動を有効にする
    /// - Throws: 登録に失敗した場合（アプリ署名が不足など）
    public func enable() throws {
        try SMAppService.mainApp.register()
    }

    /// 自動起動を無効にする
    /// - Throws: 解除に失敗した場合
    public func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
