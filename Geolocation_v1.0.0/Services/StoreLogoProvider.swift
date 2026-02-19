//
//  StoreLogoProvider.swift
//  Geolocation_v1.0.0
//
//  Created on 2/19/26.
//

import Foundation
import FirebaseFirestore

/// Provides store logo URLs by matching normalized store names against a database.
///
/// Logo sources (in priority order):
/// 1. Firestore `store_logos` collection (admin-managed)
/// 2. Built-in defaults for common stores
///
/// Firestore document structure:
///   Collection: `store_logos`
///   Document ID: normalized store name (e.g., "walmart", "trader-joes")
///   Fields: { "logoURL": "https://..." }
class StoreLogoProvider: ObservableObject {
    static let shared = StoreLogoProvider()

    private let db = Firestore.firestore()
    @Published private(set) var storeLogos: [String: String] = [:] // normalizedId -> logoURL
    private var hasFetched = false

    private init() {
        // Start with built-in defaults
        storeLogos = Self.builtInLogos
        fetchStoreLogos()
    }

    /// Look up a logo URL for a store name
    func logoURL(for storeName: String) -> String? {
        let normalizedId = Store.normalizedId(from: storeName)
        return storeLogos[normalizedId]
    }

    /// Fetch logo mappings from Firestore and merge with built-in defaults
    func fetchStoreLogos() {
        guard !hasFetched else { return }

        db.collection("store_logos").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("StoreLogoProvider: Error fetching logos: \(error.localizedDescription)")
                #endif
                // Built-in defaults are still available
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                #if DEBUG
                print("StoreLogoProvider: No store logos in Firestore, using built-in defaults")
                #endif
                self.hasFetched = true
                return
            }

            var merged = Self.builtInLogos
            for doc in documents {
                let data = doc.data()
                if let logoURL = data["logoURL"] as? String {
                    // Firestore entries override built-in defaults
                    merged[doc.documentID] = logoURL
                }
            }

