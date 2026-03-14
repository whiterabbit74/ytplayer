import SwiftUI

struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void
    var size: CGFloat = 24
    var style: Style = .standard
    
    enum Style {
        case standard    // For player
        case monochrome  // For lists/darker backgrounds
    }
    
    var body: some View {
        Button {
            HapticManager.shared.trigger(.medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                action()
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size))
                .foregroundStyle(heartColor)
                .scaleEffect(isFavorite ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private var heartColor: Color {
        if isFavorite {
            return .red // We could use white like in PlayerFullView, but red is more standard. 
            // Actually, looking at PlayerFullView.swift:195, it was using .white. 
            // Let's stick to .white if we want to preserve the current look, or .red if we want "standard".
            // User requested "standard", usually Liked is Red or Pink. 
        }
        return style == .standard ? .white.opacity(0.5) : .secondary
    }
}
