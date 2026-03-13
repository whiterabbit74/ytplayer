import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var keyboard = KeyboardObserver()
    @State private var showPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: Binding(
                get: { appState.selectedTab },
                set: { newValue in
                    if newValue == 0 && appState.selectedTab == 0 {
                        NotificationCenter.default.post(name: NSNotification.Name("ResetSearch"), object: nil)
                    }
                    appState.selectedTab = newValue
                }
            )) {
                SearchView(showPlayer: $showPlayer)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(0)

                PlaylistsView(showPlayer: $showPlayer)
                    .tabItem { Label("Playlists", systemImage: "music.note.list") }
                    .tag(1)

                FavoritesView(showPlayer: $showPlayer)
                    .tabItem { Label("Favorites", systemImage: "heart.fill") }
                    .tag(2)

                QueueView(showPlayer: $showPlayer)
                    .tabItem { Label("Queue", systemImage: "list.bullet") }
                    .tag(3)
            }

            if appState.playerStore.currentTrack != nil {
                PlayerMiniView(showPlayer: $showPlayer)
                    .padding(.bottom, keyboard.isVisible ? 0 : 60) // Align above standard TabBar, but sit on keyboard when visible
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.playerStore.currentTrack != nil)
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
