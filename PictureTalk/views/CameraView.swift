import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {
    @StateObject private var viewModel = ImageUploadViewModel()
    @StateObject private var cameraModel = CameraModel()
    @EnvironmentObject private var taskManager: TaskManager
    var tabSelection: Binding<Int>
    
    // 使用 @State 来管理本地状态
    @State private var showImagePicker = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    // 添加新的常量
    private let targetAspectRatio: CGFloat = 9.0/16.0 // 目标宽高比
    
    init(tabSelection: Binding<Int>) {
        self.tabSelection = tabSelection
    }
    
    var body: some View {
        ZStack {
            // 相机预览层
            if !showImagePicker {
                CameraPreviewView(session: cameraModel.session)
                    .ignoresSafeArea()
                    .overlay(
                        // 取景框遮罩
                        CameraOverlayView(aspectRatio: targetAspectRatio)
                    )
                    .overlay(
                        // 相机控制按钮
                        VStack {
                            Spacer()
                            HStack(spacing: 60) {
                                // 相册按钮
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    VStack {
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 24))
                                        Text("相册")
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(.white)
                                }
                                
                                // 拍照按钮
                                Button(action: {
                                    cameraModel.capturePhoto { image in
                                        handleCapturedImage(image)
                                    }
                                }) {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 60, height: 60)
                                        )
                                }
                                
                                // 切换摄像头按钮
                                Button(action: {
                                    cameraModel.switchCamera()
                                }) {
                                    VStack {
                                        Image(systemName: "camera.rotate.fill")
                                            .font(.system(size: 24))
                                        Text("翻转")
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    )
            }
            
            // 预览已选择或拍摄的图片
            if let image = viewModel.selectedImage {
                ImageCropView(
                    image: image,
                    aspectRatio: targetAspectRatio,
                    onCropComplete: { croppedImage in
                        // 更新为裁剪后的图片
                        viewModel.selectedImage = croppedImage
                        
                        // 创建任务并添加到队列
                        let task = ImageAnalysisTask(
                            image: croppedImage,
                            assetIdentifier: viewModel.selectedAssetIdentifier
                        )
                        
                        // 添加任务到队列
                        TaskManager.shared.addTask(task)
                        
                        // 重置状态
                        viewModel.selectedImage = nil
                        viewModel.selectedAssetIdentifier = ""
                        
                        // 返回首页
                        tabSelection.wrappedValue = 0
                    },
                    onCancel: {
                        viewModel.selectedImage = nil
                    }
                )
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                aspectRatio: targetAspectRatio,
                onImagePicked: { image, assetId in
                    viewModel.selectedImage = image
                    viewModel.selectedAssetIdentifier = assetId
                }
            )
        }
        .onAppear {
            // 确保在主线程上初始化相机
            DispatchQueue.main.async {
                cameraModel.checkPermissions()
            }
        }
        .onChange(of: viewModel.analysisCompleted) { completed in
            if completed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        tabSelection.wrappedValue = 0
                    }
                }
            }
        }
    }
    
    private func handleCapturedImage(_ image: UIImage) {
        DispatchQueue.main.async {
            viewModel.selectedImage = image
        }
    }
}

// 相机预览视图
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            // 确保预览层覆盖整个视图，包括状态栏
            videoPreviewLayer.frame = bounds
            videoPreviewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        
        // 设置预览层属性
        view.videoPreviewLayer.frame = UIScreen.main.bounds
        view.videoPreviewLayer.position = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        DispatchQueue.main.async {
            uiView.setNeedsLayout()
        }
    }
}

