import SwiftUI

struct VinylRecordView: View {
    let track: Track
    let size: CGFloat // This is the sleeve size
    let baseURL: String
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var rotation: Double = 0
    
    var body: some View {
        let isPlaying = playerService.isPlaying
        let recordOffset = size * 0.4
        let totalWidth = size + recordOffset
        
        ZStack {
            // The Vinyl Record
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.black.opacity(0.9), .black, .black.opacity(0.8)]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.45
                        )
                    )
                    .overlay(
                        ZStack {
                            ForEach(0..<5) { i in
                                Circle()
                                    .stroke(Color.white.opacity(0.05), lineWidth: 0.3)
                                    .scaleEffect(0.9 - CGFloat(i) * 0.1)
                            }
                        }
                    )
                
                TrackThumbnail(
                    track: track,
                    size: size * 0.35,
                    forceSquare: true,
                    cornerRadius: size * 0.175,
                    showStatus: false,
                    baseURL: baseURL,
                    downloadsStore: downloadsStore
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                
                Circle()
                    .fill(Color.black)
                    .frame(width: 4, height: 4)
            }
            .frame(width: size * 0.95, height: size * 0.95)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(isPlaying ? 1.02 : 1.0) // Subtle pulse/ready scale
            .offset(x: isPlaying ? recordOffset : 5) 
            .shadow(color: .black.opacity(0.4), radius: 10, x: 5, y: 5)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isPlaying)
            
            // The Sleeve
            TrackThumbnail(
                track: track,
                size: size,
                forceSquare: true,
                cornerRadius: 8,
                showStatus: false,
                baseURL: baseURL,
                downloadsStore: downloadsStore
            )
            .offset(x: isPlaying ? -recordOffset / 3 : 0)
            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 10)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isPlaying)
        }
        .frame(width: totalWidth, height: size)
        .onChange(of: isPlaying) { _, playing in
            if playing && scenePhase == .active {
                startRotation()
            } else {
                stopRotation()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isPlaying {
                startRotation()
            } else {
                stopRotation()
            }
        }
        .onAppear {
            if isPlaying && scenePhase == .active {
                startRotation()
            }
        }
        .onDisappear {
            stopRotation()
        }
    }

    private func startRotation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotation += 360
        }
    }

    private func stopRotation() {
        // Pause by using the current value and removing the animation
        withAnimation(.none) {
            rotation = rotation.truncatingRemainder(dividingBy: 360)
        }
    }
}
