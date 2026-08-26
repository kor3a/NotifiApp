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
    let onStoreDelete: (UserStoreItem) -> Void
    let onReorder: ([UserStoreItem]) -> Void
    @Binding var isEditMode: Bool

    @State private var appeared = false
    @State private var wiggleAngle: Double = 0
    @State private var localStores: [UserStoreItem] = []
    @State private var draggingId: String? = nil
    @State private var tappedId: String? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartTargetPos: CGPoint = .zero
    @State private var containerSize: CGSize = .zero
    @Environment(\.colorScheme) private var colorScheme

    private let circleSize: CGFloat = 58
    private let hSpacing: CGFloat = 14
    private let vSpacing: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let positions = layoutPositions(in: geo.size)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Background tap area to exit edit mode
                if isEditMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            exitEditMode()
                        }
                }

                ForEach(Array(localStores.enumerated()), id: \.element.id) { index, item in
                    let target = index < positions.count ? positions[index] : center
                    let isDragging = draggingId == item.id

                    storeIconView(
                        item: item,
                        index: index,
                        target: target,
                        center: center,
                        isDragging: isDragging,
                        allPositions: positions
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onChange(of: geo.size) { _, size in
                containerSize = size
            }
            .onAppear {
                containerSize = geo.size
            }
        }
        .onAppear {
            localStores = stores
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
            exitEditMode()
        }
        .onChange(of: stores) { _, newStores in
            // Only sync from parent when not actively dragging
            if draggingId == nil {
                localStores = newStores
            }
        }
        .onChange(of: isEditMode) { _, editing in
            if editing {
                startWiggle()
            } else {
                stopWiggle()
            }
        }
    }

    // MARK: - Icon View

    @ViewBuilder
    private func storeIconView(
        item: UserStoreItem,
        index: Int,
        target: CGPoint,
        center: CGPoint,
        isDragging: Bool,
        allPositions: [CGPoint]
    ) -> some View {
        // Alternate phase so adjacent icons jiggle in opposite directions
        let phaseSign: Double = (index % 2 == 0) ? 1 : -1
        let currentWiggle = isEditMode && !isDragging ? wiggleAngle * phaseSign : 0

        ZStack(alignment: .topLeading) {
            // Store circle — using onTapGesture instead of Button so that
            // onLongPressGesture can fire while the finger is still held down.
            storeCircle(for: item)

            // Delete badge — top-leading corner
            if isEditMode {
                Button {
                    onStoreDelete(item)
                } label: {
                    ZStack {
                        Circle()
                            .fill(OrganicPalette.rust(colorScheme))
                            .frame(width: 22, height: 22)
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: -6)
                .zIndex(2)
            }
        }
        .frame(width: circleSize, height: circleSize)
        .contentShape(Circle())
        .rotationEffect(.degrees(currentWiggle))
        // Burst-from-centre entry animation; dragging icon follows finger
        .position(
            x: isDragging ? target.x + dragOffset.width : (appeared ? target.x : center.x),
            y: isDragging ? target.y + dragOffset.height : (appeared ? target.y : center.y)
        )
        .scaleEffect(isDragging ? 1.12 : (tappedId == item.id ? 0.85 : (appeared ? 1.0 : 0.1)))
        .opacity(appeared ? 1.0 : 0.0)
        .animation(
            isDragging ? nil : .spring(response: 0.55, dampingFraction: 0.70)
                .delay(Double(index) * 0.06),
            value: appeared
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: tappedId)
        .zIndex(isDragging ? 10 : 0)
        // Tap to open store (only when not in edit mode)
        .onTapGesture {
            guard !isEditMode else { return }
            // Brief press-down bounce before opening the store, mirroring the
            // tactile feedback of the list-mode store rows.
            tappedId = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                tappedId = nil
                onStoreTap(item)
            }
        }
        // Long-press enters edit mode while the finger is still held down.
        // onLongPressGesture's perform closure fires after minimumDuration
        // without requiring the user to lift their finger.
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isEditMode = true
            }
        }
        // Drag-to-reorder (only active in edit mode)
        .simultaneousGesture(
            isEditMode ?
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if draggingId == nil {
                        draggingId = item.id
                        // Record the icon's grid position at the moment the drag begins.
                        // This anchors all subsequent offset calculations so that swapping
                        // the icon into a different slot doesn't change where it appears
                        // on screen — it stays directly under the finger.
                        dragStartTargetPos = target
                    }
                    guard draggingId == item.id else { return }

                    // Absolute finger position = original anchor + cumulative translation.
                    // This remains correct even after `target` changes due to a swap.
                    let fingerX = dragStartTargetPos.x + value.translation.width
                    let fingerY = dragStartTargetPos.y + value.translation.height

                    // Express the finger position as an offset from the *current* target
                    // so the icon always renders exactly under the finger.
                    dragOffset = CGSize(width: fingerX - target.x, height: fingerY - target.y)

                    // Use the true finger position for swap detection too
                    let dragCenter = CGPoint(x: fingerX, y: fingerY)
                    swapIfNeeded(
                        draggingIndex: index,
                        dragCenter: dragCenter,
                        positions: allPositions
                    )
                }
                .onEnded { _ in
                    let wasSwapped = draggingId != nil
                    draggingId = nil
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = .zero
                    }
                    if wasSwapped {
                        onReorder(localStores)
                    }
                }
            : nil
        )
    }

    // MARK: - Drag Swap

    private func swapIfNeeded(draggingIndex: Int, dragCenter: CGPoint, positions: [CGPoint]) {
        var closestIndex = -1
        var closestDistance = circleSize * 0.85  // swap threshold

        for (i, pos) in positions.enumerated() {
            guard i != draggingIndex, i < localStores.count else { continue }
            let dx = dragCenter.x - pos.x
            let dy = dragCenter.y - pos.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = i
            }
        }

        if closestIndex >= 0 {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.70)) {
                localStores.swapAt(draggingIndex, closestIndex)
            }
        }
    }

    // MARK: - Wiggle

    private func startWiggle() {
        wiggleAngle = -3
        withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)) {
            wiggleAngle = 3
        }
    }

    private func stopWiggle() {
        withAnimation(.spring(response: 0.2)) {
            wiggleAngle = 0
        }
    }

    private func exitEditMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = false
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
        guard !localStores.isEmpty else { return [] }

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

        while placed < localStores.count {
            let isWide   = (rowIdx % 2 == 0)
            let capacity = isWide ? iconsPerRow : iconsPerRow - 1
            let count    = min(capacity, localStores.count - placed)

            // If the last row has fewer icons than its capacity, centre them
            // within the slot their row type would normally occupy.
            let slotSpan   = CGFloat(capacity - 1) * xStep
            let actualSpan = CGFloat(count - 1) * xStep
            let centreAdj  = (slotSpan - actualSpan) / 2

            // Base X for the first icon in this row
            let baseX: CGFloat
            if isWide {
                baseX = rowCenterX - fullSpan / 2 + centreAdj
            } else {
                baseX = rowCenterX - fullSpan / 2 + xStep / 2 + centreAdj
            }

            let xPositions = (0..<count).map { i in baseX + CGFloat(i) * xStep }
            rowData.append((xPositions, isWide))

            placed += count
            rowIdx += 1
        }

        // --- Assign Y coordinates, centred vertically on screen ---
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
                        .stroke(OrganicPalette.surface(colorScheme).opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 8, x: 0, y: 4)

            // Reminder count badge
            if item.store.reminderCount > 0 {
                ZStack {
                    Circle()
                        .fill(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 19, height: 19)
                    Text("\(item.store.reminderCount)")
                        .font(.system(size: 10, weight: .bold, design: .serif))
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

    @State var editMode = false
    return StoreFloatView(
        stores: sampleStores,
        onStoreTap: { _ in },
        onStoreDelete: { _ in },
        onReorder: { _ in },
        isEditMode: $editMode
    )
}
