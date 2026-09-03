//
//  AppTheme.swift
//  Geolocation_v1.0.0
//
//  Created on 11/13/24.
//
//  The general-purpose styling the app had before the palette existed. Every
//  value here now resolves to an `AllimColor` token, so the handful of screens
//  still on these helpers (Voice Commands, the share sheets) sit in the same
//  palette as the ones drawn from `OrganicPalette`.
//

import SwiftUI

// MARK: - App Theme
extension Color {
    // MARK: - Text Colors
    //
    // The palette's own ink rather than `.primary` / `.secondary`: the system
    // pair is pure black on pure white, which is a shade harder than anything
    // else on these screens.
    static let primaryText = AllimColor.textPrimary.color
    static let secondaryText = AllimColor.textSecondary.color
    /// The quietest readable tier — a timestamp, a hint, a disabled row.
    static let mutedText = AllimColor.textMuted.color

    // MARK: - Accent Colors
    static let appAccent = AllimColor.primary.color
    static let appSuccess = AllimColor.success.color
    static let appError = AllimColor.danger.color
    static let appWarning = AllimColor.warning.color

    // MARK: - Gradients

    /// The app's default backdrop — the palette's canvas, with the faintest
    /// fall toward the bottom of the screen so a full-bleed background isn't a
    /// flat wall of one value. `shade` deepens (positive) or lifts (negative)
    /// both stops so the default look can be tuned like any other background
    /// color — see `Color.shaded(by:)`.
    static func backgroundGradient(for colorScheme: ColorScheme, shade: Double = 0) -> LinearGradient {
        let stops: [Color] = colorScheme == .dark
            ? [Color(hex: 0x121417), Color(hex: 0x171B1F)]
            : [Color(hex: 0xF8F9FA), Color(hex: 0xEFF1F3)]

        return LinearGradient(
            colors: stops.map { $0.shaded(by: shade) },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The brand gradient behind a large glyph. Two tones of the one accent
    /// rather than two different hues — the palette keeps saturation for
    /// category color.
    static let iconGradient = LinearGradient(
        colors: [AllimColor.primary.color, AllimColor.primaryPressed.color],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Card Surfaces

    /// The fill laid over a card's `.ultraThinMaterial`.
    ///
    /// Opaque on purpose. Material takes on whatever sits behind it, and the
    /// palette's cards are flat surfaces at a stated value — a card that
    /// half-dissolves into the canvas is the look this palette replaced. The
    /// material underneath is left in place so a card over a photo background
    /// still blurs it before the fill covers it.
    static func cardFillTint(for colorScheme: ColorScheme) -> Color {
        AllimColor.card(colorScheme)
    }

    /// The card outline — the palette's hairline, in both schemes. The old
    /// white gradient only read against a dark backdrop.
    static func cardBorderStyle(for colorScheme: ColorScheme) -> AnyShapeStyle {
        AnyShapeStyle(AllimColor.border(colorScheme))
    }

    /// Drop-shadow opacity that pairs with the card fill above. Lighter than it
    /// was: these cards carry a border now, so the shadow only has to lift them
    /// off the canvas rather than draw their edge.
    static func cardShadowOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.34 : 0.07
    }

    // MARK: - Border Colors
    static func cardBorder(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [AllimColor.border(colorScheme), AllimColor.border(colorScheme)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AllimColor.card(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AllimColor.border(colorScheme), lineWidth: 1)
                    )
                    .shadow(
                        color: AllimColor.shadow(colorScheme),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .padding(.vertical, 4)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    /// Defaults to the brand accent. Callers that pass a color of their own
    /// should pass a palette token, not a system color.
    var color: Color = AllimColor.primary.color
    /// What the label is drawn in on top of `color`. Not white: in dark mode
    /// the accent is a light teal and white type on it barely reads.
    var labelColor: Color = AllimColor.onPrimary.color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17))
            .foregroundColor(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = AllimColor.danger.color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Profile Picture View

/// A reusable profile picture view that shows a cached image from a URL
/// or falls back to a custom view (typically a letter avatar).
///
/// Images come from `ProfileImageCache` rather than `AsyncImage` so an avatar
/// seen once is drawn from disk on the next launch instead of being downloaded
/// again, matching how store logos behave.
struct ProfilePictureView<Fallback: View>: View {
    let profilePictureURL: String?
    let size: CGFloat
    @ViewBuilder let fallback: () -> Fallback

    // An explicit init keeps the memberwise initializer from turning private
    // along with the observed cache below.
    @ObservedObject private var imageCache = ProfileImageCache.shared

    init(
        profilePictureURL: String?,
        size: CGFloat,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.profilePictureURL = profilePictureURL
        self.size = size
        self.fallback = fallback
    }

    var body: some View {
        Group {
            if let image = imageCache.image(for: profilePictureURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallback()
            }
        }
        .frame(width: size, height: size)
    }
}
