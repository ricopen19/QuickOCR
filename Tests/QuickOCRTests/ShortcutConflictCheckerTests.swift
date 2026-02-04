import XCTest
@testable import QuickOCR

final class ShortcutConflictCheckerTests: XCTestCase {
    
    func test_既知のショートカット_conflictを返す() {
        // Cmd+C
        let copyKey = KeyBinding(keyCode: 8, modifiers: [.command])
        let message = ShortcutConflictChecker.conflict(for: copyKey)
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("コピー") ?? false)
    }
    
    func test_未知のショートカット_nilを返す() {
        // Cmd+Opt+Ctrl+Shift+P (Not in the known list)
        let unknownKey = KeyBinding(keyCode: 35, modifiers: [.command, .option, .control, .shift])
        let message = ShortcutConflictChecker.conflict(for: unknownKey)
        XCTAssertNil(message)
    }
    
    func test_修飾キーなし_nilを返す() {
        // A key only (Not in known list, though impractical for global shortcut, implementation should allow checking)
        let aKey = KeyBinding(keyCode: 0, modifiers: [])
        let message = ShortcutConflictChecker.conflict(for: aKey)
        XCTAssertNil(message)
    }
}
