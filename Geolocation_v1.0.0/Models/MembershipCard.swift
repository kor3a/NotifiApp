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

/// Storage for membership cards, kept on the device but outliving the app.
///
/// Cards are deliberately **not** synced to Firestore. A store can be shared
/// with friends and family, and everything the app writes against a store is
/// visible to everyone it's shared with — a membership number is personal, so
/// it stays on the device that entered it.
///
/// The working copies live in the app container: metadata in `UserDefaults`,
/// card photos as JPEGs in Application Support. iOS deletes that whole
/// container when the app is deleted, so every card is also mirrored into the
/// keychain, which survives a delete and reinstall of the same app. On launch
/// the two are merged, and anything the container lost is written back from the
/// keychain — a reinstalled app finds its cards already there.
///
/// The keychain copy of a photo is downscaled (see `backupPhotoData(from:)`):
/// the keychain is meant for small items, and a barcode still scans at that
/// size. Nothing else about a card is lossy.
class MembershipCardStore: ObservableObject {
    static let shared = MembershipCardStore()

    /// normalizedStoreId -> card
    @Published private(set) var cards: [String: MembershipCard] = [:]

    private static let defaultsKey = "MembershipCardStore.cards"

    /// Keychain namespace and account names for the reinstall-proof copy. The
    /// metadata is one JSON item and each photo is its own item, so a photo
    /// that fails to store never takes the membership numbers down with it.
    private static let keychainService = "com.kor3a.nearbuy.membershipCards"
    private static let metadataAccount = "cards.metadata"
    private static let photoAccountPrefix = "photo."

    /// Upper bound for a photo's keychain copy. The keychain is not a file
    /// store; large items make every read slower and can be rejected outright.
    private static let maxBackupPhotoBytes = 600_000

    private let keychain = KeychainStore(service: MembershipCardStore.keychainService)
    /// Keychain and file writes are serialized off the main thread so saving a
    /// card never blocks a scan the user is trying to show at the register.
    private let backupQueue = DispatchQueue(label: "com.kor3a.nearbuy.membershipCardBackup")
    private let imageCache = NSCache<NSString, UIImage>()

    /// Set when the launch-time keychain read failed, so nothing overwrites a
    /// backup that was merely unreadable at the time.
    private var backupUnavailable = false

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
        backUpPhoto(image, fileName: fileName)

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

    /// Remove the whole card — number, format and photo. This is the user
    /// asking for the card to be gone, so the keychain copy goes too; otherwise
    /// a reinstall would resurrect a card they deleted on purpose.
    func delete(forStoreNamed storeName: String) {
        let id = storeId(for: storeName)
        guard let card = cards.removeValue(forKey: id) else { return }
        persist()
        if let fileName = card.imageFileName { deleteImageFile(fileName) }
    }

    // MARK: - Persistence

    /// Deleting a photo removes both the working file and its keychain copy —
    /// every caller is acting on the user replacing or removing that photo.
    private func deleteImageFile(_ fileName: String) {
        imageCache.removeObject(forKey: fileName as NSString)
        try? FileManager.default.removeItem(at: cardsDirectory.appendingPathComponent(fileName))
        let account = Self.photoAccountPrefix + fileName
        backupQueue.async { [keychain = self.keychain] in
            try? keychain.removeItem(account: account)
        }
    }

    private func persist() {
        persistToDefaults()
        backUpMetadata()
    }

