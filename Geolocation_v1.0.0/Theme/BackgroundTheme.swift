//
//  BackgroundTheme.swift
//  Geolocation_v1.0.0
//
//  Per-screen custom backgrounds: colors for everyone, photos for subscribers.
//

import SwiftUI
import UIKit

// MARK: - Background Surface

/// A screen that can carry its own background.
///
/// Each surface stores its choice independently, so a user can give Stores a
/// warm sand background while Reminders stays on the default gradient.
enum BackgroundSurface: Hashable, Identifiable {
    /// The store list. The only surface there is exactly one of.
    case stores
    /// One store's reminder list. Each store carries its own look.
    case reminders(storeId: String)
    /// A single conversation, so each chat carries its own look (matching how
    /// iMessage and WhatsApp handle this).
    case conversation(id: String)

    var id: String { storageSuffix }

    /// Fallback title for the picker. Callers that know the store or chat name
    /// pass that instead — it reads far better than "Reminders".
    var displayName: String {
        switch self {
        case .stores:       return "Stores"
        case .reminders:    return "Reminders"
        case .conversation: return "Conversation"
        }
    }

    var storageSuffix: String {
        switch self {
        case .stores:               return "stores"
        case .reminders(let id):    return "reminders_\(id)"
        case .conversation(let id): return "conversation_\(id)"
        }
    }

    /// UserDefaults key holding the solid color chosen for this surface.
    var colorStorageKey: String { "backgroundColor_\(storageSuffix)" }

    /// UserDefaults key holding how much the background photo is dimmed.
    var dimStorageKey: String { "backgroundDim_\(storageSuffix)" }

    /// UserDefaults key holding how far the chosen color is deepened or lifted.
    var shadeStorageKey: String { "backgroundShade_\(storageSuffix)" }

    /// File name for this surface's background photo.
    ///
    /// Store and conversation ids come from Firestore, so they're hex-encoded
    /// rather than trusted as a path component: that keeps separators and dots
    /// out of the name, and — unlike folding unsafe characters to `_` —
    /// guarantees two different ids can never land on the same file.
    var imageFileName: String {
        switch self {
        case .stores:
            return "stores.jpg"
        case .reminders(let id):
            return "reminders_\(Self.hexEncoded(id)).jpg"
        case .conversation(let id):
            return "conversation_\(Self.hexEncoded(id)).jpg"
        }
    }

    private static func hexEncoded(_ value: String) -> String {
        value.utf8.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Background Color Palette

/// The solid background colors anyone can choose from — colors are free, only
/// photo backgrounds need a subscription.
///
/// Every color ships a light and a dark variant. The variants are deliberately
/// low-saturation: these sit *behind* the palette's cards, and a vivid backdrop
/// around a neutral card reads as a mistake rather than as a choice. They stay
/// light in light mode and deep in dark mode so the palette's ink keeps its
/// contrast on both.
///
/// That light-mode variant is why "Midnight" can land on screen looking pale:
/// the palette starts from what keeps text readable, not from what the name
/// suggests. Every fill therefore takes a `shade`, letting the user push the
/// color deeper (or lighter) from that starting point — see `Color.shaded(by:)`.
enum AppBackgroundColor: String, CaseIterable, Identifiable {
    /// The palette's own canvas. Also what a surface falls back to when a
    /// photo is set but the subscription behind it has lapsed.
    case system

    case graphite
    case slate
    case midnight
    case ocean
    case teal
    case forest
    case sage
    case sand
    case apricot
    case rose
    case plum
    case lavender

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:    return "Default"
        case .graphite:  return "Graphite"
        case .slate:     return "Slate"
        case .midnight:  return "Midnight"
        case .ocean:     return "Ocean"
        case .teal:      return "Teal"
        case .forest:    return "Forest"
        case .sage:      return "Sage"
        case .sand:      return "Sand"
        case .apricot:   return "Apricot"
        case .rose:      return "Rose"
        case .plum:      return "Plum"
        case .lavender:  return "Lavender"
        }
    }

    /// Every choice except the default gradient, in palette order.
    static var selectableColors: [AppBackgroundColor] {
        allCases.filter { $0 != .system }
    }

