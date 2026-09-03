//
//  WidgetOrganicTheme.swift
//  NotifiWidget
//
//  The widget's copy of the app's palette.
//
//  Theme/AllimColors.swift and Theme/OrganicTheme.swift can't be compiled into
//  this target: the Theme group belongs to the app, and OrganicTheme reaches for
//  UIKit's tab bar appearance proxy and for app types (Contact,
//  ProfilePictureView) that don't exist here. So this file carries the subset
//  the widget actually draws with — the same tokens, the same Commissioner
//  scale, the same avatar tints — and nothing else.
//
//  Keep the hex values below in step with Theme/AllimColors.swift; a store row
//  on the home screen and the same row inside the app should be the same
//  surface.
//

import SwiftUI
import UIKit

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
}

// MARK: - Token

/// One palette entry: a light value and a dark value. The widget's cut-down
/// copy of the app's `AllimToken`.
struct AllimToken {
    let light: UInt32
    let dark: UInt32

    /// Follows whatever trait collection the widget is rendered in.
    var color: Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Resolved against a scheme the caller is holding — how the widget's own
    /// views read the palette.
    func callAsFunction(_ scheme: ColorScheme) -> Color {
        Color(UIColor(hex: scheme == .dark ? dark : light))
    }
}

// MARK: - Core tokens

/// The Allim aisle palette, as far as the widget needs it.
enum AllimColor {
    static let canvas = AllimToken(light: 0xF6F7F8, dark: 0x121417)
    static let card = AllimToken(light: 0xFFFFFF, dark: 0x1B1F23)
    static let border = AllimToken(light: 0xE3E6E9, dark: 0x2B3238)

    static let primary = AllimToken(light: 0x0B7285, dark: 0x3EB8CC)
    static let primaryWash = AllimToken(light: 0xE0F1F4, dark: 0x12303A)
    static let onPrimary = AllimToken(light: 0xFFFFFF, dark: 0x0B1417)

    static let accent = AllimToken(light: 0xD94F16, dark: 0xFF7A45)
    static let accentWash = AllimToken(light: 0xFCEAE1, dark: 0x3A1B0E)
    static let onAccent = AllimToken(light: 0xFFFFFF, dark: 0x1A0A04)

    static let textPrimary = AllimToken(light: 0x16191C, dark: 0xECEFF2)
    static let textSecondary = AllimToken(light: 0x5A6570, dark: 0x9BA6B0)
}

// MARK: - Palette

/// The palette the widget draws with, under the same names the app's views use
/// so a row copied between the two targets still compiles.
enum OrganicPalette {
    /// Full-bleed backdrop behind the whole widget.
    static func canvas(_ scheme: ColorScheme) -> Color {
        AllimColor.canvas(scheme)
    }

    /// Store rows — a shade lifted off the canvas.
    static func surface(_ scheme: ColorScheme) -> Color {
        AllimColor.card(scheme)
    }

    static func ink(_ scheme: ColorScheme) -> Color {
        AllimColor.textPrimary(scheme)
    }

    static func inkSoft(_ scheme: ColorScheme) -> Color {
        AllimColor.textSecondary(scheme)
    }

    /// Primary action color — the header glyph, a store's leading disc.
    static func terracotta(_ scheme: ColorScheme) -> Color {
        AllimColor.primary(scheme)
    }

    /// Type and glyphs drawn on `terracotta`. Not white: in dark mode the
    /// accent is a light teal and white on it barely reads.
    static func onTerracotta(_ scheme: ColorScheme) -> Color {
        AllimColor.onPrimary(scheme)
    }

    /// Tinted wash of the accent, behind quiet glyph discs.
    static func blush(_ scheme: ColorScheme) -> Color {
        AllimColor.primaryWash(scheme)
    }

    /// The warm accent, for the one thing a widget is actually about: a store
    /// with reminders waiting in it.
    static func highlight(_ scheme: ColorScheme) -> Color {
        AllimColor.accent(scheme)
    }

    static func highlightWash(_ scheme: ColorScheme) -> Color {
        AllimColor.accentWash(scheme)
    }

