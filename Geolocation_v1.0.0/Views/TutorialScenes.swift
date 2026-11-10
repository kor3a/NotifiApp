//
//  TutorialScenes.swift
//  Geolocation_v1.0.0
//
//  The playable demos behind each tutorial chapter. Every scene is a small,
//  self-contained mock of one idea in the app — nothing here reads or writes
//  real data — and calls `onDone` the first time the user plays it through.
//

import SwiftUI

// MARK: - Shared pieces

/// A list item drawn as a chip, with the dot of the category it belongs to.
struct TutorialChip: View {
    let name: String
    let category: GroceryCategory
    /// Raised chips float on their own shadow; flat ones sit in a tray.
    var raised: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(category.palette.dot(colorScheme))
                .frame(width: 8, height: 8)
            Text(name)
                .font(OrganicPalette.body(14, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(OrganicPalette.surfaceRaised(colorScheme))
                .shadow(
                    color: OrganicPalette.shadow(colorScheme),
                    radius: raised ? 10 : 3,
                    x: 0,
                    y: raised ? 5 : 1
                )
        )
        .overlay(Capsule().strokeBorder(OrganicPalette.outline(colorScheme), lineWidth: 1))
    }
}

/// Lays chips out left to right, wrapping onto a new line when one won't fit.
private struct TutorialFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A ring that breathes outward from whatever the user is being asked to
/// touch.
private struct TutorialPulse: View {
    let color: Color
    var size: CGFloat = 58

    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(animating ? 1.7 : 1)
            .opacity(animating ? 0 : 0.8)
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animating)
            .onAppear { animating = true }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private func tutorialTap() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

private func tutorialSuccess() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}

// MARK: - 01 · Add a store

struct TutorialAddStoreScene: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var storeCount: Int

    private let stores = ["Whole Foods", "Trader Joe's", "Costco"]

    init(startsDone: Bool, onDone: @escaping () -> Void) {
        self.onDone = onDone
        _storeCount = State(initialValue: startsDone ? 1 : 0)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Stores")
                    .font(OrganicPalette.display(24))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .padding(.bottom, 4)

                if storeCount == 0 {
                    emptyCard
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                ForEach(stores.prefix(storeCount), id: \.self) { name in
                    storeCard(name)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }

                Spacer(minLength: 0)
            }
            .padding(18)

            addButton
                .padding(18)
        }
    }

    private var emptyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront")
                .font(.system(size: 18, weight: .semibold))
            Text("No stores yet")
                .font(OrganicPalette.title(15, weight: .semibold))
        }
        .foregroundColor(OrganicPalette.inkMuted(colorScheme))
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    OrganicPalette.outlineStrong(colorScheme),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
        )
    }

    private func storeCard(_ name: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(OrganicPalette.blush(colorScheme))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(OrganicPalette.title(16))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("Nearby alerts on")
                        .font(OrganicPalette.body(12))
                }
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(OrganicPalette.inkMuted(colorScheme))
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OrganicPalette.canvas(colorScheme))
        )
    }

    private var addButton: some View {
        let isFull = storeCount >= stores.count
        return Button {
            guard !isFull else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                storeCount += 1
            }
            if storeCount == 1 {
                tutorialSuccess()
                onDone()
            } else {
                tutorialTap()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(OrganicPalette.terracotta(colorScheme))
                        .shadow(
                            color: OrganicPalette.terracotta(colorScheme).opacity(0.35),
                            radius: 12, x: 0, y: 6
                        )
                )
                .background {
                    if storeCount == 0 {
                        TutorialPulse(color: OrganicPalette.terracotta(colorScheme))
                    }
                }
                .opacity(isFull ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add store")
    }
}

// MARK: - 02 · Smart Category

