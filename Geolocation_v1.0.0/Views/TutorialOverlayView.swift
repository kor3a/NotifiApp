//
//  TutorialOverlayView.swift
//  Geolocation_v1.0.0
//
//  The new-user tutorial: a full-screen, playable story. Instead of dimming
//  the live app and pointing at its buttons, each chapter stages a small
//  working demo of one idea (see TutorialScenes.swift) and asks the user to
//  try it — tap the +, drag themselves to a store, hold an item. Nothing is
//  gated: Next always works, it just asks louder once the demo is played.
//

import SwiftUI

// MARK: - Tutorial Overlay View

struct TutorialOverlayView: View {
    @ObservedObject private var tutorial = TutorialManager.shared
    @Environment(\.colorScheme) private var colorScheme

    private var step: TutorialStep { tutorial.currentStep }
    private var isDone: Bool { tutorial.completedSteps.contains(step) }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                header

                page
                    .id(step)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 28)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        )
                    )

                footer
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Backdrop

    /// The canvas, with two soft washes of color that drift to a new spot on
    /// every page so the screen feels like it is moving along with the story.
    private var backdrop: some View {
        GeometryReader { geo in
            let drift = CGFloat(step.rawValue)
            ZStack {
                OrganicPalette.canvas(colorScheme)

                Circle()
                    .fill(OrganicPalette.blush(colorScheme))
                    .frame(width: 380, height: 380)
                    .blur(radius: 80)
                    .position(
                        x: geo.size.width * (drift.truncatingRemainder(dividingBy: 2) == 0 ? 0.12 : 0.88),
                        y: geo.size.height * (0.1 + 0.07 * drift)
                    )

                Circle()
                    .fill(OrganicPalette.highlightWash(colorScheme))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .position(
                        x: geo.size.width * (drift.truncatingRemainder(dividingBy: 2) == 0 ? 0.9 : 0.15),
                        y: geo.size.height * (0.92 - 0.06 * drift)
                    )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                ForEach(TutorialStep.chapters, id: \.self) { chapter in
                    Capsule()
                        .fill(
                            chapter.rawValue <= step.rawValue
                                ? OrganicPalette.terracotta(colorScheme)
                                : OrganicPalette.outlineStrong(colorScheme).opacity(0.6)
                        )
                        .frame(height: 4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(progressLabel)

            if step != .finale {
                Button {
                    tutorial.skip()
                } label: {
                    Text("Skip")
                        .font(OrganicPalette.title(15, weight: .semibold))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .padding(.vertical, 10)
                        .padding(.leading, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 48)
    }

    private var progressLabel: String {
        guard let number = step.chapterNumber else {
            return step == .finale ? "Tour complete" : "Tour not started"
        }
        return "Step \(number) of \(TutorialStep.chapters.count)"
    }

    // MARK: - Page

    @ViewBuilder
    private var page: some View {
        switch step {
        case .intro:
            TutorialIntroPage()
        case .finale:
            TutorialFinalePage()
        default:
            chapterPage
        }
    }

    private var chapterPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(String(format: "%02d", step.chapterNumber ?? 0))
                    .font(OrganicPalette.title(13, weight: .black))
                    .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))

                Text(step.eyebrow.uppercased())
                    .font(OrganicPalette.title(13))
                    .tracking(1.2)
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
            }
            .padding(.top, 10)

            Text(step.title)
                .font(OrganicPalette.display(30))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text(step.description)
                .font(OrganicPalette.body(16))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            stage
                .padding(.top, 18)

            hintChip
                .padding(.top, 12)
                .padding(.bottom, 14)
        }
    }

    /// The card the chapter's demo plays on.
    private var stage: some View {
        scene
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(OrganicPalette.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(OrganicPalette.outline(colorScheme), lineWidth: 1)
            )
            .shadow(color: OrganicPalette.shadow(colorScheme), radius: 18, x: 0, y: 8)
    }

    @ViewBuilder
    private var scene: some View {
        let finished = { tutorial.markDone(step) }
        switch step {
        case .addStore:
            TutorialAddStoreScene(startsDone: isDone, onDone: finished)
        case .smartSort:
            TutorialSmartSortScene(onDone: finished)
        case .nearby:
            TutorialNearbyScene(onDone: finished)
        case .shortcuts:
            TutorialShortcutsScene(onDone: finished)
        case .share:
            TutorialShareScene(onDone: finished)
        case .intro, .finale:
            EmptyView()
        }
    }

    /// The instruction under the stage, which turns into a small "done" note
    /// the moment the user has played the demo.
    private var hintChip: some View {
        HStack(spacing: 8) {
            Image(systemName: isDone ? "checkmark.circle.fill" : step.hintIcon)
                .font(.system(size: 14, weight: .semibold))
            Text(isDone ? step.doneNote : step.hint)
                .font(OrganicPalette.title(14, weight: .semibold))
        }
        .foregroundColor(
            isDone ? OrganicPalette.sageInk(colorScheme) : OrganicPalette.inkOnBlush(colorScheme)
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(
                isDone ? OrganicPalette.sage(colorScheme) : OrganicPalette.blush(colorScheme)
            )
        )
        .id(isDone)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .intro:
            pill(title: "Take the tour", systemImage: "arrow.right", prominent: true) {
                tutorial.advance()
            }
        case .finale:
            pill(title: "Start shopping", systemImage: nil, prominent: true) {
                tutorial.finish()
            }
        default:
            HStack(spacing: 12) {
                OrganicCircleButton(systemImage: "chevron.left", size: 56, glyphSize: 18) {
                    tutorial.back()
                }
                .accessibilityLabel("Back")

                // Quiet until the demo has been played, then filled: the
                // button never blocks, it just changes how hard it asks.
                pill(title: "Next", systemImage: "arrow.right", prominent: isDone) {
                    tutorial.advance()
                }
            }
        }
    }

    private func pill(
        title: String,
        systemImage: String?,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(OrganicPalette.title(17))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(
                prominent
                    ? OrganicPalette.onTerracotta(colorScheme)
                    : OrganicPalette.inkOnBlush(colorScheme)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule().fill(
                    prominent
                        ? OrganicPalette.terracotta(colorScheme)
                        : OrganicPalette.blush(colorScheme)
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Intro Page

private struct TutorialIntroPage: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            TutorialHero()
                .frame(maxWidth: .infinity)
                .frame(height: 260)

            Spacer(minLength: 0)

            Text(TutorialStep.intro.eyebrow.uppercased())
                .font(OrganicPalette.title(13))
                .tracking(1.2)
                .foregroundColor(OrganicPalette.terracotta(colorScheme))

            Text(TutorialStep.intro.title)
                .font(OrganicPalette.display(40))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .lineSpacing(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text(TutorialStep.intro.description)
                .font(OrganicPalette.body(17))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.bottom, 28)
        }
    }
}

