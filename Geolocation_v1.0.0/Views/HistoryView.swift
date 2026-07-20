//
//  HistoryView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 7/20/26.
//

import SwiftUI

/// Shows the checked-off items that are no longer in the store's reminder list,
/// newest first, with a divider between different check-off dates.
struct HistoryView: View {
    let userStoreItem: UserStoreItem
    /// Normalized (lowercased, trimmed) titles currently visible in the
    /// ReminderView. History entries matching one are hidden — the item is
    /// back on the list, so it isn't "no longer there."
    var currentReminderTitles: Set<String> = []
    @StateObject private var viewModel = ReminderHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var visibleEntries: [ReminderHistoryEntry] {
        viewModel.entries.filter { entry in
            !currentReminderTitles.contains(
                entry.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    /// Entries grouped by check-off day, newest day first; entries within a
    /// day are newest first as well.
    private var groupedByDay: [(day: Date, entries: [ReminderHistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: visibleEntries) { entry in
            calendar.startOfDay(for: Date(timeIntervalSince1970: entry.checkedOffAt))
        }
        return groups.keys.sorted(by: >).map { day in
            (day: day, entries: groups[day]!.sorted { $0.checkedOffAt > $1.checkedOffAt })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading history...")
                } else if visibleEntries.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .background(
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchHistory(for: userStoreItem.reminderStoreId)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No History Yet")
                .font(.title2)
                .bold()
            Text("Items you check off and remove from \(userStoreItem.store.name) will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyListView: some View {
        List {
            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.entries) { entry in
                        HistoryRowView(entry: entry)
                            .listRowBackground(cardRowBackground)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    dateDivider(for: group.day)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// A labeled divider separating entries from different check-off dates.
    private func dateDivider(for day: Date) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)
            Text(dayLabel(for: day))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .fixedSize()
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)
        }
        .padding(.vertical, 6)
    }

    private func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private var cardRowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.cardBorder(for: colorScheme),
                        lineWidth: 1.5
                    )
            )
            .padding(.vertical, 4)
    }
}

// MARK: - History Row

struct HistoryRowView: View {
    let entry: ReminderHistoryEntry

    private var checkedOffDate: Date {
        Date(timeIntervalSince1970: entry.checkedOffAt)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Item name with the check-off date below it in italics
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 17, weight: .medium))

                Text(checkedOffDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Relevant reminder info: photo, quantity, who checked it off,
            // and who created it.
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    if let quantity = entry.quantity, quantity > 0 {
                        Text("Qty: \(quantity)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }

                    if let photoURL = entry.photoURLs?.first {
                        photoThumbnail(for: photoURL)
                    }
                }

                if let checkedOffBy = entry.checkedOffBy, !checkedOffBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(checkedOffBy)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let createdBy = entry.createdBy, !createdBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.caption2)
                            .foregroundStyle(Color.appAccent)
                        Text("Added by \(createdBy)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func photoThumbnail(for urlString: String) -> some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipped()
                    .cornerRadius(8)
            case .failure:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            case .empty:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(ProgressView())
            @unknown default:
                EmptyView()
            }
        }
    }
}

#Preview {
    HistoryView(userStoreItem: UserStoreItem(
        id: "preview_user_store",
        store: Store(name: "Trader Joe's"),
        permission: .owner,
        sharedStoreGroupId: nil,
        sourceUserStoreId: nil,
        sharedFromName: nil,
        sharedFromId: nil,
        sharedWith: nil,
        notificationsEnabled: true
    ))
}
