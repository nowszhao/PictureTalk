import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

class ImageUploadViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showImagePicker = false
    @Published var showFullScreenImage = false
    @Published var analysisCompleted = false
    @Published var selectedAssetIdentifier: String = ""
    
    private let dataManager = DataManager.shared
    private let userDefaults = UserDefaults.standard
    private let chatIdKey = "current_chat_id"
    
    private var currentChatId: String? {
        get { userDefaults.string(forKey: chatIdKey) }
        set { userDefaults.set(newValue, forKey: chatIdKey) }
    }
    
    // 创建新的聊天会话
    private func createNewChat() async throws -> String {
        let chatResponse = try await KimiService.shared.createChat()
        currentChatId = chatResponse.id
        return chatResponse.id
    }
    
    // 获取或创建聊天ID
    private func getChatId() async throws -> String {
        if let existingId = currentChatId {
            return existingId
        }
        return try await createNewChat()
    }
    
    private func getImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesFolder = documentsPath.appendingPathComponent("Images", isDirectory: true)
        
        // 创建图片文件夹
        do {
            try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true, attributes: nil)
            print("Created or confirmed Images directory at: \(imagesFolder)")
        } catch {
            print("Error creating Images directory: \(error)")
        }
        
        return imagesFolder
    }
    
    private func saveImageToDocuments(_ image: UIImage, sceneId: String) -> Bool {
        let imagesFolder = getImagesDirectory()
        let imagePath = imagesFolder.appendingPathComponent("\(sceneId).jpg")
        print("Saving image to: \(imagePath)")
        
        // 确保目录存在
        do {
            try FileManager.default.createDirectory(at: imagesFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating directory: \(error)")
            return false
        }
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: imagePath)
                print("Successfully saved image to: \(imagePath)")
                return true
            } catch {
                print("Failed to save image: \(error)")
                return false
            }
        }
        return false
    }
    
    // 修改上传和分析方法
    func uploadAndAnalyzeImage() async {
        guard let image = selectedImage else {
            print("没有选择图片")
            return
        }
        
        print("开始处理图片...")
        
        do {
            DispatchQueue.main.async {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            // 获取或创建聊天ID
            var chatId = try await getChatId()
            
            // 检测图片格式并获取合适的扩展名
            let (imageData, fileExtension) = try getImageDataAndExtension(from: image)
            let fileName = UUID().uuidString + fileExtension
            
            print("开始获取预签名URL...")
            let preSignedURL = try await KimiService.shared.getPreSignedURL(fileName: fileName)
            print("预签名URL成功: \(preSignedURL.url)")
            
            print("开始上传图片...")
            try await KimiService.shared.uploadImage(to: preSignedURL.url, imageData: imageData)
            print("图片上传成功")
            
            print("获取图片详情...")
            let fileDetail = try await KimiService.shared.getFileDetail(
                fileId: preSignedURL.fileId,
                fileName: fileName,
                width: String(Int(image.size.width)),
                height: String(Int(image.size.height))
            )
//            let fileDetail =  FileDetailResponse(id:preSignedURL.fileId,name:fileName,type:"",meta:FileMeta(width:"",height:""))
            print("获取图片详情成功")
            
            print("开始分析图片...")
            // 尝试分析图片
            func attemptAnalysis() async throws -> AnalysisResponse {
                do {
                    return try await KimiService.shared.analyzeImage(
                        fileId: preSignedURL.fileId,
                        fileName: fileName,
                        fileSize: imageData.count,
                        fileDetail: fileDetail,
                        chatId: chatId
                    ) { result in
                        // 处理进度更新
                    }
                } catch {
                    // 如果分析失败，创建新的聊天ID并���试
                    print("分析失败，创建新的聊天会话重试")
                    chatId = try await createNewChat()
                    return try await KimiService.shared.analyzeImage(
                        fileId: preSignedURL.fileId,
                        fileName: fileName,
                        fileSize: imageData.count,
                        fileDetail: fileDetail,
                        chatId: chatId
                    ) { result in
                        // 处理进度更新
                    }
                }
            }
            
            let response = try await attemptAnalysis()
            print("图片分析完成，识别到 \(response.words.count) 个单词")
            
            // 创建新场景并保存
            let newScene = SceneItem(
                id: UUID().uuidString,
                imageUrl: "",
                assetIdentifier: selectedAssetIdentifier,
                words: response.words,
                sentence: response.sentence,
                createdAt: Date(),
                status: .completed
            )
            
            // 保存图片到文档目录
            _ = saveImageToDocuments(image, sceneId: newScene.id)
            
            DispatchQueue.main.async {
                self.dataManager.updateScene(newScene)
                // 更新 WordManager
                WordManager.shared.refreshWords()
                
                self.isLoading = false
                self.showFullScreenImage = false
                self.analysisCompleted = true
            }
            
        } catch {
            print("处理过程中出错: \(error.localizedDescription)")
            DispatchQueue.main.async {
                // 提供更友好的错误信息
                if error is URLError {
                    self.errorMessage = "网络连接失败，请检查网络后重试"
                } else if error.localizedDescription.contains("timeout") {
                    self.errorMessage = "连接超时，请重试"
                } else {
                    self.errorMessage = "图片分析失败，请重试"
                }
                self.isLoading = false
                self.analysisCompleted = false
            }
        }
    }
    
    // 添加新的辅助方法来检测图片格式
    private func getImageDataAndExtension(from image: UIImage) throws -> (Data, String) {
        // 获取图片的原始数据
        if let imageData = image.heic {
            return (imageData, ".heic")
        } else if let imageData = image.pngData() {
            return (imageData, ".png")
        } else if let imageData = image.jpegData(compressionQuality: 1.0) { // 使用最高质量
            return (imageData, ".jpg")
        }
        
        throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取图片数据"])
    }
    
    func updateSceneWithAnalysis(_ analysis: AnalysisResponse) {
        if let image = selectedImage {
            print("Creating new scene...")
            let newScene = SceneItem(
                id: UUID().uuidString,
                imageUrl: "",
                assetIdentifier: selectedAssetIdentifier,
                words: analysis.words,
                sentence: analysis.sentence,
                createdAt: Date(),
                status: .completed,
                image: nil
            )
            
            // 保存图片到文档目录
            _ = saveImageToDocuments(image, sceneId: newScene.id)
            
            // 保存场景
            DispatchQueue.main.async {
                self.dataManager.updateScene(newScene)
                // 更新 WordManager
                WordManager.shared.refreshWords()
                
                // 重置状态
                self.selectedImage = nil
                self.selectedAssetIdentifier = ""
                self.analysisCompleted = true
            }
        }
    }
}


