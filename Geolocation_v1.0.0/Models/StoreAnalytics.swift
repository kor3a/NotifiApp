//
//  StoreAnalytics.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 7/22/26.
//

import Foundation

/// Time window the analytics page can be scoped to.
enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case week = "Weekly"
    case month = "Monthly"
    case allTime = "All Time"

    var id: String { rawValue }
}

/// Pure computations that turn a store's `reminder_history` entries into the
/// aggregates shown on the Store Analytics page. Every check-off that was
/// removed from the list counts as one "time gotten" — re-adding an item later
/// does not erase past purchases, so analytics never filters by the current
/// list the way HistoryView does.
struct StoreAnalytics {

    // MARK: - Aggregate Types

    /// Check-off count for one bar of the over-time chart (a day or a month).
    struct TimeBucket: Identifiable, Equatable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    struct CategoryStat: Identifiable, Equatable {
        let category: String
        let count: Int
        var id: String { category }
    }

    struct ItemStat: Identifiable, Equatable {
        let title: String
        let count: Int
        let totalQuantity: Int
        let lastGotten: Date
        var id: String { title.lowercased() }
    }

    struct WeekdayStat: Identifiable, Equatable {
        let label: String
        let count: Int
        var id: String { label }
    }

    static let uncategorizedLabel = "Uncategorized"

    // MARK: - Filtering

