//
//  OrganicTheme.swift
//  Geolocation_v1.0.0
//
//  The warm, paper-toned look shared by the people-facing screens.
//

import SwiftUI
import UIKit

// MARK: - Organic Palette

/// The palette behind Friends, Messages, Conversations, Stores and Reminders.
///
/// The app runs on paper and clay rather than its old cool gradient: a cream
/// canvas, a terracotta accent, and a sage green kept for the one idea that
/// isn't terracotta — Family in Friends, a store share in a chat, a shared
/// store in the list. The system blue and the frosted material cards read as
/// clinical beside the soft, rounded shapes these screens are built from.
enum OrganicPalette {
    /// Full-bleed paper backdrop behind a whole screen.
    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.10, green: 0.09, blue: 0.08)
            : Color(red: 0.95, green: 0.91, blue: 0.84)
    }

    /// Card and row surfaces — a shade lifted off the canvas, no border needed.
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.13, blue: 0.11)
            : Color(red: 0.98, green: 0.96, blue: 0.93)
    }

    /// Recessed inputs — search pills, the message field. Sunk into the canvas
    /// rather than raised off it.
    static func field(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.18, green: 0.16, blue: 0.14)
            : Color(red: 0.91, green: 0.87, blue: 0.82)
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

    /// Primary accent — add buttons, sent bubbles, badges, action glyphs.
    static func terracotta(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.85, green: 0.48, blue: 0.27)
            : Color(red: 0.74, green: 0.39, blue: 0.19)
    }

    /// Tinted wash of the accent, for cards that need answering and quiet
    /// icon buttons.
    static func blush(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.21, green: 0.14, blue: 0.10)
            : Color(red: 0.98, green: 0.92, blue: 0.87)
    }

    /// The one non-terracotta hue, kept for a single idea per screen.
    static func sage(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.21, blue: 0.12)
            : Color(red: 0.85, green: 0.91, blue: 0.78)
    }

    static func sageInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.78, green: 0.86, blue: 0.68)
            : Color(red: 0.18, green: 0.29, blue: 0.13)
    }

    /// A deep brick, kept for the destructive and out-of-stock states that
    /// would otherwise reach for the system red — a siren tone that pulls the
    /// eye far harder than these states deserve on a paper background.
    static func rust(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.85, green: 0.38, blue: 0.31)
            : Color(red: 0.69, green: 0.22, blue: 0.16)
    }

    /// Hairline used to outline ghost buttons and quiet rows.
    static func outline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.14)
    }

    /// Cards sit on paper, so their shadow is a warm brown rather than black.
    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.40)
            : Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.10)
    }

    /// The face behind every organic title — Commissioner, bundled in `Fonts/`
    /// and registered under `UIAppFonts`. Its low-contrast, slightly condensed
    /// letterforms are what make these screens read as organic rather than as
    /// another system list.
    ///
    /// A bundled family carries no weight axis of its own, so each weight we
    /// use names the face that actually ships rather than letting the renderer
    /// synthesize one. Weights lighter than regular round up to it; anything
    /// unrecognized lands on regular rather than silently falling back to the
    /// system font.
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

    /// Screen headings — the name in Stores, "Messages", "Friends", empty-state
    /// and sheet titles. The heaviest tier of the type scale.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .custom(commissioner(weight), fixedSize: size)
    }

    /// The quieter title tier that sits under `display` — navigation bar titles,
    /// row names, section labels, chips and badges.
    static func title(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom(commissioner(weight), fixedSize: size)
    }

    /// Running text the eye reads rather than scans — a store's name in the
    /// list, a reminder and its quantity, the words in a message bubble. The
    /// tier the three of them share is what keeps a chat and a shopping list
    /// looking like one app.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(commissioner(weight), fixedSize: size)
    }

    /// Placeholder text for `organicField`. Set as a field's `prompt:` rather
    /// than its title, so the placeholder takes the palette's own soft ink
    /// instead of the system grey a bare title string would give it.
    static func prompt(_ text: String, _ scheme: ColorScheme) -> Text {
        Text(text).foregroundColor(inkSoft(scheme).opacity(0.8))
    }

    /// The palette handed to UIKit, which resolves light and dark from the
    /// trait collection it is drawn in rather than from a `ColorScheme` passed
    /// down the view tree. Wrapping the resolver — instead of baking in one
    /// scheme at launch — is what lets a bar set up here follow the user
    /// flipping appearance mid-session.
    private static func uiColor(_ resolve: @escaping (ColorScheme) -> Color) -> UIColor {
        UIColor { traits in
            UIColor(resolve(traits.userInterfaceStyle == .dark ? .dark : .light))
        }
    }

    /// Dresses the tab bar in the same paper the screens above it are drawn on:
    /// a canvas background under a warm hairline, terracotta for the selected
    /// tab, soft ink for the rest, and terracotta badges in place of the system
    /// red siren.
    ///
    /// The bar is UIKit's, and neither a `.font` inside `.tabItem` nor the
    /// palette's own colors survive the trip down, so all of it goes through the
    /// appearance proxy. `tintColor` is set alongside the item appearance
    /// because SwiftUI pushes its accent color onto the bar's tint, which would
    /// otherwise win over the selected icon color set here.
    ///
    /// Call once before the first `TabView` is built; a proxy read after that
    /// leaves already-created bars alone.
    static func applyTabBarAppearance() {
        let selected = uiColor(terracotta)
        let unselected = uiColor(inkSoft)

        let appearance = UITabBarAppearance()
        // Opaque rather than the default blur: these screens are paper, and a
        // frosted bar smearing the list underneath is the one piece of glass the
        // rest of the app dropped.
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = uiColor(canvas)
        appearance.shadowColor = uiColor(outline)

        let titleFont = UIFont(name: commissioner(.medium), size: 10)
        let badgeFont = UIFont(name: commissioner(.bold), size: 12)

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            for (state, color) in [(layout.normal, unselected), (layout.selected, selected)] {
                state.iconColor = color

                var title: [NSAttributedString.Key: Any] = [.foregroundColor: color]
                if let titleFont {
                    title[.font] = titleFont
                }
                state.titleTextAttributes = title

                state.badgeBackgroundColor = selected
                if let badgeFont {
                    state.badgeTextAttributes = [
                        .font: badgeFont,
                        .foregroundColor: UIColor.white,
                    ]
                }
            }
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selected
        UITabBar.appearance().unselectedItemTintColor = unselected
    }
}

