import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                SearchView(showPlayer: $showPlayer)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                PlaylistsView(showPlayer: $showPlayer)
                    .tabItem { Label("Playlists", systemImage: "music.note.list") }

                FavoritesView(showPlayer: $showPlayer)
                    .tabItem { Label("Favorites", systemImage: "heart.fill") }

                QueueView(showPlayer: $showPlayer)
                    .tabItem { Label("Queue", systemImage: "list.bullet") }
            }

            // Mini-player above the tab bar — use safeAreaInset approach
            if appState.playerStore.currentTrack != nil {
                PlayerMiniView(showPlayer: $showPlayer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.playerStore.currentTrack != nil)
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerFullView()
                .environmentObject(appState)
        }
        .onAppear {
            // Load initial player state from server
            Task { await appState.playerSyncService.loadInitialState() }
            appState.playerSyncService.start()
        }
        .onDisappear {
            appState.playerSyncService.stop()
        }
    }
}
