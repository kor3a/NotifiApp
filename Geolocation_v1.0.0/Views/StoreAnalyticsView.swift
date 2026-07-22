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
            Group {
                if !subscriptionManager.isSubscribed {
                    lockedView
                } else if viewModel.isLoading {
                    ProgressView("Loading analytics...")
                } else if viewModel.entries.isEmpty {
                    emptyStateView
                } else {
                    analyticsContent
                }
            }
            .background(
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle("Analytics")
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
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView()
        }
    }

    // MARK: - Locked (non-subscriber) State

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(Color.appAccent)
            Text("Store Analytics")
                .font(.title2)
                .bold()
            Text("See how often you get items at \(userStoreItem.store.name), your category breakdown, most-gotten items, and shopping patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showingPaywall = true
            } label: {
                Label("Unlock with Premium", systemImage: "crown.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 48)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No Data Yet")
                .font(.title2)
                .bold()
            Text("Analytics build up as you check off and clear items at \(userStoreItem.store.name). Come back after a few shopping trips!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Analytics Content

    private var analyticsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(AnalyticsTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var emptyRangeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nothing checked off in this period")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardStyle()
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

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.appAccent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle()
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
                .foregroundStyle(Color.appAccent)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: xAxisValues) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .frame(height: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
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

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "square.grid.2x2", title: "By Category")

            ForEach(categories) { stat in
                HStack(spacing: 10) {
                    Image(systemName: CategoryIcon.symbol(for: stat.category))
                        .font(.caption)
                        .foregroundColor(Color.appAccent)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stat.category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(stat.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(percentLabel(stat.count, of: total))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        proportionBar(count: stat.count, max: maxCount)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    private func percentLabel(_ count: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(count) / Double(total) * 100).rounded()))%"
    }

    private func proportionBar(count: Int, max maxCount: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(max(maxCount, 1)))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Most Gotten Items

    private var topItemsCard: some View {
        let items = StoreAnalytics.topItems(for: filteredEntries, limit: 10)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "trophy", title: "Most Gotten Items")

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(index < 3 ? Color.white : Color.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(index < 3 ? Color.appAccent : Color.secondary.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Last gotten \(item.lastGotten.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.count)×")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.appAccent)
                        if item.totalQuantity > item.count {
                            Text("Qty \(item.totalQuantity)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
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
                .foregroundStyle(Color.appAccent)
                .cornerRadius(4)
            }
            .chartXScale(domain: weekdays.map { $0.label })
            .frame(height: 140)

            if let busiest {
                Label("You check off the most items on \(busiest)s", systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    // MARK: - Shared

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color.appAccent)
            Text(title)
                .font(.headline)
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
