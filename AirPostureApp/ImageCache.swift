import SwiftUI
import os
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

final class SimpleImageCache {
    static let shared = SimpleImageCache()
    private let cache = NSCache<NSString, PlatformImage>()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 50_000_000
    }

    func preloadImageSynchronously(_ name: String) {
        if let image = PlatformImage(named: name) {
            cache.setObject(image, forKey: name as NSString)
            Logger.ui.debug("Synchronously preloaded image: \(name)")
        }
    }

    func preloadImage(_ name: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let image = PlatformImage(named: name) {
                self?.cache.setObject(image, forKey: name as NSString)
                Logger.ui.debug("Preloaded image: \(name)")
            }
        }
    }

    func getCachedImage(_ name: String) -> PlatformImage? {
        return cache.object(forKey: name as NSString)
    }
}