// MARK: - Avatar Tints

/// A fill and its matching glyph color, picked together so an initial always has
/// contrast — a light peach circle needs dark type, a saturated terracotta one
/// needs white.
struct OrganicAvatarTint {
    let fill: Color
    let glyph: Color

    /// The muted, earthy set the avatars cycle through.
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

    /// The tint for a name. Keyed off the name so the same person keeps the same
    /// color between launches — `hashValue` is seeded per launch and would hand
    /// them a new one every time the app opened, so the scalars are summed.
    static func forName(_ name: String) -> OrganicAvatarTint {
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return all[seed % all.count]
    }
}

// MARK: - Organic Avatar

/// The round avatar these screens share: a profile photo when there is one,
/// otherwise a tinted circle carrying the first initial.
struct OrganicAvatar: View {
    let name: String
    let profilePictureURL: String?
    var size: CGFloat = 52
    /// Ring drawn around the circle, for stacked avatars that would otherwise
    /// bleed into each other.
    var ringColor: Color?
    /// Replaces the initial with an SF Symbol — used for group chats, which
    /// have a name but no single face behind it.
    var systemImage: String?

    private var tint: OrganicAvatarTint {
        OrganicAvatarTint.forName(name)
    }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        ProfilePictureView(profilePictureURL: profilePictureURL, size: size) {
            Circle()
                .fill(tint.fill)
                .frame(width: size, height: size)
                .overlay(glyph)
        }
        .overlay(
            Circle().strokeBorder(ringColor ?? .clear, lineWidth: ringColor == nil ? 0 : 3)
        )
    }

    @ViewBuilder
    private var glyph: some View {
        if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.40, weight: .medium))
                .foregroundColor(tint.glyph)
        } else {
            Text(initial)
                .font(OrganicPalette.title(size * 0.42))
                .foregroundColor(tint.glyph)
        }
    }
}

// MARK: - Card Surface

/// The raised paper surface shared by rows and cards on these screens.
struct OrganicCardBackground: View {
    let colorScheme: ColorScheme
    var fill: Color?
    var cornerRadius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill ?? OrganicPalette.surface(colorScheme))
            .shadow(color: OrganicPalette.shadow(colorScheme), radius: 10, x: 0, y: 4)
    }
}

// MARK: - List Rows

