//
//  MembershipCard.swift
//  Geolocation_v1.0.0
//
//  Created on 7/27/26.
//

import Foundation
import UIKit

/// Barcode symbologies the app can render from a typed-in membership number.
///
/// UPC-A and EAN-13 come first because that's what retail loyalty cards
/// overwhelmingly carry, and the symbology matters as much as the digits: a
/// register scanning a UPC-A member number will not accept the same digits
/// encoded as Code 128. Core Image can't generate the EAN family, so those two
/// are drawn by `RetailBarcode`; the rest come from Core Image.
enum BarcodeSymbology: String, Codable, CaseIterable, Identifiable {
    case upcA
    case ean13
    case code128
    case qr
    case pdf417
    case aztec

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upcA: return "UPC-A"
        case .ean13: return "EAN-13"
        case .code128: return "Code 128"
        case .qr: return "QR Code"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        }
    }

    var detail: String {
        switch self {
        case .upcA: return "12 digits — most US store loyalty cards"
        case .ean13: return "13 digits — most non-US loyalty cards"
        case .code128: return "Letters and digits, any length"
        case .qr: return "Square code, scanned by camera"
        case .pdf417: return "Wide stacked code (some IDs/passes)"
        case .aztec: return "Square code (transit, some passes)"
        }
    }

    /// Linear (1D) symbologies render wide and short; 2D codes render square.
    var isLinear: Bool {
        switch self {
        case .upcA, .ean13, .code128: return true
        case .qr, .pdf417, .aztec: return false
        }
    }

    /// The EAN family, drawn by `RetailBarcode` rather than Core Image.
    var retailKind: RetailBarcode.Kind? {
        switch self {
        case .upcA: return .upcA
        case .ean13: return .ean13
        default: return nil
        }
    }

    /// Code 128 can only encode ASCII. The 2D formats take arbitrary text.
    var requiresASCII: Bool { self == .code128 }

    /// The format that matches what the user typed, used when a card is left on
    /// automatic. Falls back to Code 128, which encodes anything printable.
    static func detected(for value: String) -> BarcodeSymbology {
        guard let kind = RetailBarcode.detectedKind(for: value) else { return .code128 }
        switch kind {
        case .upcA: return .upcA
        case .ean13: return .ean13
        }
    }
}

/// A membership / loyalty card the user saved for a store.
///
/// A card can carry a photo of the physical card's barcode, a membership number
/// the app renders into a barcode, or both — the sheet prefers the photo when
/// present since that's a literal capture of what the scanner expects.
struct MembershipCard: Codable, Equatable {
    /// `Store.normalizedId(from:)` of the store this card belongs to, so the
    /// card follows the retailer rather than one particular user_store row.
    let storeId: String
    var storeName: String
    /// Membership number as typed by the user. Empty for photo-only cards.
    var number: String
    var symbology: BarcodeSymbology
    /// Whether the format is derived from the number rather than chosen by the
    /// user. Optional so cards saved before this existed decode as `nil` and
    /// pick up automatic detection.
    var autoFormat: Bool?
    /// File name (not a full path) of the photo inside the cards directory.
    /// Paths aren't stored because the container path changes between installs.
    var imageFileName: String?
    var updatedAt: Date

    var trimmedNumber: String {
        number.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasNumber: Bool { !trimmedNumber.isEmpty }
    var hasImage: Bool { imageFileName != nil }
    var isEmpty: Bool { !hasNumber && !hasImage }

    var usesAutoFormat: Bool { autoFormat ?? true }

    /// The symbology to actually render with: detected from the number unless
    /// the user pinned a format explicitly.
    var effectiveSymbology: BarcodeSymbology {
        guard usesAutoFormat, hasNumber else { return symbology }
        return BarcodeSymbology.detected(for: trimmedNumber)
    }

    /// The number grouped the way the card prints it, for reading aloud or
    /// typing in at the register when the barcode won't scan.
    var formattedNumber: String {
        guard let digits = RetailBarcode.digits(in: trimmedNumber),
              digits.count == trimmedNumber.filter({ !$0.isWhitespace && $0 != "-" }).count else {
            return trimmedNumber
        }
        let text = digits.map(String.init).joined()
        switch digits.count {
        case 12:
            return stride(from: 0, to: 12, by: 3)
                .map { String(text.dropFirst($0).prefix(3)) }
                .joined(separator: " ")
        case 13:
            return "\(text.prefix(1)) \(text.dropFirst().prefix(6)) \(text.suffix(6))"
        default:
            return trimmedNumber
        }
    }
}

/// Device-local storage for membership cards.
///
/// Cards are deliberately **not** synced to Firestore. A store can be shared
/// with friends and family, and everything the app writes against a store is
/// visible to everyone it's shared with — a membership number is personal, so
/// it stays on the device that entered it. Metadata lives in `UserDefaults`;
/// card photos are written as JPEGs into Application Support.
class MembershipCardStore: ObservableObject {
    static let shared = MembershipCardStore()

