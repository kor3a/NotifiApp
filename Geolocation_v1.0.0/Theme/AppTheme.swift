//
//  AppTheme.swift
//  Geolocation_v1.0.0
//
//  Created on 11/13/24.
//

import SwiftUI

// MARK: - App Theme
extension Color {
    // MARK: - Text Colors
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    // MARK: - Accent Colors
    static let appAccent = Color.blue
    static let appSuccess = Color.green
    static let appError = Color.red
    static let appWarning = Color.orange

    // MARK: - Gradients
    /// The app's default backdrop. `shade` deepens (positive) or lifts
    /// (negative) both stops so the default look can be tuned like any other
    /// background color — see `Color.shaded(by:)`.
    static func backgroundGradient(for colorScheme: ColorScheme, shade: Double = 0) -> LinearGradient {
        let stops: [Color] = colorScheme == .dark
            ? [Color(red: 0.1, green: 0.1, blue: 0.15),
               Color(red: 0.15, green: 0.15, blue: 0.2)]
            : [Color(red: 0.95, green: 0.96, blue: 0.98),
               Color(red: 0.88, green: 0.92, blue: 0.96)]

        return LinearGradient(
            colors: stops.map { $0.shaded(by: shade) },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let iconGradient = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Card Surfaces

    /// A white wash laid over a card's `.ultraThinMaterial` fill in light mode.
    ///
    /// Material takes on whatever sits behind it, and every screen's backdrop is
    /// near-white in light mode, so an untinted card ends up the same brightness
    /// as the page and its edges vanish. Dark mode already separates cleanly and
    /// gets no tint.
    static func cardFillTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .clear : Color.white.opacity(0.7)
    }

    /// The card outline. `cardBorder` is a white gradient, which is invisible
    /// against the lightened light-mode card, so light mode gets a soft dark
    /// hairline instead.
    static func cardBorderStyle(for colorScheme: ColorScheme) -> AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(cardBorder(for: colorScheme))
            : AnyShapeStyle(Color.black.opacity(0.12))
    }

    /// Drop-shadow opacity that pairs with the card fill above.
    static func cardShadowOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.3 : 0.14
    }

    // MARK: - Border Colors
    static func cardBorder(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.6),
                    Color.white.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cardFillTint(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color.cardBorderStyle(for: colorScheme),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(Color.cardShadowOpacity(for: colorScheme)), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5), radius: 2, x: 0, y: -2)
                    .padding(.vertical, 4)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = .red

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
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
