import SwiftUI

@main
struct PictureTalkApp: App {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var dataManager = DataManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(taskManager)
                .environmentObject(dataManager)
        }
    }
}
