//
//  TutorialReminderScene.swift
//  Geolocation_v1.0.0
//
//  A self-contained, non-interactive mock of the Reminders screen used by the
//  onboarding tutorial. It renders over the live app (which stays on the Stores
//  tab) so we can walk new users through the reminder list without needing real
//  Firestore data or pushing the real ReminderView. Each step emphasises a
//  different feature: auto-categorised items, the info (i) list menu, and the
//  touch-and-hold item shortcut menu.
//

import SwiftUI

struct TutorialReminderScene: View {
    let step: TutorialStep
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false

    // MARK: - Mock Data

    private struct MockReminder: Identifiable {
        let id = UUID()
        let title: String
        var quantity: Int? = nil
        var isDone: Bool = false
    }

    private struct MockCategory: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let items: [MockReminder]
    }

    private let categories: [MockCategory] = [
        MockCategory(name: "Produce", icon: "leaf", items: [
            MockReminder(title: "Bananas", quantity: 2),
            MockReminder(title: "Baby Spinach"),
            MockReminder(title: "Avocados", quantity: 3),
        ]),
        MockCategory(name: "Dairy", icon: "cup.and.saucer", items: [
            MockReminder(title: "Whole Milk"),
            MockReminder(title: "Greek Yogurt", isDone: true),
        ]),
        MockCategory(name: "Bakery", icon: "birthday.cake", items: [
            MockReminder(title: "Sourdough Bread"),
        ]),
    ]

    /// The reminder the "hold for shortcuts" step anchors its menu to.
    private var anchorReminder: MockReminder { categories[0].items[0] }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Opaque app-like background so the scene fully covers the live UI.
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar
                remindersList
            }

            // The info (i) list menu, anchored below the nav bar's info button.
            if step == .remindersInfoMenu {
                infoMenu
                    .padding(.top, topInset + 46)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }

            // The touch-and-hold shortcut menu for a single reminder item.
            if step == .remindersItemMenu {
                itemShortcutMenu
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: step)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Colors

    private var backgroundColor: Color {
        OrganicPalette.canvas(colorScheme)
    }

    private var cardFill: Color {
        OrganicPalette.surface(colorScheme)
    }

    /// The accent the mock draws its highlights in, matching the real screen.
    private var accent: Color {
        OrganicPalette.terracotta(colorScheme)
    }

    /// Approximate top safe-area inset — the parent overlay ignores the safe
    /// area, so we position the mock nav bar manually below the status bar.
    private var topInset: CGFloat { 54 }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text("Stores")
                    .font(.system(size: 17))
            }
            .foregroundColor(accent)

            Spacer()

            VStack(spacing: 1) {
                Text("Whole Foods")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                Text("6 items")
                    .font(.system(size: 12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer()

            // Info (i) button — highlighted during the info-menu step.
            ZStack {
                if step == .remindersInfoMenu {
                    Circle()
                        .fill(OrganicPalette.blush(colorScheme))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulse ? 1.15 : 0.9)
                }
                Image(systemName: step == .remindersInfoMenu ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(accent)
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, topInset)
        .padding(.bottom, 10)
        .background(
            backgroundColor
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(OrganicPalette.outline(colorScheme).opacity(0.5))
                        .frame(height: 1)
                }
        )
    }

    // MARK: - Reminders List

    private var remindersList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(categories) { category in
                    categoryHeader(for: category)
                    ForEach(category.items) { item in
                        reminderRow(item)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollDisabled(true)
    }

    private func categoryHeader(for category: MockCategory) -> some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 20)

            Text(category.name)
                .font(OrganicPalette.display(20))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            OrganicCountBadge(count: category.items.count, fontSize: 12)

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(step == .remindersCategories ? (pulse ? 0.16 : 0.06) : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    accent.opacity(step == .remindersCategories ? (pulse ? 0.7 : 0.25) : 0),
                    lineWidth: 1.5
                )
        )
    }

    private func reminderRow(_ item: MockReminder) -> some View {
        let isAnchor = step == .remindersItemMenu && item.id == anchorReminder.id
        return HStack(spacing: 12) {
            Image(systemName: item.isDone ? "checkmark.square" : "square")
                .font(.system(size: 20))
                .foregroundColor(
                    item.isDone
                        ? OrganicPalette.inkSoft(colorScheme)
                        : OrganicPalette.ink(colorScheme)
                )

            Text(item.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(
                    item.isDone
                        ? OrganicPalette.inkSoft(colorScheme)
                        : OrganicPalette.ink(colorScheme)
                )
                .strikethrough(item.isDone, color: OrganicPalette.inkSoft(colorScheme))

            Spacer()

            if let quantity = item.quantity {
                Text("Qty: \(quantity)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(OrganicPalette.field(colorScheme)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardFill)
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    accent.opacity(isAnchor ? (pulse ? 0.85 : 0.4) : 0),
                    lineWidth: 2
                )
        )
        .scaleEffect(isAnchor ? 1.02 : 1.0)
        .shadow(color: accent.opacity(isAnchor ? 0.35 : 0), radius: isAnchor ? 16 : 0)
        .zIndex(isAnchor ? 5 : 0)
    }

    // MARK: - Info (i) List Menu

    private var infoMenu: some View {
        VStack(spacing: 0) {
            infoMenuRow(
                icon: "trash",
                title: "Auto Delete",
                subtitle: "Delete checked items automatically",
                trailing: .toggle(isOn: false)
            )
            menuDivider
            infoMenuRow(
                icon: "sparkles",
                title: "Smart Category",
                subtitle: "AI auto-categorizes new items",
                trailing: .toggle(isOn: true)
            )
            menuDivider
            infoMenuRow(
                icon: "fork.knife",
                title: "Recipes",
                subtitle: "Add ingredients from a saved recipe",
                trailing: .chevron
            )
            menuDivider
            infoMenuRow(
                icon: "safari",
                title: "Visit store",
                subtitle: "Open the store's app or website",
                trailing: .arrow
            )
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardFill)
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(accent.opacity(pulse ? 0.6 : 0.2), lineWidth: 1.5)
        )
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(OrganicPalette.outline(colorScheme).opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private enum InfoTrailing {
        case toggle(isOn: Bool)
        case chevron
        case arrow
    }

    private func infoMenuRow(icon: String, title: String, subtitle: String, trailing: InfoTrailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }
            Spacer(minLength: 8)
            switch trailing {
            case .toggle(let isOn):
                // Static toggle mock (non-interactive).
                Capsule()
                    .fill(isOn ? accent : OrganicPalette.field(colorScheme))
                    .frame(width: 44, height: 28)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                            .padding(2)
                    }
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
            case .arrow:
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Item Shortcut (touch-and-hold) Menu

    private var itemShortcutMenu: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: topInset + 120)

            VStack(spacing: 0) {
                shortcutRow(title: "Out of Stock", icon: "xmark.circle")
                menuDivider
                shortcutRow(title: "Move to Store", icon: "arrow.right.square", showsSubmenuChevron: true)
                menuDivider
                shortcutRow(title: "Add Photos", icon: "photo.on.rectangle.angled")
                menuDivider
                shortcutRow(title: "Add Quantity", icon: "number")
                menuDivider
                shortcutRow(title: "Change Category", icon: "tag")
            }
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardFill)
                    .shadow(color: OrganicPalette.shadow(colorScheme), radius: 24, x: 0, y: 10)
            )

            Spacer()
        }
    }

    private func shortcutRow(title: String, icon: String, showsSubmenuChevron: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(OrganicPalette.ink(colorScheme))
            Spacer()
            if showsSubmenuChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .padding(.trailing, 4)
            }
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(OrganicPalette.ink(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Preview

#Preview("Categories") {
    TutorialReminderScene(step: .remindersCategories)
}

#Preview("Info Menu") {
    TutorialReminderScene(step: .remindersInfoMenu)
}

#Preview("Item Menu") {
    TutorialReminderScene(step: .remindersItemMenu)
}