    /// The flat fill for this choice, deepened or lifted by `shade`.
    ///
    /// `.system` has no flat fill of its own — it returns a single tone close to
    /// its gradient, which is what the swatch and the miniature preview want.
    /// Use `background(for:shade:)` to render the real gradient.
    func fill(for colorScheme: ColorScheme, shade: Double = 0) -> Color {
        baseFill(for: colorScheme).shaded(by: shade)
    }

    /// The background to actually place behind a screen: the default gradient
    /// for `.system`, a flat fill for every other color, both carrying `shade`.
    ///
    /// Returns `AnyShapeStyle` because the two cases are different types, and
    /// every call site wants one thing it can drop into `Rectangle().fill(_:)`.
    /// `systemDefault` replaces the app gradient for the `.system` entry, so a
    /// screen with its own default look (Conversations, on the organic canvas)
    /// can say what "System" means there. Ignored for every other color.
    func background(
        for colorScheme: ColorScheme,
        shade: Double = 0,
        systemDefault: Color? = nil
    ) -> AnyShapeStyle {
        guard self == .system else {
            return AnyShapeStyle(fill(for: colorScheme, shade: shade))
        }
        if let systemDefault {
            return AnyShapeStyle(systemDefault.shaded(by: shade))
        }
        return AnyShapeStyle(Color.backgroundGradient(for: colorScheme, shade: shade))
    }

    private func baseFill(for colorScheme: ColorScheme) -> Color {
        let isDark = colorScheme == .dark
        switch self {
        case .system:
            // The palette's canvas, so the "Default" swatch and the real
            // backdrop it stands for are the same color.
            return isDark ? Color(hex: 0x121417) : Color(hex: 0xF6F7F8)
        case .graphite:
            return isDark ? Color(red: 0.11, green: 0.11, blue: 0.12)
                          : Color(red: 0.93, green: 0.93, blue: 0.95)
        case .slate:
            return isDark ? Color(red: 0.12, green: 0.14, blue: 0.18)
                          : Color(red: 0.90, green: 0.92, blue: 0.95)
        case .midnight:
            return isDark ? Color(red: 0.05, green: 0.06, blue: 0.11)
                          : Color(red: 0.85, green: 0.87, blue: 0.94)
        case .ocean:
            return isDark ? Color(red: 0.06, green: 0.13, blue: 0.21)
                          : Color(red: 0.86, green: 0.92, blue: 0.98)
        case .teal:
            return isDark ? Color(red: 0.05, green: 0.16, blue: 0.16)
                          : Color(red: 0.85, green: 0.94, blue: 0.93)
        case .forest:
            return isDark ? Color(red: 0.06, green: 0.14, blue: 0.10)
                          : Color(red: 0.87, green: 0.94, blue: 0.88)
        case .sage:
            return isDark ? Color(red: 0.11, green: 0.14, blue: 0.11)
                          : Color(red: 0.91, green: 0.93, blue: 0.86)
        case .sand:
            return isDark ? Color(red: 0.15, green: 0.13, blue: 0.09)
                          : Color(red: 0.96, green: 0.93, blue: 0.86)
        case .apricot:
            return isDark ? Color(red: 0.18, green: 0.12, blue: 0.08)
                          : Color(red: 0.99, green: 0.91, blue: 0.84)
        case .rose:
            return isDark ? Color(red: 0.17, green: 0.10, blue: 0.12)
                          : Color(red: 0.98, green: 0.90, blue: 0.91)
        case .plum:
            return isDark ? Color(red: 0.16, green: 0.10, blue: 0.17)
                          : Color(red: 0.94, green: 0.88, blue: 0.95)
        case .lavender:
            return isDark ? Color(red: 0.13, green: 0.11, blue: 0.20)
                          : Color(red: 0.93, green: 0.91, blue: 0.98)
        }
    }
}

// MARK: - Shading

extension Color {
    /// How dark a color gets at full shade. Deeper than any palette entry's dark
    /// variant, so "all the way right" reads as genuinely dark rather than dim.
    static let maxShadeBrightness: Double = 0.06

