import SwiftUI

struct DynamicBackgroundView: View {
    let thumbnailURL: URL?
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Background base color (dark)
            Color.black
            
            if let url = thumbnailURL {
                // Main blurred image - optimized to single instance
                CachedAsyncImage(url: url, contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .blur(radius: 40) // Reduced radius for better performance
                    .scaleEffect(animate ? 1.4 : 1.1)
                    .offset(x: animate ? 20 : -20, y: animate ? -30 : 30)
                    .opacity(0.5)
                    .drawingGroup() // Optimize rendering for animations
                    .onAppear {
                        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
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
