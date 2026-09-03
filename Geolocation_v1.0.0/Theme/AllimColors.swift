//
//  AllimColors.swift
//  Geolocation_v1.0.0
//
//  The Allim aisle palette — the single source of truth for color in the app.
//

import SwiftUI
import UIKit

// Aisle palette for Allim.
// Quiet neutral chrome; category color is the only saturated thing on screen.
// Every token has a light and dark value. Never use a raw hex in a view.

// MARK: - Hex helpers

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }

    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        }
    }
}

extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor.dynamic(light: light, dark: dark))
    }
}

// MARK: - Token

/// One palette entry: a light value and a dark value, and nothing else.
///
/// A token resolves two ways, and the app needs both. `.color` hands back a
/// dynamic `Color` that follows the trait collection it is drawn in — right for
/// a `ButtonStyle` or a UIKit proxy that has no `ColorScheme` to read. The
/// callable form resolves against a scheme the view already holds, which is how
/// the screens here have always worked: they read `@Environment(\.colorScheme)`
/// once and pass it down, and some of them (a photo background's overlay, the
/// share cards) deliberately draw one scheme's colors inside the other.
struct AllimToken {
    let light: UInt32
    let dark: UInt32

    /// Follows whatever trait collection the view is drawn in.
    var color: Color { .dynamic(light: light, dark: dark) }

    /// Resolved against a scheme the caller is holding.
    func callAsFunction(_ scheme: ColorScheme) -> Color {
        Color(UIColor(hex: scheme == .dark ? dark : light))
    }

    /// UIKit's copy, for the appearance proxies. Still dynamic, so a bar set up
    /// at launch follows the user flipping appearance mid-session.
    var uiColor: UIColor { .dynamic(light: light, dark: dark) }
}

// MARK: - Core tokens

enum AllimColor {

    // Surfaces
    static let canvas = AllimToken(light: 0xF6F7F8, dark: 0x121417)
    static let card = AllimToken(light: 0xFFFFFF, dark: 0x1B1F23)
    static let cardRaised = AllimToken(light: 0xFFFFFF, dark: 0x232830)
    static let border = AllimToken(light: 0xE3E6E9, dark: 0x2B3238)
    static let borderStrong = AllimToken(light: 0xCED4D9, dark: 0x3A434B)

    /// Recessed inputs — search pills, the message field, an alert's cancel
    /// button. Sunk into the canvas rather than raised off it. Shares its
    /// values with `itemCheckedFill`: a field and a checked-off row are the
    /// same idea, something the eye should slide past.
    static let field = AllimToken(light: 0xEEF0F2, dark: 0x1F242A)

    // Brand / actions
    static let primary = AllimToken(light: 0x0B7285, dark: 0x3EB8CC)
    static let primaryPressed = AllimToken(light: 0x075661, dark: 0x2E9AAC)
    static let primaryWash = AllimToken(light: 0xE0F1F4, dark: 0x12303A)
    static let onPrimary = AllimToken(light: 0xFFFFFF, dark: 0x0B1417)

    // Accent — reminders, "you're near <store>", unread badges. Use sparingly.
    static let accent = AllimToken(light: 0xD94F16, dark: 0xFF7A45)
    static let accentWash = AllimToken(light: 0xFCEAE1, dark: 0x3A1B0E)
    static let onAccent = AllimToken(light: 0xFFFFFF, dark: 0x1A0A04)

    // Text
    static let textPrimary = AllimToken(light: 0x16191C, dark: 0xECEFF2)
    static let textSecondary = AllimToken(light: 0x5A6570, dark: 0x9BA6B0)
    static let textMuted = AllimToken(light: 0x8A939C, dark: 0x6F7B85)
    static let textOnWash = AllimToken(light: 0x075661, dark: 0xA8E4EF)

    // Status
    static let danger = AllimToken(light: 0xC4342B, dark: 0xFF6B60)
    static let dangerWash = AllimToken(light: 0xFBEAE9, dark: 0x3A1614)
    static let onDanger = AllimToken(light: 0xFFFFFF, dark: 0x1A0605)
    static let success = AllimToken(light: 0x1C6640, dark: 0x5FCB90)
    static let onSuccess = AllimToken(light: 0xFFFFFF, dark: 0x08160E)
    /// The wash under `success`, borrowed from the produce category so a
    /// "done" state and a produce chip read as the same green.
    static let successWash = AllimToken(light: 0xE7F4EC, dark: 0x14301F)
    static let warning = AllimToken(light: 0xB06A08, dark: 0xE0A33F)
    static let warningWash = AllimToken(light: 0xFAF0DC, dark: 0x33260F)

