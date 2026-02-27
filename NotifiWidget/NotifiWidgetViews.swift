//
//  NotifiWidgetViews.swift
//  NotifiWidget
//
//  Widget views for all three supported sizes:
//    • Small  – up to 3 stores
//    • Medium – up to 5 stores
//    • Large  – up to 10 stores
//

import WidgetKit
import SwiftUI

// MARK: - Entry View (size dispatcher)

struct NotifiWidgetEntryView: View {
    let entry: StoreWidgetEntry
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(stores: entry.stores)
        case .systemMedium:
            MediumWidgetView(stores: entry.stores)
        case .systemLarge:
            LargeWidgetView(stores: entry.stores)
        default:
            SmallWidgetView(stores: entry.stores)
        }
    }
}

// MARK: - Small Widget  (up to 3 stores)

struct SmallWidgetView: View {
    let stores: [WidgetStoreData]

    private var displayed: [WidgetStoreData] { Array(stores.prefix(3)) }
    private var overflow: Int { max(stores.count - 3, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "cart.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("My Stores")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if stores.isEmpty {
                Spacer()
                Text("Open app to add stores")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(Array(displayed.enumerated()), id: \.offset) { _, store in
                    StoreRowCompact(store: store)
                }
                if overflow > 0 {
                    Text("+\(overflow) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
    }
}

// MARK: - Medium Widget  (up to 5 stores)

struct MediumWidgetView: View {
    let stores: [WidgetStoreData]

    private var displayed: [WidgetStoreData] { Array(stores.prefix(5)) }
    private var overflow: Int { max(stores.count - 5, 0) }
    private var totalReminders: Int { stores.reduce(0) { $0 + $1.reminderCount } }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "cart.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("My Stores")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if totalReminders > 0 {
                    Text("\(totalReminders) item\(totalReminders == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if stores.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Open app to add stores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(displayed.enumerated()), id: \.offset) { _, store in
                    StoreRowFull(store: store)
                }
                if overflow > 0 {
                    Text("+\(overflow) more store\(overflow == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
    }
}

// MARK: - Large Widget  (up to 10 stores)

struct LargeWidgetView: View {
    let stores: [WidgetStoreData]

    private var displayed: [WidgetStoreData] { Array(stores.prefix(10)) }
    private var overflow: Int { max(stores.count - 10, 0) }
    private var totalReminders: Int { stores.reduce(0) { $0 + $1.reminderCount } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "cart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Text("My Stores")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if totalReminders > 0 {
                    Text("\(totalReminders)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.blue)
                }
            }

            Divider()

            if stores.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "cart.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Open app to add stores")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(displayed.enumerated()), id: \.offset) { index, store in
                    StoreRowFull(store: store)
                    if index < displayed.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
                if overflow > 0 {
                    Text("+\(overflow) more store\(overflow == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
    }
}

// MARK: - Compact Row  (small widget)

struct StoreRowCompact: View {
    let store: WidgetStoreData

    var body: some View {
        HStack(spacing: 6) {
            StoreInitialBadge(name: store.storeName, size: 20, cornerRadius: 5, fontSize: .caption2)

            Text(store.storeName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if store.reminderCount > 0 {
                Text("\(store.reminderCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Full Row  (medium / large widget)

struct StoreRowFull: View {
    let store: WidgetStoreData

    var body: some View {
        HStack(spacing: 8) {
            StoreInitialBadge(name: store.storeName, size: 24, cornerRadius: 6, fontSize: .caption)

            Text(store.storeName)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if store.reminderCount > 0 {
                Text("\(store.reminderCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .clipShape(Capsule())
            } else {
                Text("0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Store Initial Badge

struct StoreInitialBadge: View {
    let name: String
    let size: CGFloat
    let cornerRadius: CGFloat
    let fontSize: Font

    private var initial: String { String(name.prefix(1).uppercased()) }

    private var color: Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        return palette[abs(name.hashValue) % palette.count]
    }

    var body: some View {
        Text(initial)
            .font(fontSize)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
