import SwiftUI
import Photos

struct WordDetailView: View {
    let word: UniqueWord
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataManager = DataManager.shared
    @State private var showDeleteAlert = false
    @State private var preloadedImages: [String: UIImage] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("加载中...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 单词信息
                            VStack(alignment: .leading, spacing: 12) {
                                Text(word.word)
                                    .font(.system(size: 24, weight: .bold))
                                
                                Text(word.phoneticsymbols)
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                                
                                Text(word.explanation)
                                    .font(.system(size: 16))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            // 发音按钮
                            Button(action: {
                                AudioService.shared.playWord(word.word)
                            }) {
                                Label("播放发音", systemImage: "speaker.wave.2")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                            
                            // 相关图片
                            VStack(alignment: .leading, spacing: 12) {
                                Text("相关图片")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 12) {
                                        ForEach(word.scenes) { scene in
                                            RelatedSceneCard(
                                                scene: scene,
                                                word: word.word,
                                                preloadedImage: preloadedImages[scene.id]
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .opacity(isLoading ? 0 : 1)
                        
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteWord()
                }
            } message: {
                Text("确定要删除单词\(word.word)吗？删除后相关场景将移除该单词卡片。")
            }
        }
        .task {
            // 视图加载时立即开始预加载所有图片
            await preloadImages()
            // 预加载完成后关闭加载状态
            withAnimation {
                isLoading = false
            }
        }
    }
    
    // 添加预加载方法
    private func preloadImages() async {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for scene in word.scenes {
                group.addTask {
                    // 创建缩略图加载器
                    let loader = ThumbnailLoader(scene: scene, targetSize: CGSize(width: 160, height: 120))
                    let image = await loader.loadThumbnail()
                    return (scene.id, image)
                }
            }
            
            // 收集加载结果
            for await (sceneId, image) in group {
                if let image = image {
                    preloadedImages[sceneId] = image
                }
            }
        }
    }
    
    private func deleteWord() {
        // 获取需要更新的场景ID列表
        let sceneIds = Set(word.scenes.map { $0.id })
        
        // 更新每个相关场景
        for scene in word.scenes {
            var updatedScene = scene
            updatedScene.words.removeAll { $0.word == word.word }
            dataManager.updateScene(updatedScene)
        }
        
        // 通知 DataManager 刷新场景数据
        DispatchQueue.main.async {
            // 强制刷新场景列表以触发UI���新
            dataManager.refreshScenes()
            
            // 更新单词管理器
            WordManager.shared.updateAllWords()
            
            // 关闭详情视图
            dismiss()
        }
    }
}

// 添加缩略图加载器
actor ThumbnailLoader {
    private let scene: SceneItem
    private let targetSize: CGSize
    private static var imageCache = NSCache<NSString, UIImage>()
    
    init(scene: SceneItem, targetSize: CGSize) {
        self.scene = scene
        self.targetSize = targetSize
    }
    
    func loadThumbnail() async -> UIImage? {
        // 1. 检查缓存
        let cacheKey = NSString(string: "\(scene.id)-thumb")
        if let cached = Self.imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        // 2. 从文件系统加载并生成缩略图
        let imagesFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        let imagePath = imagesFolder.appendingPathComponent("\(scene.id).jpg")
        
        if FileManager.default.fileExists(atPath: imagePath.path),
           let imageSource = CGImageSourceCreateWithURL(imagePath as CFURL, nil) {
            
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height) * 2,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            
            if let thumbnailRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                let thumbnail = UIImage(cgImage: thumbnailRef)
                Self.imageCache.setObject(thumbnail, forKey: cacheKey)
                return thumbnail
            }
        }
        
        // 3. 如果本地文件不存在，从相册加载
        if !scene.assetIdentifier.isEmpty {
            return await loadFromPhotoLibrary()
        }
        
        return nil
    }
    
    private func loadFromPhotoLibrary() async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [scene.assetIdentifier], options: nil)
            guard let asset = fetchResult.firstObject else {
                continuation.resume(returning: nil)
                return
            }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .exact
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    Self.imageCache.setObject(image, forKey: NSString(string: "\(self.scene.id)-thumb"))
                }
                continuation.resume(returning: image)
            }
        }
    }
}