    /// Entries inside the selected window. Weekly = the last 7 calendar days
    /// (today included), Monthly = the last 30 calendar days.
    static func entries(
        in entries: [ReminderHistoryEntry],
        range: AnalyticsTimeRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReminderHistoryEntry] {
        guard let dayCount = dayCount(for: range) else { return entries }
        let startOfToday = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(dayCount - 1), to: startOfToday) else {
            return entries
        }
        let cutoffInterval = cutoff.timeIntervalSince1970
        return entries.filter { $0.checkedOffAt >= cutoffInterval }
    }

    private static func dayCount(for range: AnalyticsTimeRange) -> Int? {
        switch range {
        case .week: return 7
        case .month: return 30
        case .allTime: return nil
        }
    }

    // MARK: - Over-Time Buckets

    /// Zero-filled buckets for the over-time bar chart: one per day for the
    /// weekly/monthly windows, one per month for all time (from the first
    /// recorded check-off through the current month).
    static func timeBuckets(
        for entries: [ReminderHistoryEntry],
        range: AnalyticsTimeRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TimeBucket] {
        if let dayCount = dayCount(for: range) {
            let startOfToday = calendar.startOfDay(for: now)
            let countsByDay = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: Date(timeIntervalSince1970: entry.checkedOffAt))
            }
            return (0..<dayCount).reversed().compactMap { daysAgo in
                guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday) else {
                    return nil
                }
                return TimeBucket(date: day, count: countsByDay[day]?.count ?? 0)
            }
        }

        // All time: monthly buckets from the earliest entry's month to now.
        guard let earliest = entries.map({ $0.checkedOffAt }).min(),
              let firstMonth = calendar.dateInterval(of: .month, for: Date(timeIntervalSince1970: earliest))?.start,
              let currentMonth = calendar.dateInterval(of: .month, for: now)?.start else {
            return []
        }
        let countsByMonth = Dictionary(grouping: entries) { entry in
            calendar.dateInterval(of: .month, for: Date(timeIntervalSince1970: entry.checkedOffAt))?.start ?? firstMonth
        }
        var buckets: [TimeBucket] = []
        var month = firstMonth
        while month <= currentMonth {
            buckets.append(TimeBucket(date: month, count: countsByMonth[month]?.count ?? 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return buckets
    }

    // MARK: - Categories

    /// Check-off counts per category, largest first. Entries with no category
    /// fall into "Uncategorized".
    static func categoryBreakdown(for entries: [ReminderHistoryEntry]) -> [CategoryStat] {
        let groups = Dictionary(grouping: entries) { entry -> String in
            let category = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return category.isEmpty ? uncategorizedLabel : category
        }
        return groups
            .map { CategoryStat(category: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
            }
    }

    // MARK: - Top Items

    /// Most-gotten items, grouped by normalized title so "Milk" and "milk "
    /// count as the same item. The display title comes from the most recent
    /// check-off of that item.
    static func topItems(for entries: [ReminderHistoryEntry], limit: Int = 10) -> [ItemStat] {
        let groups = Dictionary(grouping: entries) { entry in
            entry.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return groups.values
            .compactMap { group -> ItemStat? in
                guard let latest = group.max(by: { $0.checkedOffAt < $1.checkedOffAt }) else { return nil }
                let totalQuantity = group.reduce(0) { $0 + max($1.quantity ?? 1, 1) }
                return ItemStat(
                    title: latest.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    count: group.count,
                    totalQuantity: totalQuantity,
                    lastGotten: Date(timeIntervalSince1970: latest.checkedOffAt)
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.lastGotten > rhs.lastGotten
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Shopping Behavior

    /// Check-off counts per weekday, ordered by the calendar's first weekday.
    static func weekdayBreakdown(
        for entries: [ReminderHistoryEntry],
        calendar: Calendar = .current
    ) -> [WeekdayStat] {
        var countsByWeekday: [Int: Int] = [:] // 1 = Sunday ... 7 = Saturday
        for entry in entries {
            let weekday = calendar.component(.weekday, from: Date(timeIntervalSince1970: entry.checkedOffAt))
            countsByWeekday[weekday, default: 0] += 1
        }
        let symbols = calendar.shortWeekdaySymbols
        return (0..<7).map { offset in
            let weekdayIndex = (calendar.firstWeekday - 1 + offset) % 7
            return WeekdayStat(label: symbols[weekdayIndex], count: countsByWeekday[weekdayIndex + 1] ?? 0)
        }
    }

    /// Full name of the weekday with the most check-offs, or nil when there
    /// is no data (used for the "you shop most on ..." insight).
    static func busiestWeekday(
        for entries: [ReminderHistoryEntry],
        calendar: Calendar = .current
    ) -> String? {
        var countsByWeekday: [Int: Int] = [:]
        for entry in entries {
            let weekday = calendar.component(.weekday, from: Date(timeIntervalSince1970: entry.checkedOffAt))
            countsByWeekday[weekday, default: 0] += 1
        }
        guard let best = countsByWeekday.max(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key
        }), best.value > 0 else { return nil }
        return calendar.weekdaySymbols[best.key - 1]
    }

    /// Number of distinct days with at least one check-off ("shopping trips").
    static func shoppingTripCount(
        for entries: [ReminderHistoryEntry],
        calendar: Calendar = .current
    ) -> Int {
        Set(entries.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0.checkedOffAt)) }).count
    }
}

// MARK: - Category Icons

/// SF Symbol for each Smart Category, shared by the reminder list headers and
/// the analytics category breakdown.
enum CategoryIcon {
    static func symbol(for category: String) -> String {
        switch category.lowercased() {
        case "produce": return "leaf"
        case "dairy": return "cup.and.saucer"
        case "meat & seafood": return "fish"
        case "bakery": return "birthday.cake"
        case "beverages": return "waterbottle"
        case "snacks": return "popcorn"
        case "frozen": return "snowflake"
        case "canned goods": return "cylinder"
        case "condiments & sauces": return "flask"
        case "grains & pasta": return "takeoutbag.and.cup.and.straw"
        case "household": return "house"
        case "personal care": return "hands.sparkles"
        case "baby": return "stroller"
        case "pet": return "pawprint"
        case "health": return "cross.case"
        case "electronics": return "bolt"
        case "clothing": return "tshirt"
        case "office & stationery": return "pencil.and.ruler"
        case "furniture": return "chair"
        case "hardware & tools": return "wrench.and.screwdriver"
        case "home & kitchen": return "fork.knife"
        case "toys & games": return "gamecontroller"
        case "sports & outdoors": return "figure.run"
        case "automotive": return "car"
        case "garden & outdoor": return "tree"
        case "books & media": return "book"
        case "craft & hobby": return "paintpalette"
        case "uncategorized": return "questionmark.folder"
        default: return "tag"
        }
    }
}
