import SwiftUI

@main
struct MusicPlayApp: App {
    // MARK: v1.3.0 Refactor
    @StateObject private var appState = AppState()
    
    init() {
        print("🚀 MusicPlay_BUILD_VERSION_1.3.0_REF")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.baseURL, appState.baseURL)
        }
    }
}
