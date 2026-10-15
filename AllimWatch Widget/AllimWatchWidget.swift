//
//  AllimWatchWidget.swift
//  AllimWatch Widget
//
//  The watch face and Smart Stack widget: which stores still have something to
//  pick up, and how much.
//
//  The widget never talks to the phone. The watch app writes a snapshot into
//  the shared App Group whenever its store list changes and asks WidgetKit to
//  reload, so the timeline here is a single entry that is current until the
//  app says otherwise.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline

struct AllimWatchEntry: TimelineEntry {
    let date: Date
    /// Nil until the watch app has run once and written a snapshot.
    let snapshot: WatchWidgetSnapshot?

    /// Puts the widget forward in the Smart Stack while there is shopping to
    /// do, and lets it sink when the lists are empty.
    var relevance: TimelineEntryRelevance? {
        TimelineEntryRelevance(score: (snapshot?.totalItems ?? 0) > 0 ? 1 : 0)
    }

    static let sample = AllimWatchEntry(
        date: Date(),
        snapshot: WatchWidgetSnapshot(
            stores: [
                .init(id: "sample-1", name: "Trader Joe's", reminderCount: 5),
                .init(id: "sample-2", name: "Costco", reminderCount: 3),
                .init(id: "sample-3", name: "Target", reminderCount: 1)
            ],
            isSignedIn: true
        )
    )
}

struct AllimWatchProvider: TimelineProvider {

    func placeholder(in context: Context) -> AllimWatchEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (AllimWatchEntry) -> Void) {
        // The face/Smart Stack gallery shows the sample, so someone choosing a
        // widget sees what it looks like with a list rather than an empty state.
        completion(context.isPreview ? .sample : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AllimWatchEntry>) -> Void) {
        // Nothing here changes with time — only with the store list, and the
        // watch app reloads the timeline whenever that changes.
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> AllimWatchEntry {
        AllimWatchEntry(date: Date(), snapshot: WatchWidgetSnapshot.load())
    }
}

// MARK: - Widget

struct AllimWatchWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WatchWidgetSnapshot.widgetKind, provider: AllimWatchProvider()) { entry in
            AllimWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Allim Stores")
        .description("Stores with items left to pick up.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

// MARK: - Views

struct AllimWatchWidgetView: View {

    let entry: AllimWatchEntry

    @Environment(\.widgetFamily) private var family

    private var snapshot: WatchWidgetSnapshot? { entry.snapshot }

    private var totalItems: Int { snapshot?.totalItems ?? 0 }

    var body: some View {
        content
            .widgetURL(WatchWidgetSnapshot.storeListURL)
            .widgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    // MARK: Rectangular — Smart Stack and the larger face slots

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "cart.fill")
                Text("Allim")
                Spacer(minLength: 4)
                if totalItems > 0 {
                    Text("\(totalItems)")
                        .monospacedDigit()
                }
            }
            .font(.headline)
            .widgetAccentable()

            rectangularBody
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var rectangularBody: some View {
        if let snapshot, !snapshot.isSignedIn {
            Text("Sign in on your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let snapshot {
            let stores = snapshot.storesWithItems
            if stores.isEmpty {
                Label("All done", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Two rows fit under the header; anything past that is a count.
                ForEach(stores.prefix(2)) { store in
                    HStack(spacing: 4) {
                        Text(store.name)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(store.reminderCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                if stores.count > 2 {
                    Text("+\(stores.count - 2) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Open Allim to load your stores")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Circular

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if totalItems > 0 {
                VStack(spacing: 0) {
                    Image(systemName: "cart.fill")
                        .font(.caption)
                        .widgetAccentable()
                    Text("\(totalItems)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                }
            } else {
                Image(systemName: snapshot == nil ? "cart" : "checkmark")
                    .font(.title3)
                    .widgetAccentable()
            }
        }
    }

    // MARK: Corner

    private var corner: some View {
        Image(systemName: "cart.fill")
            .font(.title3)
            .widgetAccentable()
            .widgetLabel {
                Text(totalItems > 0 ? "\(totalItems) to get" : "All done")
            }
    }

    // MARK: Inline

    @ViewBuilder
    private var inline: some View {
        if let first = snapshot?.storesWithItems.first {
            Label("\(totalItems) to get · \(first.name)", systemImage: "cart.fill")
        } else {
            Label("Allim: all done", systemImage: "cart")
        }
    }
}

// MARK: - Background

private extension View {
    /// watchOS 10 requires widgets to declare their container background; on
    /// watchOS 9 the modifier doesn't exist and isn't needed.
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(watchOS 10.0, *) {
            containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}
