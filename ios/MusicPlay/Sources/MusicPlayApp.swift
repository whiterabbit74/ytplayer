import SwiftUI

@main
struct MusicPlayApp: App {
    // MARK: v1.3.0 Refactor
    @StateObject private var appState = AppState()
    
    init() {
        print("🚀 MusicPlay_BUILD_VERSION_2.4.0")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.playerStore)
                .environmentObject(appState.playerService)
                .environmentObject(appState.downloadsStore)
                .environmentObject(appState.playlistsStore)
                .environmentObject(appState.favoritesStore)
                .environmentObject(appState.searchStore)
                .environment(\.baseURL, appState.baseURL)
        }
    }
}
