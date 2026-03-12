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
            
            if appState.playerStore.currentTrack != nil {
                PlayerMiniView(showPlayer: $showPlayer)
                    .padding(.bottom, 60) // Simple fixed padding above tab bar
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerFullView()
        }
    }
}
