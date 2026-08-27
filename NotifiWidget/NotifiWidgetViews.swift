//
//  NotifiWidgetViews.swift
//  NotifiWidget
//
//  The widget wearing the app's organic look: a cream paper canvas, store rows
//  as raised paper cards, tinted initial discs and terracotta count badges —
//  the same shapes and palette as the Stores list inside the app.
//
//  All three families draw the same view; only `WidgetMetrics` differs, so a
//  change to the row shape lands on every size at once.
//
//  The metrics are sized against the *smallest* widget of each family (a 4.7"
//  device gives small and medium only 141pt of height), and the widget turns
//  off the system's content margins so the paper runs to the edge and the
//  padding below is the real padding. Rows have fixed heights and the layout is
//  top-anchored, so a taller device gets more paper under the last row rather
//  than a stretched card.
//

import WidgetKit
import SwiftUI

// MARK: - Entry View (size dispatcher)

struct NotifiWidgetEntryView: View {
    let entry: StoreWidgetEntry

    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.colorScheme) private var colorScheme

    private var metrics: WidgetMetrics {
        switch widgetFamily {
        case .systemMedium: return .medium
        case .systemLarge: return .large
        default: return .small
        }
    }

    var body: some View {
        StoresWidgetView(stores: entry.stores, metrics: metrics)
            .containerBackground(for: .widget) {
                OrganicPalette.canvas(colorScheme)
            }
    }
}

// MARK: - Metrics

/// Everything that changes between the three families. Sizes are deliberately
/// conservative: each layout has to clear the shortest widget of its family
/// without clipping.
struct WidgetMetrics {
    // Container
    let padding: CGFloat
    let headerGap: CGFloat
    /// Between one store card and the next.
    let cardGap: CGFloat

    // Header
    let discSize: CGFloat
    let discGlyph: CGFloat
    let titleSize: CGFloat
    /// The total across every store, as a badge beside the title. Off on the
    /// small family, where the title already fills the line.
    let showsTotal: Bool
    let totalBadgeSize: CGFloat

    // Rows
    /// How many cards the height allows, the overflow card included.
    let rowSlots: Int
    let avatarSize: CGFloat
    let nameSize: CGFloat
    let badgeSize: CGFloat
    let rowHPadding: CGFloat
    let rowVPadding: CGFloat
    let rowCorner: CGFloat
    /// Between the disc, the name and the badge inside a card.
    let rowSpacing: CGFloat
    let rowShadow: CGFloat

    // Empty state
    let emptyDisc: CGFloat
    let emptyGlyph: CGFloat
    let emptyTitleSize: CGFloat
    let emptyMessage: String?
    let emptyMessageSize: CGFloat

    var rowHeight: CGFloat { avatarSize + rowVPadding * 2 }

    static let small = WidgetMetrics(
        padding: 12, headerGap: 6, cardGap: 6,
        discSize: 20, discGlyph: 10, titleSize: 13,
        showsTotal: false, totalBadgeSize: 10,
        rowSlots: 3,
        avatarSize: 17, nameSize: 12, badgeSize: 10,
        rowHPadding: 8, rowVPadding: 4, rowCorner: 12, rowSpacing: 7, rowShadow: 0,
        emptyDisc: 44, emptyGlyph: 20, emptyTitleSize: 15,
        emptyMessage: nil, emptyMessageSize: 11
    )

    static let medium = WidgetMetrics(
        padding: 12, headerGap: 6, cardGap: 6,
        discSize: 20, discGlyph: 10, titleSize: 15,
        showsTotal: true, totalBadgeSize: 10,
        rowSlots: 3,
        avatarSize: 18, nameSize: 13, badgeSize: 11,
        rowHPadding: 10, rowVPadding: 3, rowCorner: 13, rowSpacing: 8, rowShadow: 2,
        emptyDisc: 48, emptyGlyph: 22, emptyTitleSize: 17,
        emptyMessage: "Open Allim to add the stores you shop at.", emptyMessageSize: 12
    )

    static let large = WidgetMetrics(
        padding: 14, headerGap: 8, cardGap: 7,
        discSize: 30, discGlyph: 15, titleSize: 21,
        showsTotal: true, totalBadgeSize: 12,
        rowSlots: 6,
        avatarSize: 24, nameSize: 15, badgeSize: 12,
        rowHPadding: 12, rowVPadding: 5, rowCorner: 16, rowSpacing: 10, rowShadow: 3,
        emptyDisc: 84, emptyGlyph: 38, emptyTitleSize: 24,
        emptyMessage: "Open Allim to add the stores you shop at.", emptyMessageSize: 14
    )
}

// MARK: - Widget Body

struct StoresWidgetView: View {
    let stores: [WidgetStoreData]
    let metrics: WidgetMetrics

