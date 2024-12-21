import SwiftUI

class DataManager: ObservableObject {
    static let shared = DataManager()
    @Published var scenes: [SceneItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let scenesKey = "saved_scenes"
    private let queue = DispatchQueue(label: "com.app.datamanger.queue")
    private var saveWorkItem: DispatchWorkItem?
    
    private init() {
        loadScenes()
        
        // 添加应用生命周期观察
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveOnBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    func updateScene(_ scene: SceneItem) {
        print("DataManager - 开始更新场景")
        print("DataManager - 场景ID: \(scene.id)")
        print("DataManager - 更新前场景数量: \(scenes.count)")
        
        DispatchQueue.main.async {
            if let index = self.scenes.firstIndex(where: { $0.id == scene.id }) {
                print("DataManager - 找到要更新的场景，索引: \(index)")
                print("DataManager - 更新前单词数量: \(self.scenes[index].words.count)")
                print("DataManager - 更新后单词数量: \(scene.words.count)")
                
                // 直接替换整个场景
                self.scenes[index] = scene
                
                // 确保更新后的场景单词数量正确
                print("DataManager - 实际更新后单词数量: \(self.scenes[index].words.count)")
                
                // 立即保存更新
                self.saveScenes()
                
                // 刷新单词管理器
                print("DataManager - 正在刷新单词管理器...")
                WordManager.shared.refreshWords()
            } else {
                print("DataManager - 未找到要更新的场景，ID: \(scene.id)")
                self.scenes.insert(scene, at: 0)
            }
            
            print("DataManager - 更新后场景数量: \(self.scenes.count)")
        }
    }
    
    func updateWordPosition(word: String, position: CGPoint) {
        queue.async { [weak self] in
            guard let self = self,
                  let sceneIndex = self.scenes.firstIndex(where: { scene in
                      scene.words.contains { $0.word == word }
                  }),
                  let wordIndex = self.scenes[sceneIndex].words.firstIndex(where: { $0.word == word })
            else {
                return
            }
            
            let normalizedPosition = CGPoint(
                x: max(0.0, min(position.x, 1.0)),
                y: max(0.0, min(position.y, 1.0))
            )
            
            DispatchQueue.main.async {
                var updatedScene = self.scenes[sceneIndex]
                var updatedWords = updatedScene.words
                var updatedWord = updatedWords[wordIndex]
                updatedWord.customPosition = normalizedPosition
                updatedWords[wordIndex] = updatedWord
                updatedScene.words = updatedWords
                
                withAnimation(.spring(response: 0.3)) {
                    self.scenes[sceneIndex] = updatedScene
                }
                
                self.scheduleSave()
            }
        }
    }
    
    private func scheduleSave() {
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveScenes()
        }
        
        saveWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    @objc private func saveOnBackground() {
        saveWorkItem?.cancel()
        saveScenes()
    }
    
    private func saveScenes() {
        print("DataManager - 开始保存场景")
        let encodableScenes = scenes.map { scene -> EncodableScene in
            return EncodableScene(
                id: scene.id,
                imageUrl: scene.imageUrl,
                assetIdentifier: scene.assetIdentifier,
                words: scene.words,
                sentence: scene.sentence,
                createdAt: scene.createdAt,
                status: scene.status,
                errorMessage: scene.errorMessage
            )
        }
        
        if let encoded = try? JSONEncoder().encode(encodableScenes) {
            userDefaults.set(encoded, forKey: scenesKey)
            userDefaults.synchronize() // 确保立即保存
            print("DataManager - 场景保存完成，单词数量: \(scenes.first?.words.count ?? 0)")
        }
    }
    
    private func loadScenes() {
        queue.async { [weak self] in
            guard let self = self,
                  let data = self.userDefaults.data(forKey: self.scenesKey)
            else {
                print("No saved scenes found")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decodedScenes = try decoder.decode([EncodableScene].self, from: data)
                DispatchQueue.main.async {
                    self.scenes = decodedScenes.map { scene in
                        SceneItem(
                            id: scene.id,
                            imageUrl: scene.imageUrl,
                            assetIdentifier: scene.assetIdentifier,
                            words: scene.words,
                            sentence: scene.sentence,
                            createdAt: scene.createdAt,
                            status: scene.status,
                            errorMessage: scene.errorMessage
                        )
                    }
                }
                print("Successfully loaded \(decodedScenes.count) scenes")
            } catch {
                print("Error loading scenes: \(error)")
            }
        }
    }
    
    func deleteScene(_ scene: SceneItem) {
        DispatchQueue.main.async {
            if let index = self.scenes.firstIndex(where: { $0.id == scene.id }) {
                self.scenes.remove(at: index)
                self.scheduleSave()
            }
        }
    }
    
    func refreshScenes() {
        let currentScenes = self.scenes
        self.scenes = currentScenes
        
        scheduleSave()
    }
    
    func addScene(_ scene: SceneItem) {
        scenes.append(scene)
        saveScenes()
        WordManager.shared.refreshWords()
    }
}
