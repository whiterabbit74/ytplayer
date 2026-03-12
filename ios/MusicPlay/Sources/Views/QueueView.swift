import SwiftUI

struct QueueView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool
    @Environment(\.editMode) private var editMode

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.playerStore.queue) { track in
                    queueRow(track: track)
                }
                .onMove(perform: moveItems)
                .onDelete(perform: deleteItems)
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
                        EditButton()
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
    private func queueRow(track: Track) -> some View {
        let index = appState.playerStore.queue.firstIndex(of: track) ?? 0
        let isCurrent = index == appState.playerStore.currentIndex

        HStack(spacing: 12) {
            trackIndicator(index: index, isCurrent: isCurrent)

            CachedAsyncImage(url: thumbURL(track), contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if editMode?.wrappedValue != .active {
                Button {
                    appState.playerStore.playFromQueue(index: index)
                    appState.playerService.play(track: track)
                    showPlayer = true
                } label: {
                    Image(systemName: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
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
