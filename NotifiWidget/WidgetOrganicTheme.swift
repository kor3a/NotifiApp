//
//  WidgetOrganicTheme.swift
//  NotifiWidget
//
//  The widget's copy of the app's organic look.
//
//  Theme/OrganicTheme.swift can't be compiled into this target: it reaches for
//  UIKit's tab bar appearance proxy and for app types (Contact,
//  ProfilePictureView) that don't exist here. So this file carries the subset
//  the widget actually draws with — the same palette values, the same
//  Commissioner scale, the same avatar tints — and nothing else.
//
//  Keep the numbers below in step with Theme/OrganicTheme.swift; a store row on
//  the home screen and the same row inside the app should be the same paper.
//

import SwiftUI

// MARK: - Organic Palette

/// The cream-and-terracotta palette the app runs on, as far as the widget
/// needs it.
enum OrganicPalette {
    /// Full-bleed paper backdrop behind the whole widget.
    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.10, green: 0.09, blue: 0.08)
            : Color(red: 0.95, green: 0.91, blue: 0.84)
    }

    /// Store rows — a shade lifted off the canvas, no border needed.
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.13, blue: 0.11)
            : Color(red: 0.98, green: 0.96, blue: 0.93)
    }

    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.95, green: 0.91, blue: 0.84)
            : Color(red: 0.14, green: 0.12, blue: 0.10)
    }

    static func inkSoft(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.66, green: 0.60, blue: 0.53)
            : Color(red: 0.42, green: 0.36, blue: 0.30)
    }

    /// Primary accent — the header glyph, the reminder badges.
    static func terracotta(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.85, green: 0.48, blue: 0.27)
            : Color(red: 0.74, green: 0.39, blue: 0.19)
    }

    /// Tinted wash of the accent, behind quiet glyph discs.
    static func blush(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.21, green: 0.14, blue: 0.10)
            : Color(red: 0.98, green: 0.92, blue: 0.87)
    }

    /// Rows sit on paper, so their shadow is a warm brown rather than black.
    /// Lighter than the app's — a widget row is a third the height of a list
    /// row, and the app's radius would smear across the gap between two of them.
    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.30)
            : Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.09)
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

// MARK: - Avatar Tints

/// A fill and its matching glyph color, picked together so an initial always
/// has contrast. Same set, same order and same keying as the app's, so a store
/// wears the same color on the home screen as it does in the list.
struct OrganicAvatarTint {
    let fill: Color
    let glyph: Color

    static let all: [OrganicAvatarTint] = [
        OrganicAvatarTint(
            fill: Color(red: 0.96, green: 0.73, blue: 0.59),
            glyph: Color(red: 0.55, green: 0.26, blue: 0.11)
        ),
        OrganicAvatarTint(
            fill: Color(red: 0.64, green: 0.74, blue: 0.53),
            glyph: Color(red: 0.15, green: 0.25, blue: 0.10)
        ),
        OrganicAvatarTint(
            fill: Color(red: 0.78, green: 0.75, blue: 0.68),
            glyph: Color(red: 0.28, green: 0.24, blue: 0.19)
        ),
        OrganicAvatarTint(
            fill: Color(red: 0.79, green: 0.45, blue: 0.24),
            glyph: .white
        ),
        OrganicAvatarTint(
            fill: Color(red: 0.87, green: 0.68, blue: 0.40),
            glyph: Color(red: 0.40, green: 0.25, blue: 0.07)
        ),
        OrganicAvatarTint(
            fill: Color(red: 0.55, green: 0.62, blue: 0.44),
            glyph: .white
        ),
    ]

    /// The tint for a name. Keyed off the name so the same store keeps the same
    /// color between refreshes — `hashValue` is seeded per process and would
    /// hand it a new one on every timeline reload, so the scalars are summed.
    static func forName(_ name: String) -> OrganicAvatarTint {
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return all[seed % all.count]
    }
}
