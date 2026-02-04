import XCTest
@testable import QuickOCR

final class SettingsServiceTests: XCTestCase {
    var service: SettingsService!
    let settingsKey = "com.quickocr.settings"
    
    override func setUp() {
        super.setUp()
        // テスト前にUserDefaultsをクリア
        UserDefaults.standard.removeObject(forKey: settingsKey)
        service = SettingsService()
    }
    
    override func tearDown() {
        // テスト後にUserDefaultsをクリア（クリーンアップ）
        UserDefaults.standard.removeObject(forKey: settingsKey)
        super.tearDown()
    }
    
    // デフォルト値の読み込み
    func testLoadDefault() {
        let settings = service.load()
        // デフォルト値の検証
        XCTAssertEqual(settings.shortcutKey, KeyBinding.defaultOCR)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertFalse(settings.enableSoundFeedback)
        XCTAssertTrue(settings.enableTextFormatting)
    }
    
    // ラウントリップテスト（保存して読み込み）
    func testSaveAndLoad() {
        var settings = AppSettings()
        settings.launchAtLogin = true
        settings.enableSoundFeedback = true
        settings.enableTextFormatting = false
        // デフォルトとは異なるキーバインドを設定
        settings.shortcutKey = KeyBinding(keyCode: 4, modifiers: [.command, .control]) // Cmd+Ctrl+H (example)
        
        service.save(settings)
        
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.launchAtLogin, settings.launchAtLogin)
        XCTAssertEqual(loadedSettings.enableSoundFeedback, settings.enableSoundFeedback)
        XCTAssertEqual(loadedSettings.enableTextFormatting, settings.enableTextFormatting)
        XCTAssertEqual(loadedSettings.shortcutKey, settings.shortcutKey)
    }
    
    // 個別設定の変更
    func testUpdateIndividualSetting() {
        var settings = service.load()
        XCTAssertTrue(settings.enableTextFormatting) // デフォルト確認
        
        settings.enableTextFormatting = false
        service.save(settings)
        
        let loadedSettings = service.load()
        XCTAssertFalse(loadedSettings.enableTextFormatting)
    }
    
    // KeyBindingのSet<ModifierKey>順序非依存テスト
    func testKeyBindingModifiersOrder() {
        // Setなので順序は本来関係ないが、JSONデコード時に正しく復元されるか確認
        let modifiers1: Set<ModifierKey> = [.command, .shift]
        let modifiers2: Set<ModifierKey> = [.shift, .command]
        
        var settings = AppSettings()
        settings.shortcutKey = KeyBinding(keyCode: 31, modifiers: modifiers1)
        
        service.save(settings)
        let loadedSettings = service.load()
        
        // loadedSettings.shortcutKey.modifiers が modifiers2 (= modifiers1) と等価であること
        XCTAssertEqual(loadedSettings.shortcutKey.modifiers, modifiers2)
    }
    // 境界値: 修飾キーなし・全修飾キー
    func testBoundaryValues() {
        // 1. 修飾キーなし (keyCode 0 = A)
        let noMod = KeyBinding(keyCode: 0, modifiers: [])
        service.save(AppSettings(shortcutKey: noMod))
        let loadedNoMod = service.load().shortcutKey
        XCTAssertEqual(loadedNoMod.keyCode, 0)
        XCTAssertEqual(loadedNoMod.modifiers, [])
        
        // 2. 全修飾キー (keyCode 11 = B)
        let allMod = KeyBinding(keyCode: 11, modifiers: [.command, .shift, .option, .control])
        service.save(AppSettings(shortcutKey: allMod))
        let loadedAllMod = service.load().shortcutKey
        XCTAssertEqual(loadedAllMod.keyCode, 11)
        XCTAssertTrue(loadedAllMod.modifiers.contains(.command))
        XCTAssertTrue(loadedAllMod.modifiers.contains(.shift))
        XCTAssertTrue(loadedAllMod.modifiers.contains(.option))
        XCTAssertTrue(loadedAllMod.modifiers.contains(.control))
    }
}
