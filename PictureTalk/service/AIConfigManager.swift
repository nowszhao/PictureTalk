import Foundation

class AIConfigManager: ObservableObject {
    static let shared = AIConfigManager()
    
    @Published var currentConfig: AIModelConfig {
        didSet {
            saveConfig()
            if oldValue.model != currentConfig.model {
                currentConfig.isModelLoaded = false
            }
        }
    }
    
    private let defaults = UserDefaults.standard
    private let configKey = "ai_model_config"
    
    private init() {
        if let savedData = defaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(AIModelConfig.self, from: savedData) {
            self.currentConfig = config
        } else {
            self.currentConfig = AIModelConfig.empty
        }
    }
    
    private func saveConfig() {
        if let encoded = try? JSONEncoder().encode(currentConfig) {
            defaults.set(encoded, forKey: configKey)
        }
    }
    
    func getAPIKeyStatus(for model: AIModel) -> String {
        switch model {
        case .kimi:
            return currentConfig.apiKeys.kimi.isEmpty ? "未设置" : "已设置"
        case .dou:
            return currentConfig.apiKeys.dou.isEmpty ? "未设置" : "已设置"
        case .llama:
            return "无需设置"
        }
    }
    
    func getAPIKey(for model: AIModel) -> String {
        switch model {
        case .kimi:
            return currentConfig.apiKeys.kimi
        case .dou:
            return currentConfig.apiKeys.dou
        case .llama:
            return ""
        }
    }
    
    func setAPIKey(_ key: String, for model: AIModel) {
        switch model {
        case .kimi:
            currentConfig.apiKeys.kimi = key
        case .dou:
            currentConfig.apiKeys.dou = key
        case .llama:
            break
        }
    }
} 