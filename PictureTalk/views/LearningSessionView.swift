import SwiftUI
import Photos

struct LearningSessionView: View {
    let task: LearningTask
    @StateObject private var learningManager = LearningManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var isShowingAnswer = false
    @State private var dragOffset: CGFloat = 0
    @State private var cardRotation: Double = 0
    
    private var currentWord: LearningWord? {
        guard !task.words.isEmpty, currentIndex < task.words.count else {
            return nil
        }
        return task.words[currentIndex]
    }
    
    var body: some View {
        Group {
            if let word = currentWord {
                GeometryReader { geometry in
                    VStack(spacing: 20) {
                        // 进度指示器
                        ProgressHeader(
                            currentIndex: currentIndex,
                            total: task.words.count
                        )
                        
                        Spacer()
                        
                        // 单词卡片
                        LearningWordCard(
                            word: word,
                            isShowingAnswer: $isShowingAnswer,
                            rotation: cardRotation,
                            dragOffset: dragOffset
                        )
                        .frame(height: geometry.size.height * 0.6)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation.height
                                    cardRotation = Double(value.translation.width / 20)
                                }
                                .onEnded { value in
                                    handleDragGesture(value)
                                }
                        )
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    withAnimation(.spring()) {
                                        isShowingAnswer.toggle()
                                    }
                                }
                        )
                        
                        Spacer()
                        
                        // 底部按钮
                        HStack(spacing: 40) {
                            ActionButton(
                                title: "需要复习",
                                systemImage: "arrow.clockwise",
                                color: .orange
                            ) {
                                markWord(as: .needReview)
                            }
                            
                            ActionButton(
                                title: "已掌握",
                                systemImage: "checkmark",
                                color: .green
                            ) {
                                markWord(as: .mastered)
                            }
                        }
                        .padding(.bottom)
                    }
                    .padding()
                }
            } else {
                // 显示空状态或错误状态
                VStack {
                    Text("没有可学习的单词")
                        .font(.headline)
                    Button("返回") {
                        dismiss()
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if currentWord != nil {
                playCurrentWord()
            }
        }
    }
    
    private func handleDragGesture(_ value: DragGesture.Value) {
        let verticalDistance = value.translation.height
        
        withAnimation(.spring()) {
            if verticalDistance < -100 {
                markWord(as: .mastered)
            } else if verticalDistance > 100 {
                markWord(as: .needReview)
            } else {
                dragOffset = 0
                cardRotation = 0
            }
        }
    }
    
    private func markWord(as status: LearningWord.WordStatus) {
        guard let word = currentWord else { return }
        
        learningManager.updateWordStatus(
            taskId: task.id,
            wordId: word.id,
            status: status
        )
        
        dragOffset = 0
        cardRotation = 0
        isShowingAnswer = false
        
        if currentIndex < task.words.count - 1 {
            currentIndex += 1
            playCurrentWord()
        } else {
            learningManager.recordLearning(task: task)
            dismiss()
        }
    }
    
    private func playCurrentWord() {
        if let word = currentWord {
            AudioService.shared.playWord(word.word)
        }
    }
}

// 进度头部视图
struct ProgressHeader: View {
    let currentIndex: Int
    let total: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // 进度文本
            HStack {
                Text("第\(currentIndex + 1)个单词")
                    .font(.headline)
                Spacer()
                Text("\(currentIndex + 1)/\(total)")
                    .foregroundColor(.secondary)
            }
            
            // 进度条
            ProgressView(value: Double(currentIndex + 1), total: Double(total))
        }
    }
}

// 单词卡片视图
struct LearningWordCard: View {
    let word: LearningWord
    @Binding var isShowingAnswer: Bool
    let rotation: Double
    let dragOffset: CGFloat
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // 场景图片 - 使用 sceneId 查找正确的场景
                Group {
                    if let scene = DataManager.shared.scenes.first(where: { $0.id == word.sceneId }) {
                        if let wordItem = scene.words.first(where: { $0.word == word.word }) {
                            SceneImageView(scene: scene, wordItem: wordItem)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onAppear {
                                    print("显示场景 - 单词: \(word.word), 场景ID: \(scene.id)")
                                    print("单词位置: \(wordItem.position)")
                                }
                        } else {
                            Color.gray.opacity(0.2)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onAppear {
                                    print("警告：在场景中未找到对应的单词项 - 单词: \(word.word)")
                                }
                        }
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onAppear {
                                print("警告：未找到对应的场景，sceneId: \(word.sceneId)")
                            }
                    }
                }
                
