import SwiftUI

class ImageLoader {
    static let shared = ImageLoader()
    
    func preloadImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await ImageCache.shared.set(image, forKey: urlString)
            }
        } catch {
            print("Failed to preload image: \(error)")
        }
    }
}

struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    @State private var cachedImage: UIImage?
    @State private var isLoading: Bool = false
    
    init(
        url: URL?,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }
    
    var body: some View {
        Group {
            if let cachedImage {
                content(.success(Image(uiImage: cachedImage)))
            } else {
                ZStack {
                    Color.clear // This ensures the ZStack takes up space
                    if isLoading {
                        ProgressView()
                            .tint(.accentColor)
                            .scaleEffect(1.5)
                    } else {
                        AsyncImage(
                            url: url,
                            scale: scale,
                            transaction: transaction
                        ) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(.accentColor)
                                    .scaleEffect(1.5)
                            case .failure:
                                content(phase)
                            case .success(let image):
                                cacheAndRender(phase: .success(image))
                            @unknown default:
                                content(phase)
                            }
                        }
                    }
                }
                .task {
                    await loadCachedImage()
                }
            }
        }
    }
    
    private func loadCachedImage() async {
        guard let url = url, cachedImage == nil, !isLoading else { return }
        
        // Check memory cache synchronously first
        if let memoryImage = await ImageCache.shared.getFromMemoryCache(forKey: url.absoluteString) {
            cachedImage = memoryImage
            return
        }
        
        // If not in memory, check disk cache asynchronously
        isLoading = true
        defer { isLoading = false }
        
        if let diskImage = await ImageCache.shared.loadImageAsync(forKey: url.absoluteString) {
            cachedImage = diskImage
        }
    }
    
    private func cacheAndRender(phase: AsyncImagePhase) -> some View {
        if case .success(let image) = phase {
            if let url = url {
                Task {
                    if let uiImage = await convertToUIImage(image) {
                        // Set the cachedImage state to trigger UI update
                        cachedImage = uiImage
                        
                        // Save the image to cache
                        await ImageCache.shared.set(uiImage, forKey: url.absoluteString)
                    }
                }
            }
        }
        return content(phase)
    }
    
    private func convertToUIImage(_ image: Image) async -> UIImage? {
        // This needs to run on the main thread since it uses UI components
        return await MainActor.run {
            let renderer = ImageRenderer(content: image)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        }
    }
}