            DispatchQueue.main.async {
                self.storeLogos = merged
                self.hasFetched = true
                #if DEBUG
                print("StoreLogoProvider: Loaded \(documents.count) logos from Firestore, \(merged.count) total")
                #endif
            }
        }
    }

    // MARK: - Built-in Store Logos

    /// Default logo URLs for common US retail stores.
    /// These use the Clearbit Logo API (https://logo.clearbit.com).
    /// Admins can override any of these by adding entries to the Firestore `store_logos` collection.
    static let builtInLogos: [String: String] = [
        // Grocery
        "walmart": "https://logo.clearbit.com/walmart.com",
        "target": "https://logo.clearbit.com/target.com",
        "costco": "https://logo.clearbit.com/costco.com",
        "kroger": "https://logo.clearbit.com/kroger.com",
        "whole-foods": "https://logo.clearbit.com/wholefoodsmarket.com",
        "whole-foods-market": "https://logo.clearbit.com/wholefoodsmarket.com",
        "trader-joes": "https://logo.clearbit.com/traderjoes.com",
        "aldi": "https://logo.clearbit.com/aldi.us",
        "publix": "https://logo.clearbit.com/publix.com",
        "safeway": "https://logo.clearbit.com/safeway.com",
        "h-e-b": "https://logo.clearbit.com/heb.com",
        "heb": "https://logo.clearbit.com/heb.com",
        "meijer": "https://logo.clearbit.com/meijer.com",
        "winco-foods": "https://logo.clearbit.com/wincofoods.com",
        "food-lion": "https://logo.clearbit.com/foodlion.com",
        "stop-and-shop": "https://logo.clearbit.com/stopandshop.com",
        "giant": "https://logo.clearbit.com/giantfood.com",
        "wegmans": "https://logo.clearbit.com/wegmans.com",
        "sprouts": "https://logo.clearbit.com/sprouts.com",
        "sprouts-farmers-market": "https://logo.clearbit.com/sprouts.com",

        // Warehouse / Club
        "sams-club": "https://logo.clearbit.com/samsclub.com",
        "bjs": "https://logo.clearbit.com/bjs.com",
        "bjs-wholesale-club": "https://logo.clearbit.com/bjs.com",

        // Pharmacy / Convenience
        "walgreens": "https://logo.clearbit.com/walgreens.com",
        "cvs": "https://logo.clearbit.com/cvs.com",
        "cvs-pharmacy": "https://logo.clearbit.com/cvs.com",
        "rite-aid": "https://logo.clearbit.com/riteaid.com",
        "7-eleven": "https://logo.clearbit.com/7-eleven.com",

        // Home Improvement
        "home-depot": "https://logo.clearbit.com/homedepot.com",
        "the-home-depot": "https://logo.clearbit.com/homedepot.com",
        "lowes": "https://logo.clearbit.com/lowes.com",
        "menards": "https://logo.clearbit.com/menards.com",
        "ace-hardware": "https://logo.clearbit.com/acehardware.com",

        // Dollar / Discount
        "dollar-general": "https://logo.clearbit.com/dollargeneral.com",
        "dollar-tree": "https://logo.clearbit.com/dollartree.com",
        "five-below": "https://logo.clearbit.com/fivebelow.com",

        // Department / General
        "macys": "https://logo.clearbit.com/macys.com",
        "nordstrom": "https://logo.clearbit.com/nordstrom.com",
        "kohls": "https://logo.clearbit.com/kohls.com",
        "jcpenney": "https://logo.clearbit.com/jcpenney.com",
        "marshalls": "https://logo.clearbit.com/marshalls.com",
        "tj-maxx": "https://logo.clearbit.com/tjmaxx.com",
        "ross": "https://logo.clearbit.com/rossstores.com",
        "burlington": "https://logo.clearbit.com/burlington.com",

        // Electronics / Tech
        "best-buy": "https://logo.clearbit.com/bestbuy.com",
        "apple": "https://logo.clearbit.com/apple.com",
        "apple-store": "https://logo.clearbit.com/apple.com",
        "microcenter": "https://logo.clearbit.com/microcenter.com",

        // Pet
        "petco": "https://logo.clearbit.com/petco.com",
        "petsmart": "https://logo.clearbit.com/petsmart.com",

        // Sporting / Outdoor
        "dicks-sporting-goods": "https://logo.clearbit.com/dickssportinggoods.com",
        "rei": "https://logo.clearbit.com/rei.com",
        "academy-sports": "https://logo.clearbit.com/academy.com",

        // Office
        "staples": "https://logo.clearbit.com/staples.com",
        "office-depot": "https://logo.clearbit.com/officedepot.com",

        // Auto
        "autozone": "https://logo.clearbit.com/autozone.com",
        "oreilly-auto-parts": "https://logo.clearbit.com/oreillyauto.com",

        // Craft / Hobby
        "michaels": "https://logo.clearbit.com/michaels.com",
        "hobby-lobby": "https://logo.clearbit.com/hobbylobby.com",
        "joann": "https://logo.clearbit.com/joann.com",

        // Furniture / Home
        "ikea": "https://logo.clearbit.com/ikea.com",
        "bed-bath-and-beyond": "https://logo.clearbit.com/bedbathandbeyond.com",
        "pier-1": "https://logo.clearbit.com/pier1.com",

        // Clothing
        "old-navy": "https://logo.clearbit.com/oldnavy.com",
        "gap": "https://logo.clearbit.com/gap.com",
        "handom": "https://logo.clearbit.com/hm.com",
        "handm": "https://logo.clearbit.com/hm.com",
        "zara": "https://logo.clearbit.com/zara.com",
        "uniqlo": "https://logo.clearbit.com/uniqlo.com",
        "nike": "https://logo.clearbit.com/nike.com",

        // Big Box
        "amazon-fresh": "https://logo.clearbit.com/amazon.com",
        "amazon": "https://logo.clearbit.com/amazon.com",

        // Wholesale / Asian grocery
        "hmart": "https://logo.clearbit.com/hmart.com",
        "h-mart": "https://logo.clearbit.com/hmart.com",
        "99-ranch-market": "https://logo.clearbit.com/99ranch.com",
        "mitsuwa": "https://logo.clearbit.com/mitsuwa.com",
    ]
}
