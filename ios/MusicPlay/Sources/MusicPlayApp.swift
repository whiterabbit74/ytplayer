import SwiftUI

@main
struct MusicPlayApp: App {
    // MARK: v2.6
    @StateObject private var appState = AppState()

    init() {
        print("🚀 MusicPlay_BUILD_VERSION_2.6")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