    /// Returns this color deepened (`shade` > 0) or lifted (`shade` < 0),
    /// with `0` leaving it untouched. Values outside `-1...1` are clamped.
    ///
    /// The move happens in HSB so the hue survives it. Darkening also raises
    /// saturation in proportion, because dropping brightness alone slides a pale
    /// color toward flat grey — the boost is multiplicative, so near-neutral
    /// choices like Graphite stay neutral instead of picking up a color cast.
    func shaded(by shade: Double) -> Color {
        let amount = min(max(shade, -1), 1)
        guard amount != 0 else { return self }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }

        let distance = CGFloat(abs(amount))
        let targetBrightness: CGFloat
        let targetSaturation: CGFloat
        if amount > 0 {
            targetBrightness = CGFloat(Self.maxShadeBrightness)
            targetSaturation = min(saturation * 2.2, 0.6)
        } else {
            // Lifting washes the color out as it approaches white, mirroring how
            // the light-mode variants are built.
            targetBrightness = 1
            targetSaturation = saturation * 0.25
        }

        return Color(
            hue: Double(hue),
            saturation: Double(saturation + (targetSaturation - saturation) * distance),
            brightness: Double(brightness + (targetBrightness - brightness) * distance),
            opacity: Double(alpha)
        )
    }
}

// MARK: - Card Legibility on Photos

/// A coarse read of a background photo: the average color of each cell in a
/// small grid laid over it.
///
/// That is all the card-opacity solve needs: a row spans a good share of the
/// screen's width, so what decides whether its text reads is the tone of the
/// part of the photo it sits on, not the photo's fine detail.
struct BackgroundPhotoTones: Equatable {
    /// Cells per side. 24 × 24 is enough to find a bright sky or a dark
    /// doorway anywhere in the frame while staying a trivial amount of work.
    static let gridSize = 24

    /// sRGB-encoded components of each cell, 0...1.
    let cells: [SIMD3<Double>]

    init(cells: [SIMD3<Double>]) {
        self.cells = cells
    }

    /// Averages the image down to the grid. Returns `nil` for an image with
    /// no bitmap behind it.
    init?(image: UIImage, gridSize: Int = BackgroundPhotoTones.gridSize) {
        guard let cgImage = image.cgImage,
              gridSize > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        let bytesPerRow = gridSize * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * gridSize)
        let drew: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: gridSize,
                height: gridSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                return false
            }
            // High quality averages the pixels a cell covers rather than
            // point-sampling one of them, which a 1600-to-24 reduction needs.
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: gridSize, height: gridSize))
            return true
        }
        guard drew else { return nil }

        var cells: [SIMD3<Double>] = []
        cells.reserveCapacity(gridSize * gridSize)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            cells.append(SIMD3(
                Double(pixels[index]) / 255,
                Double(pixels[index + 1]) / 255,
                Double(pixels[index + 2]) / 255
            ))
        }
        self.cells = cells
    }
}

/// Works out how opaque a card has to be for its text to stay readable over a
/// background photo — and no more opaque than that, so as much of the photo
/// shows through as the text allows.
///
/// A fixed opacity can't do this: a pale beach needs almost nothing behind
/// the text, while a night skyline in Light Mode needs nearly a solid card.
/// So the solve reads the photo as the user will actually see it — after the
/// Fade scrim — and finds, for each part of it, the lowest opacity at which
/// both the primary and the secondary text on a card still meet their contrast
/// targets. The card takes the opacity most of the photo is happy with, so a
/// bright sky or a lamp in one corner doesn't turn every card solid.
///
/// Tuned toward showing the photo: the point of choosing one is to see it.
/// The targets are WCAG AA rather than AAA, and the ceiling stops well short
/// of solid — on a photo too bright (or, in Light Mode, too dark) for that,
/// the Fade slider is what brings it into range.
enum PhotoCardLegibility {
    /// WCAG AA for the row's name — the thing the eye actually reads.
    static let primaryContrast: Double = 4.5
    /// WCAG AA for large and bold type, for the quieter line under it
    /// (counts, quantities, who added it).
    static let secondaryContrast: Double = 3

