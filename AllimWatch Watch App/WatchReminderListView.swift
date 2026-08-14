//
//  WatchReminderListView.swift
//  AllimWatch Watch App
//
//  One store's list, and the point of the whole watch app: tapping a row checks
//  the item off without taking the phone out.
//

import SwiftUI

struct WatchReminderListView: View {

    let store: WatchStorePayload

    @EnvironmentObject private var dataStore: WatchDataStore

    private var reminders: [WatchReminderPayload] {
        dataStore.reminders[store.id] ?? []
    }

    private var isLoading: Bool {
        dataStore.loadingStoreIds.contains(store.id)
    }

    /// Category order matching the phone: named categories alphabetically, with
    /// uncategorized items last.
    private var categories: [String] {
        var named = Set<String>()
        var hasUncategorized = false

        for reminder in reminders {
            if let category = reminder.category, !category.isEmpty {
                named.insert(category)
            } else {
                hasUncategorized = true
            }
        }

        var ordered = named.sorted()
        if hasUncategorized {
            ordered.append(Self.uncategorized)
        }
        return ordered
    }

    private static let uncategorized = "Uncategorized"

    private func reminders(in category: String) -> [WatchReminderPayload] {
        reminders.filter { reminder in
            guard let itemCategory = reminder.category, !itemCategory.isEmpty else {
                return category == Self.uncategorized
            }
            return itemCategory == category
        }
    }

    var body: some View {
        Group {
            if reminders.isEmpty {
                if isLoading {
                    ProgressView()
                } else if dataStore.isPhoneReachable {
                    WatchMessageView(
                        symbol: "checkmark.circle",
                        title: "Nothing to Get",
                        message: "This list is empty."
                    )
                } else {
                    // Never fetched this store, and can't now — an empty list
                    // would be a guess dressed up as an answer.
                    WatchMessageView(
                        symbol: "iphone.slash",
                        title: "iPhone Not Reachable",
                        message: "This list will load once your iPhone is nearby."
                    )
                }
            } else {
                list
            }
        }
        .navigationTitle(store.name)
        .onAppear { dataStore.refreshReminders(for: store.id) }
    }

    private var list: some View {
        List {
            WatchStatusRow()

            // A list with a single unnamed group reads better without a section
            // header taking up a line on a screen this small.
            if categories == [Self.uncategorized] {
                rows(for: reminders)
            } else {
                ForEach(categories, id: \.self) { category in
                    Section(category) {
                        rows(for: reminders(in: category))
                    }
                }
            }
        }
        .refreshable { dataStore.refreshReminders(for: store.id) }
    }

    private func rows(for items: [WatchReminderPayload]) -> some View {
        ForEach(items) { reminder in
            WatchReminderRow(
                reminder: reminder,
                isPending: dataStore.pendingToggleIds.contains(reminder.id),
                canEdit: store.canEdit
            ) {
                dataStore.toggle(reminderId: reminder.id, in: store.id)
            }
        }
    }
}

// MARK: - Row

struct WatchReminderRow: View {

    let reminder: WatchReminderPayload
    let isPending: Bool
    /// False for stores shared read-only — the row still shows the item's state
    /// but tapping does nothing, rather than promising a write the phone would
    /// reject.
    let canEdit: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: { if canEdit { onToggle() } }) {
            HStack(spacing: 10) {
                Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(reminder.isDone ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .lineLimit(2)
                        .strikethrough(reminder.isDone)
                        .foregroundStyle(reminder.isDone ? .secondary : .primary)

                    if reminder.isOutOfStock {
                        Label("Out of stock", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if isPending {
                        Label("Syncing", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
    }

    /// Quantity rides along with the title so a two-line row stays two lines.
    private var title: String {
        guard let quantity = reminder.quantity, quantity > 1 else { return reminder.title }
        return "\(reminder.title) ×\(quantity)"
    }
}

#Preview {
    NavigationStack {
        WatchReminderListView(
            store: WatchStorePayload(
                id: "preview",
                name: "Trader Joe's",
                reminderCount: 3,
                imageURL: nil,
                canEdit: true
            )
        )
        .environmentObject(WatchDataStore.shared)
    }
}
