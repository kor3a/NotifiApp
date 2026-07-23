//
//  StoreLogoProvider.swift
//  Geolocation_v1.0.0
//
//  Created on 2/19/26.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions
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
    private lazy var functions = Functions.functions()
    @Published private(set) var storeLogos: [String: String] = [:] // normalizedId -> logoURL
    private var hasFetched = false
    private var isFetching = false

    /// Store website overrides loaded from the Firestore `store_websites` collection
    /// (normalizedId -> full website URL). These take precedence over the built-in
    /// domain map, so non-derivable domains (e.g. "snrtea.com" for Sunright Tea Studio)
    /// can be added without an app update.
    @Published private(set) var storeWebsites: [String: String] = [:]
    private var hasFetchedWebsites = false
    private var isFetchingWebsites = false
    private static let websiteCacheKey = "StoreLogoProvider.cachedWebsites"

    // MARK: - Image Disk Cache

    private static let urlCacheKey = "StoreLogoProvider.cachedURLs"
    /// Domains discovered via Logo.dev name search, persisted so each store is only searched once.
    private static let searchCacheKey = "StoreLogoProvider.searchedDomains"
    private let imageCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("StoreLogos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    /// Tracks which logos are currently being downloaded to avoid duplicate requests.
    private var downloadingLogos: Set<String> = []
    /// Tracks disk reads in flight so scrolling doesn't enqueue duplicate background loads.
    private var diskLoadsInFlight: Set<String> = []
    /// Serial background queue for disk reads + image decoding (keeps the main thread free).
    private static let ioQueue = DispatchQueue(label: "StoreLogoProvider.io", qos: .userInitiated)

    // MARK: - Resolution Memoization

    /// Memoized result of `bestLogoKey(for:)`, keyed by normalizedId. The underlying
    /// computation scans every key in `storeLogos` (and canonicalizes each one), which is
    /// far too expensive to repeat on every SwiftUI row render. Cleared whenever the
    /// logo data it depends on changes.
    private var resolvedKeyCache: [String: String?] = [:]
    /// Memoized result of `logoURL(for:)`, keyed by normalizedId. Avoids re-scanning the
    /// Firebase keys and the static domain map on every render.
    private var resolvedURLCache: [String: String?] = [:]

    /// Invalidate the resolution caches after the data they depend on
    /// (`storeLogos` / `searchedDomains`) changes. Must be called on the main thread.
    private func invalidateResolutionCaches() {
        resolvedKeyCache.removeAll()
        resolvedURLCache.removeAll()
    }
    /// Tracks in-flight Logo.dev name searches to avoid duplicate API calls.
    private var searchingStores: Set<String> = []
    /// normalizedId → domain discovered via Logo.dev Brand Search API (persisted to UserDefaults).
    private var searchedDomains: [String: String] = [:]

    private init() {
        // Load cached URL mappings from UserDefaults for instant availability
        if let cached = UserDefaults.standard.dictionary(forKey: Self.urlCacheKey) as? [String: String] {
            storeLogos = cached
        }
        if let searched = UserDefaults.standard.dictionary(forKey: Self.searchCacheKey) as? [String: String] {
            searchedDomains = searched
        }
        if let cachedWebsites = UserDefaults.standard.dictionary(forKey: Self.websiteCacheKey) as? [String: String] {
            storeWebsites = cachedWebsites
        }
        fetchStoreLogos()
        fetchStoreWebsites()
    }

    /// Look up a logo URL for a store name.
    /// First tries Firebase (exact/prefix/canonical match), then falls back to
    /// the Clearbit Logo API using the built-in domain map (no API key required).
    func logoURL(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)
        if let cached = resolvedURLCache[normalizedId] {
            return cached
        }
        let result = computeLogoURL(for: normalizedId)
        resolvedURLCache[normalizedId] = result
        return result
    }

    private func computeLogoURL(for normalizedId: String) -> String? {
        #if DEBUG
        print("StoreLogoProvider: Fetching store logo with ID: \(normalizedId)")
        #endif

        // 1. Firebase — exact / canonical / prefix match
        if let key = bestLogoKey(for: normalizedId) {
            #if DEBUG
            let matchType = key == normalizedId ? "exact" : "via normalization/prefix"
            print("StoreLogoProvider: Matched Firebase logo key: \(key) (\(matchType))")
            #endif
            return storeLogos[key]
        }

        // 2. Logo.dev auto-logo — domain map + suffix-stripping heuristics
        if let url = clearbitLogoURL(for: normalizedId) {
            #if DEBUG
            print("StoreLogoProvider: Using Logo.dev fallback for '\(normalizedId)': \(url)")
            #endif
            return url
        }

        // 3. Domain previously discovered via Logo.dev Brand Search API
        if let domain = searchedDomains[normalizedId], let token = Self.logoDevToken {
            return "https://img.logo.dev/\(domain)?token=\(token)"
        }

        #if DEBUG
        print("StoreLogoProvider: No logo match for ID: \(normalizedId) (canonical: \(canonicalLogoKey(normalizedId)))")
        #endif
        return nil
    }

    // MARK: - Store Website

    /// Returns the store's website URL, or `nil` if none can be determined.
    ///
    /// Resolution order:
    ///   1. Firestore `store_websites` override (exact, then canonical match) — for
    ///      non-derivable domains like "snrtea.com" (Sunright Tea Studio).
    ///   2. Built-in domain map derived from the store name.
    ///
    /// Opening this URL lets iOS hand off to the store's app via universal links when
    /// the app is installed, and otherwise falls back to Safari.
    func websiteURL(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)

        // 1. Firestore override — exact match
        if let url = storeWebsites[normalizedId] {
            return url
        }

        // 2. Firestore override — canonical match (handles symbols/punctuation)
        if !storeWebsites.isEmpty {
            let canonicalId = canonicalLogoKey(normalizedId)
            var bestMatch: (key: String, url: String)?
            for (key, url) in storeWebsites where canonicalLogoKey(key) == canonicalId {
                if bestMatch == nil || key.count > bestMatch!.key.count {
                    bestMatch = (key, url)
                }
            }
            if let match = bestMatch {
                return match.url
            }
        }

        // 3. Built-in domain map
        if let domain = resolvedDomain(for: normalizedId) {
            return "https://\(domain)"
        }

        return nil
    }

    /// Fetch store website overrides from Firestore.
    ///
    /// ## Firestore document structure
    ///   Collection: `store_websites`
    ///   Document ID: normalized store name (e.g. "sunright-tea-studio")
    ///   Fields: { "websiteURL": "https://www.snrtea.com" }
    func fetchStoreWebsites() {
        guard !hasFetchedWebsites, !isFetchingWebsites else { return }
        isFetchingWebsites = true

        db.collection("store_websites").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isFetchingWebsites = false

            if let error = error {
                #if DEBUG
                print("StoreLogoProvider: Error fetching store websites: \(error.localizedDescription)")
                #endif
                return // Don't set hasFetched so it can be retried
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                return // Retry on next call when the collection is still empty
            }

            var websites: [String: String] = [:]
            for doc in documents {
                if let url = doc.data()["websiteURL"] as? String, !url.isEmpty {
                    websites[doc.documentID] = url
                }
            }

            DispatchQueue.main.async {
                self.storeWebsites = websites
                self.hasFetchedWebsites = true
                UserDefaults.standard.set(websites, forKey: Self.websiteCacheKey)
                #if DEBUG
                print("StoreLogoProvider: Loaded \(websites.count) store websites from Firestore")
                #endif
            }
        }
    }

    /// Add or update a store's website override in Firestore (and the local cache).
    /// The store name is normalized for the document ID; a missing scheme defaults to https.
    func setStoreWebsite(storeName: String, websiteURL: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let normalizedId = Store.normalizedId(from: storeName)
        var urlString = websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.lowercased().hasPrefix("http") {
            urlString = "https://\(urlString)"
        }

        db.collection("store_websites").document(normalizedId).setData([
            "websiteURL": urlString
        ]) { [weak self] error in
            if let error = error {
                completion?(.failure(error))
                return
            }
            DispatchQueue.main.async {
                self?.storeWebsites[normalizedId] = urlString
                if let updated = self?.storeWebsites {
                    UserDefaults.standard.set(updated, forKey: Self.websiteCacheKey)
                }
                completion?(.success(()))
            }
        }
    }

    /// Force refresh store website overrides from Firestore.
    func refreshStoreWebsites() {
        hasFetchedWebsites = false
        fetchStoreWebsites()
    }

    /// Resolves a store's canonical web domain from the built-in domain map
    /// (exact match, canonical match for punctuation/symbol variants like "85°C",
    /// leading "the-" strip, and longest-prefix match) plus any domain previously
    /// discovered via the Logo.dev Brand Search API.
    private func resolvedDomain(for normalizedId: String) -> String? {
        // 1. Explicit map entry (fast path)
        if let domain = Self.storeDomains[normalizedId] {
            return domain
        }

        // 2. Canonical exact match — handles symbols/punctuation the raw normalized ID
        //    keeps (e.g. "85°c-bakery-cafe" canonicalizes to "85c-bakery-cafe").
        let canonicalId = canonicalLogoKey(normalizedId)
        var canonicalExact: (key: String, domain: String)?
        for (key, domain) in Self.storeDomains where canonicalLogoKey(key) == canonicalId {
            if canonicalExact == nil || key.count > canonicalExact!.key.count {
                canonicalExact = (key, domain)
            }
        }
        if let match = canonicalExact {
            return match.domain
        }

        // 3. Strip a leading "the-" and re-check ("the-home-depot" -> "home-depot")
        let withoutThe = normalizedId.hasPrefix("the-") ? String(normalizedId.dropFirst(4)) : normalizedId
        if withoutThe != normalizedId, let domain = Self.storeDomains[withoutThe] {
            return domain
        }

        // 4. Longest-prefix match ("walmart-supercenter" -> "walmart")
        let candidates = withoutThe != normalizedId ? [normalizedId, withoutThe] : [normalizedId]
        for candidate in candidates {
            var bestPrefixMatch: (key: String, domain: String)?
            for (key, domain) in Self.storeDomains where candidate.hasPrefix(key) {
                if bestPrefixMatch == nil || key.count > bestPrefixMatch!.key.count {
                    bestPrefixMatch = (key, domain)
                }
            }
            if let match = bestPrefixMatch {
                return match.domain
            }
        }

        // 5. Canonical longest-prefix match (canonicalized on both sides)
        var bestCanonicalPrefix: (key: String, domain: String)?
        for (key, domain) in Self.storeDomains {
            let canonicalKey = canonicalLogoKey(key)
            if canonicalId.hasPrefix(canonicalKey) {
                if bestCanonicalPrefix == nil || canonicalKey.count > canonicalLogoKey(bestCanonicalPrefix!.key).count {
                    bestCanonicalPrefix = (key, domain)
                }
            }
        }
        if let match = bestCanonicalPrefix {
            return match.domain
        }

        // 6. Domain discovered earlier via Logo.dev Brand Search
        if let domain = searchedDomains[normalizedId] {
            return domain
        }

        return nil
    }

    /// Resolves which cache key (normalized ID) to use for a given store name,
    /// accounting for prefix matching.
    func resolvedLogoId(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)
        if let cached = resolvedKeyCache[normalizedId] {
            return cached
        }
        let result = bestLogoKey(for: normalizedId)
        resolvedKeyCache[normalizedId] = result
        return result
    }

    /// Returns a canonical key for resilient matching across punctuation/symbol variants.
    /// Example: "85°c-bakery-cafe" and "85c bakery cafe" both become "85c-bakery-cafe".
    private func canonicalLogoKey(_ value: String) -> String {
        let lowercased = value.lowercased().replacingOccurrences(of: "&", with: "and")
        var output = ""
        var lastWasHyphen = false

        for scalar in lowercased.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.append(String(scalar))
                lastWasHyphen = false
                continue
            }

            // Whitespace/common delimiters become "-", while symbols like "°" are dropped.
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "/"
            if isSeparator && !lastWasHyphen && !output.isEmpty {
                output.append("-")
                lastWasHyphen = true
            }
        }

        return output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
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
    /// If no cached image exists but a URL is known (Firebase or Clearbit), triggers
    /// a background download and caches the result to disk for future calls.
    func cachedImage(for storeName: String) -> UIImage? {
        // Use the Firebase-matched key when available so prefixed names share the
        // same disk file (e.g. "walmart-supercenter" reuses "walmart.jpg").
        // For Clearbit-only stores fall back to the bare normalizedId as cache key.
        let normalizedId = Store.normalizedId(from: storeName)
        let logoId = resolvedLogoId(for: storeName) ?? normalizedId
        let cacheKey = logoId as NSString

        // 1. Check in-memory cache. This is the only synchronous path and is safe to run
        //    on the main thread during scrolling (NSCache lookups are O(1) and lock-free
        //    enough for our purposes).
        if let image = imageCache.object(forKey: cacheKey) {
            return image
        }

        // 2. Not in memory: read from disk (and decode) OFF the main thread so file I/O
        //    and JPEG decoding never block scrolling. The result is published via
        //    objectWillChange once ready. If there's no disk copy, fall through to the
        //    download / name-search path (which already de-duplicates in-flight work).
        loadImageOffMainThread(logoId: logoId, storeName: storeName)
        return nil
    }

    /// Loads a logo image from disk on a background queue, decodes it, stores it in the
    /// in-memory cache, and notifies observers. Falls back to a network download or
    /// Logo.dev name search when no disk copy exists. Must be called on the main thread.
    private func loadImageOffMainThread(logoId: String, storeName: String) {
        // De-duplicate concurrent loads for the same logo while cells recycle during scroll.
        guard !diskLoadsInFlight.contains(logoId) else { return }
        diskLoadsInFlight.insert(logoId)

        Self.ioQueue.async { [weak self] in
            guard let self = self else { return }

            let filePath = self.cacheDirectory.appendingPathComponent("\(logoId).jpg")
            if let data = try? Data(contentsOf: filePath), let image = UIImage(data: data) {
                // Force-decode now (off the main thread) so the first on-screen draw is cheap.
                let decoded = image.preparingForDisplay() ?? image
                self.imageCache.setObject(decoded, forKey: logoId as NSString)
                DispatchQueue.main.async {
                    self.diskLoadsInFlight.remove(logoId)
                    self.objectWillChange.send()
                }
                return
            }

            // No disk copy — kick off a download / name search on the main thread, where
            // those helpers manage their own in-flight de-duplication and caches.
            DispatchQueue.main.async {
                self.diskLoadsInFlight.remove(logoId)
                let normalizedId = Store.normalizedId(from: storeName)
                if let urlString = self.logoURL(for: storeName) {
                    self.downloadAndCacheLogo(id: logoId, urlString: urlString, fallbackStoreName: storeName)
                } else {
                    self.triggerNameSearch(for: storeName, normalizedId: normalizedId)
                }
            }
        }
    }

    /// Downloads a logo image and writes it to both disk and memory cache.
    /// When `fallbackStoreName` is provided and the download fails (404 / bad data),
    /// automatically fires a Logo.dev Brand Search to find the correct domain.
    private func downloadAndCacheLogo(id: String, urlString: String, fallbackStoreName: String? = nil) {
        guard !downloadingLogos.contains(id), let url = URL(string: urlString) else { return }
        downloadingLogos.insert(id)

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.downloadingLogos.remove(id) } }

            // Treat non-200 responses (redirects to placeholder, 404, etc.) as failures
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data, error == nil, httpStatus == 200, let image = UIImage(data: data) else {
                #if DEBUG
                print("StoreLogoProvider: Failed to download logo for '\(id)' (HTTP \(httpStatus)): \(error?.localizedDescription ?? "bad data")")
                #endif
                // Fall back to name search so wrong guesses self-correct
                if let storeName = fallbackStoreName {
                    DispatchQueue.main.async {
                        self.triggerNameSearch(for: storeName, normalizedId: id)
                    }
                }
                return
            }

            // Write to disk
            let filePath = self.cacheDirectory.appendingPathComponent("\(id).jpg")
            try? data.write(to: filePath)

            // Update in-memory cache and notify UI. Force-decode off the main thread
            // (this runs on the URLSession background queue) so the first draw is cheap.
            let cacheKey = id as NSString
            self.imageCache.setObject(image.preparingForDisplay() ?? image, forKey: cacheKey)

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
                // The resolution caches were built against the old (possibly empty) data.
                self.invalidateResolutionCaches()

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
                        self.invalidateResolutionCaches()
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
                    self?.invalidateResolutionCaches()
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
        invalidateResolutionCaches()
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

    // MARK: - Logo.dev Auto-Logo

    /// Publishable token — safe to embed in client code; used for logo image URLs.
    private static let logoDevToken: String? = {
        guard let token = Bundle.main.infoDictionary?["LOGO_DEV_TOKEN"] as? String,
              !token.isEmpty,
              token != "YOUR_LOGO_DEV_PUBLISHABLE_TOKEN_HERE" else {
            return nil
        }
        return token
    }()

    /// Returns a Logo.dev image URL for a store using (in order):
    ///   1. Explicit domain map entry
    ///   2. "the-" prefix strip + re-check map
    ///   3. Prefix scan against the domain map (e.g. "walmart-supercenter" → walmart.com)
    ///   4. Suffix-stripping + domain map re-check (e.g. "chase-bank" → "chase" → in map)
    ///   5. Concatenated name guess (e.g. "zion-market" → zionmarket.com)
    ///   6. Single-word fallback (e.g. "starbucks" → starbucks.com)
    ///
    /// If none of these produce a URL the caller should fall through to `triggerNameSearch`
    /// which uses the Logo.dev Brand Search API (via the `logoBrandSearch` Cloud
    /// Function, which holds the secret key server-side) as the true catch-all.
    private func clearbitLogoURL(for normalizedId: String) -> String? {
        guard let token = Self.logoDevToken else {
            #if DEBUG
            print("StoreLogoProvider: Logo.dev token not configured — add LOGO_DEV_TOKEN to Secrets.xcconfig")
            #endif
            return nil
        }

        func logoURL(domain: String) -> String {
            "https://img.logo.dev/\(domain)?token=\(token)"
        }

        // 1. Explicit domain map
        if let domain = Self.storeDomains[normalizedId] {
            return logoURL(domain: domain)
        }

        // 2. Strip leading "the-" then re-check map
        //    "the-home-depot" → "home-depot" which is in the map
        let withoutThe = normalizedId.hasPrefix("the-") ? String(normalizedId.dropFirst(4)) : normalizedId
        if withoutThe != normalizedId {
            if let domain = Self.storeDomains[withoutThe] {
                return logoURL(domain: domain)
            }
        }

        // 3. Prefix scan — "walmart-supercenter" matches "walmart" → walmart.com
        //    Also run against the "the-" stripped version
        let candidates = withoutThe != normalizedId ? [normalizedId, withoutThe] : [normalizedId]
        for candidate in candidates {
            var bestPrefixMatch: (key: String, domain: String)?
            for (key, domain) in Self.storeDomains where candidate.hasPrefix(key) {
                if bestPrefixMatch == nil || key.count > bestPrefixMatch!.key.count {
                    bestPrefixMatch = (key, domain)
                }
            }
            if let match = bestPrefixMatch {
                return logoURL(domain: match.domain)
            }
        }

        // 4. Suffix-stripping — strip common business-type words and ONLY match against
        //    the domain map. Never blindly guess "{stripped}.com" since that produces wrong
        //    logos (e.g. "zion-market" → "zion.com" is wrong — Zion ≠ Zion Market).
        let businessSuffixes = [
            "-bank", "-banks", "-credit-union", "-financial", "-insurance", "-fcu",
            "-market", "-markets", "-supermarket", "-grocery", "-foods", "-food",
            "-pharmacy", "-drug", "-health",
            "-cafe", "-coffee", "-bakery", "-restaurant", "-grill", "-kitchen",
            "-bar", "-bistro", "-diner",
            "-store", "-stores", "-shop", "-shops", "-outlet", "-outlets",
            "-center", "-centre", "-depot", "-warehouse", "-wholesale", "-supply",
            "-express", "-plus", "-pro", "-co", "-inc",
        ]
        for suffix in businessSuffixes {
            if normalizedId.hasSuffix(suffix) {
                let stripped = String(normalizedId.dropLast(suffix.count))
                if !stripped.isEmpty, let domain = Self.storeDomains[stripped] {
                    return logoURL(domain: domain)
                }
            }
        }

        // 5. Concatenated name guess — join all parts into one word + ".com"
        //    "zion-market" → "zionmarket.com", "dollar-general" → "dollargeneral.com"
        //    This works for most businesses that use their full name as their domain.
        //    If the guess is wrong, downloadAndCacheLogo will detect the failure and
        //    automatically fall back to triggerNameSearch.
        let parts = normalizedId.split(separator: "-")
        if parts.count >= 2 && parts.count <= 4 {
            return logoURL(domain: parts.joined() + ".com")
        }

        // 6. Single-word fallback — "starbucks" → starbucks.com
        if !normalizedId.contains("-") && !normalizedId.isEmpty {
            return logoURL(domain: "\(normalizedId).com")
        }

        return nil
    }

    /// Resolves the domain for an unknown store name via the `logoBrandSearch`
    /// Cloud Function (which wraps the Logo.dev Brand Search API and holds the
    /// secret key server-side, so it never ships in the app binary), then caches
    /// the result to UserDefaults so this only ever fires once per store.
    private func triggerNameSearch(for storeName: String, normalizedId: String) {
        guard let token = Self.logoDevToken,
              !searchingStores.contains(normalizedId),
              searchedDomains[normalizedId] == nil else { return }

        searchingStores.insert(normalizedId)

        functions.httpsCallable("logoBrandSearch").call(["query": storeName]) { [weak self] result, error in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.searchingStores.remove(normalizedId) } }

            guard error == nil,
                  let data = result?.data as? [String: Any],
                  let domain = data["domain"] as? String,
                  !domain.isEmpty else {
                #if DEBUG
                print("StoreLogoProvider: Brand search failed for '\(storeName)': \(error?.localizedDescription ?? "no results")")
                #endif
                return
            }

            let logoURL = "https://img.logo.dev/\(domain)?token=\(token)"
            #if DEBUG
            print("StoreLogoProvider: Brand search found '\(domain)' for '\(storeName)'")
            #endif

            DispatchQueue.main.async {
                self.searchedDomains[normalizedId] = domain
                self.invalidateResolutionCaches()
                UserDefaults.standard.set(self.searchedDomains, forKey: Self.searchCacheKey)
                self.downloadAndCacheLogo(id: normalizedId, urlString: logoURL)
                self.objectWillChange.send()
            }
        }
    }

    /// Maps normalized store IDs to their canonical website domains so that
    /// Logo.dev can look up the right logo. Add entries here for any store whose
    /// domain doesn't match its normalized name (e.g. "trader-joes" → traderjoes.com).
    private static let storeDomains: [String: String] = [
        // Grocery & Supermarkets
        "walmart": "walmart.com",
        "walmart-neighborhood-market": "walmart.com",
        "walmart-supercenter": "walmart.com",
        "target": "target.com",
        "costco": "costco.com",
        "kroger": "kroger.com",
        "whole-foods": "wholefoodsmarket.com",
        "whole-foods-market": "wholefoodsmarket.com",
        "trader-joes": "traderjoes.com",
        "trader-joe": "traderjoes.com",
        "aldi": "aldi.us",
        "publix": "publix.com",
        "safeway": "safeway.com",
        "h-e-b": "heb.com",
        "heb": "heb.com",
        "meijer": "meijer.com",
        "vons": "vons.com",
        "ralphs": "ralphs.com",
        "albertsons": "albertsons.com",
        "sams-club": "samsclub.com",
        "bjs": "bjs.com",
        "bjs-wholesale": "bjs.com",
        "wegmans": "wegmans.com",
        "harris-teeter": "harristeeter.com",
        "food-lion": "foodlion.com",
        "winn-dixie": "winndixie.com",
        "stop-shop": "stopandshop.com",
        "giant": "giant.com",
        "hy-vee": "hy-vee.com",
        "sprouts": "sprouts.com",
        "sprouts-farmers-market": "sprouts.com",
        "fresh-market": "thefreshmarket.com",
        "fred-meyer": "fredmeyer.com",
        "king-soopers": "kingsoopers.com",
        "fry-s-food": "frysfood.com",
        "smiths": "smithsfoodanddrug.com",
        "winco-foods": "wincofoods.com",
        "grocery-outlet": "groceryoutlet.com",
        "natural-grocers": "naturalgrocers.com",
        "jewel-osco": "jewelosco.com",
        "mariano-s": "marianos.com",
        "lidl": "lidl.com",
        "hmart": "hmart.com",
        "h-mart": "hmart.com",
        "99-ranch-market": "99ranch.com",
        "99-ranch": "99ranch.com",
        "mitsuwa": "mitsuwa.com",
        "cardenas": "cardenasmarkets.com",
        "vallarta": "vallartasupermarkets.com",
        "shoprite": "shoprite.com",
        "acme": "acmemarkets.com",
        "price-chopper": "pricechopper.com",
        "stater-bros": "staterbros.com",
        "save-mart": "savemart.com",
        "pavilions": "pavilions.com",
        "amazon-fresh": "amazon.com",
        "whole-foods-365": "wholefoodsmarket.com",

        // Pharmacy & Drug Stores
        "walgreens": "walgreens.com",
        "cvs": "cvs.com",
        "rite-aid": "riteaid.com",
        "duane-reade": "duanereade.com",

        // Home Improvement
        "home-depot": "homedepot.com",
        "the-home-depot": "homedepot.com",
        "lowes": "lowes.com",
        "ace-hardware": "acehardware.com",
        "menards": "menards.com",
        "true-value": "truevalue.com",

        // Dollar / Discount Stores
        "dollar-general": "dollargeneral.com",
        "dollar-tree": "dollartree.com",
        "family-dollar": "familydollar.com",
        "five-below": "fivebelow.com",
        "big-lots": "biglots.com",
        "tuesday-morning": "tuesdaymorning.com",

        // Department & Clothing
        "macys": "macys.com",
        "macy-s": "macys.com",
        "nordstrom": "nordstrom.com",
        "nordstrom-rack": "nordstromrack.com",
        "kohls": "kohls.com",
        "kohl-s": "kohls.com",
        "marshalls": "marshalls.com",
        "tj-maxx": "tjmaxx.com",
        "ross": "rossstores.com",
        "burlington": "burlington.com",
        "old-navy": "oldnavy.com",
        "gap": "gap.com",
        "banana-republic": "bananarepublic.gap.com",
        "h-m": "hm.com",
        "zara": "zara.com",
        "uniqlo": "uniqlo.com",
        "express": "express.com",
        "forever-21": "forever21.com",
        "american-eagle": "ae.com",
        "abercrombie": "abercrombie.com",
        "hollister": "hollisterco.com",
        "urban-outfitters": "urbanoutfitters.com",
        "anthropologie": "anthropologie.com",
        "free-people": "freepeople.com",
        "j-crew": "jcrew.com",
        "loft": "anntaylor.com",
        "ann-taylor": "anntaylor.com",
        "chico-s": "chicos.com",
        "torrid": "torrid.com",
        "lane-bryant": "lanebryant.com",
        "victoria-s-secret": "victoriassecret.com",

        // Electronics
        "best-buy": "bestbuy.com",
        "apple": "apple.com",
        "microsoft": "microsoft.com",
        "micro-center": "microcenter.com",
        "fry-s-electronics": "frys.com",

        // Office / Craft / Hobby
        "staples": "staples.com",
        "office-depot": "officedepot.com",
        "officemax": "officemax.com",
        "michaels": "michaels.com",
        "hobby-lobby": "hobbylobby.com",
        "joann": "joann.com",
        "jo-ann": "joann.com",
        "ac-moore": "acmoore.com",

        // Pet Stores
        "petco": "petco.com",
        "petsmart": "petsmart.com",
        "pet-supplies-plus": "petsuppliesplus.com",

        // Sporting Goods
        "rei": "rei.com",
        "dick-s-sporting-goods": "dickssportinggoods.com",
        "dicks-sporting-goods": "dickssportinggoods.com",
        "bass-pro-shops": "basspro.com",
        "cabela-s": "cabelas.com",
        "academy": "academy.com",

        // Footwear
        "foot-locker": "footlocker.com",
        "finish-line": "finishline.com",
        "dsw": "dsw.com",
        "shoe-carnival": "shoecarnival.com",
        "payless": "payless.com",

        // Beauty
        "ulta": "ulta.com",
        "sephora": "sephora.com",
        "bath-body-works": "bathandbodyworks.com",
        "bed-bath-beyond": "bedbathandbeyond.com",

        // Athletic / Shoes
        "nike": "nike.com",
        "adidas": "adidas.com",
        "under-armour": "underarmour.com",
        "lululemon": "lululemon.com",
        "athleta": "athleta.gap.com",

        // Furniture / Home
        "ikea": "ikea.com",
        "homegoods": "homegoods.com",
        "home-goods": "homegoods.com",
        "world-market": "worldmarket.com",
        "crate-barrel": "crateandbarrel.com",
        "pottery-barn": "potterybarn.com",
        "williams-sonoma": "williams-sonoma.com",
        "restoration-hardware": "rh.com",
        "west-elm": "westelm.com",
        "cb2": "cb2.com",
        "pier-1": "pier1.com",

        // Auto
        "autozone": "autozone.com",
        "o-reilly-auto-parts": "oreillyauto.com",
        "advance-auto-parts": "advanceautoparts.com",
        "napa-auto-parts": "napaonline.com",
        "pep-boys": "pepboys.com",

        // Books / Music / Entertainment
        "barnes-noble": "barnesandnoble.com",
        "gamestop": "gamestop.com",

        // Convenience / Gas
        "7-eleven": "7-eleven.com",
        "wawa": "wawa.com",
        "sheetz": "sheetz.com",
        "circle-k": "circlek.com",
        "casey-s": "caseys.com",
        "kwik-trip": "kwiktrip.com",
        "buc-ee-s": "buc-ees.com",
        "racetrac": "racetrac.com",

        // Asian & Specialty Grocery
        "zion-market": "zionmarket.com",
        "seafood-city": "seafoodcity.com",
        "uwajimaya": "uwajimaya.com",
        "lotte-plaza": "lotteplaza.com",
        "marukai": "marukai.com",
        "nijiya": "nijiya.com",
        "ranch-99": "99ranch.com",
        "super-h-mart": "hmart.com",
        "patel-brothers": "patelbros.com",
        "india-bazaar": "indiabazaar.com",
        "fiesta-mart": "fiestamart.com",

        // Discount / Off-Price
        "99-cents-only": "99only.com",
        "99-cents-only-store": "99only.com",
        "99-cents-only-stores": "99only.com",
        "99-cent-store": "99only.com",
        "daiso": "daisojapan.com",
        "miniso": "miniso.com",
        "five-and-below": "fivebelow.com",

        // Online / General Retail
        "amazon": "amazon.com",
        "ebay": "ebay.com",
        "etsy": "etsy.com",

        // Coffee / Food Service
        "85c-bakery-cafe": "85cbakerycafe.com",
        "85c-bakery": "85cbakerycafe.com",
        "85c": "85cbakerycafe.com",
        "sunright-tea-studio": "snrtea.com",
        "sunright-tea": "snrtea.com",
        "sunright": "snrtea.com",
        "omomo-tea-shoppe": "omomoteashoppe.com",
        "omomo-tea": "omomoteashoppe.com",
        "omomo": "omomoteashoppe.com",
        "starbucks": "starbucks.com",
        "dunkin": "dunkindonuts.com",
        "dunkin-donuts": "dunkindonuts.com",
        "dutch-bros": "dutchbros.com",
        "dutch-bros-coffee": "dutchbros.com",
        "peet-s-coffee": "peets.com",
        "philz-coffee": "philzcoffee.com",
        "blue-bottle-coffee": "bluebottlecoffee.com",
        "tim-hortons": "timhortons.com",
        "coffee-bean": "coffeebean.com",
        "the-coffee-bean": "coffeebean.com",
        "trader-joes-wine-shop": "traderjoes.com",

        // Banks & Financial Institutions
        "chase": "chase.com",
        "chase-bank": "chase.com",
        "bank-of-america": "bankofamerica.com",
        "wells-fargo": "wellsfargo.com",
        "wells-fargo-bank": "wellsfargo.com",
        "citibank": "citi.com",
        "citi": "citi.com",
        "us-bank": "usbank.com",
        "td-bank": "td.com",
        "capital-one": "capitalone.com",
        "pnc-bank": "pnc.com",
        "pnc": "pnc.com",
        "truist": "truist.com",
        "truist-bank": "truist.com",
        "regions-bank": "regions.com",
        "regions": "regions.com",
        "fifth-third-bank": "53.com",
        "fifth-third": "53.com",
        "key-bank": "key.com",
        "keybank": "key.com",
        "huntington-bank": "huntington.com",
        "huntington": "huntington.com",
        "citizens-bank": "citizensbank.com",
        "ally-bank": "ally.com",
        "ally": "ally.com",
        "navy-federal": "navyfederal.org",
        "navy-federal-credit-union": "navyfederal.org",
        "usaa": "usaa.com",
        "bank-of-the-west": "bankofthewest.com",
        "bmo-harris": "bmoharris.com",
        "bmo": "bmo.com",
        "first-national-bank": "fnb-corp.com",
        "flagstar-bank": "flagstar.com",
        "goldman-sachs": "goldmansachs.com",
        "morgan-stanley": "morganstanley.com",
        "american-express": "americanexpress.com",
        "discover": "discover.com",
        "synchrony-bank": "synchrony.com",
        "comerica": "comerica.com",
        "svb": "svb.com",
        "charles-schwab": "schwab.com",
        "fidelity": "fidelity.com",
        "vanguard": "vanguard.com",
        "edward-jones": "edwardjones.com",

        // Fast Food / Quick Service Restaurants
        "mcdonalds": "mcdonalds.com",
        "mcdonald-s": "mcdonalds.com",
        "burger-king": "burgerking.com",
        "wendy-s": "wendys.com",
        "wendys": "wendys.com",
        "subway": "subway.com",
        "chipotle": "chipotle.com",
        "chipotle-mexican-grill": "chipotle.com",
        "taco-bell": "tacobell.com",
        "pizza-hut": "pizzahut.com",
        "domino-s": "dominos.com",
        "dominos": "dominos.com",
        "papa-john-s": "papajohns.com",
        "papa-johns": "papajohns.com",
        "little-caesars": "littlecaesars.com",
        "kfc": "kfc.com",
        "chick-fil-a": "chick-fil-a.com",
        "panda-express": "pandaexpress.com",
        "five-guys": "fiveguys.com",
        "shake-shack": "shakeshack.com",
        "in-n-out": "in-n-out.com",
        "in-n-out-burger": "in-n-out.com",
        "whataburger": "whataburger.com",
        "sonic": "sonicdrivein.com",
        "sonic-drive-in": "sonicdrivein.com",
        "dairy-queen": "dairyqueen.com",
        "jack-in-the-box": "jackinthebox.com",
        "del-taco": "deltaco.com",
        "carl-s-jr": "carlsjr.com",
        "hardee-s": "hardees.com",
        "popeyes": "popeyes.com",
        "raising-cane-s": "raisingcanes.com",
        "raising-canes": "raisingcanes.com",
        "wingstop": "wingstop.com",
        "buffalo-wild-wings": "buffalowildwings.com",
        "cook-out": "cookout.com",
        "smashburger": "smashburger.com",
        "habit-burger": "habitburger.com",
        "the-habit-burger-grill": "habitburger.com",

        // Casual / Fast-Casual Dining
        "panera": "panerabread.com",
        "panera-bread": "panerabread.com",
        "olive-garden": "olivegarden.com",
        "applebee-s": "applebees.com",
        "applebees": "applebees.com",
        "chili-s": "chilis.com",
        "chilis": "chilis.com",
        "red-robin": "redrobin.com",
        "red-lobster": "redlobster.com",
        "outback-steakhouse": "outback.com",
        "texas-roadhouse": "texasroadhouse.com",
        "longhorn-steakhouse": "longhornsteakhouse.com",
        "ihop": "ihop.com",
        "denny-s": "dennys.com",
        "dennys": "dennys.com",
        "waffle-house": "wafflehouse.com",
        "cracker-barrel": "crackerbarrel.com",
        "bob-evans": "bobevans.com",
        "first-watch": "firstwatch.com",
        "the-cheesecake-factory": "thecheesecakefactory.com",
        "cheesecake-factory": "thecheesecakefactory.com",
        "bj-s-restaurants": "bjsrestaurants.com",
        "sweetgreen": "sweetgreen.com",
        "cava": "cava.com",
        "mod-pizza": "modpizza.com",
        "jersey-mike-s": "jerseymikes.com",
        "jersey-mikes": "jerseymikes.com",
        "jimmy-john-s": "jimmyjohns.com",
        "jimmy-johns": "jimmyjohns.com",
        "firehouse-subs": "firehousesubs.com",
        "potbelly": "potbelly.com",
        "jason-s-deli": "jasonsdeli.com",
        "which-wich": "whichwich.com",
        "einstein-bros": "einsteinbros.com",
        "einstein-bros-bagels": "einsteinbros.com",
        "bruegger-s-bagels": "brueggers.com",
        "crumbl-cookies": "crumblcookies.com",
        "crumbl": "crumblcookies.com",
        "nothing-bundt-cakes": "nothingbundtcakes.com",
        "jamba": "jamba.com",
        "jamba-juice": "jamba.com",
        "tropical-smoothie-cafe": "tropicalsmoothiecafe.com",
        "smoothie-king": "smoothieking.com",
        "moe-s-southwest-grill": "moes.com",
        "qdoba": "qdoba.com",
        "el-pollo-loco": "elpolloloco.com",
        "bojangles": "bojangles.com",
        "zaxby-s": "zaxbys.com",
        "culver-s": "culvers.com",
        "steak-n-shake": "steaknshake.com",
        "freddy-s": "freddys.com",
        "noodles-company": "noodles.com",
        "pei-wei": "peiwei.com",
    ]

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