    /// Just enough tint that a row still reads as a row, even on a photo that
    /// needs none for the text.
    static let minOpacity: Double = 0.15
    /// Never more than this, so the photo always shows through.
    static let maxOpacity: Double = 0.7

    /// Share of the photo the chosen opacity has to satisfy. The rest — a
    /// patch of sky, a glint, a lamp — is left to the Fade slider rather than
    /// darkening (or whitening) every row for it.
    static let coverage: Double = 0.8

    /// The opacity a card should be drawn at over `tones`, faded by `dimLevel`.
    static func cardOpacity(
        for tones: BackgroundPhotoTones,
        dimLevel: Double,
        colorScheme: ColorScheme
    ) -> Double {
        guard !tones.cells.isEmpty else { return maxOpacity }

        let isDark = colorScheme == .dark
        let card = components(isDark ? AllimColor.card.dark : AllimColor.card.light)
        let primary = luminance(components(isDark ? AllimColor.textPrimary.dark : AllimColor.textPrimary.light))
        let secondary = luminance(components(isDark ? AllimColor.textSecondary.dark : AllimColor.textSecondary.light))

        // `BackgroundPhoto`'s scrim: white in Light Mode, black in Dark Mode.
        let dim = min(max(dimLevel, 0), 1)
        let veil = SIMD3<Double>(repeating: isDark ? 0 : 1)

        let texts: [(luminance: Double, target: Double)] = [
            (primary, primaryContrast),
            (secondary, secondaryContrast),
        ]

        let required = tones.cells
            .map { cell -> Double in
                let faded = cell * (1 - dim) + veil * dim
                return minimumOpacity(over: faded, card: card, textLuminances: texts)
            }
            .sorted()

        let index = min(Int((Double(required.count) * coverage).rounded(.up)) - 1, required.count - 1)
        return min(max(required[max(index, 0)], minOpacity), maxOpacity)
    }

    /// The lowest opacity at which `card` laid over `backdrop` gives every text
    /// color its target contrast.
    ///
    /// Blending is done on the encoded values, which is how Core Animation
    /// composites. Contrast only grows as the card closes in on its own color,
    /// so a bisection finds the threshold.
    static func minimumOpacity(
        over backdrop: SIMD3<Double>,
        card: SIMD3<Double>,
        textLuminances: [(luminance: Double, target: Double)]
    ) -> Double {
        func isReadable(at opacity: Double) -> Bool {
            let blended = luminance(card * opacity + backdrop * (1 - opacity))
            return textLuminances.allSatisfy { contrast(blended, $0.luminance) >= $0.target }
        }

        if isReadable(at: 0) { return 0 }
        guard isReadable(at: 1) else { return 1 }

        var low = 0.0
        var high = 1.0
        for _ in 0..<14 {
            let mid = (low + high) / 2
            if isReadable(at: mid) {
                high = mid
            } else {
                low = mid
            }
        }
        return high
    }