// 相机模型
class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    @Published var isSessionRunning = false
    
    private var photoOutput = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    private var completionHandler: ((UIImage) -> Void)?
    
    private let sessionQueue = DispatchQueue(label: "com.scenawords.camera.session")
    
    override init() {
        super.init()
    }
    
    func checkPermissions() {
        // 确保在主线程上检查权限
        DispatchQueue.main.async {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.permissionGranted = true
                self.setupCamera()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        self?.permissionGranted = granted
                        if granted {
                            self?.setupCamera()
                        }
                    }
                }
            default:
                self.permissionGranted = false
            }
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // 清除现有的输入和输出
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            
            // 添加视频输入
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition) {
                do {
                    // 配置设备以获得最高质量
                    try device.lockForConfiguration()
                    
                    // 选择最高质量的格式
                    let format = device.formats
                        .filter { $0.isHighPhotoQualitySupported }
                        .max { first, second in
                            let firstDimensions = CMVideoFormatDescriptionGetDimensions(first.formatDescription)
                            let secondDimensions = CMVideoFormatDescriptionGetDimensions(second.formatDescription)
                            return firstDimensions.width < secondDimensions.width
                        }
                    
                    if let bestFormat = format {
                        device.activeFormat = bestFormat
                    }
                    
                    // 设置自动对焦
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    
                    // 设置自动曝光
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    
                    // 设置自动平衡
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                    
                    device.unlockForConfiguration()
                    
                    // 添加输入
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                    }
                } catch {
                    print("Error setting up camera input: \(error)")
                    return
                }
            }
            
            // 添加照片输出
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                
                // 配置照片输出
                if let connection = self.photoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
                
                // 启用高分辨率捕获
                self.photoOutput.isHighResolutionCaptureEnabled = true
                
                if #available(iOS 13.0, *) {
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                }
            }
            
            self.session.commitConfiguration()
            
            // 启动相机会话
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // 移除当前输入
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            // 切换摄像头位
            self.currentPosition = self.currentPosition == .back ? .front : .back
            
            // 添加新输入
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
               let input = try? AVCaptureDeviceInput(device: device) {
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        sessionQueue.async {
            self.completionHandler = completion
            
            // 创建高质量照片设置
            var settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ])
            } else {
                settings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.jpeg
                ])
            }
            
            // 配置最高质量设置
            settings.isHighResolutionPhotoEnabled = true
            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .quality
            }
            
            // 设置闪光灯模式（如果需要）
            settings.flashMode = .auto
            
            // 捕获照片
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func setupForAspectRatio(_ ratio: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // 设置照片输出格式
            if let photoOutput = self.session.outputs.first as? AVCapturePhotoOutput {
                let photoSettings = AVCapturePhotoSettings()
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                
                // 修改获取尺寸的方法
                if let previewDimensions = self.session.inputs.first?.ports.first?.formatDescription {
                    let dimensions = CMVideoFormatDescriptionGetDimensions(previewDimensions)
                    let targetWidth = CGFloat(dimensions.width)
                    let targetHeight = targetWidth / ratio
                    photoSettings.previewPhotoFormat?[kCVPixelBufferWidthKey as String] = Int(targetWidth)
                    photoSettings.previewPhotoFormat?[kCVPixelBufferHeightKey as String] = Int(targetHeight)
                }
            }
            
            self.session.commitConfiguration()
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        
        let finalImage = currentPosition == .front ? image.withHorizontallyFlippedOrientation() : image
        
        // 使用 DispatchQueue.main.async 来调用完成处理器
        if let handler = completionHandler {
            DispatchQueue.main.async {
                handler(finalImage)
            }
        }
    }
}

// 图片水平翻转扩
extension UIImage {
    func withHorizontallyFlippedOrientation() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: size.width, y: 0)
        context.scaleBy(x: -1.0, y: 1.0)
        draw(in: CGRect(origin: .zero, size: size))
        
        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return flippedImage
    }
}

// 用于传递卡片大小的 PreferenceKey
struct CardSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// 相机取景框遮罩
struct CameraOverlayView: View {
    let aspectRatio: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width / aspectRatio
            // 不再需要 yOffset，让取景框从顶部开始
            
            ZStack {
                // 半透明黑色背景
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                // 景框区域（透明）
                Rectangle()
                    .frame(width: width, height: height)
                    .blendMode(.destinationOut)
                
                // 取景框边框
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .frame(width: width, height: height)
            }
            .compositingGroup()
        }
        .ignoresSafeArea()
    }
}

