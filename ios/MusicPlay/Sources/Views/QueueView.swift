import SwiftUI

struct QueueView: View {
    @Environment(\.baseURL) var baseURL
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(playerStore.queue) { item in
                    queueRow(item: item)
                        .shadow(radius: editMode == .active ? 2 : 0)
                        .scaleEffect(editMode == .active ? 0.98 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: editMode)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = playerStore.queue.firstIndex(where: { $0.id == item.id }) {
                                    playerStore.removeFromQueue(index: index)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onMove(perform: moveItems)
                .deleteDisabled(true)
            }
            .environment(\.editMode, $editMode)
            .safeAreaInset(edge: .bottom) {
                MiniPlayerSpacer()
            }
            .overlay {
                if playerStore.queue.isEmpty {
                    ContentUnavailableView(
                        "Queue is Empty",
                        systemImage: "list.bullet",
                        description: Text("Add tracks from search or playlists")
                    )
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !playerStore.queue.isEmpty {
                        Button("Clear") {
                            playerService.stop()
                            playerStore.clearQueue()
                        }
                    }
                }
            }
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        playerStore.moveQueue(from: source, to: destination)
    }

    @ViewBuilder
    private func queueRow(item: QueueItem) -> some View {
        let track = item.track
        let index = playerStore.queue.firstIndex(where: { $0.id == item.id }) ?? 0
        let isCurrent = index == playerStore.currentIndex

        HStack(spacing: 12) {
            trackIndicator(index: index, isCurrent: isCurrent)

            TrackThumbnail(
                track: track,
                size: 44,
                forceSquare: true,
                cornerRadius: 6,
                downloadProgress: downloadsStore.progress(for: track.id),
                isFailed: downloadsStore.isFailed(track.id)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if downloadsStore.isTrackDownloaded(track.id) {
                        DownloadIcon(size: .small)
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
                playerService.playFromQueue(index: index)
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
            Image(systemName: playerService.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
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
}
