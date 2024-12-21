import Foundation
import SwiftUI

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var tasks: [ImageAnalysisTask] = []
    @Published var processingCount: Int = 0
    
    private let queue = DispatchQueue(label: "com.app.imageanalysis", qos: .userInitiated)
    private let semaphore = DispatchSemaphore(value: 1)
    private let maxConcurrentTasks = 2
    
    private init() {}
    
    func addTask(_ task: ImageAnalysisTask) {
        DispatchQueue.main.async {
            self.tasks.insert(task, at: 0)
            self.processingCount += 1
            self.processNextTask()
        }
    }
    
    private func processNextTask() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 获取下一个等待处理的任务
            guard let taskIndex = self.tasks.firstIndex(where: { $0.status == .waiting }) else {
                return
            }
            
            DispatchQueue.main.async {
                self.tasks[taskIndex].status = .processing
            }
            
            // 开始处理任务
            Task {
                do {
                    let task = self.tasks[taskIndex]
                    let viewModel = ImageUploadViewModel()
                    viewModel.selectedImage = task.image
                    viewModel.selectedAssetIdentifier = task.assetIdentifier
                    
                    await viewModel.uploadAndAnalyzeImage()
                    
                    DispatchQueue.main.async {
                        // 任务完成后从列表中移除
                        self.tasks.removeAll { $0.id == task.id }
                        self.processingCount -= 1
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.tasks[taskIndex].status = .failed
                        self.tasks[taskIndex].errorMessage = error.localizedDescription
                        self.processingCount -= 1
                    }
                }
                
                // 处理下一个任务
                self.processNextTask()
            }
        }
    }
    
    // 添加一个方法来检查任务是否存在
    func hasTask(withId id: String) -> Bool {
        return tasks.contains { $0.id == id }
    }
    
    func retryTask(_ task: ImageAnalysisTask) {
        // 重置任务状态
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            DispatchQueue.main.async {
                self.tasks[index].status = .waiting
                self.tasks[index].errorMessage = nil
                self.processingCount += 1
                self.processNextTask()
            }
        }
    }
} 
