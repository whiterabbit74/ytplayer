import SwiftUI

struct QueueView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.playerStore.queue) { item in
                    queueRow(item: item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                let index = appState.playerStore.queue.firstIndex(where: { $0.id == item.id })
                                if let index = index {
                                    appState.playerStore.removeFromQueue(index: index)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onMove(perform: moveItems)
                .deleteDisabled(true) // Hides the red minus buttons in EditMode
            }
            .environment(\.editMode, $editMode)
            .safeAreaInset(edge: .bottom) {
                if appState.playerStore.currentTrack != nil {
                    Color.clear.frame(height: 70)
                }
            }
            .overlay {
                if appState.playerStore.queue.isEmpty {
                    ContentUnavailableView("Queue is Empty", systemImage: "list.bullet", description: Text("Add tracks from search or playlists"))
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !appState.playerStore.queue.isEmpty {
                        // EditButton is not needed since we stay in edit mode
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !appState.playerStore.queue.isEmpty {
                        Button("Clear") {
                            appState.playerService.stop()
                            appState.playerStore.clearQueue()
                        }
                    }
                }
            }
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        appState.playerStore.moveQueue(from: source, to: destination)
    }

    private func deleteItems(at offsets: IndexSet) {
        for idx in offsets.sorted(by: >) {
            appState.playerStore.removeFromQueue(index: idx)
        }
    }

    @ViewBuilder
    private func queueRow(item: QueueItem) -> some View {
        let track = item.track
        let index = appState.playerStore.queue.firstIndex(where: { $0.id == item.id }) ?? 0
        let isCurrent = index == appState.playerStore.currentIndex

        HStack(spacing: 12) {
            trackIndicator(index: index, isCurrent: isCurrent)

            TrackThumbnail(track: track, size: 44, forceSquare: true, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if appState.downloadsStore.isDownloaded(id: track.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 10))
                    }
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                HapticManager.shared.trigger(.selection)
                appState.playerService.playFromQueue(index: index)
                showPlayer = true
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 8)
            .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func trackIndicator(index: Int, isCurrent: Bool) -> some View {
        if isCurrent {
            Image(systemName: appState.playerService.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                .foregroundStyle(.white)
                .font(.caption)
                .frame(width: 20)
        } else {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
    }

    private func thumbURL(_ track: Track) -> URL? {
        if track.thumbnail.hasPrefix("http") {
            return URL(string: track.thumbnail)
        }
        let base = appState.baseURL
        if track.thumbnail.hasPrefix("/") {
            return URL(string: base + track.thumbnail)
        }
        return URL(string: base + "/" + track.thumbnail)
    }
}
