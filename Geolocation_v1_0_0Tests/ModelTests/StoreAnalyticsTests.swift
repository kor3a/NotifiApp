//
//  StoreAnalyticsTests.swift
//  Geolocation_v1_0_0Tests
//
//  Unit tests for the pure aggregation helpers behind the Store Analytics
//  page (time-range filtering, chart buckets, category breakdown, top items,
//  and weekday shopping patterns).
//

import XCTest
@testable import Allim

final class StoreAnalyticsTests: XCTestCase {

    // Fixed reference point: Wednesday, June 17, 2026, 12:00 UTC.
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 1 // Sunday
        calendar = cal
        now = cal.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 12))!
    }

    private func entry(
        title: String = "Milk",
        daysAgo: Double,
        category: String? = nil,
        quantity: Int? = nil
    ) -> ReminderHistoryEntry {
        ReminderHistoryEntry(
            id: UUID().uuidString,
            userStoreId: "store1",
            title: title,
            checkedOffAt: now.timeIntervalSince1970 - daysAgo * 86_400,
            checkedOffBy: nil,
            checkedOffById: nil,
            createdBy: nil,
            createdById: nil,
            createdAt: nil,
            deletedAt: nil,
            quantity: quantity,
            photoURLs: nil,
            category: category
        )
    }

    // MARK: - Time Range Filtering

    func testEntries_weekIncludesLast7CalendarDays() {
        let entries = [
            entry(title: "Today", daysAgo: 0),
            entry(title: "SixDaysAgo", daysAgo: 6),
            entry(title: "SevenDaysAgo", daysAgo: 7),
            entry(title: "OldItem", daysAgo: 40)
        ]
        let filtered = StoreAnalytics.entries(in: entries, range: .week, now: now, calendar: calendar)
        XCTAssertEqual(Set(filtered.map { $0.title }), ["Today", "SixDaysAgo"])
    }

    func testEntries_monthIncludesLast30CalendarDays() {
        let entries = [
            entry(title: "Recent", daysAgo: 10),
            entry(title: "Edge", daysAgo: 29),
            entry(title: "TooOld", daysAgo: 30)
        ]
        let filtered = StoreAnalytics.entries(in: entries, range: .month, now: now, calendar: calendar)
        XCTAssertEqual(Set(filtered.map { $0.title }), ["Recent", "Edge"])
    }

    func testEntries_allTimeReturnsEverything() {
        let entries = [
            entry(daysAgo: 0),
            entry(daysAgo: 100),
            entry(daysAgo: 500)
        ]
        let filtered = StoreAnalytics.entries(in: entries, range: .allTime, now: now, calendar: calendar)
        XCTAssertEqual(filtered.count, 3)
    }

    // MARK: - Time Buckets

    func testTimeBuckets_weekIsZeroFilledWithSevenDailyBuckets() {
        let entries = [
            entry(daysAgo: 0),
            entry(daysAgo: 0),
            entry(daysAgo: 3)
        ]
        let buckets = StoreAnalytics.timeBuckets(for: entries, range: .week, now: now, calendar: calendar)

        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets.map { $0.count }, [0, 0, 0, 1, 0, 0, 2])
        XCTAssertEqual(buckets.last?.date, calendar.startOfDay(for: now))
    }

    func testTimeBuckets_monthHasThirtyDailyBuckets() {
        let buckets = StoreAnalytics.timeBuckets(for: [entry(daysAgo: 5)], range: .month, now: now, calendar: calendar)
        XCTAssertEqual(buckets.count, 30)
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.count }, 1)
    }

    func testTimeBuckets_allTimeSpansMonthsFromFirstEntry() {
        // ~90 days ago lands in March 2026; June is the current month.
        let entries = [
            entry(daysAgo: 90),
            entry(daysAgo: 0)
        ]
        let buckets = StoreAnalytics.timeBuckets(for: entries, range: .allTime, now: now, calendar: calendar)

        XCTAssertEqual(buckets.count, 4) // Mar, Apr, May, Jun
        XCTAssertEqual(buckets.first?.count, 1)
        XCTAssertEqual(buckets.last?.count, 1)
        XCTAssertEqual(buckets[1].count, 0)
        XCTAssertEqual(buckets[2].count, 0)
    }

    func testTimeBuckets_allTimeEmptyEntriesGivesNoBuckets() {
        let buckets = StoreAnalytics.timeBuckets(for: [], range: .allTime, now: now, calendar: calendar)
        XCTAssertTrue(buckets.isEmpty)
    }

    // MARK: - Category Breakdown

    func testCategoryBreakdown_sortsByCountAndDefaultsToUncategorized() {
        let entries = [
            entry(title: "Apple", daysAgo: 1, category: "Produce"),
            entry(title: "Banana", daysAgo: 2, category: "Produce"),
            entry(title: "Milk", daysAgo: 3, category: "Dairy"),
            entry(title: "Mystery", daysAgo: 4, category: nil),
            entry(title: "Blank", daysAgo: 5, category: "  ")
        ]
        let stats = StoreAnalytics.categoryBreakdown(for: entries)

        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(stats[0], StoreAnalytics.CategoryStat(category: "Produce", count: 2))
        XCTAssertEqual(stats[1], StoreAnalytics.CategoryStat(category: StoreAnalytics.uncategorizedLabel, count: 2))
        XCTAssertEqual(stats[2], StoreAnalytics.CategoryStat(category: "Dairy", count: 1))
    }

    // MARK: - Top Items

    func testTopItems_groupsByNormalizedTitleAndSumsQuantity() {
        let entries = [
            entry(title: "milk ", daysAgo: 5, quantity: 2),
            entry(title: "Milk", daysAgo: 1, quantity: nil), // nil quantity counts as 1
            entry(title: "Eggs", daysAgo: 2, quantity: 12)
        ]
        let items = StoreAnalytics.topItems(for: entries)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "Milk") // display title from most recent check-off
        XCTAssertEqual(items[0].count, 2)
        XCTAssertEqual(items[0].totalQuantity, 3)
        XCTAssertEqual(items[1].title, "Eggs")
        XCTAssertEqual(items[1].count, 1)
        XCTAssertEqual(items[1].totalQuantity, 12)
    }

    func testTopItems_respectsLimit() {
        let entries = (0..<15).map { entry(title: "Item\($0)", daysAgo: Double($0)) }
        let items = StoreAnalytics.topItems(for: entries, limit: 10)
        XCTAssertEqual(items.count, 10)
    }

    // MARK: - Weekday Breakdown

    func testWeekdayBreakdown_countsPerWeekdayInCalendarOrder() {
        // now is a Wednesday; 1 day ago = Tuesday, 7 days ago = last Wednesday.
        let entries = [
            entry(daysAgo: 0),
            entry(daysAgo: 7),
            entry(daysAgo: 1)
        ]
        let stats = StoreAnalytics.weekdayBreakdown(for: entries, calendar: calendar)

        XCTAssertEqual(stats.count, 7)
        XCTAssertEqual(stats.map { $0.label }, calendar.shortWeekdaySymbols)
        XCTAssertEqual(stats[3].count, 2) // Wednesday
        XCTAssertEqual(stats[2].count, 1) // Tuesday
        XCTAssertEqual(stats.reduce(0) { $0 + $1.count }, 3)
    }

    func testBusiestWeekday_returnsFullSymbolOrNil() {
        let entries = [
            entry(daysAgo: 0),
            entry(daysAgo: 7),
            entry(daysAgo: 1)
        ]
        XCTAssertEqual(StoreAnalytics.busiestWeekday(for: entries, calendar: calendar), "Wednesday")
        XCTAssertNil(StoreAnalytics.busiestWeekday(for: [], calendar: calendar))
    }

    // MARK: - Shopping Trips

    func testShoppingTripCount_countsDistinctDays() {
        let entries = [
            entry(daysAgo: 0),
            entry(daysAgo: 0.1), // same calendar day as above
            entry(daysAgo: 3),
            entry(daysAgo: 10)
        ]
        XCTAssertEqual(StoreAnalytics.shoppingTripCount(for: entries, calendar: calendar), 3)
    }
}