extension View {
    /// Strips the List chrome so each row is just the card it draws itself.
    /// Every surface on these screens carries its own shape and fill, so the row
    /// background, separators and default insets would only fight them.
    func organicRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// A section title rendered as an ordinary row. A `.plain` list pins its
    /// headers and draws its own backing behind them, which puts a grey bar
    /// across the cream canvas as soon as the list scrolls.
    func organicSectionLabelRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 2, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Header Button

/// The quiet round icon button these screens set beside a title.
///
/// Blush rather than filled terracotta: every one of these screens already has
/// a single loud primary action (the compose disc, the add-store FAB), and a
/// second filled circle next to it would just split the user's attention.
struct OrganicCircleButton: View {
    let systemImage: String
    var size: CGFloat = 54
    var glyphSize: CGFloat = 20
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: size, height: size)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pill Button

/// The filled terracotta pill these screens use for the one action that commits
/// something — save, submit, subscribe.
///
/// Reads `isEnabled` from the environment, so callers gate it with the ordinary
/// `.disabled(_:)` rather than passing a flag in.
struct OrganicPillButton: View {
    let title: String
    var systemImage: String?
    /// Swaps the title for a spinner while the work is in flight.
    var isLoading: Bool = false
    /// Fills the available width instead of hugging the title — for a form's
    /// submit button, which sits alone at the bottom of a screen.
    var fillsWidth: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(title)
                    .font(OrganicPalette.title(17))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: 54)
            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation Row

/// A row that leads somewhere: a terracotta glyph on a blush disc, a title, an
/// optional line of explanation, and a chevron.
///
/// Content only — the caller wraps it in the `NavigationLink` or `Button` that
/// makes it go, so the same row serves a push, a sheet and an external link.
struct OrganicNavRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    /// Overrides the glyph tint for a row that isn't about the app's own
    /// accent — sage for something already granted, rust for something
    /// destructive.
    var tint: Color?
    /// The trailing glyph. Nil leaves the row without one, for a row that is a
    /// statement rather than a door.
    var accessory: String? = "chevron.right"

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint ?? OrganicPalette.terracotta(colorScheme))
                .frame(width: 38, height: 38)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .multilineTextAlignment(.leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let accessory {
                Image(systemName: accessory)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrganicCardBackground(colorScheme: colorScheme))
        .contentShape(Rectangle())
    }
}

// MARK: - Section Label

/// The display heading above a group of cards.
struct OrganicSectionLabel: View {
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(OrganicPalette.display(22))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Text Fields

extension View {
    /// A text field sunk into the canvas rather than raised off it — the search
    /// pills, the message box, a form's inputs.
    func organicField(_ scheme: ColorScheme, height: CGFloat = 54) -> some View {
        self
            .padding(.horizontal, 18)
            .frame(height: height)
            .background(Capsule().fill(OrganicPalette.field(scheme)))
    }
}

// MARK: - Count Badge

/// The small filled capsule carrying a number — unread messages, items waiting
/// in a store, the size of a category.
struct OrganicCountBadge: View {
    let count: Int
    var fontSize: CGFloat = 13

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(count)")
            .font(OrganicPalette.title(fontSize))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
    }
}

// MARK: - Empty State

/// The shape an empty screen takes here: a glyph inside a blush disc, a display
/// line naming what is missing, a sentence of context, and — when there is
/// something to do about it — one terracotta pill.
struct OrganicEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    /// A quieter line under everything else, for a state the user can't act on
    /// (a list they only have view access to).
    var footnote: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(OrganicPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: 96, height: 96)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text(title)
                .font(OrganicPalette.display(26))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(OrganicPalette.title(17))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .frame(height: 52)
                        .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            if let footnote {
                Text(footnote)
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Organic Contact Row

/// A person in a picker — search results, recent contacts, group members.
/// Distinct from `ContactRow`, which still serves the share sheets that run on
/// the app's default styling.
struct OrganicContactRow: View {
    let contact: Contact
    /// Trailing accessory: a checkmark in a picker, nothing in a plain list.
    var isSelected: Bool = false
    var showsSelection: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            OrganicAvatar(
                name: contact.name,
                profilePictureURL: contact.profilePictureURL,
                size: 46
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .lineLimit(1)

                Text(contact.email)
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if showsSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(
                        isSelected
                            ? OrganicPalette.terracotta(colorScheme)
                            : OrganicPalette.outline(colorScheme)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OrganicCardBackground(colorScheme: colorScheme))
        .contentShape(Rectangle())
    }
}
