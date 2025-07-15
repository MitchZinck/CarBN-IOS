import Foundation
import SwiftUI
import CryptoKit

actor ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, CachedImage>()
    private let expirationInterval: TimeInterval = 2592000 // 30 days in seconds
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL? {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("ImageCache")
    }
    
    private init() {
        cache.countLimit = 200 // Maximum number of images to cache
        
        // Create directory inline instead of calling actor-isolated method
        if let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("ImageCache") {
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            }
        }
    }
    
    // This method is now only used by other actor-isolated methods
    private func createCacheDirectory() {
        guard let cacheDirectory = cacheDirectory else { return }
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    class CachedImage {
        let image: UIImage
        let timestamp: Date
        
        init(image: UIImage) {
            self.image = image
            self.timestamp = Date()
        }
        
        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > ImageCache.shared.expirationInterval
        }
    }
    
    func set(_ image: UIImage, forKey key: String) {
        // Store in memory cache
        cache.setObject(CachedImage(image: image), forKey: key as NSString)
        
        // Store on disk asynchronously
        Task.detached(priority: .background) { [weak self] in
            guard let self = self, let cacheDirectory = await self.cacheDirectory else { return }
            let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
            
            // Save image data and timestamp
            let metadata: [String: Any] = [
                "timestamp": Date().timeIntervalSince1970,
                "key": key
            ]
            
            do {
                // Use PNG format to preserve exact quality without alpha channel issues
                if let imageData = image.pngData() {
                    try imageData.write(to: fileURL)
                    let metadataURL = fileURL.appendingPathExtension("metadata")
                    try JSONSerialization.data(withJSONObject: metadata)
                        .write(to: metadataURL)
                }
            } catch {
                print("Failed to write image to disk: \(error)")
            }
        }
    }
    
    func getFromMemoryCache(forKey key: String) -> UIImage? {
        // Check memory cache first - this is synchronous and fast
        if let cachedImage = cache.object(forKey: key as NSString) {
            if cachedImage.isExpired {
                cache.removeObject(forKey: key as NSString)
                Task.detached { [weak self] in
                    await self?.removeDiskCache(for: key)
                }
                return nil
            }
            return cachedImage.image
        }
        return nil
    }
    
    func get(forKey key: String) -> UIImage? {
        // Check memory cache first
        if let memoryImage = getFromMemoryCache(forKey: key) {
            return memoryImage
        }
        
        // This is still synchronous but will be called from within the async method
        return nil
    }
    
    func loadImageAsync(forKey key: String) async -> UIImage? {
        // Check memory first (again, this might have been loaded since we last checked)
        if let memoryImage = getFromMemoryCache(forKey: key) {
            return memoryImage
        }
        
        // Check disk cache asynchronously
        return await loadImageFromDisk(for: key)
    }
    
    private func loadImageFromDisk(for key: String) async -> UIImage? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        let metadataURL = fileURL.appendingPathExtension("metadata")
        
        // First check if both files exist
        if !fileManager.fileExists(atPath: fileURL.path) || !fileManager.fileExists(atPath: metadataURL.path) {
            // Cleanup if one exists but not the other
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
            if fileManager.fileExists(atPath: metadataURL.path) {
                try? fileManager.removeItem(at: metadataURL)
            }
            return nil
        }
        
        do {
            let metadataData = try Data(contentsOf: metadataURL)
            guard let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                  let timestamp = metadata["timestamp"] as? TimeInterval else {
                // Clean up invalid metadata
                try? fileManager.removeItem(at: metadataURL)
                return nil
            }
            
            // Check if cached image is expired
            if Date().timeIntervalSince1970 - timestamp > expirationInterval {
                removeDiskCache(for: key)
                return nil
            }
            
            // Load and return image
            guard let imageData = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: imageData) else {
                // Clean up if image data is invalid
                removeDiskCache(for: key)
                return nil
            }
            
            // Store in memory cache
            cache.setObject(CachedImage(image: image), forKey: key as NSString)
            return image
        } catch {
            print("Failed to load image from disk: \(error)")
            // Clean up files if there was an error
            try? fileManager.removeItem(at: fileURL)
            try? fileManager.removeItem(at: metadataURL)
            return nil
        }
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
        Task.detached { [weak self] in
            await self?.removeDiskCache(for: key)
        }
    }

    private func removeDiskCache(for key: String) {
        guard let cacheDirectory = cacheDirectory else { return }
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        let metadataURL = fileURL.appendingPathExtension("metadata")
        
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: metadataURL)
    }
    
    func clear() async {
        cache.removeAllObjects()
        Task.detached { [weak self] in
            guard let self = self else { return }
            guard let cacheDirectory = await self.cacheDirectory else { return }
            
            // Use local FileManager instance
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: cacheDirectory)
            await self.createCacheDirectory()
        }
    }
}

private extension String {
    var sha256Hash: String {
        let inputData = Data(self.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