    private func persistToDefaults() {
        do {
            let data = try JSONEncoder().encode(cards)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        } catch {
            #if DEBUG
            print("MembershipCardStore: failed to encode cards: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Loading

    /// Merge what the app container still has with what the keychain kept.
    ///
    /// After a normal launch the two agree and this is a no-op. After a
    /// reinstall the container is empty and every card comes back from the
    /// keychain; after an update from a build that predates the keychain copy,
    /// the container is the one with the cards and it seeds the backup.
    private func load() {
        let local = decodeCards(UserDefaults.standard.data(forKey: Self.defaultsKey))

        let backedUp: [String: MembershipCard]
        do {
            backedUp = decodeCards(try keychain.data(account: Self.metadataAccount))
            backupUnavailable = false
        } catch {
            // The keychain couldn't be read — a background launch before the
            // device's first unlock, most likely. Use what's in the container
            // and leave the backup alone rather than overwriting a copy we
            // can't see; `reloadIfBackupWasUnavailable()` picks it up later.
            #if DEBUG
            print("MembershipCardStore: keychain unavailable: \(error.localizedDescription)")
            #endif
            backupUnavailable = true
            cards = local
            return
        }

        cards = merged(local: local, backedUp: backedUp)
        if cards != local { persistToDefaults() }

        restoreMissingPhotos()
        backUpMetadata()
        reconcilePhotoBackups()
    }

    /// Retry the merge when the keychain was unreadable at launch. Call it from
    /// anywhere the user is about to look at a card; it does nothing in the
    /// normal case, where the launch read succeeded.
    func reloadIfBackupWasUnavailable() {
        guard backupUnavailable else { return }
        load()
    }

    private func decodeCards(_ data: Data?) -> [String: MembershipCard] {
        guard let data else { return [:] }
        do {
            return try JSONDecoder().decode([String: MembershipCard].self, from: data)
        } catch {
            #if DEBUG
            print("MembershipCardStore: failed to decode saved cards: \(error.localizedDescription)")
            #endif
            return [:]
        }
    }

    /// Cards from both copies, most recently edited wins. Nothing is dropped:
    /// a card present in only one copy is kept.
    private func merged(
        local: [String: MembershipCard],
        backedUp: [String: MembershipCard]
    ) -> [String: MembershipCard] {
        var result = local
        for (id, backup) in backedUp {
            guard let current = result[id] else {
                result[id] = backup
                continue
            }
            if backup.updatedAt > current.updatedAt {
                result[id] = backup
            }
        }
        return result
    }

    // MARK: - Keychain backup

    private func backUpMetadata() {
        // Writing now would replace a backup this launch never managed to
        // read. The next successful `load()` merges and backs up instead.
        guard !backupUnavailable else { return }
        let snapshot = cards
        backupQueue.async { [keychain = self.keychain] in
            do {
                let data = try JSONEncoder().encode(snapshot)
                try keychain.set(data, account: MembershipCardStore.metadataAccount)
            } catch {
                #if DEBUG
                print("MembershipCardStore: failed to back up cards: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func backUpPhoto(_ image: UIImage, fileName: String) {
        backupQueue.async { [keychain = self.keychain] in
            guard let data = MembershipCardStore.backupPhotoData(from: image) else {
                #if DEBUG
                print("MembershipCardStore: card photo too large to back up")
                #endif
                return
            }
            try? keychain.set(data, account: MembershipCardStore.photoAccountPrefix + fileName)
        }
    }

    /// Bring the keychain's photo items in line with the cards on disk: back up
    /// photos it doesn't have yet — cards saved by a build that predates this
    /// backup, or a photo whose earlier write failed — and drop items no card
    /// points at any more, so the keychain doesn't grow forever.
    private func reconcilePhotoBackups() {
        let fileNames = cards.values.compactMap(\.imageFileName)
        let directory = cardsDirectory

        backupQueue.async { [keychain = self.keychain] in
            let existing = Set((try? keychain.accounts()) ?? [])
            var wanted: Set<String> = []

            for fileName in fileNames {
                let account = MembershipCardStore.photoAccountPrefix + fileName
                wanted.insert(account)
                guard !existing.contains(account) else { continue }
                guard let image = UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path),
                      let data = MembershipCardStore.backupPhotoData(from: image) else { continue }
                try? keychain.set(data, account: account)
            }

            let orphans = existing
                .filter { $0.hasPrefix(MembershipCardStore.photoAccountPrefix) }
                .subtracting(wanted)
            for account in orphans {
                try? keychain.removeItem(account: account)
            }
        }
    }

    /// A JPEG small enough to belong in the keychain. Returns `nil` when even
    /// the most aggressive pass is too big, in which case the card's number and
    /// format are still backed up and only the photo is left behind.
    private static func backupPhotoData(from image: UIImage) -> Data? {
        let attempts: [(maxDimension: CGFloat, quality: CGFloat)] = [
            (1400, 0.7), (1000, 0.6), (700, 0.5)
        ]
        for (maxDimension, quality) in attempts {
            guard let data = scaled(image, maxDimension: maxDimension)?
                .jpegData(compressionQuality: quality) else { continue }
            if data.count <= maxBackupPhotoBytes { return data }
        }
        return nil
    }

    private static func scaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Keychain restore

    /// Write photo files back for cards whose image is missing from disk, which
    /// is every photo card after a reinstall.
    ///
    /// A card whose photo can't be recovered is rewritten without it rather
    /// than left pointing at a file that isn't there; if that leaves the card
    /// with nothing at all, it goes away.
    private func restoreMissingPhotos() {
        let missing = cards.values.filter { card in
            guard let fileName = card.imageFileName else { return false }
            return !FileManager.default.fileExists(
                atPath: cardsDirectory.appendingPathComponent(fileName).path
            )
        }
        guard !missing.isEmpty else { return }

        let directory = cardsDirectory
        backupQueue.async { [weak self, keychain = self.keychain] in
            var restored: [String] = []
            var unrecoverable: [String] = []

            for card in missing {
                guard let fileName = card.imageFileName else { continue }
                let account = MembershipCardStore.photoAccountPrefix + fileName
                // `try?` on a call that already returns an optional gives a
                // double optional; flatten it before unwrapping.
                let stored: Data? = (try? keychain.data(account: account)) ?? nil
                guard let data = stored else {
                    unrecoverable.append(card.storeId)
                    continue
                }
                do {
                    try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
                    restored.append(fileName)
                } catch {
                    unrecoverable.append(card.storeId)
                }
            }

            guard !restored.isEmpty || !unrecoverable.isEmpty else { return }
            DispatchQueue.main.async {
                self?.finishRestore(restored: restored, unrecoverable: unrecoverable)
            }
        }
    }

    private func finishRestore(restored: [String], unrecoverable: [String]) {
        for storeId in unrecoverable {
            guard var card = cards[storeId] else { continue }
            card.imageFileName = nil
            if card.isEmpty {
                cards.removeValue(forKey: storeId)
            } else {
                cards[storeId] = card
            }
        }

        for fileName in restored {
            imageCache.removeObject(forKey: fileName as NSString)
        }
        // The photos landed on disk after the views already read `cards`, so
        // nudge the views to read them again.
        objectWillChange.send()
        persistToDefaults()
        if !unrecoverable.isEmpty { backUpMetadata() }
    }
}
