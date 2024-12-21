import Foundation

enum AIModel: String, CaseIterable, Codable {
    case kimi = "Kimi"
    case dou = "豆包"
    case llama = "Llama3"
    
    var description: String {
        return self.rawValue
    }
    
    var needsLocalModel: Bool {
        return self == .llama
    }
    
    var needsAPIKey: Bool {
        switch self {
        case .kimi, .dou:
            return true
        case .llama:
            return false
        }
    }
}

struct ModelAPIKeys: Codable {
    var kimi: String
    var dou: String
    
    static let empty = ModelAPIKeys(kimi: "", dou: "")
}

struct AIModelConfig: Codable {
    var model: AIModel
    var apiKeys: ModelAPIKeys
    var isModelLoaded: Bool
    
    static let empty = AIModelConfig(
        model: .kimi,
        apiKeys: .empty,
        isModelLoaded: false
    )
    
    func getAPIKey() -> String {
        switch model {
        case .kimi:
            return apiKeys.kimi
        case .dou:
            return apiKeys.dou
        case .llama:
            return ""
        }
    }
    
    mutating func setAPIKey(_ key: String) {
        switch model {
        case .kimi:
            apiKeys.kimi = key
        case .dou:
            apiKeys.dou = key
        case .llama:
            break
        }
    }
} 