class KimiService {
    static let shared = KimiService()
    let config = AIConfigManager.shared.currentConfig

    let defaultAuthToken = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJ1c2VyLWNlbnRlciIsImV4cCI6MTczOTU0NzQ3OCwiaWF0IjoxNzMxNzcxNDc4LCJqdGkiOiJjc3Nib2xuZDBwODBpaGswYmIwMCIsInR5cCI6ImFjY2VzcyIsImFwcF9pZCI6ImtpbWkiLCJzdWIiOiJjb2ZzamI5a3FxNHR0cmdhaGhxZyIsInNwYWNlX2lkIjoiY29mc2piOWtxcTR0dHJnYWhocGciLCJhYnN0cmFjdF91c2VyX2lkIjoiY29mc2piOWtxcTR0dHJnYWhocDAifQ.fPEyGwA2GNsrBAPoBVJwGde6BSdRViykCodDOwDeyeabxIuAO8dtZZ8x9gsk9kxJyknfWZ1JG2pZOnMQbQmf9w"
    
    var authToken: String {
        config.apiKeys.kimi.isEmpty ? defaultAuthToken : config.apiKeys.kimi
    }
        
    private let settingsManager = SettingsManager.shared
    
    struct PreSignedURLResponse: Codable {
        let url: String
        let objectName: String
        let fileId: String
        
        enum CodingKeys: String, CodingKey {
            case url
            case objectName = "object_name"
            case fileId = "file_id"
        }
    }
    
    func getPreSignedURL(fileName: String) async throws -> PreSignedURLResponse {
        let url = URL(string: "https://kimi.moonshot.cn/api/pre-sign-url")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["action": "image", "name": fileName]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        print("getPreSignedURL-data",data)
        return try JSONDecoder().decode(PreSignedURLResponse.self, from: data)
    }
    
    func uploadImage(to urlString: String, imageData: Data) async throws {
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
//        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: imageData)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        print("uploadImage succ")
    }
    
