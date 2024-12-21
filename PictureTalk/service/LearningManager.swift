import Foundation

class LearningManager: ObservableObject {
    static let shared = LearningManager()
    @Published var learningTasks: [LearningTask] = []
    @Published var settings: LearningSettings = LearningSettings()
    @Published var learningRecords: [LearningRecord] = []
    
    private let defaults = UserDefaults.standard
    private let tasksKey = "learning_tasks"
    private let settingsKey = "learning_settings"
    private let recordsKey = "learning_records"
    private let wordManager = WordManager.shared
    
    private init() {
        loadTasks()
        loadSettings()
        loadRecords()
    }
    
    // 生成每日学习任务
    func generateDailyTask() {
        print("开始生成每日学习任务")
        
        // 检查今天是否已经有任务
        if hasTodayTask() {
            print("今日已有任务，取消生成")
            return
        }
        
        // 从所有单词中选择未学习的单词
        let allWords = wordManager.allWords
        print("获取到单词总数: \(allWords.count)")
        
        // 检查是否有可用单词
        guard !allWords.isEmpty else {
            print("没有可用的单词，请先添加场景")
            print("WordManager 状态: \(String(describing: wordManager))")
            return
        }
        
        let learningWords = selectWordsForLearning(from: allWords, count: settings.wordsPerLesson)
        print("已选择学习单词数: \(learningWords.count)")
        
        let task = LearningTask(
            id: UUID().uuidString,
            date: Date(),
            words: learningWords,
            status: .notStarted,
            createdAt: Date()
        )
        
        // 直接在主线程更新，避免异步问题
        self.learningTasks.append(task)
        self.saveTasks()
        print("学习任务创建完成，ID: \(task.id)")
    }
    
    // 将 hasTodayTask 改为 public
    func hasTodayTask() -> Bool {
        let calendar = Calendar.current
        return learningTasks.contains { task in
            calendar.isDate(task.date, inSameDayAs: Date())
        }
    }
    
    // 选择学习单词
    private func selectWordsForLearning(from words: [UniqueWord], count: Int) -> [LearningWord] {
        print("开始选择学习单词，可用单词数: \(words.count)")
        
        let selectedWords = words.prefix(count).map { uniqueWord in
            // 获取单词的第一个场景
            let firstScene = uniqueWord.scenes.first
            print("选择单词: \(uniqueWord.word), 场景ID: \(firstScene?.id ?? "无场景")")
            
            return LearningWord(
                id: UUID().uuidString,
                word: uniqueWord.word,
                phoneticsymbols: uniqueWord.phoneticsymbols,
                explanation: uniqueWord.explanation,
                sceneId: firstScene?.id ?? "",  // 使用第一个场景的ID
                status: .notLearned,
                createdAt: Date()
            )
        }
        return Array(selectedWords)
    }
    
    // 更新任务状态
    func updateTask(_ task: LearningTask) {
        if let index = learningTasks.firstIndex(where: { $0.id == task.id }) {
            learningTasks[index] = task
            saveTasks()
        }
    }
    
    // 更新单词状态
    func updateWordStatus(taskId: String, wordId: String, status: LearningWord.WordStatus) {
        if let taskIndex = learningTasks.firstIndex(where: { $0.id == taskId }),
           let wordIndex = learningTasks[taskIndex].words.firstIndex(where: { $0.id == wordId }) {
            learningTasks[taskIndex].words[wordIndex].status = status
            
            // 检查是否所有单词都已学习
            let allLearned = learningTasks[taskIndex].words.allSatisfy { $0.status != .notLearned }
            if allLearned {
                learningTasks[taskIndex].status = .completed
            } else {
                learningTasks[taskIndex].status = .inProgress
            }
            
            saveTasks()
        }
    }
    
    // 保存任务
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(learningTasks) {
            defaults.set(encoded, forKey: tasksKey)
        }
    }
    
    // 加载任务
    private func loadTasks() {
        if let data = defaults.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([LearningTask].self, from: data) {
            self.learningTasks = decoded
        }
    }
    
    // 在 LearningManager 类中添加删除方法
    func deleteTask(_ task: LearningTask) {
        if let index = learningTasks.firstIndex(where: { $0.id == task.id }) {
            learningTasks.remove(at: index)
            saveTasks()
        }
    }
    
    // 更新设置
    func updateSettings(_ newSettings: LearningSettings) {
        settings = newSettings
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: settingsKey)
        }
    }
    
    // 加载设置
    private func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(LearningSettings.self, from: data) {
            self.settings = decoded
        }
    }
    
    // 记录学习情况
    func recordLearning(task: LearningTask) {
        let completedWords = task.words.filter { $0.status != .notLearned }.count
        
        let record = LearningRecord(
            id: UUID().uuidString,
            date: task.date,
            completedWords: completedWords,
            totalWords: task.words.count
        )
        
        learningRecords.append(record)
        saveRecords()
    }
    
    // 保存记录
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(learningRecords) {
            defaults.set(encoded, forKey: recordsKey)
        }
    }
    
    // 加载记录
    private func loadRecords() {
        if let data = defaults.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([LearningRecord].self, from: data) {
            self.learningRecords = decoded
        }
    }
} 