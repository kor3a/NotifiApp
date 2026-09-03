//
//  OrganicTheme.swift
//  Geolocation_v1.0.0
//
//  The look shared by every screen in the app.
//

import SwiftUI
import UIKit

// MARK: - Palette

/// The palette behind Friends, Messages, Conversations, Stores and Reminders —
/// and, through `AppTheme`, everything else.
///
/// Every value here is an `AllimColor` token; nothing in this file names a
/// color of its own. The app used to run on paper and clay — a cream canvas and
/// a terracotta accent — and now runs on the Allim aisle palette: quiet neutral
/// chrome, one saturated brand teal for the things you can act on, and a warm
/// accent held back for the moments that are actually about a reminder (a badge
/// with something waiting in it, "you're near Trader Joe's"). Category color is
/// the only other saturated thing allowed on screen.
///
/// The names below are the old ones on purpose. Roughly a thousand call sites
/// across forty files ask for `terracotta` and `blush`, and renaming them would
/// have been a thousand-line diff that changed no pixels — so the names stayed
/// and the values moved. Read `terracotta` as "the accent that acts" and
/// `sage` as "the one non-accent hue"; `AllimColor` underneath says what each
/// one actually is. New code can reach for either.
enum OrganicPalette {
    /// Full-bleed backdrop behind a whole screen.
    static func canvas(_ scheme: ColorScheme) -> Color {
        AllimColor.canvas(scheme)
    }

    /// Card and row surfaces — a shade lifted off the canvas.
    static func surface(_ scheme: ColorScheme) -> Color {
        AllimColor.card(scheme)
    }

    /// A card sitting on another card — a sheet's inner panel, a menu.
    static func surfaceRaised(_ scheme: ColorScheme) -> Color {
        AllimColor.cardRaised(scheme)
    }

    /// Recessed inputs — search pills, the message field. Sunk into the canvas
    /// rather than raised off it.
    static func field(_ scheme: ColorScheme) -> Color {
        AllimColor.field(scheme)
    }

    static func ink(_ scheme: ColorScheme) -> Color {
        AllimColor.textPrimary(scheme)
    }

    static func inkSoft(_ scheme: ColorScheme) -> Color {
        AllimColor.textSecondary(scheme)
    }

    /// The quietest readable tier — a timestamp, a disabled row, a hint.
    static func inkMuted(_ scheme: ColorScheme) -> Color {
        AllimColor.textMuted(scheme)
    }

    /// Primary action color — add buttons, sent bubbles, action glyphs, the
    /// selected tab. The brand teal.
    static func terracotta(_ scheme: ColorScheme) -> Color {
        AllimColor.primary(scheme)
    }

    /// The pressed state of `terracotta`, for a surface that draws its own
    /// press feedback rather than fading.
    static func terracottaPressed(_ scheme: ColorScheme) -> Color {
        AllimColor.primaryPressed(scheme)
    }

    /// Type and glyphs drawn *on* `terracotta`. Not white: in dark mode the
    /// accent is a light teal, and white on it is barely legible.
    static func onTerracotta(_ scheme: ColorScheme) -> Color {
        AllimColor.onPrimary(scheme)
    }

    /// Tinted wash of the accent, for cards that need answering and quiet icon
    /// buttons.
    static func blush(_ scheme: ColorScheme) -> Color {
        AllimColor.primaryWash(scheme)
    }

    /// Type drawn on `blush` — a shade deeper than the accent itself, so a
    /// label on a wash keeps its contrast in both schemes.
    static func inkOnBlush(_ scheme: ColorScheme) -> Color {
        AllimColor.textOnWash(scheme)
    }

    /// The warm accent, held back for the app's one subject: a reminder. Unread
    /// badges, "you're near <store>", a list with something waiting in it.
    /// Everything you can *press* is `terracotta`; this is what the app is
    /// telling you about.
    static func highlight(_ scheme: ColorScheme) -> Color {
        AllimColor.accent(scheme)
    }

    /// The wash under `highlight`.
    static func highlightWash(_ scheme: ColorScheme) -> Color {
        AllimColor.accentWash(scheme)
    }

    /// Type and glyphs drawn on `highlight`.
    static func onHighlight(_ scheme: ColorScheme) -> Color {
        AllimColor.onAccent(scheme)
    }

    /// The one non-accent hue, kept for a single idea per screen — Family in
    /// Friends, a store share in a chat, a list someone else shared with you.
    static func sage(_ scheme: ColorScheme) -> Color {
        AllimColor.successWash(scheme)
    }

    static func sageInk(_ scheme: ColorScheme) -> Color {
        AllimColor.success(scheme)
    }

    /// Type and glyphs drawn on a filled `sageInk` surface — the accept button
    /// on a friend request, a "done" pill.
    static func onSageInk(_ scheme: ColorScheme) -> Color {
        AllimColor.onSuccess(scheme)
    }

    /// Destructive and out-of-stock states — a delete, a failed send, an item
    /// the store is out of.
    static func rust(_ scheme: ColorScheme) -> Color {
        AllimColor.danger(scheme)
    }

    /// The wash under `rust`, for a card carrying a warning rather than a
    /// button that does something irreversible.
    static func rustWash(_ scheme: ColorScheme) -> Color {
        AllimColor.dangerWash(scheme)
    }

    /// Type and glyphs drawn on `rust`.
    static func onRust(_ scheme: ColorScheme) -> Color {
        AllimColor.onDanger(scheme)
    }

    /// Something that needs attention but isn't an error — a lapsed
    /// subscription, a permission the app is missing.
    static func caution(_ scheme: ColorScheme) -> Color {
        AllimColor.warning(scheme)
    }

    static func cautionWash(_ scheme: ColorScheme) -> Color {
        AllimColor.warningWash(scheme)
    }