struct TutorialSmartSortScene: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var chips
    /// Ids of the items added to the list, in the order they were tapped.
    @State private var added: [String] = []

    private struct Item: Identifiable {
        let id: String
        let category: String
    }

    private let items: [Item] = [
        Item(id: "Bananas", category: "Produce"),
        Item(id: "Whole Milk", category: "Dairy"),
        Item(id: "Sourdough", category: "Bakery"),
        Item(id: "Spinach", category: "Produce"),
        Item(id: "Greek Yogurt", category: "Dairy"),
        Item(id: "Croissants", category: "Bakery"),
    ]

    private var waiting: [Item] {
        items.filter { !added.contains($0.id) }
    }

    /// Categories in the order their first item arrived, the way the real list
    /// grows a section the first time something lands in it.
    private var sections: [(name: String, items: [Item])] {
        var order: [String] = []
        for id in added {
            if let item = items.first(where: { $0.id == id }), !order.contains(item.category) {
                order.append(item.category)
            }
        }
        return order.map { name in
            (name, added.compactMap { id in items.first { $0.id == id && $0.category == name } })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Whole Foods")
                    .font(OrganicPalette.display(22))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                if !added.isEmpty {
                    OrganicCountBadge(count: added.count, fontSize: 12)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
            }
            .padding(.bottom, 2)

            if added.isEmpty {
                Text("Your list is empty.")
                    .font(OrganicPalette.body(14))
                    .foregroundColor(OrganicPalette.inkMuted(colorScheme))
                    .transition(.opacity)
            }

            ForEach(sections, id: \.name) { section in
                sectionRow(name: section.name, items: section.items)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }

            Spacer(minLength: 0)

            tray
        }
        .padding(18)
    }

    private func sectionRow(name: String, items: [Item]) -> some View {
        let palette = GroceryCategory.matching(name).palette
        return HStack(alignment: .center, spacing: 8) {
            Text(name)
                .font(OrganicPalette.title(13))
                .foregroundColor(palette.label(colorScheme))
                .frame(width: 62, alignment: .leading)

            TutorialFlowLayout(spacing: 6) {
                ForEach(items) { item in
                    chip(item)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.tint(colorScheme))
        )
    }

    private var tray: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(waiting.isEmpty ? "ALL SORTED" : "ADD TO LIST")
                .font(OrganicPalette.title(11))
                .tracking(1)
                .foregroundColor(OrganicPalette.inkMuted(colorScheme))

            if waiting.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        added = []
                    }
                } label: {
                    Label("Play again", systemImage: "arrow.counterclockwise")
                        .font(OrganicPalette.title(14, weight: .semibold))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }
                .buttonStyle(.plain)
            } else {
                TutorialFlowLayout(spacing: 8) {
                    ForEach(waiting) { item in
                        Button {
                            add(item)
                        } label: {
                            chip(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OrganicPalette.field(colorScheme))
        )
    }

    private func chip(_ item: Item) -> some View {
        TutorialChip(name: item.id, category: GroceryCategory.matching(item.category))
            .matchedGeometryEffect(id: item.id, in: chips)
    }

    private func add(_ item: Item) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            added.append(item.id)
        }
        if added.count == 2 {
            tutorialSuccess()
            onDone()
        } else {
            tutorialTap()
        }
    }
}

// MARK: - 03 · Nearby alerts

