//
//  NotifiWidgetViews.swift
//  NotifiWidget
//
//  The widget wearing the app's look: the palette's canvas, store rows as
//  raised cards, tinted initial discs and accent count badges — the same shapes
//  and palette as the Stores list inside the app.
//
//  All three families draw the same view; only `WidgetMetrics` differs, so a
//  change to the row shape lands on every size at once.
//
//  How many stores fit isn't declared, it's measured: a family's widget is a
//  different height on every phone (a 4.7" device gives the medium widget 141pt
//  where a 6.9" gives 170), so the rows are handed the space that's left after
//  the header and count the cards that fit in it. Cards keep a fixed height on
//  every device — the slack buys another store rather than taller paper.
//
//  The widget also turns off the system's content margins, so the paper runs to
//  the edge and the padding below is the real padding.
//

import WidgetKit
import SwiftUI
import UIKit

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

    /// How many cards fit in `height` — the overflow card counting as one of
    /// them. The last card sits flush against the bottom padding when the
    /// division comes out even.
    func slots(inRowsHeight height: CGFloat) -> Int {
        let pitch = rowHeight + cardGap
        guard pitch > 0 else { return 1 }
        return max(1, Int((height + cardGap) / pitch))
    }

    static let small = WidgetMetrics(
        padding: 12, headerGap: 6, cardGap: 6,
        discSize: 20, discGlyph: 10, titleSize: 13,
        showsTotal: false, totalBadgeSize: 10,
        avatarSize: 17, nameSize: 12, badgeSize: 10,
        rowHPadding: 8, rowVPadding: 4, rowCorner: 12, rowSpacing: 7, rowShadow: 0,
        emptyDisc: 44, emptyGlyph: 20, emptyTitleSize: 15,
        emptyMessage: nil, emptyMessageSize: 11
    )

    static let medium = WidgetMetrics(
        padding: 12, headerGap: 6, cardGap: 6,
        discSize: 20, discGlyph: 10, titleSize: 15,
        showsTotal: true, totalBadgeSize: 10,
        avatarSize: 18, nameSize: 13, badgeSize: 11,
        rowHPadding: 10, rowVPadding: 3, rowCorner: 13, rowSpacing: 8, rowShadow: 2,
        emptyDisc: 48, emptyGlyph: 22, emptyTitleSize: 17,
        emptyMessage: "Open Allim to add the stores you shop at.", emptyMessageSize: 12
    )

    static let large = WidgetMetrics(
        padding: 14, headerGap: 8, cardGap: 7,
        discSize: 30, discGlyph: 15, titleSize: 21,
        showsTotal: true, totalBadgeSize: 12,
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

    private var totalReminders: Int { stores.reduce(0) { $0 + $1.reminderCount } }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.headerGap) {
            WidgetHeader(total: totalReminders, metrics: metrics)

            if stores.isEmpty {
                WidgetEmptyState(metrics: metrics)
            } else {
                // The reader takes whatever the header left, which is exactly
                // the height the cards have to divide up.
                GeometryReader { geometry in
                    StoreStack(
                        stores: stores,
                        metrics: metrics,
                        slots: metrics.slots(inRowsHeight: geometry.size.height)
                    )
                }
            }
        }
        .padding(metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The stack of store cards, filling the slots it was measured for. One slot
/// goes to the overflow card when there are more stores than fit, so the tally
/// never costs height the layout didn't count.
private struct StoreStack: View {
    let stores: [WidgetStoreData]
    let metrics: WidgetMetrics
    let slots: Int

    private var displayed: [WidgetStoreData] {
        stores.count > slots ? Array(stores.prefix(slots - 1)) : stores
    }

    private var overflow: Int { stores.count - displayed.count }

    var body: some View {
        VStack(spacing: metrics.cardGap) {
            ForEach(Array(displayed.enumerated()), id: \.offset) { _, store in
                StoreRow(store: store, metrics: metrics)
            }

            if overflow > 0 {
                OverflowRow(count: overflow, metrics: metrics)
            }

            Spacer(minLength: 0)
        }
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
            StoreLogoDisc(store: store, size: metrics.avatarSize)

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

// MARK: - Store Logo Disc

/// The store's logo in a circle, as the app's rows draw it — falling back to
/// the tinted initial the avatars use when the app hasn't cached a logo for
/// this store, or hasn't exported it into the group container yet.
///
/// The file was downscaled on the way in, so reading it here is cheap enough to
/// do while the view builds; WidgetKit renders a timeline entry once.
struct StoreLogoDisc: View {
    let store: WidgetStoreData
    let size: CGFloat

    private var logo: UIImage? {
        store.logoFileName.flatMap(SharedContainer.logo(named:))
    }

    private var tint: OrganicAvatarTint {
        OrganicAvatarTint.forName(store.storeName)
    }

    private var initial: String {
        String(store.storeName.trimmingCharacters(in: .whitespaces).prefix(1))
            .uppercased()
    }

    var body: some View {
        if let logo {
            Image(uiImage: logo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
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
}

// MARK: - Count Badge

/// The filled capsule the app puts a number in. Takes the warm accent rather
/// than the brand teal: a badge is the widget saying something is waiting for
/// you, which is the one thing the accent is reserved for.
struct CountBadge: View {
    let count: Int
    let fontSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(count)")
            .font(OrganicPalette.title(fontSize))
            .foregroundColor(OrganicPalette.onHighlight(colorScheme))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(OrganicPalette.highlight(colorScheme)))
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
