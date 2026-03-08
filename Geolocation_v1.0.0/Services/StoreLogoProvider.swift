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
    /// First tries Firebase (exact/prefix/canonical match), then falls back to
    /// the Clearbit Logo API using the built-in domain map (no API key required).
    func logoURL(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)
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

        // 2. Clearbit auto-logo fallback
        if let url = clearbitLogoURL(for: normalizedId) {
            #if DEBUG
            print("StoreLogoProvider: Using Clearbit fallback for '\(normalizedId)': \(url)")
            #endif
            return url
        }

        #if DEBUG
        print("StoreLogoProvider: No logo match for ID: \(normalizedId) (canonical: \(canonicalLogoKey(normalizedId)))")
        #endif
        return nil
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

        // 3. No cache hit — trigger background download if we have any URL
        //    (logoURL covers both Firebase and Clearbit fallback)
        if let urlString = logoURL(for: storeName) {
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

    // MARK: - Clearbit Auto-Logo

    /// Returns a Clearbit Logo API URL for a store, or nil if neither the domain
    /// map nor a reasonable domain guess yields a supported store.
    ///
    /// Clearbit's free Logo API (`https://logo.clearbit.com/{domain}`) returns a
    /// high-quality square PNG for the company — no API key required.
    private func clearbitLogoURL(for normalizedId: String) -> String? {
        // 1. Explicit domain mapping (covers non-obvious domains and alternate names)
        if let domain = Self.storeDomains[normalizedId] {
            return "https://logo.clearbit.com/\(domain)"
        }

        // 2. Prefix scan so "walmart-supercenter" matches "walmart" → walmart.com
        var bestMatch: (key: String, domain: String)?
        for (key, domain) in Self.storeDomains {
            if normalizedId.hasPrefix(key) {
                if bestMatch == nil || key.count > bestMatch!.key.count {
                    bestMatch = (key, domain)
                }
            }
        }
        if let match = bestMatch {
            return "https://logo.clearbit.com/\(match.domain)"
        }

        // 3. Generic guess: strip hyphens and append .com (works for simple brand names)
        //    Only attempt this when the normalized ID looks like a single brand word
        //    (no hyphens = unlikely to be a multi-word variant like "target-express").
        if !normalizedId.contains("-") && !normalizedId.isEmpty {
            return "https://logo.clearbit.com/\(normalizedId).com"
        }

        return nil
    }

    /// Maps normalized store IDs to their canonical website domains so that
    /// Clearbit can look up the right logo. Add entries here for any store whose
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
        "tuesday-morning": "tuesdaymorning.com",

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

        // Online / General Retail
        "amazon": "amazon.com",

        // Coffee / Food
        "starbucks": "starbucks.com",
        "dunkin": "dunkindonuts.com",
        "dunkin-donuts": "dunkindonuts.com",
        "trader-joes-wine-shop": "traderjoes.com",
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
