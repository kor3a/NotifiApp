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
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading history...")
                        .tint(OrganicPalette.terracotta(colorScheme))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                } else if visibleEntries.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }

                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                }
            }
        }
        .onAppear {
            viewModel.fetchHistory(for: userStoreItem.reminderStoreId)
        }
    }

    private var emptyStateView: some View {
        OrganicEmptyState(
            systemImage: "clock.arrow.circlepath",
            title: "Nothing here yet",
            message: "Items you check off and remove from \(userStoreItem.store.name) will appear here."
        )
    }

    private var historyListView: some View {
        List {
            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    // The date label is an ordinary row rather than a section
                    // header: a `.plain` list pins its headers and draws its own
                    // backing behind them, which puts a grey bar across the
                    // paper canvas as soon as the list scrolls.
                    dateDivider(for: group.day)
                        .organicSectionLabelRow()

                    ForEach(group.entries) { entry in
                        HistoryRowView(entry: entry)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(OrganicCardBackground(colorScheme: colorScheme))
                            .organicRow()
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(10)
        .scrollContentBackground(.hidden)
    }

    /// A labeled divider separating entries from different check-off dates.
    private func dateDivider(for day: Date) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(OrganicPalette.outline(colorScheme).opacity(0.6))
                .frame(height: 1)

            Text(dayLabel(for: day))
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .fixedSize()

            Rectangle()
                .fill(OrganicPalette.outline(colorScheme).opacity(0.6))
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
}

// MARK: - History Row

struct HistoryRowView: View {
    let entry: ReminderHistoryEntry

    @Environment(\.colorScheme) private var colorScheme

    private var checkedOffDate: Date {
        Date(timeIntervalSince1970: entry.checkedOffAt)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Item name with the check-off date below it in italics
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))

                Text(checkedOffDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13))
                    .italic()
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer(minLength: 8)

            // Relevant reminder info: photo, quantity, who checked it off,
            // and who created it.
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    if let quantity = entry.quantity, quantity > 0 {
                        Text("Qty: \(quantity)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(OrganicPalette.field(colorScheme)))
                    }

                    if let photoURL = entry.photoURLs?.first {
                        photoThumbnail(for: photoURL)
                    }
                }

                if let checkedOffBy = entry.checkedOffBy, !checkedOffBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(OrganicPalette.sageInk(colorScheme))
                        Text(checkedOffBy)
                            .font(.system(size: 12))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    }
                }

                if let createdBy = entry.createdBy, !createdBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 11))
                            .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        Text("Added by \(createdBy)")
                            .font(.system(size: 12))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    }
                }
            }
        }
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
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            case .failure:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OrganicPalette.field(colorScheme))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 13))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    )
            case .empty:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OrganicPalette.field(colorScheme))
                    .frame(width: 44, height: 44)
                    .overlay(
                        ProgressView()
                            .tint(OrganicPalette.terracotta(colorScheme))
                    )
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