// 裁剪图
struct ImageCropView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let onCropComplete: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @GestureState private var dragState: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let cropWidth = geometry.size.width
            let cropHeight = cropWidth / aspectRatio
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 图片层
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cropWidth, height: cropHeight)
                    .offset(x: offset.width + dragState.width, y: offset.height + dragState.height)
                    .scaleEffect(scale)
                    .gesture(
                        DragGesture()
                            .updating($dragState) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                offset.width += value.translation.width
                                offset.height += value.translation.height
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value
                            }
                            .onEnded { value in
                                scale = min(max(value, 1), 3)
                            }
                    )
                    .clipped()
                
                // 裁剪框
                Rectangle()
                    .stroke(Color.white, lineWidth: 1)
                    .frame(width: cropWidth, height: cropHeight)
                
                // 控制按钮移到底部
                VStack {
                    Spacer()
                    
                    // 添加半透明背景条
                    HStack(spacing: 30) {  // 增加按钮间距
                        // 取消按钮
                        Button(action: {
                            onCancel()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 44))  // 增大图标尺寸
                                .symbolRenderingMode(.palette)  // 使用调色板渲染模式
                                .foregroundStyle(
                                    Color.white,  // 图标主色
                                    Color.red.opacity(0.5)  // 背景色
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)  // 添加阴影
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        // 完成按钮
                        Button(action: {
                            let croppedImage = cropImage()
                            onCropComplete(croppedImage)
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))  // 增大图标尺寸
                                .symbolRenderingMode(.palette)  // 使用调色板渲染模式
                                .foregroundStyle(
                                    Color.white,  // 图标主色
                                    Color.green.opacity(0.8)  // 背景色
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)  // 添加阴影
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.vertical, 20)  // 增加垂直内边距
                    .frame(maxWidth: .infinity)  // 占满宽度
                    .padding(.bottom, 30)  // 调整底部间距
                }
            }
        }
    }
    
    private func cropImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: UIScreen.main.bounds.size)
        let croppedImage = renderer.image { context in
            // 计算实际显示尺寸
            let cropWidth = UIScreen.main.bounds.width
            let cropHeight = cropWidth / aspectRatio
            let yOffset = (UIScreen.main.bounds.height - cropHeight) / 2
            
            // 计算图片的实际显示区域
            let imageSize = image.size
            let imageAspectRatio = imageSize.width / imageSize.height
            var drawWidth: CGFloat
            var drawHeight: CGFloat
            
            if imageAspectRatio > aspectRatio {
                drawHeight = cropHeight
                drawWidth = drawHeight * imageAspectRatio
            } else {
                drawWidth = cropWidth
                drawHeight = drawWidth / imageAspectRatio
            }
            
            // 计算绘制位置
            let drawX = (cropWidth - drawWidth) / 2 + offset.width
            let drawY = (cropHeight - drawHeight) / 2 + offset.height + yOffset
            
            // 创建裁剪路径
            let clipPath = UIBezierPath(rect: CGRect(x: 0, y: yOffset, width: cropWidth, height: cropHeight))
            clipPath.addClip()
            
            // 绘制图片
            image.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth * scale, height: drawHeight * scale))
        }
        
        // 裁剪到目标尺寸
        let targetWidth: CGFloat = 1080 // 设置合适的输出尺寸
        let targetHeight = targetWidth / aspectRatio
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        let finalRenderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: targetHeight), format: format)
        let finalImage = finalRenderer.image { context in
            croppedImage.draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        }
        
        return finalImage
    }
}

// 修改 ImagePicker 以支持固定比例选择
struct ImagePicker: UIViewControllerRepresentable {
    let aspectRatio: CGFloat
    let onImagePicked: (UIImage, String) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        configureImagePicker(picker)
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.presentationMode.wrappedValue.dismiss()
                return
            }
            
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self?.parent.onImagePicked(image, result.assetIdentifier ?? "")
                            self?.parent.presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            } else {
                // 如果无法加载图片，也要关闭选择器
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func configureImagePicker(_ picker: PHPickerViewController) {
        // 设置图片选择器的UI
        if let sheet = picker.view.subviews.first?.subviews.first as? UIView {
            sheet.backgroundColor = .black
        }
    }
}

#Preview {
    CameraView(tabSelection: .constant(0))
} 
