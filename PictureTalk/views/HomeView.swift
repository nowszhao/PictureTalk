import SwiftUI
import Photos

struct HomeView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var currentIndex = 0
    
    var body: some View {
        Group {
            if dataManager.scenes.isEmpty {
                EmptyStateView()
            } else {
                VerticalPageView(
                    scenes: dataManager.scenes,
                    currentIndex: $currentIndex
                )
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            // 隐藏导航栏和标签栏
            UINavigationBar.appearance().isHidden = true
        }
    }
}

struct EmptyStateView: View {
    @Environment(\.tabSelection) private var tabSelection
    @StateObject private var taskManager = TaskManager.shared
    @State private var showTaskList = false
    @State private var currentIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色
                Color.black
                    .ignoresSafeArea()
                
                // 空状态提示 - 居中显示
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("还没有任何场景")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("点击下方开拍按钮\n开始创建你的一个场景")
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        tabSelection.wrappedValue = 1
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("开始拍摄")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                    .padding(.top, 20)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 右侧按钮组 - 固定在右侧
                HStack {
                    Spacer()
                    
                    VStack(spacing: 25) {
                        Spacer()
                        
                        // 播放按钮（禁用状态）
                        VStack(spacing: 6) {
                            Button(action: {}) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.3))
                                    .frame(width: 52, height: 52)
                                    .contentShape(Circle())
                            }
                            .disabled(true)
                            
                            Text("播放")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        // 分享按钮（禁用状态）
                        VStack(spacing: 6) {
                            Button(action: {}) {
                                Image(systemName: "arrowshape.turn.up.right.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.3))
                                    .frame(width: 52, height: 52)
                                    .contentShape(Circle())
                            }
                            .disabled(true)
                            .buttonStyle(TikTokButtonStyle())
                            
                            Text("分享")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        // 任务按钮（正常状态）
                        VStack(spacing: 6) {
                            Button(action: {
                                showTaskList = true
                            }) {
                                ZStack {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                        .frame(width: 52, height: 52)
                                        .contentShape(Circle())
                                    
                                    if taskManager.processingCount > 0 {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 20, height: 20)
                                            
                                            Text("\(taskManager.processingCount)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .offset(x: 18, y: -18)
                                    }
                                }
                            }
                            
                            Text("任务")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                        }
                        

                        Spacer()
                            .frame(height: 100)
                    }
                    .frame(width: 85)
                    .padding(.trailing, 8)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showTaskList) {
            TaskListView()
        }
    }
}

struct SceneCardView: View {
    let scene: SceneItem
    @ObservedObject var playViewModel: WordPlayViewModel
    @State private var imageSize: CGSize = .zero
    @State private var existingCardPositions: [CGRect] = []
    @State private var image: UIImage?
    @State private var isExpanded = false
    @State private var showingShareSheet = false
    @State private var isEditMode = false
    @StateObject private var dataManager = DataManager.shared
    @State private var showingDeleteAlert = false
    @State private var wordToDelete: WordItem?
    @State private var visibleWords: [WordItem] = []
    
    private let referenceSize = CGSize(width: 1080, height: 1920)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 背景色
                Color.black
                    .ignoresSafeArea()
                
