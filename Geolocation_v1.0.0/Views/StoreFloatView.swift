//
//  StoreFloatView.swift
//  Geolocation_v1.0.0
//
//  Created on 3/10/26.
//

import SwiftUI

struct StoreFloatView: View {
    let stores: [UserStoreItem]
    let onStoreTap: (UserStoreItem) -> Void

    @State private var appeared = false

    private let circleSize: CGFloat = 58
    private let hSpacing: CGFloat = 14   // horizontal gap between icon edges
    private let vSpacing: CGFloat = 10   // vertical gap between row edges

    var body: some View {
        GeometryReader { geo in
            let positions = layoutPositions(in: geo.size)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                ForEach(Array(stores.enumerated()), id: \.element.id) { index, item in
                    let target = index < positions.count ? positions[index] : center

                    Button { onStoreTap(item) } label: {
                        storeCircle(for: item)
                    }
                    .buttonStyle(.plain)
                    // All icons burst from the screen centre, then settle into position.
                    .position(
                        x: appeared ? target.x : center.x,
                        y: appeared ? target.y : center.y
                    )
                    .scaleEffect(appeared ? 1.0 : 0.1)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.70)
                            .delay(Double(index) * 0.06),
                        value: appeared
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }

    // MARK: - Layout

    /// Arranges store icons in an alternating-row honeycomb pattern centred on screen:
    ///
    ///   • Even rows (0, 2, 4 …)  — "wide"   — hold `iconsPerRow` icons
    ///   • Odd  rows (1, 3, 5 …)  — "narrow" — hold `iconsPerRow - 1` icons,
    ///     each positioned above and between the pair of icons in the row below
    ///
    /// Rows are stacked bottom-to-top and the whole block is centred vertically.
    private func layoutPositions(in size: CGSize) -> [CGPoint] {
        guard !stores.isEmpty else { return [] }

        let sidePadding: CGFloat = 24
        let xStep = circleSize + hSpacing   // centre-to-centre horizontal distance
        let yStep = circleSize + vSpacing   // centre-to-centre vertical distance

        // How many icons fit side-by-side with the given padding
        let available = size.width - 2 * sidePadding
        let iconsPerRow = max(2, Int((available + hSpacing) / xStep))

        // The horizontal span of a full wide row (edge-to-edge of centres)
        let fullSpan  = CGFloat(iconsPerRow - 1) * xStep
        let rowCenterX = size.width / 2

        // --- Build rows bottom-to-top ---
        var rowData: [(xPositions: [CGFloat], isWide: Bool)] = []
        var placed = 0
        var rowIdx = 0

        while placed < stores.count {
            let isWide   = (rowIdx % 2 == 0)
            let capacity = isWide ? iconsPerRow : iconsPerRow - 1
            let count    = min(capacity, stores.count - placed)

            // If the last row has fewer icons than its capacity, centre them
            // within the slot their row type would normally occupy.
            let slotSpan   = CGFloat(capacity - 1) * xStep
            let actualSpan = CGFloat(count - 1) * xStep
            let centreAdj  = (slotSpan - actualSpan) / 2   // shifts partial row to centre

            // Base X for the first icon in this row
            let baseX: CGFloat
            if isWide {
                baseX = rowCenterX - fullSpan / 2 + centreAdj
            } else {
                // Narrow row: shift right by half a step so each icon sits
                // between the two icons directly below it in the wide row
                baseX = rowCenterX - fullSpan / 2 + xStep / 2 + centreAdj
            }

            let xPositions = (0..<count).map { i in baseX + CGFloat(i) * xStep }
            rowData.append((xPositions, isWide))

            placed += count
            rowIdx += 1
        }

        // --- Assign Y coordinates, centred vertically on screen ---
        // rowData[0] = bottom row (largest Y), rowData[last] = top row (smallest Y)
        let totalRows   = rowData.count
        let totalHeight = CGFloat(totalRows - 1) * yStep + circleSize
        let topY        = (size.height - totalHeight) / 2 + circleSize / 2

        var positions: [CGPoint] = []
        for (ri, row) in rowData.enumerated() {
            let y = topY + CGFloat(totalRows - 1 - ri) * yStep
            for x in row.xPositions {
                positions.append(CGPoint(x: x, y: y))
            }
        }

        return positions
    }

    // MARK: - Store Circle

    private func storeCircle(for item: UserStoreItem) -> some View {
        ZStack(alignment: .topTrailing) {
            CachedLogoImage(storeName: item.store.name, size: circleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.22), radius: 7, x: 0, y: 3)

            // Reminder count badge
            if item.store.reminderCount > 0 {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 19, height: 19)
                    Text("\(item.store.reminderCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 5, y: -5)
            }
        }
        .frame(width: circleSize, height: circleSize)
    }
}

#Preview {
    let sampleStores: [UserStoreItem] = [
        UserStoreItem(id: "1",  store: Store(name: "Walmart",        reminderCount: 3), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "2",  store: Store(name: "Target",         reminderCount: 0), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "3",  store: Store(name: "Costco",         reminderCount: 1), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "4",  store: Store(name: "Trader Joe's",   reminderCount: 5), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "5",  store: Store(name: "Whole Foods",    reminderCount: 0), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "6",  store: Store(name: "Kroger",         reminderCount: 2), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "7",  store: Store(name: "Walgreens",      reminderCount: 0), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "8",  store: Store(name: "CVS",            reminderCount: 4), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "9",  store: Store(name: "Home Depot",     reminderCount: 0), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "10", store: Store(name: "Starbucks",      reminderCount: 1), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "11", store: Store(name: "Chipotle",       reminderCount: 0), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
        UserStoreItem(id: "12", store: Store(name: "Safeway",        reminderCount: 0), permission: .edit, sharedStoreGroupId: nil, sourceUserStoreId: nil, sharedFromName: nil, sharedFromId: nil, sharedWith: nil, notificationsEnabled: true),
    ]
    return StoreFloatView(stores: sampleStores, onStoreTap: { _ in })
}
