import SwiftUI

struct PlayPauseButton: View {
    let isPlaying: Bool
    let isBuffering: Bool
    let action: () -> Void
    var style: Style = .standard
    
    enum Style {
        case large     // For PlayerFullView
        case mini      // For PlayerMiniView
        case row       // For TrackRow/Lists
    }
    
    var body: some View {
        Button {
            HapticManager.shared.trigger(style == .large ? .light : .selection)
            action()
        } label: {
            ZStack {
                if style == .large {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 80)
                }
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(iconFont)
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(isBuffering ? 0 : 1)
                
                if isBuffering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(style == .large ? 1.5 : 1.0)
                }
            }
            .if(style == .large) { view in
                view.scaleEffect(isPlaying ? 1.0 : 0.9)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
        .animation(.default, value: isBuffering)
    }
    
    private var iconFont: Font {
        switch style {
        case .large: return .system(size: 48, weight: .bold)
        case .mini: return .title2
        case .row: return .caption
        }
    }
}