/// The opening illustration: a store, the ring around it that Allim watches,
/// and a few list items orbiting it.
private struct TutorialHero: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animating = false

    private struct Floater: Identifiable {
        let id: String
        let category: GroceryCategory
        let x: CGFloat
        let y: CGFloat
        let delay: Double
    }

    private let floaters: [Floater] = [
        Floater(id: "Bananas", category: .produce, x: -104, y: -78, delay: 0),
        Floater(id: "Whole Milk", category: .dairy, x: 108, y: -34, delay: 0.5),
        Floater(id: "Sourdough", category: .bakery, x: -86, y: 86, delay: 1.0),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(OrganicPalette.highlight(colorScheme), lineWidth: 2)
                    .frame(width: 96, height: 96)
                    .scaleEffect(animating ? 2.7 : 1)
                    .opacity(animating ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 2.7)
                            .repeatForever(autoreverses: false)
                            .delay(Double(ring) * 0.9),
                        value: animating
                    )
            }

            Circle()
                .fill(OrganicPalette.terracotta(colorScheme))
                .frame(width: 96, height: 96)
                .shadow(color: OrganicPalette.terracotta(colorScheme).opacity(0.35), radius: 18, x: 0, y: 8)
                .overlay(
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
                )

            ForEach(floaters) { floater in
                TutorialChip(name: floater.id, category: floater.category, raised: true)
                    .offset(x: floater.x, y: floater.y + (animating ? -7 : 7))
                    .animation(
                        .easeInOut(duration: 2.2)
                            .repeatForever(autoreverses: true)
                            .delay(floater.delay),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Finale Page

private struct TutorialFinalePage: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private struct Place: Identifiable {
        let id: String
        let systemImage: String
        let detail: String
    }

    private let places: [Place] = [
        Place(id: "Stores", systemImage: "storefront.fill", detail: "Your stores and their lists. Tap + to add one."),
        Place(id: "Messages", systemImage: "message.fill", detail: "Chat, and send a store or an item along."),
        Place(id: "AI Recipe", systemImage: "fork.knife.circle.fill", detail: "Turn any recipe into a shopping list."),
        Place(id: "Search", systemImage: "map.fill", detail: "Find stores near you on the map."),
        Place(id: "Profile", systemImage: "person.crop.circle.fill", detail: "Friends, Family and your settings."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(OrganicPalette.onSageInk(colorScheme))
                .frame(width: 60, height: 60)
                .background(Circle().fill(OrganicPalette.sageInk(colorScheme)))
                .scaleEffect(appeared ? 1 : 0.3)
                .opacity(appeared ? 1 : 0)

            Text(TutorialStep.finale.title)
                .font(OrganicPalette.display(38))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .padding(.top, 18)

            Text(TutorialStep.finale.description)
                .font(OrganicPalette.body(16))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    HStack(spacing: 14) {
                        Image(systemName: place.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(OrganicPalette.terracotta(colorScheme))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(OrganicPalette.blush(colorScheme)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.id)
                                .font(OrganicPalette.title(16))
                                .foregroundColor(OrganicPalette.ink(colorScheme))
                            Text(place.detail)
                                .font(OrganicPalette.body(13))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8).delay(0.15 + Double(index) * 0.07),
                        value: appeared
                    )

                    if index < places.count - 1 {
                        Rectangle()
                            .fill(OrganicPalette.divider(colorScheme))
                            .frame(height: 1)
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 28))
            .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                appeared = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Preview

#Preview {
    TutorialOverlayView()
        .onAppear {
            TutorialManager.shared.currentStep = .intro
            TutorialManager.shared.isActive = true
        }
}