    /// Hairline used to outline ghost buttons and quiet rows. Translucent, so
    /// it works on cards, washes and photo backgrounds alike.
    static func outline(_ scheme: ColorScheme) -> Color {
        AllimColor.hairline(scheme)
    }

    /// The opaque divider between rows inside one card, where a translucent
    /// hairline would show the shadow through it.
    static func divider(_ scheme: ColorScheme) -> Color {
        AllimColor.border(scheme)
    }

    /// The heavier border, for a control that has to read as an edge — a
    /// segmented picker, an unselected swatch.
    static func outlineStrong(_ scheme: ColorScheme) -> Color {
        AllimColor.borderStrong(scheme)
    }

    /// Cards sit on a neutral canvas, so their shadow is neutral.
    static func shadow(_ scheme: ColorScheme) -> Color {
        AllimColor.shadow(scheme)
    }

    /// The scrim behind a modal.
    static func scrim(_ scheme: ColorScheme) -> Color {
        AllimColor.scrim(scheme)
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

    /// Dresses UIKit's tab bar in the same palette the screens above it are
    /// drawn from: a canvas background under a hairline, the accent for the
    /// selected tab, soft ink for the rest, and the warm highlight on badges in
    /// place of the system red siren.
    ///
    /// A backstop rather than the bar the user navigates from. `OrganicTabBar`
    /// is what they see and HomeView hides this one under it — built against
    /// the current SDK it renders as system glass, and the appearance proxy can
    /// only tint that glass, never turn it into canvas. What this still buys is
    /// the frame or two before the hide takes effect, and anywhere a tab bar
    /// slips out from under the SwiftUI modifier.
    ///
    /// Call once before the first `TabView` is built; a proxy read after that
    /// leaves already-created bars alone.
    static func applyTabBarAppearance() {
        let selected = uiColor(terracotta)
        let unselected = uiColor(inkSoft)

        let appearance = UITabBarAppearance()
        // Opaque rather than the default blur: these screens are flat surfaces
        // on a flat canvas, and a frosted bar smearing the list underneath is
        // the one piece of glass the rest of the app dropped.
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AllimColor.canvas.uiColor
        appearance.shadowColor = AllimColor.border.uiColor

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

                state.badgeBackgroundColor = AllimColor.accent.uiColor
                if let badgeFont {
                    state.badgeTextAttributes = [
                        .font: badgeFont,
                        .foregroundColor: AllimColor.onAccent.uiColor,
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

/// A fill and its matching glyph color, picked together so an initial always
/// has contrast.
///
/// Both come straight out of the category palette — a category's `tint` behind
/// its `label` — which is what keeps an avatar quiet next to the one saturated
/// thing on the row, and what guarantees the pair reads in both schemes
/// without a second set of numbers to keep in step.
struct OrganicAvatarTint {
    let fill: Color
    let glyph: Color

    private init(_ category: GroceryCategory) {
        let palette = category.palette
        self.fill = palette.tint.color
        self.glyph = palette.label.color
    }

    /// The set the avatars cycle through. Six hue families, far enough apart
    /// that two people in the same conversation never look like each other.
    static let all: [OrganicAvatarTint] = [
        OrganicAvatarTint(.produce),
        OrganicAvatarTint(.dairy),
        OrganicAvatarTint(.meat),
        OrganicAvatarTint(.pantry),
        OrganicAvatarTint(.snacks),
        OrganicAvatarTint(.household),
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
/// otherwise the drawn portrait that stands in until someone uploads theirs.
struct OrganicAvatar: View {
    let name: String
    let profilePictureURL: String?
    var size: CGFloat = 52
    /// Ring drawn around the circle, for stacked avatars that would otherwise
    /// bleed into each other.
    var ringColor: Color?
    /// Replaces the portrait with an SF Symbol — used for group chats, which
    /// have a name but no single face behind it.
    var systemImage: String?
    /// Draws the initial instead of a portrait, for a row where a stand-in
    /// face would be read as a photo the person chose.
    var usesPortrait: Bool = true

    private var tint: OrganicAvatarTint {
        OrganicAvatarTint.forName(name)
    }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        ProfilePictureView(profilePictureURL: profilePictureURL, size: size) {
            placeholder
        }
        .overlay(
            Circle().strokeBorder(ringColor ?? .clear, lineWidth: ringColor == nil ? 0 : 3)
        )
    }

    /// What stands in for a photo: the group glyph, then the portrait, and the
    /// tinted initial only when there is no name to draw a face from.
    @ViewBuilder
    private var placeholder: some View {
        if systemImage == nil, usesPortrait, let portrait = PortraitAvatar.image(for: name) {
            Image(uiImage: portrait)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(tint.fill)
                .frame(width: size, height: size)
                .overlay(glyph)
        }
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

/// The raised surface shared by rows and cards on these screens.
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
    /// across the canvas as soon as the list scrolls.
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

/// The filled accent pill these screens use for the one action that commits
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
                        .tint(OrganicPalette.onTerracotta(colorScheme))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(title)
                    .font(OrganicPalette.title(17))
            }
            .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
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

/// A row that leads somewhere: an accent glyph on a blush disc, a title, an
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
///
/// Takes the warm highlight rather than the accent: a badge is the app telling
/// you something is waiting, not a thing you press.
struct OrganicCountBadge: View {
    let count: Int
    var fontSize: CGFloat = 13

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(count)")
            .font(OrganicPalette.title(fontSize))
            .foregroundColor(OrganicPalette.onHighlight(colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(OrganicPalette.highlight(colorScheme)))
    }
}

// MARK: - Empty State

/// The shape an empty screen takes here: a glyph inside a blush disc, a display
/// line naming what is missing, a sentence of context, and — when there is
/// something to do about it — one accent pill.
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
                        .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
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
