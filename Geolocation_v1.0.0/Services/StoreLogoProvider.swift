//
//  StoreLogoProvider.swift
//  Geolocation_v1.0.0
//
//  Created on 2/19/26.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

/// Provides store logo URLs by matching normalized store names against a Firestore database.
///
/// ## How it works
/// 1. Logos are stored in Firebase Storage under `stores_logos/{normalizedId}.jpg`
/// 2. Download URLs are cached in Firestore `stores_logos` collection
/// 3. The app fetches from Firestore on launch and caches in memory
/// 4. When a store name matches a known logo, the logo is displayed
/// 5. Downloaded images are cached to disk so they persist across app sessions
///
/// ## Adding logos
/// Call `uploadStoreLogo(storeName:image:)` to upload a logo for a store.
/// This uploads the image to Firebase Storage and saves the URL to Firestore.
///
/// ## Firestore document structure
///   Collection: `stores_logos`
///   Document ID: normalized store name (e.g., "walmart", "trader-joes")
///   Fields: { "logoURL": "https://firebasestorage.googleapis.com/..." }
class StoreLogoProvider: ObservableObject {
    static let shared = StoreLogoProvider()

    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    @Published private(set) var storeLogos: [String: String] = [:] // normalizedId -> logoURL
    private var hasFetched = false
    private var isFetching = false

    // MARK: - Image Disk Cache

    private static let urlCacheKey = "StoreLogoProvider.cachedURLs"
    private let imageCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("StoreLogos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    /// Tracks which logos are currently being downloaded to avoid duplicate requests.
    private var downloadingLogos: Set<String> = []

    private init() {
        // Load cached URL mappings from UserDefaults for instant availability
        if let cached = UserDefaults.standard.dictionary(forKey: Self.urlCacheKey) as? [String: String] {
            storeLogos = cached
        }
        fetchStoreLogos()
    }

    /// Look up a logo URL for a store name.
    /// First tries an exact match on the normalized ID, then checks if the
    /// normalized name starts with any known store key (e.g., "walmart-supercenter" matches "walmart").
    func logoURL(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)
        #if DEBUG
        print("StoreLogoProvider: Fetching store logo with ID: \(normalizedId)")
        #endif
        guard let key = bestLogoKey(for: normalizedId) else { return nil }
        #if DEBUG
        if key == normalizedId {
            print("StoreLogoProvider: Matched logo key: \(key) (exact)")
        } else {
            print("StoreLogoProvider: Matched logo key: \(key) (via normalization/prefix)")
        }
        #endif
        return storeLogos[key]
    }

