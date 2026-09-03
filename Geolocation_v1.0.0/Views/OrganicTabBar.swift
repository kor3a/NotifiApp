//
//  OrganicTabBar.swift
//  Geolocation_v1.0.0
//
//  The app's own bottom tab bar, drawn in the organic palette.
//

import SwiftUI
import UIKit

// MARK: - Tab

/// One destination in `OrganicTabBar`.
struct OrganicTab: Identifiable {
    /// Matches the `TabView` tag the bar drives.
    let tag: Int
    let title: String
    /// Outline glyph for the tabs the user isn't on.
    let systemImage: String
    /// Filled counterpart, so the selected tab reads as selected even in the
    /// grey-scale accessibility settings that flatten the terracotta away.
    let selectedImage: String
    /// Unread messages, waiting friend requests — zero draws nothing.
    var badge: Int = 0

    var id: Int { tag }
}

// MARK: - Tab Bar

/// The floating bar the app navigates from.
///
/// UIKit's bar is hidden behind this one rather than restyled: built against
/// the current SDK it renders as system glass, and the appearance proxy can
/// only tint that glass, never turn it into canvas. Everything the palette says
/// about a surface — the canvas fill, the shadow, the accent on its wash,
/// Commissioner labels — has to be drawn here to be true.
///
/// Deliberately the same capsule the map screen floats over its imagery, so
/// crossing into Search swaps what the bar can do without changing what it is.
struct OrganicTabBar: View {
    let tabs: [OrganicTab]
    @Binding var selection: Int
    /// Tapping the tab you are already on. The system bar pops that tab back to
    /// its root screen, and nothing else in the app does — without this, a user
    /// two screens deep on Stores taps Stores and watches nothing happen.
    var onReselect: ((Int) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var indicator

    /// The three numbers the bar is built from. Named because `reservedHeight`
    /// has to add up to exactly what the bar draws — a screen that reserves the
    /// wrong amount lands its own chrome under the capsule.
    private static let itemHeight: CGFloat = 52
    private static let capsuleInset: CGFloat = 6
    private static let bottomGap: CGFloat = 6

    /// The room a screen has to leave at its bottom edge for the bar floating
    /// over it — the space the system tab bar used to take out of the safe area.
    static let reservedHeight: CGFloat = itemHeight + capsuleInset * 2 + bottomGap

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                Button {
                    guard selection != tab.tag else {
                        onReselect?(tab.tag)
                        return
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = tab.tag
                    }
                } label: {
                    label(for: tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: tab))
                .accessibilityAddTraits(
                    selection == tab.tag ? [.isButton, .isSelected] : [.isButton]
                )
            }
        }
        .padding(.horizontal, Self.capsuleInset)
        .padding(.vertical, Self.capsuleInset)
        // Paper with a shadow rather than a blur: the bar floats over a list
        // that scrolls under it, and what separates the two is the same warm
        // shadow every card on these screens sits on.
        .background(
            Capsule()
                .fill(OrganicPalette.surface(colorScheme))
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, Self.bottomGap)
    }

    // MARK: - Item

    @ViewBuilder
    private func label(for tab: OrganicTab) -> some View {
        let isSelected = selection == tab.tag

        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isSelected ? tab.selectedImage : tab.systemImage)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                    // A fixed box under the glyph so swapping outline for fill
                    // doesn't nudge the label underneath it.
                    .frame(width: 26, height: 22)

                if tab.badge > 0 {
                    badge(tab.badge)
                        .offset(x: 11, y: -7)
                }
            }

            Text(tab.title)
                .font(OrganicPalette.body(11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(
            isSelected
                ? OrganicPalette.terracotta(colorScheme)
                : OrganicPalette.inkSoft(colorScheme)
        )
        .frame(maxWidth: .infinity)
        .frame(height: Self.itemHeight)
        .background {
            if isSelected {
                Capsule()
                    .fill(OrganicPalette.blush(colorScheme))
                    // One shape shared across the tabs, so the wash slides to
                    // the tapped one instead of blinking out and back in.
                    .matchedGeometryEffect(id: "organicTabSelection", in: indicator)
            }
        }
        .contentShape(Capsule())
    }

    /// The warm highlight rather than the accent the selected tab takes: a
    /// badge is the app saying something is waiting for you, not a control.
    /// Matches the badge on the UIKit bar underneath.
    private func badge(_ count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(OrganicPalette.title(10))
            .foregroundColor(OrganicPalette.onHighlight(colorScheme))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(OrganicPalette.highlight(colorScheme)))
            // A ring in the bar's own surface, so a badge overhanging the glyph
            // reads as sitting on top of it rather than merging into it.
            .overlay(
                Capsule().strokeBorder(OrganicPalette.surface(colorScheme), lineWidth: 1.5)
            )
    }

    private func accessibilityLabel(for tab: OrganicTab) -> String {
        tab.badge > 0 ? "\(tab.title), \(tab.badge) new" : tab.title
    }
}

// MARK: - Screen Inset

extension View {
    /// Reserves the bar's room at the bottom of a screen the bar floats over.
    ///
    /// Applied to the screen itself, not to the `TabView` or the
    /// `NavigationStack` around it: each tab and each pushed screen is hosted
    /// separately, and an inset set outside those boundaries never reaches the
    /// content — which is what left the Stores FAB and the banner ads sitting
    /// under the bar. On the screen it is ordinary SwiftUI layout, so anything
    /// the screen pins to its bottom edge lands above the bar for the same
    /// reason it used to land above the system one.
    ///
    /// Every screen under the bar needs it, pushed ones included — a
    /// conversation, a store's reminders, the profile page all pin something
    /// to the bottom.
    func organicTabBarInset() -> some View {
        modifier(OrganicTabBarInset())
    }
}

/// The reservation itself, which the keyboard takes back.
///
/// The system bar released its room the moment a keyboard covered it, and the
/// message field in a conversation rose to sit on the keyboard. A fixed inset
/// would instead hold the field a bar's height above the keyboard, so this one
/// collapses for as long as the keyboard is up — the bar is behind it anyway.
private struct OrganicTabBarInset: ViewModifier {
    @State private var isKeyboardUp = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: isKeyboardUp ? 0 : OrganicTabBar.reservedHeight)
                    // Spacing only. `Color` takes taps, and this strip sits
                    // under the gap below the capsule.
                    .allowsHitTesting(false)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification
                )
            ) { _ in
                isKeyboardUp = true
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillHideNotification
                )
            ) { _ in
                isKeyboardUp = false
            }
    }
}

#Preview {
    OrganicTabBarPreview()
}

/// Selection has to live somewhere for the bar to be tappable in a preview.
private struct OrganicTabBarPreview: View {
    @State private var selection = 0

    var body: some View {
        ZStack {
            OrganicPalette.canvas(.light).ignoresSafeArea()

            VStack {
                Spacer()
                OrganicTabBar(
                    tabs: [
                        OrganicTab(
                            tag: 0,
                            title: "Stores",
                            systemImage: "storefront",
                            selectedImage: "storefront.fill"
                        ),
                        OrganicTab(
                            tag: 1,
                            title: "Messages",
                            systemImage: "message",
                            selectedImage: "message.fill",
                            badge: 3
                        ),
                        OrganicTab(
                            tag: 2,
                            title: "Friends",
                            systemImage: "person.2",
                            selectedImage: "person.2.fill",
                            badge: 12
                        ),
                        OrganicTab(
                            tag: 3,
                            title: "Search",
                            systemImage: "map",
                            selectedImage: "map.fill"
                        ),
                    ],
                    selection: $selection
                )
            }
        }
    }
}
