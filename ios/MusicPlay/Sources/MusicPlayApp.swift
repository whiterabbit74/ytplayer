import SwiftUI

@main
struct MusicPlayApp: App {
    // MARK: v1.3.0 Refactor
    @StateObject private var appState = AppState()
    @StateObject private var i18n = I18nManager()
    
    init() {
        print("🚀 MusicPlay_BUILD_VERSION_2.1.0")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(i18n)
                .environment(\.baseURL, appState.baseURL)
        }
    }
}