    /// The stores that get a card of their own. One slot is given up to the
    /// overflow card when there are more stores than slots, so the layout never
    /// has to fit a line it didn't budget height for.
    private var displayed: [WidgetStoreData] {
        stores.count > metrics.rowSlots
            ? Array(stores.prefix(metrics.rowSlots - 1))
            : stores
    }

    private var overflow: Int { stores.count - displayed.count }

    private var totalReminders: Int { stores.reduce(0) { $0 + $1.reminderCount } }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.headerGap) {
            WidgetHeader(total: totalReminders, metrics: metrics)

            if stores.isEmpty {
                WidgetEmptyState(metrics: metrics)
            } else {
                VStack(spacing: metrics.cardGap) {
                    ForEach(Array(displayed.enumerated()), id: \.offset) { _, store in
                        StoreRow(store: store, metrics: metrics)
                    }

                    if overflow > 0 {
                        OverflowRow(count: overflow, metrics: metrics)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Header

/// A terracotta storefront on a blush disc, the title in the display face, and
/// the total waiting across every store — the same header furniture the app's
/// screens set beside their titles.
struct WidgetHeader: View {
    let total: Int
    let metrics: WidgetMetrics

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "storefront")
                .font(.system(size: metrics.discGlyph, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: metrics.discSize, height: metrics.discSize)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("My Stores")
                .font(OrganicPalette.display(metrics.titleSize))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            if metrics.showsTotal && total > 0 {
                CountBadge(count: total, fontSize: metrics.totalBadgeSize)
            }
        }
    }
}

// MARK: - Store Row

/// One store on its own paper card: the tinted initial disc the app gives a
/// store without a logo, its name in the body tier, and what's waiting there.
struct StoreRow: View {
    let store: WidgetStoreData
    let metrics: WidgetMetrics

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: metrics.rowSpacing) {
            StoreInitialDisc(name: store.storeName, size: metrics.avatarSize)

            Text(store.storeName)
                .font(OrganicPalette.body(metrics.nameSize, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            // A store with nothing waiting stays quiet, as it does in the list.
            if store.reminderCount > 0 {
                CountBadge(count: store.reminderCount, fontSize: metrics.badgeSize)
            }
        }
        .padding(.horizontal, metrics.rowHPadding)
        .frame(height: metrics.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: metrics.rowCorner, style: .continuous)
                .fill(OrganicPalette.surface(colorScheme))
                .shadow(
                    color: OrganicPalette.shadow(colorScheme),
                    radius: metrics.rowShadow,
                    x: 0,
                    y: metrics.rowShadow / 2
                )
        )
    }
}

/// The card that stands in for the stores that didn't fit. Same shape as a
/// store row so the stack keeps its rhythm, but in soft ink — it isn't a store,
/// it's a count of them.
struct OverflowRow: View {
    let count: Int
    let metrics: WidgetMetrics

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: metrics.rowSpacing) {
            Image(systemName: "ellipsis")
                .font(.system(size: metrics.avatarSize * 0.42, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: metrics.avatarSize, height: metrics.avatarSize)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("\(count) more store\(count == 1 ? "" : "s")")
                .font(OrganicPalette.body(metrics.nameSize))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.rowHPadding)
        .frame(height: metrics.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: metrics.rowCorner, style: .continuous)
                .fill(OrganicPalette.surface(colorScheme).opacity(0.6))
        )
    }
}

// MARK: - Store Initial Disc

/// The app's avatar circle, keyed off the store name so a store wears the same
/// tint here as it does everywhere else.
struct StoreInitialDisc: View {
    let name: String
    let size: CGFloat

    private var tint: OrganicAvatarTint { OrganicAvatarTint.forName(name) }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(tint.fill)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(OrganicPalette.title(size * 0.46))
                    .foregroundColor(tint.glyph)
            )
    }
}

// MARK: - Count Badge

/// The filled terracotta capsule the app puts a number in.
struct CountBadge: View {
    let count: Int
    let fontSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(count)")
            .font(OrganicPalette.title(fontSize))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
    }
}

// MARK: - Empty State

/// The shape an empty screen takes in the app, shrunk to the widget: a glyph
/// inside a blush disc, a display line naming what's missing, and — where
/// there's room for it — a sentence of context.
struct WidgetEmptyState: View {
    let metrics: WidgetMetrics

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            Image(systemName: "cart")
                .font(.system(size: metrics.emptyGlyph, weight: .light))
                .foregroundColor(OrganicPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: metrics.emptyDisc, height: metrics.emptyDisc)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("No stores yet")
                .font(OrganicPalette.display(metrics.emptyTitleSize))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .multilineTextAlignment(.center)

            if let message = metrics.emptyMessage {
                Text(message)
                    .font(OrganicPalette.body(metrics.emptyMessageSize))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