                if let displayImage = image {
                    // 图片层
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    if scene.status == .completed {
                        ZStack {
                            ForEach(visibleWords, id: \.word) { item in
                                let isCurrentlyPlaying = playViewModel.isPlaying && 
                                                       playViewModel.currentWordIndex == visibleWords.firstIndex(of: item)
                                
                                if !isEditMode || wordToDelete?.word != item.word {
                                    WordCardView(
                                        item: item,
                                        imageSize: referenceSize,
                                        existingPositions: existingCardPositions,
                                        isHighlighted: isCurrentlyPlaying,
                                        playViewModel: playViewModel,
                                        isEditMode: isEditMode,
                                        onDelete: {
                                            print("准备删除单词: \(item.word)")
                                            wordToDelete = item
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .id(item.word)
                                    .zIndex(isCurrentlyPlaying ? 999 : 0)
                                    .transition(.opacity)
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    
                    // 句子层
                    VStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // 英文句子
                            Text(scene.sentence.text)
                                .font(.system(size: 17))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(isExpanded ? nil : 2)
                                .multilineTextAlignment(.leading)
                                .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 1)
                                .padding(.bottom, 2)
                            
                            if !isExpanded {
                                // 更多按钮
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded.toggle()
                                    }
                                }) {
                                    Text("more")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            if isExpanded {
                                // 中文翻译
                                Text(scene.sentence.translation)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.top, 2)
                                
                                // 收起按钮
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded.toggle()
                                    }
                                }) {
                                    Text("less")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 60)
                        .frame(width: geometry.size.width)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.2),
                                    Color.clear
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: isExpanded ? 200 : 120)
                            .allowsHitTesting(false)
                        )
                        .offset(y: -30)
                    }
                    .zIndex(1)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                // 添加编辑模式提示
                if isEditMode {
                    VStack {
                        Text("编辑模式")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(15)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 50)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            isEditMode.toggle()
                        }
                    }
            )
            .onTapGesture {
                if isEditMode {
                    withAnimation(.spring()) {
                        isEditMode = false
                    }
                }
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {
                    print("取消删除单词")
                    wordToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let word = wordToDelete {
                        print("确认删除单词: \(word.word)")
                        deleteWord(word)
                        wordToDelete = nil
                    }
                }
            } message: {
                if let word = wordToDelete {
                    Text("确定要删除单词\(word.word)吗？")
                }
            }
            .onChange(of: isEditMode) { newValue in
                print("编辑模式状态变更: \(newValue ? "开启" : "关闭")")
            }
        }
        .ignoresSafeArea()
        .onAppear {
            loadImage()
            visibleWords = scene.words
        }
        .onChange(of: scene.words) { newWords in
            print("SceneCardView - 场景单词发生变化")
            print("SceneCardView - 新的单词数量: \(newWords.count)")
            print("SceneCardView - 单词列表: \(newWords.map { $0.word }.joined(separator: ", "))")
            withAnimation(.easeInOut(duration: 0.3)) {
                visibleWords = newWords
            }
        }
    }
    
    private func loadImage() {
        // 首先尝试从文档目录加载
        loadImageFromDocuments()
        
        // 如果文档目录没有图片，且有 assetIdentifier，则从相册加载
        if image == nil && !scene.assetIdentifier.isEmpty {
            checkPhotoLibraryPermission()
        }
    }
    
    private func loadImageFromLibrary() {
        guard !scene.assetIdentifier.isEmpty else {
            print("Asset identifier is empty for scene ID: \(scene.id)")
            loadImageFromDocuments()
            return
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [scene.assetIdentifier], options: nil)
        
        if let asset = fetchResult.firstObject {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let image = image {
                    DispatchQueue.main.async {
                        self.image = image
                        self.imageSize = image.size
                        print("Successfully loaded image from library for scene ID: \(self.scene.id)")
                    }
                } else {
                    self.loadImageFromDocuments()
                }
            }
        } else {
            loadImageFromDocuments()
        }
    }
    
    private func loadImageFromDocuments() {
        let imagesFolder = getImagesDirectory()
        let imagePath = imagesFolder.appendingPathComponent("\(scene.id).jpg")
        print("Trying to load image from: \(imagePath)")
        
        guard FileManager.default.fileExists(atPath: imagePath.path) else {
            print("Image file does not exist at path: \(imagePath)")
            return
        }
        
        do {
            let imageData = try Data(contentsOf: imagePath)
            if let loadedImage = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.imageSize = loadedImage.size
                    print("Successfully loaded image from documents for scene ID: \(scene.id)")
                }
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
    
    private func getImagesDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesFolder = documentsPath.appendingPathComponent("Images", isDirectory: true)
        return imagesFolder
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            loadImageFromLibrary()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        loadImageFromLibrary()
                    }
                }
            }
        default:
            print("Photo library access denied")
        }
    }
    
    private func shareScene(image: UIImage, words: [WordItem]) {
        print("开始执行 shareScene 方法")
        print("图片尺寸: \(image.size)")
        print("单词数量: \(words.count)")
        
        // 创建分享图片
        let shareView = ShareSceneView(
            image: image,
            words: words,
            sentence: scene.sentence
        )
        print("创建了 ShareSceneView")
        
        let renderer = ImageRenderer(content: shareView)
        print("创建了 ImageRenderer")
        
        // 设置渲染尺寸和比例
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 1.5)
        renderer.proposedSize = ProposedViewSize(targetSize)
        renderer.scale = UIScreen.main.scale
        print("设置了渲染尺寸: \(targetSize) 和比例: \(UIScreen.main.scale)")
        
        if let shareImage = renderer.uiImage {
            print("成功生成分享图片，尺寸: \(shareImage.size)")
            
            // 创建分享项
            let activityItems: [Any] = [shareImage]
            let activityVC = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            print("创建了 UIActivityViewController")
            
            // 设置排除的活动类型
            activityVC.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks,
                .markupAsPDF
            ]
            
            // 获取当前的 UIWindow 并显示分享表单
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                print("获取到 windowScene")
                if let window = windowScene.windows.first {
                    print("获取到 window")
                    if let rootViewController = window.rootViewController {
                        print("获取到 rootViewController")
                        
                        // 在 iPad 需要设置弹出位置
                        if let popoverController = activityVC.popoverPresentationController {
                            print("设置 iPad 弹出位置")
                            popoverController.sourceView = window
                            popoverController.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                            popoverController.permittedArrowDirections = []
                        }
                        
                        DispatchQueue.main.async {
                            print("准备显示分享表单")
                            rootViewController.present(activityVC, animated: true) {
                                print("分享表单显示完成")
                            }
                        }
                    } else {
                        print("错误：未能获取 rootViewController")
                    }
                } else {
                    print("错误：未能获取 window")
                }
            } else {
                print("错误：未能获取 windowScene")
            }
        } else {
            print("错误：未能生成分享图片")
        }
    }
    
    private func deleteWord(_ word: WordItem) {
        print("SceneCardView - 开始删除单词: \(word.word)")
        print("SceneCardView - 当前场景ID: \(scene.id)")
        print("SceneCardView - 当前场景单词数量: \(scene.words.count)")
        
        // 先更新本地显示状态
        withAnimation(.easeInOut(duration: 0.3)) {
            visibleWords.removeAll { $0.word == word.word }
        }
        
        var updatedScene = scene
        updatedScene.words.removeAll { $0.word == word.word }
        
        // 更新 DataManager
        dataManager.updateScene(updatedScene)
        
        print("SceneCardView - 单词删除完成")
        
        // 如果删除后没有单词了，自动退出编辑模式
        if updatedScene.words.isEmpty {
            print("SceneCardView - 场景中没有单词了，退出编辑模式")
            withAnimation(.spring()) {
                isEditMode = false
            }
        }
    }
}

