import SwiftUI

struct ProfileView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var aiConfig = AIConfigManager.shared
    @State private var showingAPIKeyAlert = false
    @State private var tempAPIKey = ""
    @State private var isLoading = false
    @State private var selectedModel: AIModel? = nil
    
    var body: some View {
        NavigationView {
            List {
                // 单词设置
                WordSettingsSection()
                
                // 大模型配置
                Section(header: Text("大模型配置")) {
                    // 当前选择的模型
                    Picker("选择模型", selection: $aiConfig.currentConfig.model) {
                        ForEach(AIModel.allCases, id: \.self) { model in
                            Text(model.description).tag(model)
                        }
                    }
                    
                    // 所有模型的配置状态
                    ForEach(AIModel.allCases, id: \.self) { model in
                        if model.needsAPIKey {
                            // API Key 配置行
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.description)
                                        .font(.subheadline)
                                    Text(aiConfig.getAPIKeyStatus(for: model))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    selectedModel = model
                                    tempAPIKey = aiConfig.getAPIKey(for: model)
                                    showingAPIKeyAlert = true
                                }) {
                                    Text("设置")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 关于
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("设置")
            .alert("设置 API Key", isPresented: $showingAPIKeyAlert) {
                SecureField("请输入 API Key", text: $tempAPIKey)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                Button("取消", role: .cancel) {}
                Button("确定") {
                    if let model = selectedModel {
                        aiConfig.setAPIKey(tempAPIKey, for: model)
                    }
                }
            } message: {
                if let model = selectedModel {
                    Text("请输入您的 \(model.description) API Key")
                }
            }
        }
    }
    
    private func connectToLocalServer() {
        isLoading = true
        
        Task {
            do {
                let url = URL(string: "http://localhost:8080/health")!
                let (_, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        aiConfig.currentConfig.isModelLoaded = true
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("无法连接到本地服务器: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }
}

// Bundle 扩展，用于获取应用版本号
extension Bundle {
    var appVersion: String {
        if let version = infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0"
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}

struct WordSettingsSection: View {
    @StateObject private var learningManager = LearningManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingWordsPerLessonEditor = false
    
    var body: some View {
        Group {
            // 学习记录 Section
            Section("学习记录") {
                LearningContributionView(records: learningManager.learningRecords)
            }
            
            // 单词设置 Section
            Section("单词设置") {
                // 英语等级设置
                Picker("英语等级", selection: $settingsManager.englishLevel) {
                    ForEach(EnglishLevel.allCases, id: \.self) { level in
                        Text(level.description).tag(level)
                    }
                }
                
                // 课程单词数设置
                HStack {
                    Text("每课时单词数")
                    Spacer()
                    Text("\(learningManager.settings.wordsPerLesson)")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingWordsPerLessonEditor = true
                }
            }
        }
        .sheet(isPresented: $showingWordsPerLessonEditor) {
            WordsPerLessonEditor(settings: learningManager.settings) { newSettings in
                learningManager.updateSettings(newSettings)
            }
        }
    }
}

struct WordsPerLessonEditor: View {
    let settings: LearningSettings
    let onSave: (LearningSettings) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wordsPerLesson: Double
    
    init(settings: LearningSettings, onSave: @escaping (LearningSettings) -> Void) {
        self.settings = settings
        self.onSave = onSave
        _wordsPerLesson = State(initialValue: Double(settings.wordsPerLesson))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack {
                        Slider(
                            value: $wordsPerLesson,
                            in: Double(LearningSettings.minWordsPerLesson)...Double(LearningSettings.maxWordsPerLesson),
                            step: 1
                        )
                        
                        Text("每课时 \(Int(wordsPerLesson)) 个单词")
                            .font(.headline)
                    }
                    .padding(.vertical)
                } footer: {
                    Text("设置每个学习任务包含的单词数量（\(LearningSettings.minWordsPerLesson)-\(LearningSettings.maxWordsPerLesson)个）")
                }
            }
            .navigationTitle("课程设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        var newSettings = settings
                        newSettings.wordsPerLesson = Int(wordsPerLesson)
                        onSave(newSettings)
                        dismiss()
                    }
                }
            }
        }
    }
} 
