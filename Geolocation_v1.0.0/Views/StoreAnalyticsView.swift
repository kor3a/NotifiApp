//
//  StoreAnalyticsView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 7/22/26.
//

import SwiftUI
import Charts

/// Premium analytics page for a single store: how often items were gotten
/// over time (weekly / monthly / all time), the category breakdown, the
/// most-gotten items, and which weekdays the user shops on. Data comes from
/// the same `reminder_history` collection HistoryView reads, but here every
/// past check-off counts even when the item is back on the list.
struct StoreAnalyticsView: View {
    let userStoreItem: UserStoreItem
    @StateObject private var viewModel = ReminderHistoryViewModel()
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var timeRange: AnalyticsTimeRange = .allTime
    @State private var showingPaywall = false

    private var filteredEntries: [ReminderHistoryEntry] {
        StoreAnalytics.entries(in: viewModel.entries, range: timeRange)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                if !subscriptionManager.isSubscribed {
                    lockedView
                } else if viewModel.isLoading {
                    ProgressView("Loading analytics...")
                        .tint(OrganicPalette.terracotta(colorScheme))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                } else if viewModel.entries.isEmpty {
                    emptyStateView
                } else {
                    analyticsContent
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
                    Text("Analytics")
                        .font(OrganicPalette.title(17))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                }
            }
        }
        .onAppear {
            viewModel.fetchHistory(for: userStoreItem.reminderStoreId)
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView()
        }
    }

    // MARK: - Locked (non-subscriber) State

    private var lockedView: some View {
        OrganicEmptyState(
            systemImage: "chart.bar.xaxis",
            title: "Store Analytics",
            message: "See how often you get items at \(userStoreItem.store.name), your category breakdown, most-gotten items, and shopping patterns.",
            actionTitle: "Unlock with Premium",
            action: { showingPaywall = true }
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        OrganicEmptyState(
            systemImage: "chart.bar.xaxis",
            title: "No data yet",
            message: "Analytics build up as you check off and clear items at \(userStoreItem.store.name). Come back after a few shopping trips."
        )
    }

    // MARK: - Analytics Content

    private var analyticsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                timeRangePicker

                if filteredEntries.isEmpty {
                    emptyRangeCard
                } else {
                    summaryTiles
                    overTimeCard
                    categoryCard
                    topItemsCard
                    weekdayCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    /// The range filter, in one row above the charts. A segmented control keeps
    /// the system's grey capsule on the canvas, so it is three pills.
    private var timeRangePicker: some View {
        HStack(spacing: 6) {
            ForEach(AnalyticsTimeRange.allCases) { range in
                let isSelected = timeRange == range

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { timeRange = range }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(
                            isSelected
                                ? OrganicPalette.onTerracotta(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            Capsule().fill(
                                isSelected ? OrganicPalette.terracotta(colorScheme) : .clear
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(OrganicPalette.field(colorScheme)))
    }

    private var emptyRangeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(OrganicPalette.terracotta(colorScheme).opacity(0.55))

            Text("Nothing checked off in this period")
                .font(.system(size: 15))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    // MARK: - Summary Tiles

    private var summaryTiles: some View {
        let itemCount = filteredEntries.count
        let trips = StoreAnalytics.shoppingTripCount(for: filteredEntries)
        let avgPerTrip = trips > 0 ? Double(itemCount) / Double(trips) : 0

        return HStack(spacing: 12) {
            statTile(value: "\(itemCount)", label: "Items Gotten")
            statTile(value: "\(trips)", label: "Shopping Trips")
            statTile(value: String(format: "%.1f", avgPerTrip), label: "Avg per Trip")
        }
    }

    /// The number wears ink rather than the accent: it is text, and a screen of
    /// terracotta figures competes with the bars, which are what the colour is
    /// for.
    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OrganicPalette.display(24))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    // MARK: - Items Over Time

    private var overTimeCard: some View {
        let buckets = StoreAnalytics.timeBuckets(for: filteredEntries, range: timeRange)
        let unit: Calendar.Component = timeRange == .allTime ? .month : .day

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "chart.bar.fill", title: "Items Over Time")

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Date", bucket.date, unit: unit),
                    y: .value("Items", bucket.count)
                )
                .foregroundStyle(OrganicPalette.terracotta(colorScheme))
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: xAxisValues) { _ in
                    AxisGridLine().foregroundStyle(OrganicPalette.outline(colorScheme))
                    AxisValueLabel(format: xAxisFormat)
                        .foregroundStyle(OrganicPalette.inkSoft(colorScheme))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(OrganicPalette.outline(colorScheme))
                    AxisValueLabel()
                        .foregroundStyle(OrganicPalette.inkSoft(colorScheme))
                }
            }
            .frame(height: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    private var xAxisValues: AxisMarkValues {
        switch timeRange {
        case .week: return .stride(by: .day)
        case .month: return .stride(by: .day, count: 7)
        case .allTime: return .automatic
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch timeRange {
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.month(.abbreviated).day()
        case .allTime: return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    // MARK: - Category Breakdown

    private var categoryCard: some View {
        let categories = StoreAnalytics.categoryBreakdown(for: filteredEntries)
        let total = filteredEntries.count
        let maxCount = categories.first?.count ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "square.grid.2x2", title: "By Category")

            ForEach(categories) { stat in
                // Each aisle in its own hue, matching the section headers in
                // the reminder list this breakdown is counting.
                let palette = GroceryCategory.matching(stat.category).palette

                HStack(spacing: 10) {
                    Image(systemName: CategoryIcon.symbol(for: stat.category))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.label(colorScheme))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(palette.tint(colorScheme)))

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(stat.category)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(OrganicPalette.ink(colorScheme))

                            Spacer()

                            Text("\(stat.count)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(OrganicPalette.ink(colorScheme))

                            Text(percentLabel(stat.count, of: total))
                                .font(.system(size: 12))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                .frame(width: 44, alignment: .trailing)
                        }

                        proportionBar(count: stat.count, max: maxCount, fill: palette.dot(colorScheme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    private func percentLabel(_ count: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(count) / Double(total) * 100).rounded()))%"
    }

    /// `fill` carries the category's own hue where the caller has one, so a
    /// row's bar and its glyph agree; the accent is the fallback for the bars
    /// that aren't about a category.
    private func proportionBar(
        count: Int,
        max maxCount: Int,
        fill: Color? = nil
    ) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(OrganicPalette.field(colorScheme))
                Capsule()
                    .fill(fill ?? OrganicPalette.terracotta(colorScheme))
                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(max(maxCount, 1)))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Most Gotten Items

    private var topItemsCard: some View {
        let items = StoreAnalytics.topItems(for: filteredEntries, limit: 10)

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "trophy", title: "Most Gotten Items")

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(OrganicPalette.title(12))
                        .foregroundColor(
                            index < 3
                                ? OrganicPalette.onTerracotta(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme)
                        )
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(
                                index < 3
                                    ? OrganicPalette.terracotta(colorScheme)
                                    : OrganicPalette.field(colorScheme)
                            )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(OrganicPalette.ink(colorScheme))

                        Text("Last gotten \(item.lastGotten.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.count)\u{00D7}")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(OrganicPalette.ink(colorScheme))

                        if item.totalQuantity > item.count {
                            Text("Qty \(item.totalQuantity)")
                                .font(.system(size: 12))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    // MARK: - Shopping Pattern (Weekdays)

    private var weekdayCard: some View {
        let weekdays = StoreAnalytics.weekdayBreakdown(for: filteredEntries)
        let busiest = StoreAnalytics.busiestWeekday(for: filteredEntries)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "calendar", title: "Shopping Pattern")

            Chart(weekdays) { stat in
                BarMark(
                    x: .value("Day", stat.label),
                    y: .value("Items", stat.count)
                )
                .foregroundStyle(OrganicPalette.terracotta(colorScheme))
                .cornerRadius(4)
            }
            .chartXScale(domain: weekdays.map { $0.label })
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(OrganicPalette.inkSoft(colorScheme))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(OrganicPalette.outline(colorScheme))
                    AxisValueLabel()
                        .foregroundStyle(OrganicPalette.inkSoft(colorScheme))
                }
            }
            .frame(height: 140)

            if let busiest {
                Label("You check off the most items on \(busiest)s", systemImage: "lightbulb")
                    .font(.system(size: 13))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    // MARK: - Shared

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))

            Text(title)
                .font(OrganicPalette.display(19))
                .foregroundColor(OrganicPalette.ink(colorScheme))
        }
    }
}

#Preview {
    StoreAnalyticsView(userStoreItem: UserStoreItem(
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
