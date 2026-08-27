//
//  LocationDetailsView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/7/24.
//

import SwiftUI
import MapKit


struct LocationDetailsView: View {
    @Binding var mapSelection: MKMapItem?
    @Binding var show: Bool
    @ObservedObject var viewModel: StoresViewModel
    var onViewReminders: ((UserStoreItem) -> Void)? = nil
    @ObservedObject private var logoProvider = StoreLogoProvider.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingPaywall = false

    /// Free-tier store limit check. Existing stores over the limit are kept
    /// (grandfathered), but adding another store requires a subscription.
    private var canAddStore: Bool {
        TutorialManager.shared.isActive || SubscriptionManager.canAddStore(
            isSubscribed: subscriptionManager.isSubscribed,
            currentStoreCount: viewModel.userStoreItems.count
        )
    }

    // Find the matching UserStoreItem for the currently selected store (by normalized name)
    private var matchingUserStoreItem: UserStoreItem? {
        guard let mapSelection = mapSelection else { return nil }
        let storeName = mapSelection.name ?? ""
        let normalizedId = Store.normalizedId(from: storeName)

        return viewModel.userStoreItems.first { userStoreItem in
            Store.normalizedId(from: userStoreItem.store.name) == normalizedId
        }
    }

    private var isStoreAlreadyAdded: Bool {
        matchingUserStoreItem != nil
    }

    private var storeName: String {
        mapSelection?.name ?? "Store"
    }

    private var address: String {
        mapSelection?.placemark.title ?? "Address unavailable"
    }

    private var firstLetter: String {
        let letter = storeName.prefix(1).uppercased()
        return letter.isEmpty ? "?" : letter
    }

    /// The store's own tint, from the palette the avatars share. Keyed off the
    /// name the same way they are — `hashValue` is seeded per launch, so the
    /// old hash gave a place a different colour every time the app opened.
    ///
    /// It dresses the logo badge only. The screen's accent is terracotta like
    /// everywhere else; a sheet whose buttons change colour per store reads as
    /// a different sheet each time.
    private var storeTint: OrganicAvatarTint {
        OrganicAvatarTint.forName(storeName)
    }

