//
//  OrganicTabBar.swift
//  Geolocation_v1.0.0
//
//  The app's own bottom tab bar, drawn in the organic palette.
//

import SwiftUI

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

/// The floating paper bar the app navigates from.
///
/// UIKit's bar is hidden behind this one rather than restyled: built against
/// the current SDK it renders as system glass, and the appearance proxy can
/// only tint that glass, never turn it into paper. Everything the palette says
/// about a surface — the cream fill, the warm shadow, terracotta on blush,
/// Commissioner labels — has to be drawn here to be true.
///
/// Deliberately the same capsule the map screen floats over its imagery, so
/// crossing into Search swaps what the bar can do without changing what it is.
struct OrganicTabBar: View {
    let tabs: [OrganicTab]
    @Binding var selection: Int

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                Button {
                    guard selection != tab.tag else { return }
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
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        // Paper with a shadow rather than a blur: the bar floats over a list
        // that scrolls under it, and what separates the two is the same warm
        // shadow every card on these screens sits on.
        .background(
            Capsule()
                .fill(OrganicPalette.surface(colorScheme))
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
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
        .frame(height: 52)
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

    private func badge(_ count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(OrganicPalette.title(10))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
            // A ring in the bar's own paper, so a badge overhanging the glyph
            // reads as sitting on top of it rather than merging into it.
            .overlay(
                Capsule().strokeBorder(OrganicPalette.surface(colorScheme), lineWidth: 1.5)
            )
    }

    private func accessibilityLabel(for tab: OrganicTab) -> String {
        tab.badge > 0 ? "\(tab.title), \(tab.badge) new" : tab.title
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
