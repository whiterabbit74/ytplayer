import SwiftUI

extension View {
    func injectEnvironment(appState: AppState) -> some View {
        self
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
