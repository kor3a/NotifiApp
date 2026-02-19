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
/// 1. Logos are stored in Firebase Storage under `store_logos/{normalizedId}.jpg`
/// 2. Download URLs are cached in Firestore `store_logos` collection
/// 3. The app fetches from Firestore on launch and caches in memory
/// 4. When a store name matches a known logo, the logo is displayed
///
/// ## Adding logos
/// Call `uploadStoreLogo(storeName:image:)` to upload a logo for a store.
/// This uploads the image to Firebase Storage and saves the URL to Firestore.
///
/// ## Firestore document structure
///   Collection: `store_logos`
///   Document ID: normalized store name (e.g., "walmart", "trader-joes")
///   Fields: { "logoURL": "https://firebasestorage.googleapis.com/..." }
class StoreLogoProvider: ObservableObject {
    static let shared = StoreLogoProvider()

    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    @Published private(set) var storeLogos: [String: String] = [:] // normalizedId -> logoURL
    private var hasFetched = false

    private init() {
        fetchStoreLogos()
    }

    /// Look up a logo URL for a store name.
    /// First tries an exact match on the normalized ID, then checks if the
    /// normalized name starts with any known store key (e.g., "walmart-supercenter" matches "walmart").
    func logoURL(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)

        // Exact match
        if let url = storeLogos[normalizedId] {
            return url
        }

        // Prefix match: find the longest key that the normalized name starts with.
        // E.g., "walmart-supercenter" starts with "walmart"
        var bestMatch: (key: String, url: String)?
        for (key, url) in storeLogos {
            if normalizedId.hasPrefix(key) {
                if bestMatch == nil || key.count > bestMatch!.key.count {
                    bestMatch = (key, url)
                }
            }
        }
        return bestMatch?.url
    }

    /// Fetch logo mappings from Firestore
    func fetchStoreLogos() {
        guard !hasFetched else { return }

        db.collection("store_logos").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("StoreLogoProvider: Error fetching logos: \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                #if DEBUG
                print("StoreLogoProvider: No store logos in Firestore yet")
                #endif
                self.hasFetched = true
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
                #if DEBUG
                print("StoreLogoProvider: Loaded \(logos.count) store logos from Firestore")
                #endif
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

        let logoRef = storage.child("store_logos/\(normalizedId).jpg")
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
                self.db.collection("store_logos").document(normalizedId).setData([
                    "logoURL": downloadURL
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    // Update local cache
                    DispatchQueue.main.async {
                        self.storeLogos[normalizedId] = downloadURL
                    }

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

        let logoRef = storage.child("store_logos/\(normalizedId).jpg")
        logoRef.delete { [weak self] error in
            // Continue even if Storage delete fails (file might not exist)
            if let error = error {
                #if DEBUG
                print("StoreLogoProvider: Storage delete warning: \(error.localizedDescription)")
                #endif
            }

            self?.db.collection("store_logos").document(normalizedId).delete { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                DispatchQueue.main.async {
                    self?.storeLogos.removeValue(forKey: normalizedId)
                }
                completion(.success(()))
            }
        }
    }

    /// Force refresh logos from Firestore
    func refreshLogos() {
        hasFetched = false
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
