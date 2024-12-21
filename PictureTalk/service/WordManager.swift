import SwiftUI

class WordManager: ObservableObject {
    static let shared = WordManager()
    @Published var allWords: [UniqueWord] = []
    
    private init() {
        updateAllWords()
    }
    
    func updateAllWords() {
        // 从所有场景中收集单词并去重
        let scenes = DataManager.shared.scenes
        var uniqueWords: [UniqueWord] = []
        var wordDict: [String: UniqueWord] = [:]
        
        for scene in scenes {
            for word in scene.words {
                if let existingWord = wordDict[word.word] {
                    // 如果单词已存在，检查场景是否已添加
                    if !existingWord.scenes.contains(where: { $0.id == scene.id }) {
                        existingWord.addScene(scene)
                    }
                } else {
                    // 创建新的唯一单词
                    let uniqueWord = UniqueWord(
                        word: word.word,
                        phoneticsymbols: word.phoneticsymbols,
                        explanation: word.explanation,
                        scenes: [scene]
                    )
                    wordDict[word.word] = uniqueWord
                    uniqueWords.append(uniqueWord)
                }
            }
        }
        
        // 按字母顺序排序
        allWords = uniqueWords.sorted { $0.word < $1.word }
        
        // 加载收藏状态
        loadFavorites()
    }
    
    // 修改删除场景的方法
    func removeWordsForScene(_ scene: SceneItem) {
        // 创建新的单词数组，只保留仍然有其他场景的单词
        allWords = allWords.compactMap { word in
            // 从单词中移除场景
            word.removeScene(scene)
            
            // 如果单词没有关联场景了，返回 nil（将被过滤掉）
            return word.scenes.isEmpty ? nil : word
        }
        
        // 通知视图更新
        objectWillChange.send()
    }
    
    // 为了兼容性，添加 refreshWords 方法作为 updateAllWords 的别名
    func refreshWords() {
        updateAllWords()
    }
    
    func toggleFavorite(_ word: UniqueWord) {
        if let index = allWords.firstIndex(where: { $0.id == word.id }) {
            word.toggleFavorite()
            saveFavorites()
            objectWillChange.send()
        }
    }
    
    private func saveFavorites() {
        let favorites = allWords.filter { $0.isFavorite }.map { $0.word }
        UserDefaults.standard.set(favorites, forKey: "favorited_words")
        UserDefaults.standard.synchronize()
    }
    
    private func loadFavorites() {
        if let favorites = UserDefaults.standard.stringArray(forKey: "favorited_words") {
            for word in allWords {
                if favorites.contains(word.word) {
                    word.isFavorite = true
                } else {
                    word.isFavorite = false
                }
            }
        }
    }
}

// 修改 UniqueWord 类
class UniqueWord: Identifiable, ObservableObject {
    let id = UUID()
    let word: String
    let phoneticsymbols: String
    let explanation: String
    @Published private(set) var scenes: [SceneItem]
    @Published var isFavorite: Bool = false
    @Published private(set) var learningStatus: LearningWord.WordStatus?
    
    init(word: String, phoneticsymbols: String, explanation: String, scenes: [SceneItem]) {
        self.word = word
        self.phoneticsymbols = phoneticsymbols
        self.explanation = explanation
        self.scenes = scenes
        
        // 从 LearningManager 获取学习状态
        if let task = LearningManager.shared.learningTasks.last,
           let learningWord = task.words.first(where: { $0.word == word }) {
            self.learningStatus = learningWord.status
        } else {
            self.learningStatus = .notLearned
        }
    }
    
    func addScene(_ scene: SceneItem) {
        if !scenes.contains(where: { $0.id == scene.id }) {
            scenes.append(scene)
            objectWillChange.send()
        }
    }
    
    func removeScene(_ scene: SceneItem) {
        scenes.removeAll { $0.id == scene.id }
        objectWillChange.send()
    }
    
    func containsScene(_ sceneId: String) -> Bool {
        return scenes.contains { $0.id == sceneId }
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
    }
} 