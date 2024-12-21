import SwiftUI
import Photos

struct TaskListView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var dataManager = DataManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var selectedScene: SceneItem?
    @State private var isEditing = false
    @State private var selectedScenes: Set<String> = []
    @State private var showingRetryAlert = false
    @State private var retryTask: ImageAnalysisTask?
    @State private var isAllSelected = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var allScenes: [SceneItem] {
        // 获取所有任务场景，包括失败的任务
        let taskScenes = taskManager.tasks.map { task in
            SceneItem(
                id: task.id,
                imageUrl: "",
                assetIdentifier: task.assetIdentifier,
                words: [],
                sentence: Sentence(text: "", translation: ""),
                createdAt: task.createdAt,
                status: task.status == .failed ? .analyzing : .analyzing,
                image: task.image,
                errorMessage: task.status == .failed ? task.errorMessage : nil
            )
        }
        
        // 过滤掉已经在 DataManager 中的场景
        let filteredTaskScenes = taskScenes.filter { taskScene in
            !dataManager.scenes.contains { $0.id == taskScene.id }
        }
        
        return (filteredTaskScenes + dataManager.scenes)
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(allScenes) { scene in
                        SceneGridItem(
                            scene: scene,
                            isEditing: isEditing,
                            isSelected: selectedScenes.contains(scene.id)
                        ) {
                            if isEditing {
                                if selectedScenes.contains(scene.id) {
                                    selectedScenes.remove(scene.id)
                                } else {
                                    selectedScenes.insert(scene.id)
                                }
                            }
                        } onDelete: {
                            selectedScene = scene
                            showingDeleteAlert = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("任务列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button(action: {
                            isAllSelected.toggle()
                            if isAllSelected {
                                // 选择所有场景
                                selectedScenes = Set(allScenes.map { $0.id })
                            } else {
                                // 取消选择所有场景
                                selectedScenes.removeAll()
                            }
                        }) {
                            Text(isAllSelected ? "取消全选" : "全选")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button(action: {
                            if !selectedScenes.isEmpty {
                                showingDeleteAlert = true
                            }
                        }) {
                            Text("删除(\(selectedScenes.count))")
                                .foregroundColor(.red)
                        }
                        .disabled(selectedScenes.isEmpty)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isEditing.toggle()
                        if !isEditing {
                            selectedScenes.removeAll()
                            isAllSelected = false
                        }
                    }) {
                        Text(isEditing ? "完成" : "编辑")
                    }
                }
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let scene = selectedScene {
                        deleteScene(scene)
                    } else if !selectedScenes.isEmpty {
                        // 删除选中的场景
                        for sceneId in selectedScenes {
                            if let scene = allScenes.first(where: { $0.id == sceneId }) {
                                deleteScene(scene)
                            }
                        }
                        selectedScenes.removeAll()
                        isAllSelected = false
                        isEditing = false
                    }
                }
            } message: {
                if let _ = selectedScene {
                    Text("确定要删除这个场景吗？此操作不可恢复。")
                } else {
                    Text("确定要删除\(selectedScenes.count)个场景吗？此操作不可恢复。")
                }
            }
            .alert("重试分析", isPresented: $showingRetryAlert) {
                Button("取消", role: .cancel) {
                    retryTask = nil
                }
                Button("重试") {
                    if let task = retryTask {
                        taskManager.retryTask(task)
                    }
                    retryTask = nil
                }
            } message: {
                Text("是否要重新分析这张图片？")
            }
        }
    }
    
    private func deleteScene(_ scene: SceneItem) {
        // 1. 删除图片文件
        let imagesFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        let imagePath = imagesFolder.appendingPathComponent("\(scene.id).jpg")
        try? FileManager.default.removeItem(at: imagePath)
        
        // 2. 从数据管理器中删除场景
        dataManager.deleteScene(scene)
        
        // 3. 如果是正在处理的任务，从任务管理器中删除
        if let taskIndex = taskManager.tasks.firstIndex(where: { $0.id == scene.id }) {
            taskManager.tasks.remove(at: taskIndex)
            if taskManager.processingCount > 0 {
                taskManager.processingCount -= 1
            }
        }
        
        // 4. 更新单词管理器
        WordManager.shared.removeWordsForScene(scene)
        WordManager.shared.updateAllWords()
        
        // 5. 重置选中状态
        selectedScene = nil
    }
}

// 修改网格项视图以支持显示错误状态
struct SceneGridItem: View {
    let scene: SceneItem
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var loadedImage: UIImage?
    @EnvironmentObject private var dataManager: DataManager
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 图片缩略图按钮
            Button(action: {
                if isEditing {
                    onTap()
                } else {
                    // 如果不是编辑模式，则跳转到对应场景
                    if let index = dataManager.scenes.firstIndex(where: { $0.id == scene.id }) {
                        // 直接发送跳转通知，由父视图处理关闭操作
                        NotificationCenter.default.post(
                            name: NSNotification.Name("JumpToScene"),
                            object: nil,
                            userInfo: ["index": index]
                        )
                    }
                }
            }) {
                ZStack {
                    if let image = loadedImage ?? scene.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                    
                    // 编辑模式下显示选中状态
                    if isEditing {
                        ZStack {
                            Color.black.opacity(0.3)
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 状态指示器
            if scene.status == .analyzing {
                if let task = TaskManager.shared.tasks.first(where: { $0.id == scene.id }),
                   task.status == .failed {
                    // 失败状态显示
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                        Text("重试")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 100)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // 处理中状态
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .frame(width: 100, height: 100)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // 非编辑模式下显示删除按钮
            if !isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                        .clipShape(Circle())
                }
                .padding(4)
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
    }
    
    private func loadImageIfNeeded() {
        // 如果已经有图片，直接使用
        if scene.image != nil {
            loadedImage = scene.image
            return
        }
        
        // 从文档目录加载图片
        let imagesFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        let imagePath = imagesFolder.appendingPathComponent("\(scene.id).jpg")
        
        if FileManager.default.fileExists(atPath: imagePath.path),
           let imageData = try? Data(contentsOf: imagePath),
           let image = UIImage(data: imageData) {
            loadedImage = image
        }
        // 如果有 assetIdentifier，尝试相册加载
        else if !scene.assetIdentifier.isEmpty {
            loadImageFromPhotoLibrary()
        }
    }
    
    private func loadImageFromPhotoLibrary() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [scene.assetIdentifier], options: nil)
        if let asset = fetchResult.firstObject {
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200), // 适当的缩略图大小
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        self.loadedImage = image
                    }
                }
            }
        }
    }
}

#Preview {
    TaskListView()
} 
