import SwiftUI

// MARK: - 场景相关模型

// 场景状态枚举
enum SceneStatus: String, Codable {
    case analyzing
    case completed
}

// 场景模型
struct SceneItem: Identifiable {
    let id: String
    let imageUrl: String
    let assetIdentifier: String
    var words: [WordItem]
    var sentence: Sentence
    let createdAt: Date
    let status: SceneStatus
    var image: UIImage?
    var errorMessage: String?
    
    init(id: String = UUID().uuidString,
         imageUrl: String,
         assetIdentifier: String,
         words: [WordItem] = [],
         sentence: Sentence,
         createdAt: Date = Date(),
         status: SceneStatus = .analyzing,
         image: UIImage? = nil,
         errorMessage: String? = nil) {
        self.id = id
        self.imageUrl = imageUrl
        self.assetIdentifier = assetIdentifier
        self.words = words
        self.sentence = sentence
        self.createdAt = createdAt
        self.status = status
        self.image = image
        self.errorMessage = errorMessage
    }
}

// 可编码的场景模型
struct EncodableScene: Codable {
    let id: String
    let imageUrl: String
    let assetIdentifier: String
    let words: [WordItem]
    let sentence: Sentence
    let createdAt: Date
    let status: SceneStatus
    let errorMessage: String?
}

// MARK: - 单词相关模型

// 修改 WordItem 结构体，添加 Equatable 协议
struct WordItem: Codable, Identifiable, Equatable {
    let word: String
    let phoneticsymbols: String
    let explanation: String
    let location: String
    var customPosition: CGPoint?
    
    var id: String { word }
    
    // 添加 Equatable 协议实现
    static func == (lhs: WordItem, rhs: WordItem) -> Bool {
        return lhs.word == rhs.word &&
               lhs.phoneticsymbols == rhs.phoneticsymbols &&
               lhs.explanation == rhs.explanation &&
               lhs.location == rhs.location &&
               lhs.customPosition == rhs.customPosition
    }
    
    // 原始位置（已经是归一化的）
    var originalPosition: CGPoint {
        let components = location.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let x = Double(components[0]),
              let y = Double(components[1]) else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(x: x, y: y)
    }
    
    // 实际显示位置（确保返回归一化坐标）
    var position: CGPoint {
        if let custom = customPosition {
            // 确保自定义位置也是归一化的
            return CGPoint(
                x: max(0.0, min(custom.x, 1.0)),
                y: max(0.0, min(custom.y, 1.0))
            )
        }
        return originalPosition
    }
    
    // 添加编码键
    enum CodingKeys: String, CodingKey {
        case word
        case phoneticsymbols
        case explanation
        case location
        case customPosition
    }
    
    // 自定义编码方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(word, forKey: .word)
        try container.encode(phoneticsymbols, forKey: .phoneticsymbols)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(location, forKey: .location)
        try container.encodeIfPresent(customPosition, forKey: .customPosition)
    }
    
    // 自定义解码方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        phoneticsymbols = try container.decode(String.self, forKey: .phoneticsymbols)
        explanation = try container.decode(String.self, forKey: .explanation)
        location = try container.decode(String.self, forKey: .location)
        customPosition = try container.decodeIfPresent(CGPoint.self, forKey: .customPosition)
    }
}

struct Sentence: Codable, Identifiable {
    let text: String
    let translation: String
    
    var id: String { text }
}

struct AnalysisResponse: Codable {
    let words: [WordItem]
    let sentence:Sentence
    
    enum CodingKeys: CodingKey {
        case words, sentence
    }
}


// 图片详情请求模型
struct FileDetailRequest: Codable {
    let type: String
    let name: String
    let fileId: String
    let meta: FileMeta
    
    enum CodingKeys: String, CodingKey {
        case type, name
        case fileId = "file_id"
        case meta
    }
}

struct FileMeta: Codable {
    let width: String
    let height: String
}

// 图片详情响应模型
struct FileDetailResponse: Codable {
    let id: String
    let name: String
    let parentPath: String
    let type: String
    let size: Int
    let status: String
    let presignedUrl: String
    let previewUrl: String
    let thumbnailUrl: String
    let miniUrl: String
    let extraInfo: ExtraInfo
    let createdAt: String
    let updatedAt: String
    let contentType: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, size, status
        case parentPath = "parent_path"
        case presignedUrl = "presigned_url"
        case previewUrl = "preview_url"
        case thumbnailUrl = "thumbnail_url"
        case miniUrl = "mini_url"
        case extraInfo = "extra_info"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case contentType = "content_type"
    }
}

struct ExtraInfo: Codable {
    let width: Int
    let height: Int
}

// 图片解析请求模型
struct ImageAnalysisRequest: Codable {
    let messages: [Message]
    let useSearch: Bool
    let extend: Extend
    let kimiplusId: String
    let useResearch: Bool
    let useMath: Bool
    let refs: [String]
    let refsFile: [FileRef]
    
