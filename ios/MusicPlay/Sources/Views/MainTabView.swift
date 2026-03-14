import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var keyboard = KeyboardObserver()
    @State private var showPlayer = false
    @State private var showSplash = true

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
                SearchView(
                    searchStore: appState.searchStore,
                    playlistsStore: appState.playlistsStore,
                    playerStore: appState.playerStore,
                    playerService: appState.playerService,
                    downloadsStore: appState.downloadsStore,
                    favoritesStore: appState.favoritesStore,
                    baseURL: appState.baseURL,
                    showPlayer: $showPlayer
                )
                    .tabItem { Label("Search", systemImage: "magnifyingglass").symbolEffect(.bounce, value: appState.selectedTab == 0) }
                    .tag(0)

                PlaylistsView(playlistsStore: appState.playlistsStore, showPlayer: $showPlayer)
                    .tabItem { Label("Playlists", systemImage: "music.note.list").symbolEffect(.bounce, value: appState.selectedTab == 1) }
                    .tag(1)

                FavoritesView(favoritesStore: appState.favoritesStore, showPlayer: $showPlayer)
                    .tabItem { Label("Favorites", systemImage: "heart.fill").symbolEffect(.bounce, value: appState.selectedTab == 2) }
                    .tag(2)

                QueueView(
                    playerStore: appState.playerStore,
                    playerService: appState.playerService,
                    downloadsStore: appState.downloadsStore,
                    baseURL: appState.baseURL,
                    showPlayer: $showPlayer
                )
                .tabItem { Label("Queue", systemImage: "list.bullet").symbolEffect(.bounce, value: appState.selectedTab == 3) }
                .tag(3)
            }

            if appState.playerStore.currentTrack != nil {
                PlayerMiniView(
                    playerStore: appState.playerStore,
                    playerService: appState.playerService,
                    downloadsStore: appState.downloadsStore,
                    progressStore: appState.progressStore,
                    baseURL: appState.baseURL,
                    showPlayer: $showPlayer
                )
                .padding(.bottom, keyboard.isVisible ? 0 : 60) // Align above standard TabBar, but sit on keyboard when visible
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showSplash {
                ZStack {
                    Color(UIColor.systemBackground).ignoresSafeArea()
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                }
                .transition(.opacity.combined(with: .scale(scale: 1.2)))
                .zIndex(100)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.playerStore.currentTrack != nil)
        .sheet(isPresented: $showPlayer) {
            PlayerFullView(
                playerStore: appState.playerStore,
                playerService: appState.playerService,
                downloadsStore: appState.downloadsStore,
                favoritesStore: appState.favoritesStore,
                playlistsStore: appState.playlistsStore,
                progressStore: appState.progressStore,
                baseURL: appState.baseURL,
                dynamicBackgroundEnabled: appState.dynamicBackgroundEnabled,
                coverStyle: appState.coverStyle,
                squareCovers: appState.squareCovers
            )
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