    /// Friendly (icon, label) for the place's point-of-interest category.
    private var categoryInfo: (icon: String, label: String)? {
        guard let category = mapSelection?.pointOfInterestCategory else { return nil }
        switch category {
        case .cafe:        return ("cup.and.saucer.fill", "Café")
        case .restaurant:  return ("fork.knife", "Restaurant")
        case .bakery:      return ("takeoutbag.and.cup.and.straw.fill", "Bakery")
        case .foodMarket:  return ("cart.fill", "Grocery")
        case .pharmacy:    return ("cross.case.fill", "Pharmacy")
        case .gasStation:  return ("fuelpump.fill", "Gas")
        case .store:       return ("bag.fill", "Store")
        case .bank, .atm:  return ("building.columns.fill", "Bank")
        case .hotel:       return ("bed.double.fill", "Hotel")
        case .park:        return ("tree.fill", "Park")
        case .hospital:    return ("cross.fill", "Hospital")
        default:           return ("mappin.and.ellipse", "Place")
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            headerCard
            chipRow
            Spacer(minLength: 0)
            actionSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrganicPalette.canvas(colorScheme))
        .presentationBackground(OrganicPalette.canvas(colorScheme))
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(.top, 12)
                .padding(.trailing, 14)
        }
        // Learn this place's real website as soon as the sheet shows it, so the logo in
        // the header resolves from a verified domain rather than a name-based guess.
        .onAppear { recordSelectedPlaceWebsite() }
        .onChange(of: mapSelection) { _, _ in recordSelectedPlaceWebsite() }
    }

    private func recordSelectedPlaceWebsite() {
        guard let selection = mapSelection, let name = selection.name else { return }
        logoProvider.recordPlaceWebsite(storeName: name, url: selection.url)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 16) {
            logoBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(storeName)
                    .font(OrganicPalette.display(22))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .lineLimit(1)

                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        .padding(.top, 1)
                    Text(address)
                        .font(.system(size: 13))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        // Leave room on the right so the long name never slides under the close button.
        .padding(.trailing, 24)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 24))
    }

    private var logoBadge: some View {
        ZStack {
            Circle()
                .fill(storeTint.fill)
                .frame(width: 64, height: 64)

            if let image = logoProvider.cachedImage(for: storeName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
            } else if logoProvider.logoURL(for: storeName) != nil {
                ProgressView()
                    .tint(storeTint.glyph)
            } else {
                Text(firstLetter)
                    .font(OrganicPalette.title(27))
                    .foregroundColor(storeTint.glyph)
            }
        }
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 8) {
            if let categoryInfo {
                chip(
                    icon: categoryInfo.icon,
                    text: categoryInfo.label,
                    tint: OrganicPalette.terracotta(colorScheme),
                    fill: OrganicPalette.blush(colorScheme)
                )
            }

            if isStoreAlreadyAdded {
                // Sage is this palette's one non-terracotta idea, and here it is
                // "you already have this".
                chip(
                    icon: "checkmark.seal.fill",
                    text: "Saved",
                    tint: OrganicPalette.sageInk(colorScheme),
                    fill: OrganicPalette.sage(colorScheme)
                )

                if let count = matchingUserStoreItem?.store.reminderCount, count > 0 {
                    chip(
                        icon: "bell.fill",
                        text: "\(count) reminder\(count == 1 ? "" : "s")",
                        tint: OrganicPalette.terracotta(colorScheme),
                        fill: OrganicPalette.blush(colorScheme)
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func chip(icon: String, text: String, tint: Color, fill: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(fill))
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: 10) {
            if let existingItem = matchingUserStoreItem {
                Button {
                    show = false
                    mapSelection = nil
                    onViewReminders?(existingItem)
                } label: {
                    Label("View Reminders", systemImage: "bell.badge.fill")
                }
                .buttonStyle(OrganicActionButtonStyle(colorScheme: colorScheme))
            } else {
                Button {
                    guard let selectedItem = mapSelection else { return }

                    guard canAddStore else {
                        showingPaywall = true
                        return
                    }

                    let storeName = selectedItem.name ?? "Unknown Store"

                    // Record the website MapKit has for this exact place before resolving
                    // the logo, so the logo comes from the store's verified domain rather
                    // than one guessed from its name.
                    logoProvider.recordPlaceWebsite(storeName: storeName, url: selectedItem.url)

                    // Create a Store object from the MKMapItem (name-based, no address/coords stored)
                    let store = Store(
                        name: storeName,
                        imageURL: logoProvider.logoURL(for: storeName)
                    )

                    // Add store to user's list
                    viewModel.addStoreToUser(store: store)

                    // Close the detail view
                    show = false
                    mapSelection = nil
                } label: {
                    Label("Add to My Stores", systemImage: "plus.circle.fill")
                }
                .buttonStyle(OrganicActionButtonStyle(colorScheme: colorScheme))
                .sheet(isPresented: $showingPaywall) {
                    SubscriptionPaywallView()
                }
            }

            Button {
                mapSelection?.openInMaps(launchOptions: nil)
            } label: {
                Label("Open in Apple Maps", systemImage: "map.fill")
            }
            .buttonStyle(OrganicGhostButtonStyle(colorScheme: colorScheme))
        }
    }

    private var closeButton: some View {
        Button {
            show = false
            withAnimation(.snappy) {
                mapSelection = nil
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .frame(width: 30, height: 30)
                .background(Circle().fill(OrganicPalette.field(colorScheme)))
        }
    }
}

// MARK: - Button Styles

/// The sheet's primary action: the same terracotta pill the rest of the app
/// commits with. A `ButtonStyle` rather than `OrganicPillButton` because these
/// buttons carry a `Label`, not a bare title.
private struct OrganicActionButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OrganicPalette.title(17))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct OrganicGhostButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(OrganicPalette.terracotta(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Capsule().fill(OrganicPalette.blush(colorScheme)))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    LocationDetailsView(mapSelection: .constant(nil), show: .constant(false), viewModel: StoresViewModel())
}
