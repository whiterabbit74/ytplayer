import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    var padding: CGFloat = 30
    var speed: Double = 30 // Points per second

    @State private var offset: CGFloat = 0
    @State private var textSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if needsScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offset)
                        .padding(.trailing, padding)
                }
                .disabled(true)
                .mask(
                    HStack(spacing: 0) {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0), Color.black]),
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 15)

                        Color.black

                        LinearGradient(
                            gradient: Gradient(colors: [Color.black, Color.black.opacity(0)]),
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 15)
                    }
                )
            } else {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    containerSize = geometry.size
                    startAnimation()
                }
                .onChange(of: geometry.size) { _, newSize in
                    containerSize = newSize
                    startAnimation()
                }
            }
        )
        .overlay(
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .opacity(0)
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear {
                            textSize = textGeo.size
                            startAnimation()
                        }
                        .onChange(of: textGeo.size) { _, newSize in
                            textSize = newSize
                            startAnimation()
                        }
                    }
                ),
            alignment: .center
        )
        .frame(height: textSize.height > 0 ? textSize.height : nil)
        .onAppear {
            startAnimation()
        }
        .onChange(of: text) { _, _ in
            offset = 0
            startAnimation()
        }
    }

    private var needsScroll: Bool {
        textSize.width > containerSize.width && containerSize.width > 0
    }

    private func startAnimation() {
        scrollTask?.cancel()
        offset = 0

        guard needsScroll else { return }

        let scrollDistance = textSize.width - containerSize.width + padding
        let duration = Double(scrollDistance) / speed

        scrollTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            
            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.linear(duration: duration)) {
                        offset = -scrollDistance
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 1_000_000_000)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    offset = 0
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}