    static func onHighlight(_ scheme: ColorScheme) -> Color {
        AllimColor.onAccent(scheme)
    }

    /// Hairline between rows.
    static func outline(_ scheme: ColorScheme) -> Color {
        AllimColor.border(scheme)
    }

    /// Rows sit on a neutral canvas, so their shadow is neutral. Lighter than
    /// the app's — a widget row is a third the height of a list row, and the
    /// app's radius would smear across the gap between two of them.
    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.34)
            : Color(UIColor(hex: 0x16191C)).opacity(0.07)
    }

    /// Commissioner ships in this target's bundle and is registered in the
    /// extension's own `UIAppFonts` — a widget can't read the host app's fonts.
    /// Each weight names the face that actually ships rather than letting the
    /// renderer synthesize one; an unrecognized weight lands on regular.
    private static func commissioner(_ weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "Commissioner-Medium"
        case .semibold: return "Commissioner-SemiBold"
        case .bold: return "Commissioner-Bold"
        case .heavy: return "Commissioner-ExtraBold"
        case .black: return "Commissioner-Black"
        default: return "Commissioner-Regular"
        }
    }

    /// The heading tier — "My Stores", the empty-state line.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .custom(commissioner(weight), fixedSize: size)
    }

    /// Badges and other small set-in-caps type.
    static func title(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom(commissioner(weight), fixedSize: size)
    }

    /// Running text — a store's name, the overflow line.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(commissioner(weight), fixedSize: size)
    }
}

// MARK: - Category tokens

/// The category hue families, kept in step with the app's `GroceryCategory`.
/// The widget doesn't draw category chips, but the avatar tints below are built
/// from these — same set, same order, so a store wears the same color on the
/// home screen as it does in the list.
enum GroceryCategory {
    case produce, dairy, meat, pantry, snacks, household

    var tint: AllimToken {
        switch self {
        case .produce:   return AllimToken(light: 0xE7F4EC, dark: 0x14301F)
        case .dairy:     return AllimToken(light: 0xE7F0FA, dark: 0x14243A)
        case .meat:      return AllimToken(light: 0xF8EAE8, dark: 0x351715)
        case .pantry:    return AllimToken(light: 0xF8EFDD, dark: 0x322512)
        case .snacks:    return AllimToken(light: 0xF8E9F0, dark: 0x331723)
        case .household: return AllimToken(light: 0xEEEBF8, dark: 0x221E38)
        }
    }

    var label: AllimToken {
        switch self {
        case .produce:   return AllimToken(light: 0x1C6640, dark: 0xA9E3C0)
        case .dairy:     return AllimToken(light: 0x1F5490, dark: 0xB3D2F2)
        case .meat:      return AllimToken(light: 0x8A2F28, dark: 0xF0B8B1)
        case .pantry:    return AllimToken(light: 0x7A5410, dark: 0xEDCE8C)
        case .snacks:    return AllimToken(light: 0x8A3660, dark: 0xF0BBD2)
        case .household: return AllimToken(light: 0x4E4090, dark: 0xCAC1F0)
        }
    }
}

// MARK: - Avatar Tints

/// A fill and its matching glyph color, picked together so an initial always
/// has contrast. Same set, same order and same keying as the app's, so a store
/// wears the same color on the home screen as it does in the list.
struct OrganicAvatarTint {
    let fill: Color
    let glyph: Color

    private init(_ category: GroceryCategory) {
        self.fill = category.tint.color
        self.glyph = category.label.color
    }

    static let all: [OrganicAvatarTint] = [
        OrganicAvatarTint(.produce),
        OrganicAvatarTint(.dairy),
        OrganicAvatarTint(.meat),
        OrganicAvatarTint(.pantry),
        OrganicAvatarTint(.snacks),
        OrganicAvatarTint(.household),
    ]

    /// The tint for a name. Keyed off the name so the same store keeps the same
    /// color between refreshes — `hashValue` is seeded per process and would
    /// hand it a new one on every timeline reload, so the scalars are summed.
    static func forName(_ name: String) -> OrganicAvatarTint {
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return all[seed % all.count]
    }
}
