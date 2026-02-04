import Foundation
import UserNotifications

/// 通知センター操作を抽象化するプロトコル
protocol NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}

private struct NoopNotificationCenter: NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
    func add(_ request: UNNotificationRequest) async throws {}
}

/// macOSシステム通知の表示を担当するサービス
final class NotificationService {
    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol? = nil) {
        if let center {
            self.center = center
        } else if AppEnvironment.isAppBundle {
            self.center = UNUserNotificationCenter.current()
        } else {
            self.center = NoopNotificationCenter()
        }
    }

    /// 通知の許可を要求する
    func requestPermission() async -> Bool {
        do {
            return try await center
                .requestAuthorization(options: [.alert])
        } catch {
            return false
        }
    }

    /// OCR完了通知を表示する
    func showOCRComplete(text: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "OCR完了"
        content.subtitle = "テキストをコピーしました"
        content.body = truncate(text)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    /// エラー通知を表示する
    func showError(title: String, message: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    /// テキストを最初の3行または100文字に制限する。超える場合は末尾に「…」を付加する
    func truncate(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let firstThree = Array(lines.prefix(3))
        let joined = firstThree.joined(separator: "\n")
        let wasLineTruncated = lines.count > 3

        if joined.count > 100 {
            return String(joined.prefix(100)) + "…"
        }
        return wasLineTruncated ? joined + "…" : joined
    }
}
