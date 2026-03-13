import SwiftUI

final class ImageCache {
    static let shared = ImageCache()
    private let memoryCache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    
    private lazy var diskCacheDirectory: URL = {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("ImageCache")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func image(for url: URL) -> UIImage? {
        // 1. Memory Cache
        if let image = memoryCache.object(forKey: url as NSURL) {
            return image
        }
        
        // 2. Disk Cache
        let fileName = cacheFileName(for: url)
        let filePath = diskCacheDirectory.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: filePath), let image = UIImage(data: data) {
            // Put back into memory cache
            memoryCache.setObject(image, forKey: url as NSURL, cost: data.count)
            return image
        }
        
        return nil
    }

    func insert(_ image: UIImage, for url: URL) {
        let data = image.pngData()
        let cost = data?.count ?? 0
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
        
        // Save to disk asynchronously
        if let data = data {
            let fileName = cacheFileName(for: url)
            let filePath = diskCacheDirectory.appendingPathComponent(fileName)
            Task.detached(priority: .background) {
                try? data.write(to: filePath)
            }
        }
    }
    
    private func cacheFileName(for url: URL) -> String {
        // Simple hash or base64 of the URL to make a safe filename
        let data = url.absoluteString.data(using: .utf8)!
        let base64 = data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return base64.suffix(100) + ".png" // Limit length
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
        // Optimization: In a real app we'd use a more robust caching library like Kingfisher
        // to avoid double downloads. For now, we'll keep this but ensure it doesn't
        // trample the main thread.
        Task.detached(priority: .background) {
            guard ImageCache.shared.image(for: url) == nil else { return }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else { return }
            
            ImageCache.shared.insert(uiImage, for: url)
            
            await MainActor.run {
                if self.url == url {
                    self.cachedImage = uiImage
                    self.loadedURL = url
                }
            }
        }
    }
}
