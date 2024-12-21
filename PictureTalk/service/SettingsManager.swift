import Foundation

// 英语等级枚举
enum EnglishLevel: String, CaseIterable, Codable {
    case cet4 = "四级"
    case cet6 = "六级"
    case ielts = "雅思"
    case toefl = "托福"
    case gre = "GRE"
    
    var description: String {
        return self.rawValue
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var englishLevel: EnglishLevel {
        didSet {
            saveSettings()
        }
    }
    
    private let defaults = UserDefaults.standard
    private let englishLevelKey = "english_level"
    
    private init() {
        // 从 UserDefaults 加载设置，如果没有则使用默认值
        if let savedLevel = defaults.string(forKey: englishLevelKey),
           let level = EnglishLevel(rawValue: savedLevel) {
            self.englishLevel = level
        } else {
            self.englishLevel = .cet4  // 默认为四级
        }
    }
    
    private func saveSettings() {
        defaults.set(englishLevel.rawValue, forKey: englishLevelKey)
    }
} 