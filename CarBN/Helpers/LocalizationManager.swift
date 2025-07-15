import Foundation

class LocalizationManager {
    static let shared = LocalizationManager()
    
    private init() {
        // Initialize with saved language or default
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language") {
            setLanguage(savedLanguage)
        }
    }
    
    func setLanguage(_ languageCode: String) {
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.set(languageCode, forKey: "app_language")
        UserDefaults.standard.synchronize()
        
        // Post notification to update UI
        NotificationCenter.default.post(name: Notification.Name("LanguageChanged"), object: nil)
    }
    
    func getCurrentLanguage() -> String {
        return UserDefaults.standard.string(forKey: "app_language") ?? "en"
    }
}