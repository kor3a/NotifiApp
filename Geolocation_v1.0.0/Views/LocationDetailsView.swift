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

    /// A stable per-store accent color so each place gets its own personality.
    private var accentColor: Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .cyan]
        let hash = abs(storeName.hashValue)
        return palette[hash % palette.count]
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(accentColor)
                        .padding(.top, 1)
                    Text(address)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        // Leave room on the right so the long name never slides under the close button.
        .padding(.trailing, 24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(accentColor.opacity(colorScheme == .dark ? 0.10 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accentColor.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var logoBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accentGradient)
                .frame(width: 68, height: 68)
                .shadow(color: accentColor.opacity(0.45), radius: 10, x: 0, y: 6)

            // Glossy top highlight for a little depth.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 68, height: 68)

            if let image = logoProvider.cachedImage(for: storeName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if logoProvider.logoURL(for: storeName) != nil {
                ProgressView()
                    .tint(.white)
            } else {
                Text(firstLetter)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 8) {
            if let categoryInfo {
                chip(icon: categoryInfo.icon, text: categoryInfo.label, tint: accentColor)
            }

            if isStoreAlreadyAdded {
                chip(icon: "checkmark.seal.fill", text: "Saved", tint: .green)

                if let count = matchingUserStoreItem?.store.reminderCount, count > 0 {
                    chip(
                        icon: "bell.fill",
                        text: "\(count) reminder\(count == 1 ? "" : "s")",
                        tint: .orange
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func chip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(tint.opacity(colorScheme == .dark ? 0.20 : 0.13))
        )
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
                .buttonStyle(GradientActionButtonStyle(gradient: accentGradient))
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
                .buttonStyle(GradientActionButtonStyle(gradient: accentGradient))
                .sheet(isPresented: $showingPaywall) {
                    SubscriptionPaywallView()
                }
            }

            Button {
                mapSelection?.openInMaps(launchOptions: nil)
            } label: {
                Label("Open in Apple Maps", systemImage: "map.fill")
            }
            .buttonStyle(GhostActionButtonStyle(tint: accentColor))
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
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}

// MARK: - Button Styles

private struct GradientActionButtonStyle: ButtonStyle {
    let gradient: LinearGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct GhostActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    LocationDetailsView(mapSelection: .constant(nil), show: .constant(false), viewModel: StoresViewModel())
}