struct TutorialNearbyScene: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    /// Where the user has dragged themselves to; nil until they first move.
    @State private var position: CGPoint?
    @State private var dragOrigin: CGPoint?
    @State private var isInside = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let store = CGPoint(x: size.width * 0.64, y: size.height * 0.52)
            let radius = min(size.width, size.height) * 0.27
            let start = CGPoint(x: size.width * 0.17, y: size.height * 0.8)
            let you = position ?? start

            ZStack {
                map

                // The area Allim watches around the store.
                Circle()
                    .fill(OrganicPalette.highlightWash(colorScheme).opacity(isInside ? 0.95 : 0.5))
                    .overlay(
                        Circle().strokeBorder(
                            OrganicPalette.highlight(colorScheme),
                            style: StrokeStyle(lineWidth: 2, dash: isInside ? [] : [7, 6])
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .scaleEffect(isInside ? 1.06 : 1)
                    .position(store)

                Button {
                    // For anyone who would rather tap than drag.
                    move(to: CGPoint(x: store.x - radius * 0.45, y: store.y + radius * 0.45), store: store, radius: radius, animated: true)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(OrganicPalette.terracotta(colorScheme)))
                        Text("Whole Foods")
                            .font(OrganicPalette.title(11))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(OrganicPalette.surfaceRaised(colorScheme)))
                    }
                }
                .buttonStyle(.plain)
                .position(x: store.x, y: store.y + 8)
                .accessibilityLabel("Walk to Whole Foods")

                youDot
                    .position(you)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let origin = dragOrigin ?? you
                                dragOrigin = origin
                                let target = CGPoint(
                                    x: min(max(origin.x + value.translation.width, 20), size.width - 20),
                                    y: min(max(origin.y + value.translation.height, 20), size.height - 20)
                                )
                                move(to: target, store: store, radius: radius, animated: false)
                            }
                            .onEnded { _ in dragOrigin = nil }
                    )

                if isInside {
                    banner
                        .padding(12)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private func move(to target: CGPoint, store: CGPoint, radius: CGFloat, animated: Bool) {
        let inside = hypot(target.x - store.x, target.y - store.y) < radius
        if animated {
            withAnimation(.easeInOut(duration: 0.9)) { position = target }
        } else {
            position = target
        }
        guard inside != isInside else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(animated ? 0.7 : 0)) {
            isInside = inside
        }
        if inside {
            tutorialSuccess()
            onDone()
        }
    }

    /// A few streets and a park — enough to read as a map without being one.
    private var map: some View {
        let road = OrganicPalette.surface(colorScheme)
        let park = OrganicPalette.sage(colorScheme)
        return Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(OrganicPalette.field(colorScheme))
            )

            let parkRect = CGRect(
                x: size.width * 0.06, y: size.height * 0.1,
                width: size.width * 0.3, height: size.height * 0.34
            )
            context.fill(Path(roundedRect: parkRect, cornerRadius: 18), with: .color(park))

            var roads = Path()
            for fraction in [0.52, 0.94] {
                roads.move(to: CGPoint(x: 0, y: size.height * fraction))
                roads.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
            }
            for fraction in [0.44, 0.93] {
                roads.move(to: CGPoint(x: size.width * fraction, y: 0))
                roads.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
            }
            roads.move(to: CGPoint(x: 0, y: size.height * 0.98))
            roads.addLine(to: CGPoint(x: size.width * 0.44, y: size.height * 0.52))
            context.stroke(roads, with: .color(road), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        }
    }

    private var youDot: some View {
        ZStack {
            if position == nil {
                TutorialPulse(color: OrganicPalette.terracotta(colorScheme), size: 34)
            }
            Circle()
                .fill(OrganicPalette.ink(colorScheme))
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(OrganicPalette.surfaceRaised(colorScheme), lineWidth: 4))
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 6, x: 0, y: 3)
        }
        .frame(width: 64, height: 64)
        .contentShape(Circle())
        .accessibilityLabel("You")
    }

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(OrganicPalette.onHighlight(colorScheme))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(OrganicPalette.highlight(colorScheme))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("You're near Whole Foods")
                    .font(OrganicPalette.title(14))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                Text("3 items waiting: Bananas, Whole Milk…")
                    .font(OrganicPalette.body(12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("now")
                .font(OrganicPalette.body(11))
                .foregroundColor(OrganicPalette.inkMuted(colorScheme))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OrganicPalette.surfaceRaised(colorScheme))
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 14, x: 0, y: 6)
        )
    }
}

// MARK: - 04 · Shortcuts