// 用于图片尺寸的 PreferenceKey
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// 优化后的播放按钮
struct PlayButton: View {
    @Binding var isPlaying: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // 景圆
                    Circle()
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                    
                    // 灰色边框
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 48, height: 48)
                    
                    // 播放/暂停图标
                    Group {
                        if isPlaying {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 22, weight: .bold))
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .offset(x: 2)
                        }
                    }
                    .foregroundColor(.gray)
                }
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // 文字标签
                Text(isPlaying ? "暂停" : "播放")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// 自定义按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// 添加 Image 扩展来支持 aspectFill
extension Image {
    func aspectFill() -> some View {
        self.scaledToFill()
            .contentShape(Rectangle())
    }
}

// 修改 ShareSceneView
struct ShareSceneView: View {
    let image: UIImage
    let words: [WordItem]
    let sentence: Sentence
    
    private let referenceSize = CGSize(width: 1080, height: 1920)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 背景色
                Color.black
                
                // 图片层
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                // 水印层 - 添加在图片上方，右上角
                VStack(spacing: 2) {
                    Text("「图说单词」")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 3)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .blur(radius: 3)
                )
                .padding(.top, geometry.safeAreaInsets.top + 20)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                
                // 单词卡片层
                ForEach(words) { word in
                    WordCardView(
                        item: word,
                        imageSize: referenceSize,
                        existingPositions: [],
                        isHighlighted: false,
                        playViewModel: WordPlayViewModel(),
                        isEditMode: false,
                        onDelete: {}
                    )
                }
                
                // 句子层
                VStack(alignment: .leading, spacing: 6) {
                    Text(sentence.text)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                    
                    Text(sentence.translation)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.7),
                            .black.opacity(0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
        }
    }
}

// 分享用的单词卡片视图
struct ShareWordCard: View {
    let word: WordItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(word.word)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Text(word.phoneticsymbols)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Text(word.explanation)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
 

#Preview {
    HomeView()
}
