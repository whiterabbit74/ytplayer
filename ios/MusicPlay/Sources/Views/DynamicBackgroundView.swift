import SwiftUI

struct DynamicBackgroundView: View {
    let thumbnailURL: URL?
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Background base color (dark)
            Color.black
            
            if let url = thumbnailURL {
                ZStack {
                    // Main blurred image
                    CachedAsyncImage(url: url, contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .blur(radius: 60)
                        .opacity(0.6)
                    
                    // Moving blobs (simulated by multiple blurred instances of the same image)
                    // Blob 1
                    CachedAsyncImage(url: url, contentMode: .fill)
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: animate ? 100 : -100, y: animate ? -50 : 50)
                        .opacity(0.4)
                    
                    // Blob 2
                    CachedAsyncImage(url: url, contentMode: .fill)
                        .frame(width: 350, height: 350)
                        .blur(radius: 100)
                        .offset(x: animate ? -150 : 50, y: animate ? 100 : -100)
                        .opacity(0.3)
                        .rotationEffect(.degrees(animate ? 360 : 0))
                }
                .drawingGroup() // Optimize rendering for animations
                .onAppear {
                    withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
            }
            
            // Glassmorphism overlay
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
    }
}