// 修改 RelatedSceneCard 以使用预加载的图片
struct RelatedSceneCard: View {
    let scene: SceneItem
    let word: String
    let preloadedImage: UIImage?
    @State private var showFullScreen = false
    
    var body: some View {
        VStack {
            if let image = preloadedImage {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if let wordItem = scene.words.first(where: { $0.word == word }) {
                        WordLocationIndicator(location: wordItem.position)
                            .frame(width: 160, height: 120)
                    }
                }
                .onTapGesture {
                    showFullScreen = true
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let wordItem = scene.words.first(where: { $0.word == word }) {
                NavigationView {
                    FullScreenImageView(
                        scene: scene,
                        wordLocation: wordItem.position,
                        isPresented: $showFullScreen
                    )
                }
            }
        }
    }
}

struct WordLocationIndicator: View {
    let location: CGPoint
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 外圈
                Circle()
                    .stroke(Color.orange, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                
                // 内圈
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 20, height: 20)
            }
            .position(
                x: location.x * geometry.size.width,
                y: location.y * geometry.size.height
            )
        }
    }
}

// 修改 FullScreenImageView 以支持从场景加载图片
struct FullScreenImageView: View {
    let scene: SceneItem
    let wordLocation: CGPoint
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let displayImage = image {
                    // 图片和标注层
                    GeometryReader { imageGeometry in
                        let imageSize = calculateImageFrame(
                            imageSize: displayImage.size,
                            viewSize: imageGeometry.size
                        )
                        
                        ZStack {
                            // 图片
                            Image(uiImage: displayImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: imageSize.width, height: imageSize.height)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(
                                    SimultaneousGesture(
                                        // 缩放手势
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                scale = min(max(scale * delta, 1), 4)
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                            },
                                        // 拖动手势
                                        DragGesture()
                                            .onChanged { value in
                                                offset = value.translation
                                            }
                                            .onEnded { value in
                                                offset = value.translation
                                            }
                                    )
                                )
                            
                            // 单词位置标注
                            let indicatorPosition = calculateIndicatorPosition(
                                wordLocation: wordLocation,
                                imageSize: imageSize,
                                scale: scale,
                                offset: offset
                            )
                            
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                                .frame(width: 24 * scale, height: 24 * scale)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                                .position(indicatorPosition)
                            
                            Circle()
                                .fill(Color.orange.opacity(0.3))
                                .frame(width: 20 * scale, height: 20 * scale)
                                .position(indicatorPosition)
                        }
                        .position(x: imageGeometry.size.width / 2, y: imageGeometry.size.height / 2)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") {
                    isPresented = false
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("重置") {
                    withAnimation {
                        scale = 1.0
                        offset = .zero
                    }
                }
            }
        }
        .task {
            // 加载高清图片
            await loadFullImage()
        }
    }
    
    private func loadFullImage() async {
        let imagesFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        let imagePath = imagesFolder.appendingPathComponent("\(scene.id).jpg")
        
        if FileManager.default.fileExists(atPath: imagePath.path),
           let imageData = try? Data(contentsOf: imagePath),
           let loadedImage = UIImage(data: imageData) {
            await MainActor.run {
                self.image = loadedImage
            }
        } else if !scene.assetIdentifier.isEmpty {
            // 从相册加载
            await loadFromPhotoLibrary()
        }
    }
    
    private func loadFromPhotoLibrary() async {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [scene.assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { loadedImage, _ in
                if let loadedImage = loadedImage {
                    Task { @MainActor in
                        self.image = loadedImage
                    }
                }
                continuation.resume()
            }
        }
    }
    
    // 计算图片在视图中的实际尺寸
    private func calculateImageFrame(imageSize: CGSize, viewSize: CGSize) -> CGSize {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        if imageAspect > viewAspect {
            // 图片较宽，以宽度为准
            let width = viewSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // 图片较高，以高度为准
            let height = viewSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
    
    // 计算标注的位置
    private func calculateIndicatorPosition(
        wordLocation: CGPoint,
        imageSize: CGSize,
        scale: CGFloat,
        offset: CGSize
    ) -> CGPoint {
        let x = imageSize.width * wordLocation.x * scale + offset.width
        let y = imageSize.height * wordLocation.y * scale + offset.height
        return CGPoint(x: x, y: y)
    }
} 