    enum CodingKeys: String, CodingKey {
        case messages
        case useSearch = "use_search"
        case extend
        case kimiplusId = "kimiplus_id"
        case useResearch = "use_research"
        case useMath = "use_math"
        case refs
        case refsFile = "refs_file"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

struct Extend: Codable {
    let sidebar: Bool
}

struct FileRef: Codable {
    let id: String
    let name: String
    let size: Int
    let file: [String: String]
    let uploadProgress: Int
    let uploadStatus: String
    let parseStatus: String
    let detail: FileDetailResponse
    let fileInfo: FileDetailResponse
    let done: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, size, file
        case uploadProgress = "upload_progress"
        case uploadStatus = "upload_status"
        case parseStatus = "parse_status"
        case detail
        case fileInfo = "file_info"
        case done
    }
    
    init(id: String, name: String, size: Int, uploadProgress: Int = 100,
         uploadStatus: String = "success", parseStatus: String = "success",
         detail: FileDetailResponse, fileInfo: FileDetailResponse, done: Bool = true) {
        self.id = id
        self.name = name
        self.size = size
        self.file = [:]
        self.uploadProgress = uploadProgress
        self.uploadStatus = uploadStatus
        self.parseStatus = parseStatus
        self.detail = detail
        self.fileInfo = fileInfo
        self.done = done
    }
}


struct SSEEvent: Codable {
    let event: String
    let content: String?
    let text: String?
    
    enum CodingKeys: String, CodingKey {
        case event, content, text
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        event = try container.decode(String.self, forKey: .event)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        text = try container.decodeIfPresent(String.self, forKey: .text)
    }
}



// 创建聊天请求模型
struct CreateChatRequest: Codable {
    let name: String
    let isExample: Bool
    let enterMethod: String
    let kimiplusId: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case isExample = "is_example"
        case enterMethod = "enter_method"
        case kimiplusId = "kimiplus_id"
    }
}

// 创建聊天响应模型
struct CreateChatResponse: Codable {
    let id: String
    let name: String
    let thumbStatus: ThumbStatus
    let createdAt: String
    let isExample: Bool
    let status: String
    let isVoiceKimiplus: Int
    let type: String
    let avatar: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, type, avatar
        case thumbStatus = "thumb_status"
        case createdAt = "created_at"
        case isExample = "is_example"
        case isVoiceKimiplus = "is_voice_kimiplus"
    }
}

struct ThumbStatus: Codable {
    let isThumbUp: Bool
    let isThumbDown: Bool
    
    enum CodingKeys: String, CodingKey {
        case isThumbUp = "is_thumb_up"
        case isThumbDown = "is_thumb_down"
    }
}


// CGPoint 的编解码扩展
extension CGPoint: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(CGFloat.self)
        let y = try container.decode(CGFloat.self)
        self.init(x: x, y: y)
    }
}
 
enum TaskStatus: String, Codable {
    case waiting     // 等待处理
    case processing // 处理中
    case completed  // 完成
    case failed     // 失败
    
    var description: String {
        switch self {
        case .waiting: return "等待处理"
        case .processing: return "处理中"
        case .completed: return "已完成"
        case .failed: return "处理失败"
        }
    }
}

struct ImageAnalysisTask: Identifiable {
    let id: String
    let image: UIImage
    let createdAt: Date
    var status: TaskStatus
    var errorMessage: String?
    var assetIdentifier: String
    
    init(id: String = UUID().uuidString,
         image: UIImage,
         assetIdentifier: String = "",
         status: TaskStatus = .waiting,
         createdAt: Date = Date()) {
        self.id = id
        self.image = image
        self.assetIdentifier = assetIdentifier
        self.status = status
        self.createdAt = createdAt
    }
}

// 在 Models.swift 中添加新的模型
struct LearningTask: Identifiable, Codable {
    let id: String
    let date: Date
    var words: [LearningWord]
    var status: LearningStatus
    let createdAt: Date
    
    enum LearningStatus: String, Codable {
        case notStarted   // 未开始
        case inProgress   // 学习中
        case completed    // 已完成
    }
}

struct LearningWord: Identifiable, Codable {
    let id: String
    let word: String
    let phoneticsymbols: String
    let explanation: String
    let sceneId: String      // 关联的场景ID
    var status: WordStatus   // 学习状态
    let createdAt: Date
    
    enum WordStatus: String, Codable {
        case notLearned    // 未学习
        case needReview    // 需要复习
        case mastered      // 已掌握
    }
}

// 添加学习设置模型
struct LearningSettings: Codable {
    var wordsPerLesson: Int = 10  // 默认每课时10个单词
    
    static let minWordsPerLesson = 5
    static let maxWordsPerLesson = 100
}

// 添加学习记录模型
struct LearningRecord: Identifiable, Codable {
    let id: String
    let date: Date
    let completedWords: Int
    let totalWords: Int
    
    var completionRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(completedWords) / Double(totalWords)
    }
}

struct Word: Identifiable, Codable {
    let id: String
    let word: String
    let phoneticsymbols: String
    let explanation: String
    var customPosition: CGPoint?
    // ... 其他属性
}

extension LearningWord.WordStatus {
    static var allCases: [Self] {
        [.notLearned, .needReview, .mastered]
    }
    
    var description: String {
        switch self {
        case .notLearned: return "未学习"
        case .needReview: return "需复习"
        case .mastered: return "已掌握"
        }
    }
    
    var color: Color {
        switch self {
        case .notLearned: return .gray
        case .needReview: return .orange
        case .mastered: return .green
        }
    }
}