                // 单词
                Text(word.word)
                    .font(.system(size: 32, weight: .bold))
                
                if isShowingAnswer {
                    // 音标和释义
                    VStack(spacing: 12) {
                        Text(word.phoneticsymbols)
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        
                        Text(word.explanation)
                            .font(.system(size: 18))
                            .multilineTextAlignment(.center)
                    }
                    .transition(.opacity)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 5)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 0, z: 1)
            )
            .offset(y: dragOffset)
        }
    }
}

// 场景图片视图
struct SceneImageView: View {
    let scene: SceneItem
    let wordItem: WordItem
    @State private var image: UIImage?
    
    private var wordLocation: CGPoint {
        wordItem.position
    }
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                // 计算以标注点为中心的裁剪区域
                let cropInfo = calculateCropInfo(
                    imageSize: image.size,
                    viewSize: geometry.size,
                    wordLocation: wordLocation
                )
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cropInfo.displaySize.width, height: cropInfo.displaySize.height)
                    .offset(x: -cropInfo.offset.x, y: -cropInfo.offset.y)
                    .overlay {
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .overlay(
                                Circle()
                                    .fill(Color.orange.opacity(0.3))
                                    .frame(width: 20, height: 20)
                            )
                            .position(
                                x: geometry.size.width / 2,
                                y: geometry.size.height / 2
                            )
                    }
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            loadImage()
        }
        .id(scene.id)
    }
    
    private func loadImage() {
        // 重置图片状态
        self.image = nil
        
        let imagesFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        let imagePath = imagesFolder.appendingPathComponent("\(scene.id).jpg")
        
        print("加载图片 - 场景ID: \(scene.id), 单词: \(wordItem.word)")
        
        if FileManager.default.fileExists(atPath: imagePath.path) {
            if let imageData = try? Data(contentsOf: imagePath),
               let loadedImage = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                    print("成功从文件加载图片 - 场景ID: \(scene.id)")
                }
            }
        } else if !scene.assetIdentifier.isEmpty {
            loadFromPhotoLibrary()
        }
    }
    
    private func loadFromPhotoLibrary() {
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
            ) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        self.image = image
                        print("成功从相册加载图片 - 场景ID: \(scene.id)")
                    }
                }
            }
        }
    }
}

// 裁剪信息结构体
private struct CropInfo {
    let displaySize: CGSize
    let offset: CGPoint
}

// 计算以标注点为中心的裁剪信息
private func calculateCropInfo(imageSize: CGSize, viewSize: CGSize, wordLocation: CGPoint) -> CropInfo {
    // 计算缩放比例，确保图片足够大以覆盖视图
    let scale = max(
        viewSize.width / imageSize.width,
        viewSize.height / imageSize.height
    ) * 1.5 // 放大1.5倍以确保有足够的移动空间
    
    // 计算缩放后的图片尺寸
    let scaledSize = CGSize(
        width: imageSize.width * scale,
        height: imageSize.height * scale
    )
    
    // 计算偏移量，使标注点位于中心
    let offsetX = (wordLocation.x * scaledSize.width) - (viewSize.width / 2)
    let offsetY = (wordLocation.y * scaledSize.height) - (viewSize.height / 2)
    
    // 确保图片边缘不会露出
    let maxOffsetX = scaledSize.width - viewSize.width
    let maxOffsetY = scaledSize.height - viewSize.height
    
    let finalOffsetX = min(max(0, offsetX), maxOffsetX)
    let finalOffsetY = min(max(0, offsetY), maxOffsetY)
    
    return CropInfo(
        displaySize: scaledSize,
        offset: CGPoint(x: finalOffsetX, y: finalOffsetY)
    )
}

// 操作按钮
struct ActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
} 