import SwiftUI

struct ScenesView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var currentIndex = 0
    
    var body: some View {
        if dataManager.scenes.isEmpty {
            EmptyStateView()
        } else {
            VerticalPageView(
                scenes: dataManager.scenes,
                currentIndex: $currentIndex
            )
            .ignoresSafeArea(.all)
        }
    }
}

#Preview {
    ScenesView()
} 