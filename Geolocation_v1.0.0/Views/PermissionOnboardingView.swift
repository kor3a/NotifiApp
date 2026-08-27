//
//  PermissionOnboardingView.swift
//  Geolocation_v1.0.0
//
//  The permission primers a new account sees between profile setup and the
//  tutorial: one screen for location, one for notifications. Each explains what
//  the permission buys the user, and the button at the bottom is what triggers
//  the real iOS prompt — the system dialog never appears unprompted.
//
//  Answering a prompt (either way) moves the walkthrough on. iOS only asks once
//  per install, so a decline can't be retried here; the screens after this point
//  and Settings are where a user changes their mind.
//

import SwiftUI
import CoreLocation
import UserNotifications

// MARK: - Container

struct PermissionOnboardingView: View {

    @ObservedObject private var manager = PermissionOnboardingManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            if case .active(let step) = manager.state {
                Group {
                    switch step {
                    case .location:
                        LocationPermissionPrimerView()
                    case .notifications:
                        NotificationPermissionPrimerView()
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }//:ZSTACK
    }
}

// MARK: - Location

private struct LocationPermissionPrimerView: View {

    @ObservedObject private var locationMonitor = LocationMonitoringManager.shared
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isRequesting = false

    var body: some View {
        PermissionPrimerScaffold(
            step: .location,
            symbol: "location.fill",
            title: "Enable Location Services",
            subtitle: "Allim uses your location while you're using the app to spot the stores nearby. Choose \"Allow While Using App\" when iOS asks.",
            bullets: [
                PermissionPrimerBullet(
                    symbol: "bell.badge",
                    title: "Reminders at the right moment",
                    detail: "Get your list the moment you're near a store you saved — not hours after you've driven past it."
                ),
                PermissionPrimerBullet(
                    symbol: "storefront",
                    title: "Stores around you",
                    detail: "See the supermarkets and shops nearby on the map without typing in an address."
                )
            ],
            footnote: "You can change this any time in Settings.",
            buttonTitle: "Enable Location",
            isRequesting: isRequesting,
            action: requestLocation
        )
        .onChange(of: locationMonitor.authorizationStatus) { _, status in
            // Covers grant *and* denial: iOS won't ask again either way, so both
            // answers end this step.
            guard status != .notDetermined else { return }
            PermissionOnboardingManager.shared.advance(from: .location)
        }
        .onChange(of: scenePhase) { _, phase in
            // Safety net for a prompt that was answered while the app wasn't
            // frontmost (e.g. answered from a Settings round trip), where the
            // delegate callback can land before this screen is listening.
            guard phase == .active, isRequesting else { return }
            guard locationMonitor.checkLocationPermission() != .notDetermined else { return }
            PermissionOnboardingManager.shared.advance(from: .location)
        }
    }

    private func requestLocation() {
        guard !isRequesting else { return }

        let status = locationMonitor.checkLocationPermission()
        guard status == .notDetermined else {
            // Restricted by Screen Time, or answered elsewhere in the meantime —
            // no dialog is coming, so don't leave the user waiting on one.
            PermissionOnboardingManager.shared.advance(from: .location)
            return
        }

        isRequesting = true

        // Seed the monitor so a grant starts geofencing immediately instead of
        // waiting for HomeView to appear.
        if let userId = sessionManager.currentUser?.userId {
            locationMonitor.setUserId(userId)
        }

        locationMonitor.requestLocationPermission()
    }
}

// MARK: - Notifications

private struct NotificationPermissionPrimerView: View {

    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var isRequesting = false

    var body: some View {
        PermissionPrimerScaffold(
            step: .notifications,
            symbol: "bell.badge.fill",
            title: "Turn On Notifications",
            subtitle: "Notifications are how a reminder actually finds you — while you're still in the store, not after you've driven home.",
            bullets: [
                PermissionPrimerBullet(
                    symbol: "cart",
                    title: "Nearby store alerts",
                    detail: "A tap-to-open list of what you still need, right as you arrive at a store."
                ),
                PermissionPrimerBullet(
                    symbol: "message",
                    title: "Messages and friend requests",
                    detail: "Know when a friend messages you or sends you a request."
                ),
                PermissionPrimerBullet(
                    symbol: "person.2",
                    title: "Shared list updates",
                    detail: "See when someone adds to — or checks off — a list you share with them."
                )
            ],
            footnote: "You can fine-tune or turn these off any time in Settings.",
            buttonTitle: "Enable Notifications",
            isRequesting: isRequesting,
            action: requestNotifications
        )
    }

