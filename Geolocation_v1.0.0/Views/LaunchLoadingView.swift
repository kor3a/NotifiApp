//
//  LaunchLoadingView.swift
//  Geolocation_v1.0.0
//
//  The screen the app opens on while a signed-in account is being restored.
//

import SwiftUI

/// What a returning user sees between launch and their stores appearing.
///
/// Opening straight into `StoresView` meant the header rendered before the
/// profile came back, so the greeting fell through to its "Hi, there"
/// placeholder above an empty list — a stranger's screen for the half second
/// the fetch takes. This stands in its place: the app's own mark, a line
/// saying what is happening, and skeletons in the shape of the store rows
/// that are about to land, so the wait reads as the list loading rather than
/// as an empty app.
///
/// Used both full-screen (during the profile lookup, before the tab bar is
/// even built) and inside `StoresView`'s content while the store snapshot is
/// in flight, which is why the background is optional — inside Stores the
/// user's own chosen background is already drawn behind it.
struct LaunchLoadingView: View {
    /// Draw the canvas behind the content. False when the caller has
    /// already laid down a background of its own.
    var drawsBackground: Bool = true

    /// Say what is loading. False for the moment before the app knows whether
    /// anyone is signed in at all — a launch that ends at the login screen
    /// shouldn't have promised stores on the way there. The mark holds the
    /// screen either way, so this only ever adds to what is already drawn.
    var namesStores: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            if drawsBackground {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                mark

                if namesStores {
                    VStack(spacing: 6) {
                        Text("Loading your stores")
                            .font(OrganicPalette.display(26))
                            .foregroundColor(OrganicPalette.ink(colorScheme))

                        Text("Just a moment…")
                            .font(OrganicPalette.body(15))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    }
                    .padding(.top, 18)

                    if reduceMotion {
                        // Nothing else on the screen moves in this mode, so the
                        // spinner is the only thing left saying the app is working.
                        ProgressView()
                            .tint(OrganicPalette.terracotta(colorScheme))
                            .padding(.top, 20)
                    }

                    VStack(spacing: 10) {
                        skeletonRow(nameWidth: 132, index: 0)
                        skeletonRow(nameWidth: 96, index: 1)
                        skeletonRow(nameWidth: 116, index: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                }

                Spacer(minLength: 24)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(namesStores ? "Loading your stores" : "Loading")
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear { isAnimating = true }
    }

    // MARK: - Mark

    /// The same mark and blush disc the login screen opens on, so a relaunch
    /// carries on from the artwork the user already associates with the app.
    private var mark: some View {
        Image("AllimMark")
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
            .frame(width: 96, height: 96)
            .background(Circle().fill(OrganicPalette.blush(colorScheme)))
            .scaleEffect(reduceMotion ? 1.0 : (isAnimating ? 1.06 : 0.94))
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .accessibilityHidden(true)
    }

    // MARK: - Skeleton Rows

    /// A store row with its content replaced by blocks: the logo disc, the
    /// name, and the reminder badge, at the same sizes and on the same surface
    /// card `StoreItemView` uses, so the real rows land where these sat.
    private func skeletonRow(nameWidth: CGFloat, index: Int) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(placeholder)
                .frame(width: 48, height: 48)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(placeholder)
                .frame(width: nameWidth, height: 14)

            Spacer(minLength: 8)

            Capsule()
                .fill(placeholder)
                .frame(width: 34, height: 24)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(OrganicCardBackground(colorScheme: colorScheme))
        .overlay(shimmer(delay: Double(index) * 0.18))
        .opacity(1.0 - Double(index) * 0.18)
    }

    /// The blocks are a shade of the canvas rather than grey — a system
    /// placeholder grey reads as a broken image on the canvas.
    private var placeholder: Color {
        OrganicPalette.field(colorScheme)
    }

    /// A soft band of light travelling across a card. Clipped to the card's own
    /// shape so it never spills onto the canvas, and staggered per row so the
    /// three read as one sweep rather than three blinks.
    @ViewBuilder
    private func shimmer(delay: Double) -> some View {
        if !reduceMotion {
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        .clear,
                        OrganicPalette.surface(colorScheme).opacity(colorScheme == .dark ? 0.55 : 0.9),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.55)
                .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.55)
                .animation(
                    .easeInOut(duration: 1.3)
                        .repeatForever(autoreverses: false)
                        .delay(delay),
                    value: isAnimating
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    LaunchLoadingView()
}
