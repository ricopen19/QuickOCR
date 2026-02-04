import XCTest
import UserNotifications

@testable import QuickOCR

final class NotificationServiceTests: XCTestCase {
    private var service: NotificationService!
    private var mockCenter: MockNotificationCenter!
    
    override func setUp() {
         super.setUp()
         mockCenter = MockNotificationCenter()
         service = NotificationService(center: mockCenter)
    }

    // MARK: - 正常系

    func test_truncate_短いテキスト_そのまま返す() {
        XCTAssertEqual(service.truncate("Hello"), "Hello")
    }

    func test_truncate_3行以下のテキスト_そのまま返す() {
        let text = "行1\n行2\n行3"
        XCTAssertEqual(service.truncate(text), "行1\n行2\n行3")
    }

    func test_truncate_4行以上のテキスト_3行に制限して省略符を付加する() {
        let text = "行1\n行2\n行3\n行4\n行5"
        XCTAssertEqual(service.truncate(text), "行1\n行2\n行3…")
    }

    func test_truncate_100文字を超えるテキスト_100文字に制限して省略符を付加する() {
        let text = String(repeating: "あ", count: 150)

        let result = service.truncate(text)

        XCTAssertTrue(result.hasSuffix("…"))
        XCTAssertEqual(result.dropLast().count, 100)
    }

    func test_showOCRComplete_通知が正しくスケジュールされる() async throws {
        let text = "Hello World"
        try await service.showOCRComplete(text: text)
        
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let request = mockCenter.addedRequests.first!
        XCTAssertEqual(request.content.title, "OCR完了")
        XCTAssertEqual(request.content.body, "Hello World")
    }

    func test_showError_エラー通知が正しくスケジュールされる() async throws {
        try await service.showError(title: "エラー", message: "メッセージ")
        
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let request = mockCenter.addedRequests.first!
        XCTAssertEqual(request.content.title, "エラー")
        XCTAssertEqual(request.content.body, "メッセージ")
    }

    func test_requestPermission_許可される_trueを返す() async {
        mockCenter.authorizationResult = true
        let result = await service.requestPermission()
        XCTAssertTrue(result)
        XCTAssertEqual(mockCenter.requestedOptions, [.alert])
    }

    func test_requestPermission_拒否される_falseを返す() async {
        mockCenter.authorizationResult = false
        let result = await service.requestPermission()
        XCTAssertFalse(result)
    }

    // MARK: - 境界値

    func test_truncate_空文字列_空文字列を返す() {
        XCTAssertEqual(service.truncate(""), "")
    }

    func test_truncate_正確に100文字のテキスト_省略符なしで返す() {
        let text = String(repeating: "あ", count: 100)
        XCTAssertEqual(service.truncate(text), text)
    }

    func test_truncate_101文字のテキスト_100文字に制限して省略符を付加する() {
        let text = String(repeating: "あ", count: 101)

        let result = service.truncate(text)

        XCTAssertTrue(result.hasSuffix("…"))
        XCTAssertEqual(result.dropLast().count, 100)
    }

    func test_truncate_正確に3行のテキスト_省略符なしで返す() {
        let text = "行1\n行2\n行3"
        XCTAssertEqual(service.truncate(text), text)
    }

    func test_truncate_3行で100文字超_100文字で切り捨て_省略符を付加する() {
        let line1 = String(repeating: "あ", count: 40)
        let line2 = String(repeating: "い", count: 40)
        let line3 = String(repeating: "う", count: 40)
        let text = [line1, line2, line3].joined(separator: "\n")

        let result = service.truncate(text)

        XCTAssertTrue(result.hasSuffix("…"))
        XCTAssertEqual(result.dropLast().count, 100)
    }
}

// MARK: - Mocks

private class MockNotificationCenter: NotificationCenterProtocol {
    var addedRequests: [UNNotificationRequest] = []
    var requestedOptions: UNAuthorizationOptions?
    var authorizationResult = true
    
    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
    
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions = options
        return authorizationResult
    }
}
