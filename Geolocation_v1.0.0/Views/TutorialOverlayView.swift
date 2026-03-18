//
//  TutorialOverlayView.swift
//  Geolocation_v1.0.0
//
//  Full-screen tutorial overlay that dims the UI, highlights a target element
//  with an animated rectangle border, and shows a callout card.
//

import SwiftUI

// MARK: - Tutorial Overlay View

struct TutorialOverlayView: View {
    @ObservedObject private var tutorialManager = TutorialManager.shared
    @State private var borderOpacity: Double = 1.0
    @State private var glowOpacity: Double = 0.5
    @State private var glowRadius: CGFloat = 8
    @State private var appeared: Bool = false

    private var step: TutorialStep { tutorialManager.currentStep }

    private var highlightRect: CGRect? {
        guard let id = step.elementId else { return nil }
        return tutorialManager.elementFrames[id]
    }

    // Padded rectangle for the highlight cutout
    private var paddedRect: CGRect? {
        guard let rect = highlightRect else { return nil }
        return rect.insetBy(dx: -14, dy: -14)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed backdrop with cutout
                dimmingLayer(in: geo)

                // Animated highlight border
                if let rect = paddedRect {
                    highlightBorder(rect: rect)
                }

                // Family action popover — shown anchored to the friend card
                if step == .friendsFamily, let rect = paddedRect {
                    familyActionPopover(anchoredTo: rect, in: geo)
                }

                // Callout card (above or below the highlight)
                calloutCard(in: geo)
            }
        }
        .ignoresSafeArea()
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.25)) {
                appeared = true
            }
            startPulseAnimation()
        }
        .onChange(of: step) { _, _ in
            // Reset pulse on step change
            borderOpacity = 1.0
            glowOpacity = 0.5
            glowRadius = 8
            startPulseAnimation()
        }
    }

    // MARK: - Dimming Layer

    @ViewBuilder
    private func dimmingLayer(in geo: GeometryProxy) -> some View {
        if let rect = paddedRect {
            // Even-odd fill: full screen rect minus the highlight cutout = dark everywhere except the hole
            Canvas { context, size in
                var fullScreen = Path()
                fullScreen.addRect(CGRect(origin: .zero, size: size))

                var cutout = Path()
                let cornerRadius: CGFloat = 14
                cutout.addRoundedRect(
                    in: rect,
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )

                var combined = fullScreen
                combined.addPath(cutout)

                context.fill(combined, with: .color(Color.black.opacity(0.62)),
                             style: FillStyle(eoFill: true))
            }
            .ignoresSafeArea()
        } else {
            // Welcome / complete screens: no cutout, full dim
            Color.black.opacity(0.62)
                .ignoresSafeArea()
        }
    }

    // MARK: - Animated Highlight Border

    private func highlightBorder(rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white, Color.blue.opacity(0.9), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2.5
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            // Pulse via opacity and glow only — no scaleEffect so the border
            // never moves outside the cutout hole regardless of element size.
            .opacity(borderOpacity)
            .shadow(color: Color.blue.opacity(glowOpacity), radius: glowRadius, x: 0, y: 0)
            .shadow(color: Color.white.opacity(glowOpacity * 0.5), radius: glowRadius * 0.5, x: 0, y: 0)
    }

    // MARK: - Callout Card

    @ViewBuilder
    private func calloutCard(in geo: GeometryProxy) -> some View {
        let cardWidth: CGFloat = min(geo.size.width - 40, 340)
        let cardX: CGFloat = geo.size.width / 2

        // Decide whether the card goes above or below the highlight
        let cardY: CGFloat = cardVerticalPosition(in: geo, cardHeight: 180)

        VStack(spacing: 0) {
            calloutCardContent(cardWidth: cardWidth)
        }
        .frame(width: cardWidth)
        .position(x: cardX, y: cardY)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
    }

    private func calloutCardContent(cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Step indicator dots
            if step != .welcome && step != .complete {
                stepDots
            }

            // Title
            Text(step.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Description
            Text(step.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Buttons
            HStack {
                // Skip button (not shown on final step)
                if step != .complete {
                    Button(action: { tutorialManager.skip() }) {
                        Text("Skip")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Next / Get Started
                Button(action: {
                    if step.isLastStep {
                        tutorialManager.finish()
                    } else {
                        tutorialManager.advance()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(step.buttonLabel)
                            .font(.system(size: 15, weight: .semibold))
                        if !step.isLastStep {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 8)
        )
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        let steps = TutorialStep.allCases.filter { $0 != .welcome && $0 != .complete }
        return HStack(spacing: 6) {
            ForEach(steps, id: \.rawValue) { s in
                Circle()
                    .fill(s == step ? Color.white : Color.white.opacity(0.3))
                    .frame(width: s == step ? 8 : 6, height: s == step ? 8 : 6)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    // MARK: - Vertical Positioning

    private func cardVerticalPosition(in geo: GeometryProxy, cardHeight: CGFloat) -> CGFloat {
        let screenH = geo.size.height
        let padding: CGFloat = 16

        guard let rect = paddedRect else {
            // No highlight: center in screen
            return screenH / 2
        }

        let spaceAbove = rect.minY
        let spaceBelow = screenH - rect.maxY

        if spaceBelow >= cardHeight + padding * 2 {
            // Fits below
            return rect.maxY + padding + cardHeight / 2
        } else if spaceAbove >= cardHeight + padding * 2 {
            // Fits above
            return rect.minY - padding - cardHeight / 2
        } else {
            // Not enough space — center below with overlap allowed
            return rect.maxY + padding + cardHeight / 2
        }
    }

    // MARK: - Family Action Popover

    /// An iOS-style action sheet popover pinned above (or below) the highlighted friend card.
    private func familyActionPopover(anchoredTo rect: CGRect, in geo: GeometryProxy) -> some View {
        let popoverWidth: CGFloat = 260
        let popoverHeight: CGFloat = 138
        let gap: CGFloat = 10

        // Prefer above the card; fall back to below if there isn't enough room.
        let spaceAbove = rect.minY - gap
        let fitsAbove = spaceAbove >= popoverHeight

        let popoverY: CGFloat = fitsAbove
            ? rect.minY - gap - popoverHeight / 2
            : rect.maxY + gap + popoverHeight / 2

        // Clamp horizontally so it never bleeds off screen.
        let rawX = rect.midX
        let popoverX = min(max(rawX, popoverWidth / 2 + 12), geo.size.width - popoverWidth / 2 - 12)

        return VStack(spacing: 0) {
            // Title row
            Text("Add Alex to Family?")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // Primary action
            Text("Add to Family")
                .font(.system(size: 17))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

            Divider()

            // Cancel
            Text("Cancel")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .frame(width: popoverWidth)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.systemBackground).opacity(0.97))
                .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .position(x: popoverX, y: popoverY)
        .transition(.scale(scale: 0.85, anchor: fitsAbove ? .bottom : .top).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.1)
            .repeatForever(autoreverses: true)
        ) {
            borderOpacity = 0.55
            glowOpacity = 1.0
            glowRadius = 18
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        Text("App content here")
        TutorialOverlayView()
    }
    .onAppear {
        TutorialManager.shared.startIfNeeded()
    }
}
