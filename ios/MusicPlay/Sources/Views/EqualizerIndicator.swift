import SwiftUI

struct EqualizerIndicator: View {
    @State private var heights: [CGFloat] = [0.3, 0.7, 0.4]
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 3, height: 12 * heights[i])
                    .animation(.easeInOut(duration: 0.2), value: heights[i])
            }
        }
        .frame(height: 12, alignment: .bottom)
        .onReceive(timer) { _ in
            for i in 0..<3 {
                heights[i] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
}