struct TutorialShortcutsScene: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var checked: Set<String> = []
    @State private var outOfStock: Set<String> = []
    @State private var pressing: String?
    /// The item whose touch-and-hold menu is open.
    @State private var heldItem: String?
    @State private var showsListMenu = false
    @State private var autoDelete = false
    @State private var smartCategory = true

    private let items = ["Bananas", "Whole Milk", "Sourdough"]

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                HStack {
                    Text("Whole Foods")
                        .font(OrganicPalette.display(22))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                    Spacer(minLength: 0)
                    Button {
                        open { showsListMenu = true }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundColor(OrganicPalette.terracotta(colorScheme))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(OrganicPalette.blush(colorScheme)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("List menu")
                }
                .padding(.bottom, 2)

                ForEach(items, id: \.self) { item in
                    row(item)
                }

                Spacer(minLength: 0)
            }
            .padding(18)

            // Catches a tap anywhere outside an open menu. The rows dim
            // themselves, so the one being held stays lit under its menu.
            if heldItem != nil || showsListMenu {
                Color.black.opacity(0.001)
                    .onTapGesture { closeMenus() }
            }

            if let heldItem {
                itemMenu(for: heldItem)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
            }

            if showsListMenu {
                listMenu
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
            }
        }
    }

    private func open(_ change: () -> Void) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            change()
        }
        tutorialSuccess()
        onDone()
    }

    private func closeMenus() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            heldItem = nil
            showsListMenu = false
        }
    }

    // MARK: Rows

    /// Rows fall back while a menu is open — all of them under the list menu,
    /// every one but the held item under its shortcut menu.
    private func isDimmed(_ item: String) -> Bool {
        if showsListMenu { return true }
        if let heldItem { return heldItem != item }
        return false
    }

    private func row(_ item: String) -> some View {
        let isChecked = checked.contains(item)
        let isOut = outOfStock.contains(item)
        return HStack(spacing: 12) {
            Button {
                tutorialTap()
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isChecked { checked.remove(item) } else { checked.insert(item) }
                }
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21))
                    .foregroundColor(
                        isChecked
                            ? OrganicPalette.terracotta(colorScheme)
                            : OrganicPalette.inkSoft(colorScheme)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "Uncheck \(item)" : "Check \(item)")

            Text(item)
                .font(OrganicPalette.body(16, weight: .semibold))
                .foregroundColor(
                    isChecked ? OrganicPalette.inkMuted(colorScheme) : OrganicPalette.ink(colorScheme)
                )
                .strikethrough(isChecked, color: OrganicPalette.inkMuted(colorScheme))

            Spacer(minLength: 0)

            if isOut {
                Text("Out of stock")
                    .font(OrganicPalette.title(11))
                    .foregroundColor(OrganicPalette.rust(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(OrganicPalette.rustWash(colorScheme)))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OrganicPalette.canvas(colorScheme))
        )
        .scaleEffect(pressing == item ? 0.96 : (heldItem == item ? 1.03 : 1))
        .shadow(
            color: heldItem == item ? OrganicPalette.shadow(colorScheme) : .clear,
            radius: 12, x: 0, y: 6
        )
        .opacity(isDimmed(item) ? 0.3 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressing)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onLongPressGesture(minimumDuration: 0.3) {
            open { heldItem = item }
        } onPressingChanged: { isPressing in
            pressing = isPressing ? item : nil
        }
        .accessibilityAction(named: "Open shortcuts") {
            open { heldItem = item }
        }
    }

    // MARK: Touch-and-hold menu

    private func itemMenu(for item: String) -> some View {
        let isOut = outOfStock.contains(item)
        return VStack(spacing: 0) {
            menuRow(isOut ? "Back in Stock" : "Out of Stock", icon: isOut ? "checkmark.circle" : "xmark.circle") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if isOut { outOfStock.remove(item) } else { outOfStock.insert(item) }
                }
            }
            menuDivider
            menuRow("Move to Store", icon: "arrow.right.square") {}
            menuDivider
            menuRow("Add Photos", icon: "photo.on.rectangle.angled") {}
            menuDivider
            menuRow("Add Quantity", icon: "number") {}
            menuDivider
            menuRow("Change Category", icon: "tag") {}
        }
        .frame(width: 230)
        .background(menuBackground)
    }

    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            tutorialTap()
            action()
            closeMenus()
        } label: {
            HStack {
                Text(title)
                    .font(OrganicPalette.body(15))
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 15))
            }
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .padding(.horizontal, 16)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: ⓘ list menu

    private var listMenu: some View {
        VStack(spacing: 0) {
            toggleRow("Auto Delete", detail: "Clear checked items", icon: "trash", isOn: $autoDelete)
            menuDivider
            toggleRow("Smart Category", detail: "Sort new items for you", icon: "sparkles", isOn: $smartCategory)
            menuDivider
            listMenuRow("Recipes", detail: "Add a recipe's ingredients", icon: "fork.knife", trailing: "chevron.right")
            menuDivider
            listMenuRow("Visit store", detail: "Open its app or website", icon: "safari", trailing: "arrow.up.right")
        }
        .frame(width: 262)
        .background(menuBackground)
    }

    private func toggleRow(_ title: String, detail: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            listMenuLabel(title, detail: detail, icon: icon)
            Spacer(minLength: 4)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(OrganicPalette.terracotta(colorScheme))
                .scaleEffect(0.8)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 50)
    }

    private func listMenuRow(_ title: String, detail: String, icon: String, trailing: String) -> some View {
        HStack(spacing: 10) {
            listMenuLabel(title, detail: detail, icon: icon)
            Spacer(minLength: 4)
            Image(systemName: trailing)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OrganicPalette.inkMuted(colorScheme))
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }

    private func listMenuLabel(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 30, height: 30)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OrganicPalette.title(14, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                Text(detail)
                    .font(OrganicPalette.body(11))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }
        }
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(OrganicPalette.divider(colorScheme))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(OrganicPalette.surfaceRaised(colorScheme))
            .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 10)
    }
}

