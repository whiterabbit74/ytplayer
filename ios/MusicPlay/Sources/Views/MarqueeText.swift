import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    var padding: CGFloat = 30

    @State private var offset: CGFloat = 0
    @State private var textSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: geometry.size.width, alignment: .center)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear.onAppear {
                                textSize = textGeo.size
                            }
                            .onChange(of: textGeo.size) { _, newSize in
                                textSize = newSize
                            }
                        }
                    )
                    .offset(x: offset)
                    .padding(.trailing, needsScroll ? padding : 0)
                    .onAppear {
                        containerSize = geometry.size
                        startAnimation()
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        containerSize = newSize
                        startAnimation()
                    }
                    .onChange(of: text) { _, _ in
                        offset = 0
                        startAnimation()
                    }
            }
            .disabled(true) // Disable manual scrolling
            // Apply fade at the edges
            .mask(
                HStack(spacing: 0) {
                    if needsScroll {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0), Color.black]),
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 10)
                    }

                    Color.black

                    if needsScroll {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black, Color.black.opacity(0)]),
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 10)
                    }
                }
            )
        }
        .frame(height: textSize.height > 0 ? textSize.height : nil)
    }

    private var needsScroll: Bool {
        textSize.width > containerSize.width && containerSize.width > 0
    }

    private func startAnimation() {
        scrollTask?.cancel()

        withAnimation(.none) {
            offset = 0
        }

        guard needsScroll else { return }

        let scrollDistance = textSize.width - containerSize.width + padding
        let duration = Double(scrollDistance) / 30.0 // 30 points per second

        scrollTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    offset = -scrollDistance
                }
            }
        }
    }
}