    func getFileDetail(fileId: String, fileName: String, width: String, height: String) async throws -> FileDetailResponse {
        let url = URL(string: "https://kimi.moonshot.cn/api/file")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = FileDetailRequest(
            type: "image",
            name: fileName,
            fileId: fileId,
            meta: FileMeta(width: width, height: height)
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(FileDetailResponse.self, from: data)
    }
    
    
    func analyzeImage(fileId: String, fileName: String, fileSize: Int, fileDetail: FileDetailResponse, chatId: String, onReceive: @escaping (String) -> Void) async throws -> AnalysisResponse {
        let url = URL(string: "https://kimi.moonshot.cn/api/chat/\(chatId)/completion/stream")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let fileRef = FileRef(
            id: fileId,
            name: fileName,
            size: fileSize,
            detail: fileDetail,
            fileInfo: fileDetail
        )
        
        
        let prompt1 = """
            我作为一名英语学习者，当前的英语水平为\(settingsManager.englishLevel.description)级别。我希望通过图片进行场景化学习英语单词。请根据我提供的图片，分析并返回以下信息：
            1、单词
              - 从图中提取常用的英语单词。
              - 提供以下信息：
                    - 单词
                    - 音标，美式
                    - 中文解释
                    - 单词所在的图片位置：包括 x 和 y 坐标（归一化到 0~1 范围，保留四位小数点）。
               - 注意：单词的指示点应标记物品中的一个具体点，单词之间的位置不要重叠。
            2、句子
              - 使用一句最简单、准确的英语描述图片内容。
              - 提供地道的中文翻译。
              - 返回格式
                 - 请以 标准 JSON 格式 返回结果，示例如下：
                    {
                        "words": [
                            {
                                "word": "Stool",
                                "phoneticsymbols": "/stuːl/",
                                "explanation": "凳子",
                                "location": "0.55, 0.65"
                            },
                            ...
                        ],
                        "sentence": {
                            "text": "A green plastic stool stands on a wooden floor against a gray wall, near a light switch.",
                            "translation": "一个绿色的塑料凳子放在木地板上，靠在灰色的墙上，靠近一个灯开关。"
                        }
                    }
            """
        
        let prompt = """
        我作为一个英语学习者，英语水平为\(settingsManager.englishLevel.description)水平，我想通过图片场景化学习新的英语词块，请分析我提供的图片，提供一下信息：
        1、词块：
          - 图片场景中我可以学习到相对我英语水平之上的 Top 8 英语词块，信息包括词块、音标和中文解释、词块所在图片大致位置（词块指向物品中的一个点表示，x 和 y 坐标，归一化到0~1的范围，精度为后四位小数点，词块之间的位置不要重叠）
          - 英语词块（chunk）是指在语言处理中，作为一个整体来理解和使用的一组词或短语。词块可以是固定搭配、习惯用语、短语动词、常见的表达方式等。它们在语言中频繁出现，具有一定的固定性和连贯性，使得学习者能够更自然地使用语言。
        2、句子
          - 使用一句最简单、准确的英语描述图片内容。
          - 提供地道的中文翻译。
          - 返回格式，请以 标准 JSON 格式 返回结果，示例如下：
            {
                "words": [
                    {
                        "word": "emergency brake",
                        "phoneticsymbols": "/iˈmɜːdʒənsi breɪk/",
                        "explanation": "紧急刹车",
                        "location": "0.55, 0.65"
                    },
                    ...
                ],
                "sentence": {
                    "text": "The subway car is empty, with handrails, safety strips, and overhead lights clearly visible.",
                    "translation": "地铁车厢是空的，扶手、安全条和头顶灯清晰可见。"
                }
            }
        """
        print("prompt:",prompt)
        let analysisRequest = ImageAnalysisRequest(
            messages: [
                Message(role: "user", content: prompt)
            ],
            useSearch: true,
            extend: Extend(sidebar: true),
            kimiplusId: "kimi",
            useResearch: false,
            useMath: false,
            refs: [fileId],
            refsFile: [fileRef]
        )
        
        request.httpBody = try JSONEncoder().encode(analysisRequest)
        
        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        
        var buffer = ""
        print("开始接收 SSE 数据流...")
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else {
                continue
            }
            let jsonString = String(line.dropFirst(6))
            
            if let data = jsonString.data(using: .utf8) {
                do {
                    let event = try JSONDecoder().decode(SSEEvent.self, from: data)
                    
                    switch event.event {
                    case "cmpl":
                        if let text = event.text {
                            buffer += text
                            onReceive(buffer)
                        }
                    case "done":
                        print("收到完成事件")
                        break
                    default:
                        break
                    }
                } catch {
                    print("解析SSE事件失败: \(error)")
                }
            }
        }
        
        print("最终的buffer内容: \(buffer)")
        
        // Handle empty buffer case
        guard !buffer.isEmpty else {
            throw NSError(domain: "AnalysisError",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No response data received"])
        }

        guard let data = buffer.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        do {
            let response = try JSONDecoder().decode(AnalysisResponse.self, from: data)
            print("成功解析为AnalysisResponse，包含 \(response.words.count) 个单词，sentence：\(response.sentence)")
            return response
        } catch {
            print("解析AnalysisResponse失败: \(error)")
            print("尝试解析的数据内容: \(String(data: data, encoding: .utf8) ?? "无法读取")")
            throw error
        }
    }
    
    func createChat() async throws -> CreateChatResponse {
        print("createCha start")
        let url = URL(string: "https://kimi.moonshot.cn/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = CreateChatRequest(
            name: "拍单词",
            isExample: false,
            enterMethod: "new_chat",
            kimiplusId: "kimi"
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        print("createCha end,data:",data)
        
        return try JSONDecoder().decode(CreateChatResponse.self, from: data)
    }
}


extension UIImage {
    var heic: Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.heic.identifier as CFString, 1, nil) else { return nil }
        guard let cgImage = self.cgImage else { return nil }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