    /// Resolves which cache key (normalized ID) to use for a given store name,
    /// accounting for prefix matching.
    func resolvedLogoId(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)
        return bestLogoKey(for: normalizedId)
    }

    /// Returns a canonical key for resilient matching across punctuation/symbol variants.
    /// Example: "85°c-bakery-cafe" and "85c bakery cafe" both become "85c-bakery-cafe".
    private func canonicalLogoKey(_ value: String) -> String {
        let lowercased = value.lowercased().replacingOccurrences(of: "&", with: "and")
        let allowed = CharacterSet.alphanumerics
        let replaced = lowercased.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "-"
        }.joined()
        let collapsed = replaced.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Finds the best matching logo key using exact and prefix checks on both
    /// raw normalized IDs and canonicalized IDs.
    private func bestLogoKey(for normalizedId: String) -> String? {
        // 1) Raw exact match (fast path)
        if storeLogos[normalizedId] != nil { return normalizedId }

        // 2) Canonical exact match (handles symbols like "°")
        let canonicalId = canonicalLogoKey(normalizedId)
        var canonicalExact: String?
        for key in storeLogos.keys {
            if canonicalLogoKey(key) == canonicalId {
                if canonicalExact == nil || key.count > canonicalExact!.count {
                    canonicalExact = key
                }
            }
        }
        if let canonicalExact {
            return canonicalExact
        }

        // 3) Raw prefix match
        var bestRawPrefix: String?
        for key in storeLogos.keys where normalizedId.hasPrefix(key) {
            if bestRawPrefix == nil || key.count > bestRawPrefix!.count {
                bestRawPrefix = key
            }
        }
        if let bestRawPrefix {
            return bestRawPrefix
        }

        // 4) Canonical prefix match
        var bestCanonicalPrefix: String?
        for key in storeLogos.keys {
            let canonicalKey = canonicalLogoKey(key)
            if canonicalId.hasPrefix(canonicalKey) {
                if bestCanonicalPrefix == nil || canonicalKey.count > canonicalLogoKey(bestCanonicalPrefix!).count {
                    bestCanonicalPrefix = key
                }
            }
        }
        return bestCanonicalPrefix
    }

    // MARK: - Cached Image Access

    /// Returns a cached UIImage for the given store name, checking memory then disk.
    /// If no cached image exists but a URL is known, triggers a background download.
    func cachedImage(for storeName: String) -> UIImage? {
        guard let logoId = resolvedLogoId(for: storeName) else { return nil }
        let cacheKey = logoId as NSString

        // 1. Check in-memory cache
        if let image = imageCache.object(forKey: cacheKey) {
            return image
        }

        // 2. Check disk cache
        let filePath = cacheDirectory.appendingPathComponent("\(logoId).jpg")
        if let data = try? Data(contentsOf: filePath), let image = UIImage(data: data) {
            imageCache.setObject(image, forKey: cacheKey)
            return image
        }

        // 3. No cache hit — trigger background download if we have a URL
        if let urlString = storeLogos[logoId] {
            downloadAndCacheLogo(id: logoId, urlString: urlString)
        }

        return nil
    }

    /// Downloads a logo image and writes it to both disk and memory cache.
    private func downloadAndCacheLogo(id: String, urlString: String) {
        guard !downloadingLogos.contains(id), let url = URL(string: urlString) else { return }
        downloadingLogos.insert(id)

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.downloadingLogos.remove(id) } }

            guard let data = data, error == nil, let image = UIImage(data: data) else {
                #if DEBUG
                print("StoreLogoProvider: Failed to download logo for '\(id)': \(error?.localizedDescription ?? "bad data")")
                #endif
                return
            }

            // Write to disk
            let filePath = self.cacheDirectory.appendingPathComponent("\(id).jpg")
            try? data.write(to: filePath)

            // Update in-memory cache and notify UI
            let cacheKey = id as NSString
            self.imageCache.setObject(image, forKey: cacheKey)

            DispatchQueue.main.async {
                self.objectWillChange.send()
            }

            #if DEBUG
            print("StoreLogoProvider: Cached logo to disk for '\(id)'")
            #endif
        }.resume()
    }

    /// Removes the cached image for a store from both disk and memory.
    private func removeCachedImage(for id: String) {
        imageCache.removeObject(forKey: id as NSString)
        let filePath = cacheDirectory.appendingPathComponent("\(id).jpg")
        try? FileManager.default.removeItem(at: filePath)
    }

    /// Fetch logo mappings from Firestore
    func fetchStoreLogos() {
        guard !hasFetched, !isFetching else { return }
        isFetching = true

        db.collection("stores_logos").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            self.isFetching = false

            if let error = error {
                #if DEBUG
                print("StoreLogoProvider: Error fetching logos: \(error.localizedDescription)")
                #endif
                // Don't set hasFetched so it can be retried
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                #if DEBUG
                print("StoreLogoProvider: No store logos in Firestore yet")
                #endif
                // Don't set hasFetched when empty so it retries on next appear
                return
            }

            var logos: [String: String] = [:]
            for doc in documents {
                let data = doc.data()
                if let logoURL = data["logoURL"] as? String {
                    logos[doc.documentID] = logoURL
                }
            }

            DispatchQueue.main.async {
                self.storeLogos = logos
                self.hasFetched = true

                // Persist URL mappings for instant availability on next launch
                UserDefaults.standard.set(logos, forKey: Self.urlCacheKey)

                #if DEBUG
                print("StoreLogoProvider: Loaded \(logos.count) store logos from Firestore")
                for (id, url) in logos {
                    print("  - \(id): \(url.prefix(80))...")
                }
                #endif

                // Pre-download any logos not yet cached to disk
                for (id, urlString) in logos {
                    let filePath = self.cacheDirectory.appendingPathComponent("\(id).jpg")
                    if !FileManager.default.fileExists(atPath: filePath.path) {
                        self.downloadAndCacheLogo(id: id, urlString: urlString)
                    }
                }
            }
        }
    }

    // MARK: - Upload Store Logo

    /// Upload a logo image for a store to Firebase Storage and save the URL to Firestore.
    ///
    /// - Parameters:
    ///   - storeName: The store name (will be normalized for the ID)
    ///   - image: The logo image to upload
    ///   - completion: Called with the download URL on success, or an error
    func uploadStoreLogo(storeName: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        let normalizedId = Store.normalizedId(from: storeName)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(StoreLogoError.imageConversionFailed))
            return
        }

        let logoRef = storage.child("stores_logos/\(normalizedId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        logoRef.putData(imageData, metadata: metadata) { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("StoreLogoProvider: Upload error: \(error.localizedDescription)")
                #endif
                completion(.failure(error))
                return
            }

            logoRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let downloadURL = url?.absoluteString else {
                    completion(.failure(StoreLogoError.downloadURLFailed))
                    return
                }

                // Save to Firestore
                self.db.collection("stores_logos").document(normalizedId).setData([
                    "logoURL": downloadURL
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    // Update local cache (memory, disk, and UserDefaults)
                    DispatchQueue.main.async {
                        self.storeLogos[normalizedId] = downloadURL
                        UserDefaults.standard.set(self.storeLogos, forKey: Self.urlCacheKey)
                    }

                    // Cache the image to disk immediately (we already have the data)
                    let filePath = self.cacheDirectory.appendingPathComponent("\(normalizedId).jpg")
                    try? imageData.write(to: filePath)
                    self.imageCache.setObject(image, forKey: normalizedId as NSString)

                    #if DEBUG
                    print("StoreLogoProvider: Uploaded logo for '\(storeName)' (id: \(normalizedId))")
                    #endif
                    completion(.success(downloadURL))
                }
            }
        }
    }

    /// Delete a store logo from Firebase Storage and Firestore.
    func deleteStoreLogo(storeName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let normalizedId = Store.normalizedId(from: storeName)

        let logoRef = storage.child("stores_logos/\(normalizedId).jpg")
        logoRef.delete { [weak self] error in
            // Continue even if Storage delete fails (file might not exist)
            if let error = error {
                #if DEBUG
                print("StoreLogoProvider: Storage delete warning: \(error.localizedDescription)")
                #endif
            }

            self?.db.collection("stores_logos").document(normalizedId).delete { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                DispatchQueue.main.async {
                    self?.storeLogos.removeValue(forKey: normalizedId)
                    if let updatedLogos = self?.storeLogos {
                        UserDefaults.standard.set(updatedLogos, forKey: Self.urlCacheKey)
                    }
                }
                self?.removeCachedImage(for: normalizedId)
                completion(.success(()))
            }
        }
    }

    /// Force refresh logos from Firestore and re-download all images.
    func refreshLogos() {
        hasFetched = false
        // Clear disk cache so images are re-downloaded
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
        imageCache.removeAllObjects()
        fetchStoreLogos()
    }

    enum StoreLogoError: LocalizedError {
        case imageConversionFailed
        case downloadURLFailed

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                return "Failed to convert image to JPEG data"
            case .downloadURLFailed:
                return "Failed to get download URL from Firebase Storage"
            }
        }
    }

    // MARK: - Known Store Names

    /// List of common US store normalized IDs for reference.
    /// Use this to know which stores could benefit from having logos uploaded.
    static let commonStoreIds: [String] = [
        "walmart", "target", "costco", "kroger", "whole-foods", "trader-joes",
        "aldi", "publix", "safeway", "h-e-b", "meijer", "vons", "ralphs",
        "albertsons", "sams-club", "bjs", "walgreens", "cvs", "rite-aid",
        "home-depot", "lowes", "dollar-general", "dollar-tree", "five-below",
        "macys", "nordstrom", "kohls", "marshalls", "tj-maxx", "ross",
        "best-buy", "apple", "petco", "petsmart", "staples", "ikea",
        "starbucks", "dunkin", "amazon", "hmart", "99-ranch-market",
        "ulta", "sephora", "nike", "old-navy", "gap", "zara", "uniqlo",
        "michaels", "hobby-lobby", "autozone", "rei", "ace-hardware",
        "7-eleven", "wawa", "sheetz", "circle-k",
    ]
}