    private func requestNotifications() {
        guard !isRequesting else { return }
        isRequesting = true

        Task {
            // Already answered (only reachable if something else asked first) —
            // requesting again wouldn't show a dialog, so just move on.
            if await notificationManager.authorizationStatus() == .notDetermined {
                _ = await notificationManager.requestAuthorization()
            }
            notificationManager.checkAuthorizationStatus()

            await MainActor.run {
                PermissionOnboardingManager.shared.advance(from: .notifications)
            }
        }
    }
}

// MARK: - Shared Layout

private struct PermissionPrimerBullet: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

/// The shared shape of both primers: an icon and a promise up top, the reasons
/// in the middle, and the one button that opens the system prompt pinned to the
/// bottom where the user's thumb already is.
private struct PermissionPrimerScaffold: View {

    let step: PermissionOnboardingManager.Step
    let symbol: String
    let title: String
    let subtitle: String
    let bullets: [PermissionPrimerBullet]
    let footnote: String
    let buttonTitle: String
    let isRequesting: Bool
    let action: () -> Void

    @ObservedObject private var manager = PermissionOnboardingManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    icon

                    VStack(spacing: 12) {
                        Text(title)
                            .font(OrganicPalette.display(30))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                            .multilineTextAlignment(.center)

                        Text(subtitle)
                            .font(OrganicPalette.body(16))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(bullets) { bullet in
                            bulletRow(bullet)
                        }
                    }
                    .padding(22)
                    .background(OrganicCardBackground(colorScheme: colorScheme))
                }
                .padding(.horizontal, 24)
                .padding(.top, 44)
                .padding(.bottom, 28)
            }//:SCROLLVIEW
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 14) {
                if manager.stepCount > 1 {
                    stepIndicator
                }

                OrganicPillButton(
                    title: buttonTitle,
                    isLoading: isRequesting,
                    fillsWidth: true,
                    action: action
                )
                .disabled(isRequesting)

                Text(footnote)
                    .font(OrganicPalette.body(12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }//:VSTACK
    }

    /// The same shape the About screen gives the app itself — a terracotta
    /// glyph resting on a blush disc — so the first screens a new account sees
    /// are already speaking the app's language.
    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 48, weight: .semibold))
            .foregroundColor(OrganicPalette.terracotta(colorScheme))
            .frame(width: 120, height: 120)
            .background(Circle().fill(OrganicPalette.blush(colorScheme)))
    }

    private func bulletRow(_ bullet: PermissionPrimerBullet) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: bullet.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 38, height: 38)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            VStack(alignment: .leading, spacing: 4) {
                Text(bullet.title)
                    .font(OrganicPalette.body(16, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))

                Text(bullet.detail)
                    .font(OrganicPalette.body(14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 7) {
            ForEach(Array(0..<manager.stepCount), id: \.self) { index in
                Capsule()
                    .fill(index + 1 == manager.position(of: step)
                          ? OrganicPalette.terracotta(colorScheme)
                          : OrganicPalette.outline(colorScheme))
                    .frame(width: index + 1 == manager.position(of: step) ? 20 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: manager.position(of: step))
        .accessibilityElement()
        .accessibilityLabel("Step \(manager.position(of: step)) of \(manager.stepCount)")
    }
}

// Previewed one screen at a time: the container renders whichever step the
// manager is on, and the manager has no signed-in account in a preview.
#Preview("Location") {
    LocationPermissionPrimerView()
        .background(OrganicPalette.canvas(.light).ignoresSafeArea())
}

#Preview("Notifications") {
    NotificationPermissionPrimerView()
        .background(OrganicPalette.canvas(.dark).ignoresSafeArea())
        .preferredColorScheme(.dark)
}
