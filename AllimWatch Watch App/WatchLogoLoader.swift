//
//  WatchLogoLoader.swift
//  AllimWatch Watch App
//
//  Store logos, shrunk to the size a watch row actually draws.
//
//  A logo URL can point at anything: Logo.dev's small PNGs, or a photo someone
//  uploaded from their phone at full camera resolution. AsyncImage decodes the
//  whole thing, so a 4000-pixel photo costs tens of megabytes of memory to fill
//  a 28-point circle — and scrolling a long store list quickly starts several
//  of those at once. Older watches run out of memory well before newer ones and
//  watchOS ends the app.
//
//  So the download goes to a file instead of memory, ImageIO reads a thumbnail
//  straight from it without decoding the full image, and the thumbnail is kept
//  in memory and on disk. A logo is downloaded and decoded once, and every
//  later appearance of the row is a lookup.
//

import CryptoKit
import Foundation
import ImageIO
import UIKit

enum WatchLogoLoader {

    /// Thumbnails already made this launch. NSCache gives them back on its own
    /// when the system asks for memory.
    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150
        return cache
    }()

    /// Thumbnails from earlier launches, so the list doesn't download every
    /// logo again each time the app opens.
    private static let directory: URL? = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = caches.appendingPathComponent("StoreLogos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    /// The thumbnail if it's already in memory. Lets a row that scrolls back
    /// into view draw its logo straight away instead of flashing the initial.
    static func cachedImage(for url: URL, maxPixelSize: Int) -> UIImage? {
        memory.object(forKey: key(for: url, maxPixelSize: maxPixelSize) as NSString)
    }

    /// The logo at no more than `maxPixelSize` on its longest side, or nil if it
    /// can't be had. Cancelling the calling task (the row scrolling away) stops
    /// the download, so a fast scroll doesn't leave a queue of them behind.
    static func image(for url: URL, maxPixelSize: Int) async -> UIImage? {
        let key = key(for: url, maxPixelSize: maxPixelSize)

        if let image = memory.object(forKey: key as NSString) {
            return image
        }

        let file = directory?.appendingPathComponent(key + ".png")
        if let file, let image = UIImage(contentsOfFile: file.path) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }

        guard let (download, response) = try? await URLSession.shared.download(from: url) else {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: download) }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        guard let image = thumbnail(of: download, maxPixelSize: maxPixelSize) else {
            return nil
        }

        memory.setObject(image, forKey: key as NSString)
        if let file, let data = image.pngData() {
            try? data.write(to: file, options: .atomic)
        }
        return image
    }

    // MARK: - Helpers

    /// Reads a downscaled copy of the image in `file`. JPEGs are decoded at a
    /// reduced size directly, so the full-resolution image is never in memory.
    private static func thumbnail(of file: URL, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(file as CFURL, sourceOptions) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }

        return UIImage(cgImage: image)
    }

    /// One cache entry per URL and size. Hashed, because Firebase download URLs
    /// are long and full of characters a file name can't hold.
    private static func key(for url: URL, maxPixelSize: Int) -> String {
        let digest = SHA256.hash(data: Data("\(url.absoluteString)#\(maxPixelSize)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
