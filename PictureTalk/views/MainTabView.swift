import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var taskManager: TaskManager
    @State public var tabSelection: Int = 0
    
    var body: some View {
        TabView(selection: $tabSelection) {
            HomeTabView()
                .tabItem {
                    Label {
                        Text("首页")
                    } icon: {
                        Image(systemName: taskManager.processingCount > 0 ? "house.fill.badge" : "house.fill")
                    }
                }
                .tag(0)
            
            CameraView(tabSelection: $tabSelection)
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("开拍")
                }
                .tag(1)
            
            LearningView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("学习")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
                .tag(3)
        }
        .environmentObject(taskManager)
        .environment(\.tabSelection, $tabSelection)
    }
}

// 自定义标签栏按钮
struct TabBarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}

// 毛玻璃效果
struct Blur: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// 添加环境键来支持标签切换
private struct TabSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var tabSelection: Binding<Int> {
        get { self[TabSelectionKey.self] }
        set { self[TabSelectionKey.self] = newValue }
    }
}

#Preview {
    MainTabView()
} 
