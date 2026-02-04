import XCTest
import AppKit

@testable import QuickOCR

final class HotkeyServiceTests: XCTestCase {
    // MARK: - 初期状態

    func test_初期状態_コールバックはnil() {
        let service = HotkeyService()
        XCTAssertNil(service.onHotkeyPressed)
    }

    // MARK: - 安全性（境界値）

    func test_unregister_登録前に呼び出しても不正終了しない() {
        let service = HotkeyService()
        service.unregister()
    }

    func test_unregister_連続呼び出しでも不正終了しない() {
        let service = HotkeyService()
        service.unregister()
        service.unregister()
    }

    func test_register_アクセシビリティ権限に応じてBoolを返す() {
        let service = HotkeyService()
        let registered = service.register()
        // アクセシビリティ権限の有無で結果が変わるため、結果に関わらず不正終了しないことを検証
        if registered {
            service.unregister()
        }
    }
}