    /// normalizedStoreId -> card
    @Published private(set) var cards: [String: MembershipCard] = [:]

    private static let defaultsKey = "MembershipCardStore.cards"
    private let imageCache = NSCache<NSString, UIImage>()

    private let cardsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MembershipCards", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        load()
    }

    // MARK: - Lookup

    func storeId(for storeName: String) -> String {
        Store.normalizedId(from: storeName)
    }

    func card(forStoreNamed storeName: String) -> MembershipCard? {
        cards[storeId(for: storeName)]
    }

    /// The saved photo for a card, decoded once and cached in memory.
    func image(for card: MembershipCard) -> UIImage? {
        guard let fileName = card.imageFileName else { return nil }
        if let cached = imageCache.object(forKey: fileName as NSString) {
            return cached
        }
        let url = cardsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            return nil
        }
        imageCache.setObject(image, forKey: fileName as NSString)
        return image
    }

    // MARK: - Mutation

    /// Save (or clear) the typed membership number and its barcode format,
    /// leaving any saved photo untouched. `symbology` is ignored while
    /// `autoFormat` is on — the format is then derived from the number.
    func saveNumber(
        _ number: String,
        symbology: BarcodeSymbology,
        autoFormat: Bool,
        forStoreNamed storeName: String
    ) {
        let id = storeId(for: storeName)
        var card = cards[id] ?? MembershipCard(
            storeId: id,
            storeName: storeName,
            number: "",
            symbology: symbology,
            autoFormat: autoFormat,
            imageFileName: nil,
            updatedAt: Date()
        )
        card.storeName = storeName
        card.number = number.trimmingCharacters(in: .whitespacesAndNewlines)
        card.symbology = symbology
        card.autoFormat = autoFormat
        card.updatedAt = Date()

        if card.isEmpty {
            delete(forStoreNamed: storeName)
        } else {
            cards[id] = card
            persist()
        }
    }

    /// Save a photo of the physical card, replacing any previous one.
    func saveImage(_ image: UIImage, forStoreNamed storeName: String) {
        let id = storeId(for: storeName)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }

        let fileName = "\(id)-\(UUID().uuidString).jpg"
        let url = cardsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("MembershipCardStore: failed to write card image: \(error.localizedDescription)")
            #endif
            return
        }

        var card = cards[id] ?? MembershipCard(
            storeId: id,
            storeName: storeName,
            number: "",
            symbology: .code128,
            autoFormat: true,
            imageFileName: nil,
            updatedAt: Date()
        )
        let previousFileName = card.imageFileName
        card.storeName = storeName
        card.imageFileName = fileName
        card.updatedAt = Date()
        cards[id] = card
        persist()

        if let previousFileName { deleteImageFile(previousFileName) }
        imageCache.setObject(image, forKey: fileName as NSString)
    }

    /// Remove just the photo, keeping a typed number if there is one.
    func removeImage(forStoreNamed storeName: String) {
        let id = storeId(for: storeName)
        guard var card = cards[id], let fileName = card.imageFileName else { return }
        card.imageFileName = nil
        card.updatedAt = Date()

        if card.isEmpty {
            cards.removeValue(forKey: id)
        } else {
            cards[id] = card
        }
        persist()
        deleteImageFile(fileName)
    }

    /// Remove the whole card — number, format and photo.
    func delete(forStoreNamed storeName: String) {
        let id = storeId(for: storeName)
        guard let card = cards.removeValue(forKey: id) else { return }
        persist()
        if let fileName = card.imageFileName { deleteImageFile(fileName) }
    }

    // MARK: - Persistence

    private func deleteImageFile(_ fileName: String) {
        imageCache.removeObject(forKey: fileName as NSString)
        try? FileManager.default.removeItem(at: cardsDirectory.appendingPathComponent(fileName))
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else { return }
        do {
            cards = try JSONDecoder().decode([String: MembershipCard].self, from: data)
        } catch {
            #if DEBUG
            print("MembershipCardStore: failed to decode saved cards: \(error.localizedDescription)")
            #endif
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(cards)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        } catch {
            #if DEBUG
            print("MembershipCardStore: failed to encode cards: \(error.localizedDescription)")
            #endif
        }
    }
}
