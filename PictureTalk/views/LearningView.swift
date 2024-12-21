import SwiftUI

struct LearningView: View {
    @StateObject private var learningManager = LearningManager.shared
    @StateObject private var wordManager = WordManager.shared
    @State private var showingEmptyState = false
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: LearningTask?
    @State private var isCreatingTask = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.tabSelection) private var tabSelection
    
    var body: some View {
        NavigationView {
            ZStack {
                if learningManager.learningTasks.isEmpty {
                    // 空状态视图
                    VStack(spacing: 24) {
                        Image(systemName: "book.closed.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 12) {
                            Text("开始你的学习之旅")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("点击右上角"+"按钮创建今日学习任务")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        if WordManager.shared.allWords.isEmpty {
                            VStack(spacing: 16) {
                                Text("提示：请先添加场景")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                
                                Button(action: {
                                    // 使用环境变量切换标签页
                                    tabSelection.wrappedValue = 1
                                }) {
                                    Label("去添加场景", systemImage: "camera.fill")
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                } else {
                    // 现有的列表视图
                    List {
                        ForEach(learningManager.learningTasks.sorted(by: { $0.date > $1.date })) { task in
                            NavigationLink(destination: LearningSessionView(task: task)) {
                                LearningTaskRow(task: task)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    taskToDelete = task
                                    showingDeleteAlert = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                if isCreatingTask {
                    ProgressView("创建学习任务...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                }
            }
            .navigationTitle("学习")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if learningManager.hasTodayTask() {
                            showingEmptyState = true
                        } else {
                            createTask()
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(isCreatingTask)
                }
            }
            .alert("今日任务已存在", isPresented: $showingEmptyState) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("请完成今的学习任务后再创建新任务")
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let task = taskToDelete {
                        learningManager.deleteTask(task)
                    }
                }
            } message: {
                if let task = taskToDelete {
                    Text("确定要删除\(formatDate(task.date))的学习任务吗？")
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            // 确保单词数据已加载
            wordManager.refreshWords()
        }
    }
    
    private func createTask() {
        isCreatingTask = true
        
        if WordManager.shared.allWords.isEmpty {
            errorMessage = "没有可用的单词，请先添加场景"
            showError = true
            isCreatingTask = false
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            learningManager.generateDailyTask()
            isCreatingTask = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

struct LearningTaskRow: View {
    let task: LearningTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(task.date))
                    .font(.headline)
                Spacer()
                StatusBadge(status: task.status)
            }
            
            Text("\(task.words.count)个单词")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 进度条
            ProgressView(value: progress)
                .tint(progressColor)
        }
        .padding(.vertical, 4)
    }
    
    private var progress: Double {
        let completed = Double(task.words.filter { $0.status != .notLearned }.count)
        return completed / Double(task.words.count)
    }
    
    private var progressColor: Color {
        switch task.status {
        case .completed:
            return .green
        case .inProgress:
            return .blue
        case .notStarted:
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: LearningTask.LearningStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusText: String {
        switch status {
        case .notStarted:
            return "未开始"
        case .inProgress:
            return "学习中"
        case .completed:
            return "已完成"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .notStarted:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        }
    }
} 