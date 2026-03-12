import SwiftUI

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        let cost = image.pngData()?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode

    @State private var cachedImage: UIImage?
    @State private var loadedURL: URL?

    init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            if let cachedImage, loadedURL == url {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .default)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color.gray.opacity(0.1)
                            ProgressView().controlSize(.small)
                        }
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: contentMode)
                            .onAppear {
                                cacheImage(from: url)
                            }
                    case .failure:
                        ZStack {
                            Color.gray.opacity(0.1)
                            Image(systemName: "music.note").foregroundStyle(.secondary)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .id(url) // Force AsyncImage to reload when URL changes
            } else {
                ZStack {
                    Color.gray.opacity(0.1)
                    Image(systemName: "music.note").foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .onAppear { loadFromCache() }
        .onChange(of: url) { _, _ in loadFromCache() }
    }

    private func loadFromCache() {
        if let url {
            if let cached = ImageCache.shared.image(for: url) {
                cachedImage = cached
                loadedURL = url
            } else {
                // URL changed but no cache — reset so AsyncImage shows
                cachedImage = nil
                loadedURL = nil
            }
        } else {
            cachedImage = nil
            loadedURL = nil
        }
    }

    private func cacheImage(from url: URL) {
        Task.detached(priority: .utility) {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else { return }
            ImageCache.shared.insert(uiImage, for: url)
            await MainActor.run {
                cachedImage = uiImage
                loadedURL = url
            }
        }
    }
}
