import SwiftUI
import UIKit
import Photos

struct VerticalPageView: UIViewControllerRepresentable {
    let scenes: [SceneItem]
    @Binding var currentIndex: Int
    @StateObject private var playViewModel = WordPlayViewModel()
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: [.interPageSpacing: 0]
        )
        
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        pageViewController.view.backgroundColor = .clear
        
        pageViewController.edgesForExtendedLayout = .all
        pageViewController.extendedLayoutIncludesOpaqueBars = true
        
        context.coordinator.playViewModel = playViewModel
        context.coordinator.pageViewController = pageViewController
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.jumpToScene(_:)),
            name: NSNotification.Name("JumpToScene"),
            object: nil
        )
        
        if !scenes.isEmpty && currentIndex < scenes.count {
            let initialVC = SceneHostingController(
                scene: scenes[currentIndex],
                playViewModel: playViewModel
            )
            initialVC.view.backgroundColor = .clear
            pageViewController.setViewControllers(
                [initialVC],
                direction: .forward,
                animated: false
            )
        }
        
        let buttonsVC = UIHostingController(
            rootView: SceneButtonsView(
                scenes: scenes,
                currentIndex: $currentIndex,
                playViewModel: playViewModel
            )
        )
        buttonsVC.view.backgroundColor = .clear
        pageViewController.addChild(buttonsVC)
        pageViewController.view.addSubview(buttonsVC.view)
        buttonsVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            buttonsVC.view.trailingAnchor.constraint(equalTo: pageViewController.view.trailingAnchor),
            buttonsVC.view.topAnchor.constraint(equalTo: pageViewController.view.topAnchor),
            buttonsVC.view.bottomAnchor.constraint(equalTo: pageViewController.view.bottomAnchor),
            buttonsVC.view.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        buttonsVC.didMove(toParent: pageViewController)
        
        return pageViewController
    }
    
    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        
        guard !scenes.isEmpty && currentIndex < scenes.count else {
            return
        }
        
        if let currentVC = pageViewController.viewControllers?.first as? SceneHostingController {
            let currentSceneIndex = scenes.firstIndex { $0.id == currentVC.scene.id } ?? 0
            if currentSceneIndex != currentIndex {
                playViewModel.stopPlaying()
                
                let newVC = SceneHostingController(
                    scene: scenes[currentIndex],
                    playViewModel: playViewModel
                )
                let direction: UIPageViewController.NavigationDirection = 
                    currentSceneIndex < currentIndex ? .forward : .reverse
                pageViewController.setViewControllers(
                    [newVC],
                    direction: direction,
                    animated: true
                )
            }
        } else {
            let newVC = SceneHostingController(
                scene: scenes[currentIndex],
                playViewModel: playViewModel
            )
            pageViewController.setViewControllers(
                [newVC],
                direction: .forward,
                animated: false
            )
        }
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalPageView
        var playViewModel: WordPlayViewModel!
        weak var pageViewController: UIPageViewController?
        
        init(_ pageViewController: VerticalPageView) {
            self.parent = pageViewController
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let currentVC = viewController as? SceneHostingController,
                  let currentIndex = parent.scenes.firstIndex(where: { $0.id == currentVC.scene.id }),
                  currentIndex > 0,
                  parent.scenes.count > 1
            else {
                return nil
            }
            
            playViewModel.stopPlaying()
            
            return SceneHostingController(
                scene: parent.scenes[currentIndex - 1],
                playViewModel: playViewModel
            )
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let currentVC = viewController as? SceneHostingController,
                  let currentIndex = parent.scenes.firstIndex(where: { $0.id == currentVC.scene.id }),
                  currentIndex < parent.scenes.count - 1,
                  parent.scenes.count > 1
            else {
                return nil
            }
            
            playViewModel.stopPlaying()
            
            return SceneHostingController(
                scene: parent.scenes[currentIndex + 1],
                playViewModel: playViewModel
            )
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard finished && completed,
                  let currentVC = pageViewController.viewControllers?.first as? SceneHostingController,
                  let index = parent.scenes.firstIndex(where: { $0.id == currentVC.scene.id })
            else { return }
            
            playViewModel.stopPlaying()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.currentIndex = index
            }
        }
        
        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            playViewModel.stopPlaying()
            
            if let pendingVC = pendingViewControllers.first as? SceneHostingController,
               let index = parent.scenes.firstIndex(where: { $0.id == pendingVC.scene.id }) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.currentIndex = index
                }
            }
        }
        
        @objc func jumpToScene(_ notification: Notification) {
            guard let index = notification.userInfo?["index"] as? Int,
                  index < parent.scenes.count else {
                return
            }
            
            let newVC = SceneHostingController(
                scene: parent.scenes[index],
                playViewModel: playViewModel
            )
            
            pageViewController?.setViewControllers(
                [newVC],
                direction: .forward,
                animated: false
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.parent.currentIndex = index
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

class SceneHostingController: UIHostingController<SceneCardView> {
    let scene: SceneItem
    
    init(scene: SceneItem, playViewModel: WordPlayViewModel) {
        self.scene = scene
        super.init(rootView: SceneCardView(
            scene: scene,
            playViewModel: playViewModel
        ))
        
        self.view.backgroundColor = .clear
        self.view.clipsToBounds = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        
        self.view.frame = UIScreen.main.bounds
        self.view.insetsLayoutMarginsFromSafeArea = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.edgesForExtendedLayout = .all
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct SceneButtonsView: View {
    let scenes: [SceneItem]
    @Binding var currentIndex: Int
    @ObservedObject var playViewModel: WordPlayViewModel
    @StateObject private var taskManager = TaskManager.shared
    @State private var showTaskList = false
    
    
    
    var currentScene: SceneItem? {
        guard currentIndex < scenes.count else { return nil }
        return scenes[currentIndex]
    }
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            VStack(spacing: 6) {
                Button(action: {
                    if let scene = currentScene {
                        withAnimation(.spring(response: 0.3)) {
                            if playViewModel.isPlaying && playViewModel.currentSceneId == scene.id {
                                playViewModel.stopPlaying()
                            } else {
                                playViewModel.startPlaying(words: scene.words, sceneId: scene.id)
                            }
                        }
                    }
                }) {
                    Image(systemName: playViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(scenes.isEmpty ? .white.opacity(0.3) : .white)
                        .frame(width: 52, height: 52)
                        .contentShape(Circle())
                }
                .disabled(scenes.isEmpty)
                
                Text("播放")
                    .font(.system(size: 13))
                    .foregroundColor(scenes.isEmpty ? .white.opacity(0.3) : .white)
            }
            
            VStack(spacing: 6) {
                Button(action: {
                    print("分享按钮被点击")
                    if !scenes.isEmpty {
                        let currentScene = scenes[currentIndex]
                        if let image = loadImageFromDocuments(for: currentScene.id) {
                            print("从文档目录加载图片成功")
                            shareScene(image: image, words: currentScene.words, sentence: currentScene.sentence)
                        }
                        else if !currentScene.assetIdentifier.isEmpty {
                            print("尝试从相册加载图片")
                            loadImageFromPhotoLibrary(assetIdentifier: currentScene.assetIdentifier) { image in
                                if let image = image {
                                    print("从相册加载图片成功")
                                    shareScene(image: image, words: currentScene.words, sentence: currentScene.sentence)
                                } else {
                                    print("从相册加载图片失败")
                                }
                            }
                        } else {
                            print("��误：找不到场景图片")
                        }
                    }
                }) {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 32))
                        .foregroundColor(scenes.isEmpty ? .white.opacity(0.3) : .white)
                        .frame(width: 52, height: 52)
                        .contentShape(Circle())
                }
                .disabled(scenes.isEmpty)
                .buttonStyle(TikTokButtonStyle())
                
                Text("分享")
                    .font(.system(size: 13))
                    .foregroundColor(scenes.isEmpty ? .white.opacity(0.3) : .white)
            }
            
            VStack(spacing: 6) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showTaskList = true
                    }
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
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: taskManager.processingCount)
                        }
                    }
                }
                .buttonStyle(TikTokButtonStyle())
                
                Text("任务")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .allowsHitTesting(true)
            
            Spacer()
                .frame(height: 100)
            
            Color.clear
                .frame(height: UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
        }
        .frame(width: 85)
        .padding(.trailing, 8)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .sheet(isPresented: $showTaskList) {
            TaskListView()
        }
    }
    
    private func loadImageFromDocuments(for sceneId: String) -> UIImage? {
        let imagesFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        let imagePath = imagesFolder.appendingPathComponent("\(sceneId).jpg")
        
        if FileManager.default.fileExists(atPath: imagePath.path),
           let imageData = try? Data(contentsOf: imagePath),
           let image = UIImage(data: imageData) {
            return image
        }
        return nil
    }
    
    private func loadImageFromPhotoLibrary(assetIdentifier: String, completion: @escaping (UIImage?) -> Void) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
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
                completion(image)
            }
        } else {
            completion(nil)
        }
    }
    
    private func shareScene(image: UIImage, words: [WordItem], sentence: Sentence) {
        print("开始执行 shareScene 方法")
        
        let shareView = ShareSceneView(
            image: image,
            words: words,
            sentence: sentence
        )
        
        let renderer = ImageRenderer(content: shareView)
        
        // 使用屏幕尺寸作为渲染尺寸
        let screenSize = UIScreen.main.bounds.size
        renderer.proposedSize = ProposedViewSize(screenSize)
        renderer.scale = UIScreen.main.scale
        
        if let shareImage = renderer.uiImage {
            let activityVC = UIActivityViewController(
                activityItems: [shareImage],
                applicationActivities: nil
            )
            
            activityVC.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks,
                .markupAsPDF
            ]
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = window
                    popoverController.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                DispatchQueue.main.async {
                    rootViewController.present(activityVC, animated: true)
                }
            }
        }
    }
    
}