    // Checked-off list items
    static let itemChecked = AllimToken(light: 0x8A939C, dark: 0x6F7B85)
    static let itemCheckedFill = AllimToken(light: 0xEEF0F2, dark: 0x1F242A)

    /// Cards sit on a neutral canvas, so their shadow is neutral too — the
    /// warm brown the old paper palette used casts a tea stain on this one.
    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.44)
            : Color(hex: 0x16191C).opacity(0.08)
    }

    /// Hairline for ghost buttons and quiet rows, as a translucent overlay
    /// rather than an opaque fill — it has to sit on cards, washes and photo
    /// backgrounds alike.
    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }

    /// The scrim behind a modal. Neutral, matching the canvas it dims.
    static func scrim(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.58)
            : Color(hex: 0x16191C).opacity(0.36)
    }
}

extension Color {
    /// A palette hex, for the few places that need one value rather than a
    /// light/dark pair — a scrim's tint, a share card rendered light-only.
    init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }
}

// MARK: - Category tokens

// Three values per category:
//   dot   — the filled swatch / leading indicator
//   tint  — chip or section-header background
//   label — text on that tint (never white; see contrast note)

struct CategoryPalette {
    let dot: AllimToken
    let tint: AllimToken
    let label: AllimToken
}

/// The category hues, and the only saturated color the app allows itself
/// besides the brand teal.
///
/// The app's Smart Categories are free-form strings out of Firestore (and there
/// are far more of them than there are hues here), so this enum is a *palette*
/// rather than a model: `GroceryCategory.matching(_:)` folds a category name
/// onto the family it belongs to, and anything unrecognized lands on `.other`
/// rather than picking up a color at random.
enum GroceryCategory: String, CaseIterable, Codable {
    case produce
    case dairy
    case meat
    case bakery
    case pantry
    case frozen
    case beverages
    case snacks
    case household
    case other

    var palette: CategoryPalette {
        switch self {
        case .produce:
            return CategoryPalette(
                dot: AllimToken(light: 0x3FA96B, dark: 0x5FC489),
                tint: AllimToken(light: 0xE7F4EC, dark: 0x14301F),
                label: AllimToken(light: 0x1C6640, dark: 0xA9E3C0)
            )
        case .dairy:
            return CategoryPalette(
                dot: AllimToken(light: 0x4C8DD6, dark: 0x6EA9E8),
                tint: AllimToken(light: 0xE7F0FA, dark: 0x14243A),
                label: AllimToken(light: 0x1F5490, dark: 0xB3D2F2)
            )
        case .meat:
            return CategoryPalette(
                dot: AllimToken(light: 0xC4574F, dark: 0xE0796F),
                tint: AllimToken(light: 0xF8EAE8, dark: 0x351715),
                label: AllimToken(light: 0x8A2F28, dark: 0xF0B8B1)
            )
        case .bakery:
            return CategoryPalette(
                dot: AllimToken(light: 0xB98A5A, dark: 0xD3A87A),
                tint: AllimToken(light: 0xF4EBE1, dark: 0x2E2318),
                label: AllimToken(light: 0x7A5432, dark: 0xE6CBAB)
            )
        case .pantry:
            return CategoryPalette(
                dot: AllimToken(light: 0xC08A22, dark: 0xDFAB44),
                tint: AllimToken(light: 0xF8EFDD, dark: 0x322512),
                label: AllimToken(light: 0x7A5410, dark: 0xEDCE8C)
            )
        case .frozen:
            return CategoryPalette(
                dot: AllimToken(light: 0x4FA8C4, dark: 0x74C4DC),
                tint: AllimToken(light: 0xE5F2F7, dark: 0x122A33),
                label: AllimToken(light: 0x1B5D74, dark: 0xADDCEB)
            )
        case .beverages:
            return CategoryPalette(
                dot: AllimToken(light: 0x0B7285, dark: 0x3EB8CC),
                tint: AllimToken(light: 0xE0F1F4, dark: 0x12303A),
                label: AllimToken(light: 0x075661, dark: 0xA8E4EF)
            )
        case .snacks:
            return CategoryPalette(
                dot: AllimToken(light: 0xC96A93, dark: 0xE08CAF),
                tint: AllimToken(light: 0xF8E9F0, dark: 0x331723),
                label: AllimToken(light: 0x8A3660, dark: 0xF0BBD2)
            )
        case .household:
            return CategoryPalette(
                dot: AllimToken(light: 0x8A7BC8, dark: 0xA99CE0),
                tint: AllimToken(light: 0xEEEBF8, dark: 0x221E38),
                label: AllimToken(light: 0x4E4090, dark: 0xCAC1F0)
            )
        case .other:
            return CategoryPalette(
                dot: AllimToken(light: 0x8A939C, dark: 0x9BA6B0),
                tint: AllimToken(light: 0xEEF0F2, dark: 0x22272C),
                label: AllimToken(light: 0x4A535B, dark: 0xC3CBD2)
            )
        }
    }