// MARK: - 05 · Sharing

struct TutorialShareScene: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    /// Who the list is shared with, in the order they were tapped.
    @State private var shared: [String] = []

    private struct Person: Identifiable {
        let id: String
        let isFamily: Bool
    }

    private let people = [
        Person(id: "Sam", isFamily: true),
        Person(id: "Alex", isFamily: false),
        Person(id: "Jamie", isFamily: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            storeCard

            Text("SHARE WITH")
                .font(OrganicPalette.title(11))
                .tracking(1)
                .foregroundColor(OrganicPalette.inkMuted(colorScheme))
                .padding(.top, 2)

            HStack(alignment: .top, spacing: 0) {
                ForEach(people) { person in
                    personButton(person)
                        .frame(maxWidth: .infinity)
                }
            }

            if let first = shared.first {
                message(from: first)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private var storeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(OrganicPalette.blush(colorScheme))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Whole Foods")
                    .font(OrganicPalette.title(16))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                Text(shared.isEmpty ? "Only you" : "Shared with \(shared.joined(separator: ", "))")
                    .font(OrganicPalette.body(12))
                    .foregroundColor(
                        shared.isEmpty
                            ? OrganicPalette.inkSoft(colorScheme)
                            : OrganicPalette.sageInk(colorScheme)
                    )
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: -10) {
                ForEach(shared, id: \.self) { name in
                    OrganicAvatar(
                        name: name,
                        profilePictureURL: nil,
                        size: 28,
                        ringColor: OrganicPalette.canvas(colorScheme)
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OrganicPalette.canvas(colorScheme))
        )
    }

    private func personButton(_ person: Person) -> some View {
        let isShared = shared.contains(person.id)
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                if isShared {
                    shared.removeAll { $0 == person.id }
                } else {
                    shared.append(person.id)
                }
            }
            if !isShared, shared.count == 1 {
                tutorialSuccess()
                onDone()
            } else {
                tutorialTap()
            }
        } label: {
            VStack(spacing: 5) {
                OrganicAvatar(name: person.id, profilePictureURL: nil, size: 54)
                    .overlay(
                        Circle().strokeBorder(
                            OrganicPalette.sageInk(colorScheme),
                            lineWidth: isShared ? 3 : 0
                        )
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if isShared {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(OrganicPalette.onSageInk(colorScheme))
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(OrganicPalette.sageInk(colorScheme)))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .background {
                        if shared.isEmpty, person.isFamily {
                            TutorialPulse(color: OrganicPalette.terracotta(colorScheme), size: 54)
                        }
                    }

                Text(person.id)
                    .font(OrganicPalette.title(13, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))

                Text("Family")
                    .font(OrganicPalette.title(10))
                    .foregroundColor(OrganicPalette.sageInk(colorScheme))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(OrganicPalette.sage(colorScheme)))
                    .opacity(person.isFamily ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShared ? "Stop sharing with \(person.id)" : "Share with \(person.id)")
    }

    private func message(from name: String) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            OrganicAvatar(name: name, profilePictureURL: nil, size: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(OrganicPalette.title(11))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                Text("On my way to Whole Foods — I'll grab the milk.")
                    .font(OrganicPalette.body(14))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(OrganicPalette.field(colorScheme))
            )

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Previews

#Preview("Add store") {
    TutorialAddStoreScene(startsDone: false, onDone: {})
        .frame(height: 320)
}

#Preview("Smart Category") {
    TutorialSmartSortScene(onDone: {})
        .frame(height: 320)
}

#Preview("Nearby") {
    TutorialNearbyScene(onDone: {})
        .frame(height: 320)
}

#Preview("Shortcuts") {
    TutorialShortcutsScene(onDone: {})
        .frame(height: 320)
}

#Preview("Sharing") {
    TutorialShareScene(onDone: {})
        .frame(height: 320)
}
