import SwiftUI

enum HomeTab: String, CaseIterable {
    case scenes = "场景"
    case words = "词汇"
}

struct HomeTabView: View {
    @State private var selectedTab: HomeTab = .scenes
    @State private var dragOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var wordManager = WordManager.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            // 内容视图
            TabView(selection: $selectedTab) {
                ScenesView()
                    .tag(HomeTab.scenes)
                
                WordsView()
                    .tag(HomeTab.words)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onChange(of: selectedTab) { newTab in
                if newTab == .words {
                    // 切换到词汇标签时更新单词列表
                    wordManager.updateAllWords()
                }
            }
            
            // 顶部标签栏
            HStack(spacing: 30) {
                ForEach(HomeTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab,
                        colorScheme: colorScheme
                    ) {
                        withAnimation {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.top, 35)
        }
    }
}

// 顶部标签按钮
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                .foregroundColor(getTextColor())
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                .overlay(
                    Rectangle()
                        .frame(height: 3)
                        .foregroundColor(getIndicatorColor())
                        .offset(y: 6),
                    alignment: .bottom
                )
        }
    }
    
    private func getTextColor() -> Color {
        if colorScheme == .dark {
            return .white
        } else {
            return isSelected ? .black : .gray
        }
    }
    
    private func getIndicatorColor() -> Color {
        if isSelected {
            return colorScheme == .dark ? .white : .black
        }
        return .clear
    }
} 
