//
//  ProfileImageCache.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI
import CryptoKit
import ImageIO

/// Memory + disk cache for user profile pictures, mirroring what
/// `StoreLogoProvider` does for store logos.
///
/// `AsyncImage` re-downloads an avatar on every cold launch, which is why
/// friends' photos used to pop in half a second after the list rendered while
/// store logos were there immediately. Here the decoded image lives in an
/// `NSCache` for the session and the original bytes live in the caches
/// directory across launches, so the second launch onwards is a local disk read.
///
/// Cache keys ignore the URL's query string: Firebase Storage hands out a new
/// `token=` every time a user re-uploads their picture, and the friendship
/// documents keep an older copy of the URL than the `users` collection does.
/// Keying on the path alone means both URLs hit the same entry instead of
/// flickering back to a letter avatar. The full URL is remembered alongside it
/// so a genuinely new upload still refreshes — in the background, with the old
/// photo on screen until the new one is ready.
final class ProfileImageCache: ObservableObject {
    static let shared = ProfileImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()

    private let cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("ProfilePictures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let ioQueue = DispatchQueue(label: "com.allim.profileImageCache.io", qos: .userInitiated)

    /// Avatars are drawn at most at 100pt, so 512px covers a 3x screen with room
    /// to spare and keeps a full friends list from holding camera-sized bitmaps.
    private static let maxPixelSize: CGFloat = 512

    /// Files untouched for this long are swept on launch.
    private static let maxFileAge: TimeInterval = 60 * 60 * 24 * 30

    private static let versionsDefaultsKey = "ProfileImageCache.urlVersions"

    /// cacheKey -> the full URL string the cached bytes were downloaded from.
    private var urlVersions: [String: String]

    // The three sets below are only ever touched on the main thread: `image(for:)`
    // is called from view bodies, and every background completion hops back first.
    private var diskLoadsInFlight: Set<String> = []
    private var downloadsInFlight: Set<String> = []
    private var notifyScheduled = false

    private init() {
        memoryCache.countLimit = 300
        memoryCache.totalCostLimit = 32 * 1024 * 1024
        urlVersions = UserDefaults.standard.dictionary(forKey: Self.versionsDefaultsKey) as? [String: String] ?? [:]
        pruneStaleFiles()
    }

    // MARK: - Lookup

    /// Returns the avatar for `urlString` if it's already decoded in memory, and
    /// otherwise starts a disk read (falling back to a download) and returns nil
    /// so the caller can draw its placeholder in the meantime.
    func image(for urlString: String?) -> UIImage? {
        guard let urlString = urlString,
              !urlString.isEmpty,
              let url = URL(string: urlString) else { return nil }

        #if DEBUG
        // The screenshot mocks address drawn portraits rather than uploads, so
        // there is nothing to fetch — hand the drawing straight back.
        if let portrait = ScreenshotAvatarFactory.image(forMockURL: urlString) {
            return portrait
        }
        #endif

        let key = Self.cacheKey(for: url)

        if let image = memoryCache.object(forKey: key as NSString) {
            redownloadIfURLChanged(key: key, url: url, urlString: urlString)
            return image
        }

        loadFromDisk(key: key, url: url, urlString: urlString)
        return nil
    }

    /// Warms the cache for avatars that are about to be shown, e.g. right after a
    /// friends list arrives, so the first draw already has them in memory.
    func prefetch(_ urlStrings: [String?]) {
        for urlString in urlStrings {
            _ = image(for: urlString)
        }
    }

    // MARK: - Loading

    private func loadFromDisk(key: String, url: URL, urlString: String) {
        guard !diskLoadsInFlight.contains(key) else { return }
        diskLoadsInFlight.insert(key)

        Self.ioQueue.async { [weak self] in
            guard let self = self else { return }

            let file = self.cacheDirectory.appendingPathComponent("\(key).jpg")
            if let data = try? Data(contentsOf: file), let image = Self.decode(data) {
                self.store(image, forKey: key)
                // Touch the file so an avatar in daily use is never swept.
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)

                DispatchQueue.main.async {
                    self.diskLoadsInFlight.remove(key)
                    self.scheduleNotify()
                    self.redownloadIfURLChanged(key: key, url: url, urlString: urlString)
                }
                return
            }

            DispatchQueue.main.async {
                self.diskLoadsInFlight.remove(key)
                self.download(key: key, url: url, urlString: urlString)
            }
        }
    }

    /// Re-fetches when the picture behind a cached path has been replaced. The
    /// cached image stays on screen until the replacement finishes decoding.
    private func redownloadIfURLChanged(key: String, url: URL, urlString: String) {
        guard urlVersions[key] != urlString else { return }
        download(key: key, url: url, urlString: urlString)
    }

    private func download(key: String, url: URL, urlString: String) {
        guard !downloadsInFlight.contains(key) else { return }
        downloadsInFlight.insert(key)

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.downloadsInFlight.remove(key) } }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data, error == nil, status == 200, let image = Self.decode(data) else {
                #if DEBUG
                print("ProfileImageCache: Failed to download avatar (HTTP \(status)): \(error?.localizedDescription ?? "bad data")")
                #endif
                return
            }

            let file = self.cacheDirectory.appendingPathComponent("\(key).jpg")
            try? data.write(to: file)
            self.store(image, forKey: key)

            DispatchQueue.main.async {
                self.urlVersions[key] = urlString
                UserDefaults.standard.set(self.urlVersions, forKey: Self.versionsDefaultsKey)
                self.scheduleNotify()
            }
        }.resume()
    }

    private func store(_ image: UIImage, forKey key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// Coalesces the redraws for a screenful of avatars finishing at once into a
    /// single notification per runloop turn.
    private func scheduleNotify() {
        guard !notifyScheduled else { return }
        notifyScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.notifyScheduled = false
            self?.objectWillChange.send()
        }
    }

    // MARK: - Decoding

    /// Downsamples and decodes off the main thread so the first draw is cheap.
    private static func decode(_ data: Data) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)?.preparingForDisplay()
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Keys & Housekeeping

    /// Hash of the URL without its query string, so a re-issued Firebase download
    /// token maps to the same entry as the token it replaced.
    private static func cacheKey(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        let canonical = components?.string ?? url.absoluteString
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func pruneStaleFiles() {
        let directory = cacheDirectory
        let cutoff = Date().addingTimeInterval(-Self.maxFileAge)

        Self.ioQueue.async { [weak self] in
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            var removedKeys: [String] = []
            for file in files {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let modified = modified, modified > cutoff { continue }
                try? FileManager.default.removeItem(at: file)
                removedKeys.append(file.deletingPathExtension().lastPathComponent)
            }

            guard !removedKeys.isEmpty else { return }
            DispatchQueue.main.async {
                guard let self = self else { return }
                for key in removedKeys {
                    self.urlVersions.removeValue(forKey: key)
                }
                UserDefaults.standard.set(self.urlVersions, forKey: Self.versionsDefaultsKey)
            }
        }
    }
}