    /// WCAG relative luminance of sRGB-encoded components.
    static func luminance(_ rgb: SIMD3<Double>) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.x) + 0.7152 * linear(rgb.y) + 0.0722 * linear(rgb.z)
    }

    /// WCAG contrast ratio between two relative luminances.
    static func contrast(_ first: Double, _ second: Double) -> Double {
        (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private static func components(_ hex: UInt32) -> SIMD3<Double> {
        SIMD3(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Preferences Store

/// Stores each surface's background choice locally on the device.
///
/// Kept in UserDefaults rather than Firestore: a background is a per-device
/// look, and writing it to Firestore on every tap would cost a network round
/// trip for a purely cosmetic setting.
final class BackgroundPreferences: ObservableObject {
    static let shared = BackgroundPreferences()

    /// Longest edge a stored background photo is scaled down to. Comfortably
    /// covers the largest iPhone at 3x without holding a 12-megapixel original
    /// in memory for the whole time a screen is on.
    static let maxImageDimension: CGFloat = 1600

    /// How much a background photo is dimmed when the user hasn't said.
    static let defaultDimLevel: Double = 0.3

    /// Widest dimming the slider offers. Past this the photo is barely visible.
    static let maxDimLevel: Double = 0.8

    private let defaults: UserDefaults
    private let imageDirectory: URL?

    /// Decoded photos, kept in memory so the background doesn't hit the disk on
    /// every re-render. Cleared for a surface whenever its photo changes.
    private var imageCache: [String: UIImage] = [:]

    /// Each photo's tones, read once and kept for the card-opacity solve.
    /// Cleared alongside `imageCache`.
    private var toneCache: [String: BackgroundPhotoTones] = [:]

    /// Solved card opacities per surface, keyed by appearance and fade. The
    /// solve is cheap, but every row on screen asks for it on every render.
    private var cardOpacityCache: [String: [CardOpacityKey: Double]] = [:]

    private struct CardOpacityKey: Hashable {
        let isDark: Bool
        /// The fade in hundredths — finer than the slider can meaningfully set.
        let dim: Int
    }

    /// Bumped on every change so views observing this object re-render.
    @Published private var revision: Int = 0

    init(defaults: UserDefaults = .standard, imageDirectory: URL? = BackgroundPreferences.defaultImageDirectory()) {
        self.defaults = defaults
        self.imageDirectory = imageDirectory
    }

    /// `Application Support/Backgrounds` — app-private, backed up, and not
    /// visible to the user in Files.
    static func defaultImageDirectory() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support.appendingPathComponent("Backgrounds", isDirectory: true)
    }

    /// The color chosen for a surface, or `.system` if the user never picked one.
    func backgroundColor(for surface: BackgroundSurface) -> AppBackgroundColor {
        guard let raw = defaults.string(forKey: surface.colorStorageKey),
              let color = AppBackgroundColor(rawValue: raw) else {
            return .system
        }
        return color
    }

    /// Sets the solid color for a surface.
    ///
    /// A color and a photo are mutually exclusive — picking a color drops the
    /// photo, so there is only ever one answer to "what is behind this screen".
    func setBackgroundColor(_ color: AppBackgroundColor, for surface: BackgroundSurface) {
        if color == .system {
            defaults.removeObject(forKey: surface.colorStorageKey)
        } else {
            defaults.set(color.rawValue, forKey: surface.colorStorageKey)
        }
        deleteImageFile(for: surface)
        revision &+= 1
    }

    // MARK: - Photos

    private func imageURL(for surface: BackgroundSurface) -> URL? {
        imageDirectory?.appendingPathComponent(surface.imageFileName)
    }

    /// The photo chosen for a surface, or `nil` if the user hasn't set one.
    func backgroundImage(for surface: BackgroundSurface) -> UIImage? {
        if let cached = imageCache[surface.storageSuffix] { return cached }
        guard let url = imageURL(for: surface),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        imageCache[surface.storageSuffix] = image
        return image
    }

    func hasBackgroundImage(for surface: BackgroundSurface) -> Bool {
        backgroundImage(for: surface) != nil
    }

    /// Decodes, downscales and re-encodes a photo ready for storage.
    ///
    /// Split out from `storeImageData` because this is the slow part — a
    /// full-resolution photo takes long enough to decode that doing it on the
    /// main thread stutters the picker. It touches no shared state, so callers
    /// can run it off the main actor and hand the result back.
    /// Returns `nil` if the data isn't a decodable image.
    static func preparedImageData(from data: Data, maxDimension: CGFloat = maxImageDimension) -> Data? {
        guard let original = UIImage(data: data),
              let scaled = downscaled(original, maxDimension: maxDimension) else {
            return nil
        }
        return scaled.jpegData(compressionQuality: 0.85)
    }

    /// Writes already-prepared JPEG data as the surface's background.
    ///
    /// Returns `false` if the data can't be decoded or the write fails, so the
    /// caller can tell the user instead of silently doing nothing.
    @discardableResult
    func storeImageData(_ jpeg: Data, for surface: BackgroundSurface) -> Bool {
        guard let url = imageURL(for: surface),
              let directory = imageDirectory,
              let image = UIImage(data: jpeg) else {
            return false
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try jpeg.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("BackgroundPreferences: Failed to store background image — \(error.localizedDescription)")
            #endif
            return false
        }

        imageCache[surface.storageSuffix] = image
        forgetPhotoAnalysis(for: surface)
        // A photo replaces any solid color, mirroring setBackgroundColor.
        defaults.removeObject(forKey: surface.colorStorageKey)
        revision &+= 1
        return true
    }

    /// Prepares and stores a photo in one step.
    @discardableResult
    func setBackgroundImage(from data: Data, for surface: BackgroundSurface) -> Bool {
        guard let jpeg = Self.preparedImageData(from: data) else { return false }
        return storeImageData(jpeg, for: surface)
    }

    func removeBackgroundImage(for surface: BackgroundSurface) {
        deleteImageFile(for: surface)
        defaults.removeObject(forKey: surface.dimStorageKey)
        revision &+= 1
    }

    private func deleteImageFile(for surface: BackgroundSurface) {
        imageCache[surface.storageSuffix] = nil
        forgetPhotoAnalysis(for: surface)
        guard let url = imageURL(for: surface) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Scales an image so its longest edge is at most `maxDimension` points.
    /// Images already within budget are returned untouched.
    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > maxDimension, longestEdge > 0 else { return image }

        let scale = maxDimension / longestEdge
        let target = CGSize(width: (image.size.width * scale).rounded(),
                            height: (image.size.height * scale).rounded())
        guard target.width >= 1, target.height >= 1 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    // MARK: - Dimming

    /// How much to darken (or lighten) a background photo, 0...`maxDimLevel`.
    ///
    /// Photos vary wildly in brightness, and the app's content sits on
    /// translucent cards, so a fixed scrim can't keep text readable across
    /// every photo — the user gets to tune it.
    func dimLevel(for surface: BackgroundSurface) -> Double {
        guard defaults.object(forKey: surface.dimStorageKey) != nil else {
            return Self.defaultDimLevel
        }
        return min(max(defaults.double(forKey: surface.dimStorageKey), 0), Self.maxDimLevel)
    }

    func setDimLevel(_ level: Double, for surface: BackgroundSurface) {
        defaults.set(min(max(level, 0), Self.maxDimLevel), forKey: surface.dimStorageKey)
        revision &+= 1
    }

    // MARK: - Card Opacity

    /// How opaque the cards on a surface should be so their text stays readable
    /// over its photo, or `nil` when the surface has no photo and cards are
    /// drawn solid as usual.
    ///
    /// Follows the Fade level, so dragging the slider re-solves it live.
    func cardOpacity(for surface: BackgroundSurface, colorScheme: ColorScheme) -> Double? {
        guard let image = backgroundImage(for: surface) else { return nil }

        let dim = dimLevel(for: surface)
        let key = CardOpacityKey(isDark: colorScheme == .dark, dim: Int((dim * 100).rounded()))
        if let cached = cardOpacityCache[surface.storageSuffix]?[key] {
            return cached
        }

        guard let tones = photoTones(for: surface, image: image) else {
            return PhotoCardLegibility.maxOpacity
        }
        let opacity = PhotoCardLegibility.cardOpacity(for: tones, dimLevel: dim, colorScheme: colorScheme)
        cardOpacityCache[surface.storageSuffix, default: [:]][key] = opacity
        return opacity
    }

    private func photoTones(for surface: BackgroundSurface, image: UIImage) -> BackgroundPhotoTones? {
        if let cached = toneCache[surface.storageSuffix] { return cached }
        guard let tones = BackgroundPhotoTones(image: image) else { return nil }
        toneCache[surface.storageSuffix] = tones
        return tones
    }

    private func forgetPhotoAnalysis(for surface: BackgroundSurface) {
        toneCache[surface.storageSuffix] = nil
        cardOpacityCache[surface.storageSuffix] = nil
    }

    // MARK: - Shade

    /// How far the surface's color is pushed from its palette value, -1...1.
    ///
    /// Negative lifts it toward white, positive deepens it toward black, and 0 —
    /// the default, and what an unset key reads back as — leaves the palette
    /// value alone. Kept separate from the color itself so switching swatches
    /// keeps the depth the user settled on.
    func shadeLevel(for surface: BackgroundSurface) -> Double {
        min(max(defaults.double(forKey: surface.shadeStorageKey), -1), 1)
    }

    func setShadeLevel(_ level: Double, for surface: BackgroundSurface) {
        defaults.set(min(max(level, -1), 1), forKey: surface.shadeStorageKey)
        revision &+= 1
    }

    // MARK: - Applying One Look Everywhere

    /// Copies one surface's whole look — color and shade, or photo and fade —
    /// onto every surface in `targets`.
    ///
    /// Most people want one background across all their store lists, and
    /// setting that store by store is a lot of taps. The source surface is
    /// skipped if it appears in `targets`, so callers can pass every store id
    /// without filtering out the one they're editing.
    ///
    /// `includingPhoto` is false when the user isn't subscribed: a lapsed photo
    /// already falls back to the color on screen, so the color is what they're
    /// looking at and what should travel.
    ///
    /// Writes are batched behind a single publish — one redraw for the whole
    /// sweep rather than one per store.
    ///
    /// Returns `false` if any target couldn't be written, so the caller can say
    /// so instead of silently doing nothing.
    @discardableResult
    func applyBackground(from source: BackgroundSurface,
                         to targets: [BackgroundSurface],
                         includingPhoto: Bool = true) -> Bool {
        let colorRaw = defaults.string(forKey: source.colorStorageKey)
        let shade = shadeLevel(for: source)
        let dim = dimLevel(for: source)
        let photoData: Data? = {
            guard includingPhoto, let url = imageURL(for: source) else { return nil }
            return try? Data(contentsOf: url)
        }()
        let photo: UIImage? = photoData.flatMap { UIImage(data: $0) }

        var succeeded = true

        for target in targets where target.storageSuffix != source.storageSuffix {
            // A photo and a color are mutually exclusive, so the target is
            // cleared first and then given exactly one of them.
            deleteImageFile(for: target)

            if let photoData, let photo {
                guard let url = imageURL(for: target), let directory = imageDirectory else {
                    succeeded = false
                    continue
                }
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try photoData.write(to: url, options: .atomic)
                } catch {
                    #if DEBUG
                    print("BackgroundPreferences: Failed to copy background image — \(error.localizedDescription)")
                    #endif
                    succeeded = false
                    continue
                }
                imageCache[target.storageSuffix] = photo
                // Same photo, same tones — every store's cards come out the
                // same without each one re-reading the image.
                toneCache[target.storageSuffix] = toneCache[source.storageSuffix]
                defaults.removeObject(forKey: target.colorStorageKey)
                defaults.set(dim, forKey: target.dimStorageKey)
            } else {
                defaults.removeObject(forKey: target.dimStorageKey)
                if let colorRaw {
                    defaults.set(colorRaw, forKey: target.colorStorageKey)
                } else {
                    defaults.removeObject(forKey: target.colorStorageKey)
                }
            }

            // An unset key already reads back as 0, so the default shade is
            // stored by removing the key rather than writing a zero.
            if shade == 0 {
                defaults.removeObject(forKey: target.shadeStorageKey)
            } else {
                defaults.set(shade, forKey: target.shadeStorageKey)
            }
        }

        revision &+= 1
        return succeeded
    }

    // MARK: - Reset

    /// Clears a single surface back to the app default.
    func reset(_ surface: BackgroundSurface) {
        defaults.removeObject(forKey: surface.colorStorageKey)
        defaults.removeObject(forKey: surface.dimStorageKey)
        defaults.removeObject(forKey: surface.shadeStorageKey)
        deleteImageFile(for: surface)
        revision &+= 1
    }

    /// Clears every stored background. Used when signing out so the next
    /// account on this device starts from the default look.
    ///
    /// Sweeps by key prefix rather than by enumerating surfaces: most surfaces
    /// are keyed by a store or conversation id, so there is no finite list to
    /// walk.
    func resetAll() {
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("backgroundColor_")
            || key.hasPrefix("backgroundDim_")
            || key.hasPrefix("backgroundShade_") {
            defaults.removeObject(forKey: key)
        }

        imageCache.removeAll()
        toneCache.removeAll()
        cardOpacityCache.removeAll()
        if let directory = imageDirectory {
            try? FileManager.default.removeItem(at: directory)
        }
        revision &+= 1
    }
}

// MARK: - Background View

/// The background layer for a surface — the user's chosen color, or their photo
/// when they're subscribed.
///
/// Colors are free for everyone; only photos are a subscription feature. The
/// photo check lives here rather than at selection time so a lapsed
/// subscription falls back to the default look without erasing the photo;
/// resubscribing brings it straight back.
struct SurfaceBackground: View {
    let surface: BackgroundSurface
    /// What "System" resolves to for this surface. `AppBackgroundColor.system`
    /// means "whatever this screen looks like by default", and not every screen
    /// wants the app gradient any more — Conversations run on the organic
    /// canvas. Leave it nil to keep the gradient. A color the user picked
    /// explicitly always wins over this.
    var systemDefault: Color?

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var preferences = BackgroundPreferences.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    private var selection: AppBackgroundColor {
        preferences.backgroundColor(for: surface)
    }

    private var image: UIImage? {
        guard subscriptionManager.isSubscribed else { return nil }
        return preferences.backgroundImage(for: surface)
    }

    var body: some View {
        Group {
            if let image {
                BackgroundPhoto(
                    image: image,
                    dimLevel: preferences.dimLevel(for: surface),
                    colorScheme: colorScheme
                )
            } else {
                Rectangle()
                    .fill(selection.background(
                        for: colorScheme,
                        shade: preferences.shadeLevel(for: surface),
                        systemDefault: systemDefault
                    ))
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: selection)
    }
}

/// A background photo scaled to fill the screen, with a scrim on top.
///
/// The scrim matches the appearance rather than always darkening: `.primary`
/// text is black in light mode and white in dark mode, so a white veil in light
/// mode and a black one in dark mode is what actually preserves contrast.
struct BackgroundPhoto: View {
    let image: UIImage
    let dimLevel: Double
    let colorScheme: ColorScheme

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(
                    (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(dimLevel)
                )
        }
    }
}

/// The card behind a row on a screen the user can put a photo behind.
///
/// Without a photo it is exactly `OrganicCardBackground`. On a photo it turns
/// into a see-through tint: the card's own color at whatever opacity
/// `PhotoCardLegibility` says keeps the row's text readable over that
/// particular photo at its current Fade, and a hairline where the shadow was —
/// a shadow under a see-through card shows through it as a grey smear.
///
/// No blur material under it: every system material carries its own tint,
/// which in Dark Mode stacks a second dark layer on the card and hides the
/// photo the user picked.
///
/// Gated on the subscription the same way `SurfaceBackground` is, so a lapsed
/// photo falls back to solid cards along with the backdrop behind them.
struct SurfaceCardBackground: View {
    let surface: BackgroundSurface
    var cornerRadius: CGFloat = 24

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var preferences = BackgroundPreferences.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    private var photoOpacity: Double? {
        guard subscriptionManager.isSubscribed else { return nil }
        return preferences.cardOpacity(for: surface, colorScheme: colorScheme)
    }

    var body: some View {
        if let photoOpacity {
            PhotoCardBackground(
                opacity: photoOpacity,
                colorScheme: colorScheme,
                cornerRadius: cornerRadius
            )
        } else {
            OrganicCardBackground(colorScheme: colorScheme, cornerRadius: cornerRadius)
        }
    }
}

/// The see-through card `SurfaceCardBackground` draws over a photo, split out so
/// the background picker's preview can show the same card at the same opacity.
struct PhotoCardBackground: View {
    let opacity: Double
    let colorScheme: ColorScheme
    var cornerRadius: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(OrganicPalette.surface(colorScheme).opacity(opacity))
            .overlay(shape.strokeBorder(OrganicPalette.outline(colorScheme), lineWidth: 0.5))
            .animation(.easeInOut(duration: 0.2), value: opacity)
    }
}

extension View {
    /// Places the surface's background behind this view.
    func surfaceBackground(_ surface: BackgroundSurface, systemDefault: Color? = nil) -> some View {
        background(SurfaceBackground(surface: surface, systemDefault: systemDefault))
    }
}