    /// The hue family a Smart Category name belongs to.
    ///
    /// The names come from the categorizer and from whatever the user typed, so
    /// this matches on the words rather than on an exact case: "Meat & Seafood"
    /// and a hand-typed "seafood" both land on `.meat`. Anything with no family
    /// here takes `.other`'s neutral rather than a hue borrowed from a
    /// category it has nothing to do with.
    static func matching(_ name: String?) -> GroceryCategory {
        guard let name, !name.isEmpty else { return .other }
        let key = name.lowercased()

        func has(_ needles: [String]) -> Bool {
            needles.contains { key.contains($0) }
        }

        if has(["produce", "fruit", "vegetable", "garden", "tree", "plant", "flower"]) { return .produce }
        if has(["dairy", "egg", "cheese", "milk", "yogurt"]) { return .dairy }
        if has(["meat", "seafood", "fish", "poultry", "deli", "butcher"]) { return .meat }
        if has(["bakery", "bread", "pastry", "dessert", "baking"]) { return .bakery }
        if has(["pantry", "canned", "condiment", "sauce", "grain", "pasta", "spice", "rice", "cereal", "oil"]) { return .pantry }
        if has(["frozen", "ice cream"]) { return .frozen }
        if has(["beverage", "drink", "coffee", "tea", "juice", "water", "soda", "alcohol", "wine", "beer"]) { return .beverages }
        if has(["snack", "candy", "chip", "chocolate", "sweet"]) { return .snacks }
        if has([
            "household", "cleaning", "paper", "laundry", "personal care", "baby",
            "pet", "health", "pharmacy", "beauty", "home", "kitchen", "hardware",
            "tool", "office", "stationery", "furniture", "electronic", "clothing",
            "toy", "game", "sport", "outdoor", "automotive", "book", "media",
            "craft", "hobby",
        ]) { return .household }

        return .other
    }
}

// MARK: - Participant fills

/// The fills a participant avatar cycles through — the initial discs on a
/// shared store's reminders.
///
/// One hue per category family, so the set is the palette's own rather than a
/// second one to keep in step, but pitched deeper than the category `dot`: an
/// avatar carries white type at 22 points, and a chip's dot carries none. Every
/// entry clears 4.5:1 against white in both schemes, which is why the dark
/// variants are lifted rather than reused — a light-mode fill deep enough for
/// white type disappears into a dark card.
enum AllimAvatarFill {
    static let all: [AllimToken] = [
        AllimToken(light: 0x1F5490, dark: 0x2F6FB5), // dairy blue
        AllimToken(light: 0x1C6640, dark: 0x2A8155), // produce green
        AllimToken(light: 0x8A2F28, dark: 0xA84A41), // meat red
        AllimToken(light: 0x4E4090, dark: 0x6555B0), // household violet
        AllimToken(light: 0x8A3660, dark: 0xA9497B), // snacks rose
        AllimToken(light: 0x075661, dark: 0x0E7080), // beverages teal
        AllimToken(light: 0x1B5D74, dark: 0x2A7B96), // frozen blue
        AllimToken(light: 0x7A5410, dark: 0x9A6E1E), // pantry amber
        AllimToken(light: 0x4A535B, dark: 0x5E6972), // neutral slate
        AllimToken(light: 0x7A5432, dark: 0x966C45), // bakery brown
    ]

    /// Type drawn on any of them. White in both schemes: every fill above is
    /// deep enough to carry it, which is the point of the set.
    static let ink = Color.white
}

// MARK: - Category chip

/// The small tinted capsule naming a category — a section header's badge, a
/// reminder's category tag.
struct CategoryChip: View {
    let category: GroceryCategory
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(OrganicPalette.title(12, weight: .medium))
            .foregroundStyle(category.palette.label(colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(category.palette.tint(colorScheme), in: Capsule())
    }
}

// MARK: - Button styles

/// The filled brand button, for a label that isn't already an
/// `OrganicPillButton` — a `Button` inside a form, a sheet's confirm.
/// Reads the palette through the tokens' dynamic form rather than
/// `@Environment(\.colorScheme)`: a `ButtonStyle` is not a view, so a property
/// wrapper on it is never fed the environment and would silently resolve light
/// in both schemes. The dynamic colors follow the trait collection the label is
/// actually drawn in, which is the same answer by a route that works here.
struct AllimPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OrganicPalette.title(16, weight: .medium))
            .foregroundStyle(AllimColor.onPrimary.color)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                configuration.isPressed
                    ? AllimColor.primaryPressed.color
                    : AllimColor.primary.color,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}