struct TikTokButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

class WordPlayViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentWordIndex = 0
    @Published var currentSceneId: String? = nil
    @Published var words: [WordItem] = []
    private var timer: Timer?
    
    func startPlaying(words: [WordItem], sceneId: String) {
        stopPlaying()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.words = words
            self.currentWordIndex = 0
            self.currentSceneId = sceneId
            self.isPlaying = true
            
            self.playCurrentWord()
            self.scheduleNextWord()
        }
    }
    
    func stopPlaying() {
        timer?.invalidate()
        timer = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isPlaying = false
            self.currentWordIndex = 0
            self.currentSceneId = nil
            self.words = []
        }
    }
    
    private func playCurrentWord() {
        guard currentWordIndex < words.count else {
            // 如果播放完所有单词，重新开始
            currentWordIndex = 0
            if isPlaying {
                playCurrentWord()
            }
            return
        }
        
        // 确保在播放前检查状态
        if isPlaying && !words.isEmpty {
            AudioService.shared.playWord(words[currentWordIndex].word)
        }
        objectWillChange.send()
    }
    
    private func scheduleNextWord() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            
            DispatchQueue.main.async {
                // 确保在更新索引前检查播放状态
                if self.isPlaying {
                    self.currentWordIndex = (self.currentWordIndex + 1) % self.words.count
                    self.playCurrentWord()
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

