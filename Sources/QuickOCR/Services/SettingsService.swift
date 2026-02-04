import Foundation

final class SettingsService {
    private let userDefaults: UserDefaults
    private let settingsKey = "com.quickocr.settings"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// 設定を読み込む。未保存の場合はデフォルト値を返す。
    func load() -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return AppSettings()
        }
        
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error)")
            // デコード失敗時はデフォルト値を返す（破損データの安全策）
            return AppSettings()
        }
    }
    
    /// 設定を保存する。
    func save(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }
}
