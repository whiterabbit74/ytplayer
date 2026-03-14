import SwiftUI

struct DownloadIcon: View {
    enum IconSize {
        case small    // For lists, miniplayer
        case medium   // For full player
        case custom(CGFloat)
        
        var value: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .custom(let size): return size
            }
        }
    }
    
    let size: IconSize
    var showShadow: Bool = false
    
    init(size: IconSize = .small, showShadow: Bool = false) {
        self.size = size
        self.showShadow = showShadow
    }
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.system(size: size.value))
            .if(showShadow) { view in
                view.shadow(color: .green.opacity(0.4), radius: 2)
            }
    }
}

// Helper for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
