//
//  OrganicTheme.swift
//  Geolocation_v1.0.0
//
//  The warm, paper-toned look shared by the people-facing screens.
//

import SwiftUI

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

    /// Display type for titles and section labels. The serif is what makes these
    /// screens read as organic rather than as another system list.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .serif)
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
                .font(.system(size: size * 0.42, weight: .bold, design: .serif))
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
struct OrganicCircleButton<Glyph: View>: View {
    var size: CGFloat = 54
    let action: () -> Void
    @ViewBuilder let glyph: () -> Glyph

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            glyph()
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: size, height: size)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))
        }
        .buttonStyle(.plain)
    }
}

extension OrganicCircleButton where Glyph == Image {
    /// The common case: an SF Symbol on the disc.
    init(
        systemImage: String,
        size: CGFloat = 54,
        glyphSize: CGFloat = 20,
        action: @escaping () -> Void
    ) {
        self.init(size: size, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: glyphSize, weight: .semibold))
        }
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
            .font(.system(size: fontSize, weight: .bold, design: .serif))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
    }
}

// MARK: - Empty State

/// The shape an empty screen takes here: a glyph inside a blush disc, a serif
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
                        .font(.system(size: 17, weight: .bold, design: .serif))
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
