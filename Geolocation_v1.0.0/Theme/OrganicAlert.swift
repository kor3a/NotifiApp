//
//  OrganicAlert.swift
//  Geolocation_v1.0.0
//
//  The app's own replacement for the system alert, drawn from the palette.
//

import SwiftUI

// MARK: - Action

/// One button in an organic alert.
///
/// The system alert reads its buttons out of a `ViewBuilder` and works out from
/// each `Button`'s `role` how to draw it. A `ButtonStyle` can't see that role
/// until iOS 26, so the buttons here are values rather than views: the kind is
/// stated up front and the surface draws it.
struct OrganicAlertAction: Identifiable {
    enum Kind {
        /// The one thing the alert is asking for — a filled accent pill.
        case primary
        /// Something that removes or ends what the user is looking at — the
        /// palette's danger tone, kept off the system red siren.
        case destructive
        /// Backing out. Quiet and recessed, so the eye lands on the action
        /// above it.
        case cancel
    }

    let id = UUID()
    let title: String
    let kind: Kind
    let action: () -> Void

    static func primary(_ title: String, action: @escaping () -> Void = {}) -> OrganicAlertAction {
        OrganicAlertAction(title: title, kind: .primary, action: action)
    }

    static func destructive(_ title: String, action: @escaping () -> Void = {}) -> OrganicAlertAction {
        OrganicAlertAction(title: title, kind: .destructive, action: action)
    }

    static func cancel(_ title: String = "Cancel", action: @escaping () -> Void = {}) -> OrganicAlertAction {
        OrganicAlertAction(title: title, kind: .cancel, action: action)
    }

    /// The one-button acknowledgement an informational alert ends on. Drawn as
    /// the primary pill by the surface, since a lone quiet button on a card
    /// with nothing to weigh it against just reads as disabled.
    static func ok(_ title: String = "OK", action: @escaping () -> Void = {}) -> OrganicAlertAction {
        OrganicAlertAction(title: title, kind: .cancel, action: action)
    }
}

// MARK: - Tone

/// What the glyph disc at the top of the card is saying. Only the icon takes
/// the tone — the buttons are coloured by their own kind, so a destructive
/// confirmation still reads as destructive on an otherwise accent-toned card.
enum OrganicAlertTone {
    /// The app's own accent — a question, a confirmation, a piece of news.
    case accent
    /// Something is about to be removed, or something went wrong.
    case destructive
    /// It worked. The one green moment these screens allow themselves.
    case success
}

// MARK: - Text Field

/// The input an alert asks a question through — a quantity, a category, a
/// password. Sunk into the card the way `organicField` sinks a search pill into
/// the canvas, and centred, because an alert's text sits centred above it.
struct OrganicAlertTextField: View {
    let placeholder: String
    @Binding var text: String
    /// Masks the entry, for the password an account deletion asks to confirm.
    var isSecure: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: OrganicPalette.prompt(placeholder, colorScheme))
            } else {
                TextField("", text: $text, prompt: OrganicPalette.prompt(placeholder, colorScheme))
            }
        }
        .font(.system(size: 16))
        .foregroundColor(OrganicPalette.ink(colorScheme))
        .multilineTextAlignment(.center)
        .focused($isFocused)
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(Capsule().fill(OrganicPalette.field(colorScheme)))
        .onAppear {
            // The card is still scaling in on the first frame; focusing into it
            // before it has settled drops the keyboard's own animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isFocused = true }
        }
    }
}

// MARK: - Presentation

extension View {
    /// The organic replacement for `.alert(_:isPresented:actions:message:)`.
    ///
    /// Same shape as the system modifier — a title, a binding, a line of
    /// explanation and the buttons — but drawn as a palette card on the
    /// palette's scrim instead of the system's frosted rectangle, so a
    /// confirmation looks like the screen that raised it.
    ///
    /// Presented through a `fullScreenCover` with a clear background rather than
    /// an overlay: an overlay is clipped to the view it is attached to, which
    /// leaves the navigation bar sitting undimmed above the scrim, and half
    /// these alerts are raised from a row deep inside a list.
    func organicAlert(
        _ title: String,
        isPresented: Binding<Bool>,
        icon: String? = nil,
        tone: OrganicAlertTone = .accent,
        message: String? = nil,
        actions: [OrganicAlertAction]
    ) -> some View {
        organicAlert(
            title,
            isPresented: isPresented,
            icon: icon,
            tone: tone,
            message: message,
            actions: actions,
            content: { EmptyView() }
        )
    }

    /// The variant that asks for something typed — `content` is the field, and
    /// sits between the message and the buttons.
    func organicAlert<Content: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        icon: String? = nil,
        tone: OrganicAlertTone = .accent,
        message: String? = nil,
        actions: [OrganicAlertAction],
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            OrganicAlertModifier(
                isPresented: isPresented,
                title: title,
                icon: icon,
                tone: tone,
                message: message,
                actions: actions,
                alertContent: content
            )
        )
    }
}

private struct OrganicAlertModifier<AlertContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let icon: String?
    let tone: OrganicAlertTone
    let message: String?
    let actions: [OrganicAlertAction]
    let alertContent: () -> AlertContent

    /// This alert's place in the queue below, stable for as long as the view is
    /// alive.
    @State private var token = UUID()
    /// Whether the cover is actually up. Separate from `isPresented` so an alert
    /// raised while another is still on screen can wait its turn instead of
    /// being dropped.
    @State private var isCoverShown = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isCoverShown) {
                OrganicAlertSurface(
                    isPresented: $isPresented,
                    title: title,
                    icon: icon,
                    tone: tone,
                    message: message,
                    actions: actions,
                    content: alertContent
                )
                .presentationBackground(Color.clear)
                .onAppear { OrganicAlertQueue.shared.confirmPresented(token) }
                .onDisappear { OrganicAlertQueue.shared.release(token) }
            }
            // A cover slides up from the bottom; an alert doesn't. Scoping the
            // transaction to the presenting value keeps the suppression to this
            // one update, rather than flattening every animation on the screen
            // underneath for as long as the modifier is attached.
            .transaction(value: isCoverShown) { $0.disablesAnimations = true }
            .onAppear { if isPresented { present() } }
            .onChange(of: isPresented) { _, presented in
                if presented { present() } else { withdraw() }
            }
    }

    private func present() {
        OrganicAlertQueue.shared.request(token) { isCoverShown = true }
    }

    private func withdraw() {
        if isCoverShown {
            // The cover's `onDisappear` hands the turn on once it is really gone.
            isCoverShown = false
        } else {
            OrganicAlertQueue.shared.release(token)
        }
    }
}

// MARK: - Queue

/// Keeps two organic alerts from reaching for the screen at once.
///
/// A button that answers one alert often raises the next — applying a
/// background fails, deleting an account turns out to need a password. UIKit
/// will not present a second cover while the first is still going away, and
/// drops it silently, so the second alert waits here and is let through by the
/// first one's `onDisappear`.
///
/// Main-thread only, which is where every caller already is: SwiftUI's
/// `onAppear`, `onChange` and `onDisappear`.
private final class OrganicAlertQueue {
    static let shared = OrganicAlertQueue()

    private var active: UUID?
    /// Whether the alert holding the turn actually made it onto the screen.
    /// A turn handed to a view that has since been torn down would otherwise
    /// never come back, and every later alert would wait behind it.
    private var activeDidPresent = false
    private var waiting: [(token: UUID, grant: () -> Void)] = []

    private init() {}

    func request(_ token: UUID, grant: @escaping () -> Void) {
        guard active != token, !waiting.contains(where: { $0.token == token }) else { return }

        if active == nil {
            take(token, grant: grant, deferred: false)
        } else {
            waiting.append((token, grant))
        }
    }

    func confirmPresented(_ token: UUID) {
        if active == token { activeDidPresent = true }
    }

    func release(_ token: UUID) {
        guard active == token else {
            waiting.removeAll { $0.token == token }
            return
        }

        active = nil
        activeDidPresent = false
        guard !waiting.isEmpty else { return }

        let next = waiting.removeFirst()
        take(next.token, grant: next.grant, deferred: true)
    }

    private func take(_ token: UUID, grant: @escaping () -> Void, deferred: Bool) {
        active = token
        activeDidPresent = false

        if deferred {
            // A frame after the cover it is replacing has gone: `onDisappear`
            // runs as the dismissal finishes, and presenting inside it is early
            // enough to be dropped again.
            DispatchQueue.main.async(execute: grant)
        } else {
            grant()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
            guard active == token, !activeDidPresent else { return }
            release(token)
        }
    }
}

// MARK: - Surface

private struct OrganicAlertSurface<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let icon: String?
    let tone: OrganicAlertTone
    let message: String?
    let actions: [OrganicAlertAction]
    let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowing = false

    /// Backing out always sits at the bottom, however the caller listed it —
    /// the eye should land on what the alert is asking for first.
    private var orderedActions: [OrganicAlertAction] {
        actions.filter { $0.kind != .cancel } + actions.filter { $0.kind == .cancel }
    }

    /// A lone dismiss button carries the card on its own, so it takes the
    /// primary pill rather than the recessed one it asked for.
    private func resolvedKind(for action: OrganicAlertAction) -> OrganicAlertAction.Kind {
        actions.count == 1 && action.kind == .cancel ? .primary : action.kind
    }

    var body: some View {
        ZStack {
            scrim
            card
                .padding(.horizontal, 28)
                .scaleEffect(isShowing ? 1 : 0.92)
                .opacity(isShowing ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { isShowing = true }
        }
    }

    // MARK: Pieces

    /// The palette's own scrim rather than flat black — it dims the canvas
    /// showing around the card without casting a color over it.
    private var scrim: some View {
        Rectangle()
            .fill(OrganicPalette.scrim(colorScheme))
            .ignoresSafeArea()
            .opacity(isShowing ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                // Only where there is something to back out to. An alert with
                // one acknowledgement, or a choice with no way out, keeps the
                // user on the card.
                if let cancel = actions.first(where: { $0.kind == .cancel }), actions.count > 1 {
                    close(cancel)
                }
            }
    }

    private var card: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 10) {
                ForEach(orderedActions) { action in
                    button(for: action)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(OrganicPalette.surface(colorScheme))
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 26, x: 0, y: 14)
        )
    }

    private var header: some View {
        VStack(spacing: 12) {
            if let icon {
                iconDisc(icon)
            }

            Text(title)
                .font(OrganicPalette.display(23))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let message, !message.isEmpty {
                // Content-sized until the message stops fitting — a long one at
                // an accessibility type size — and only then does it start
                // scrolling, so the buttons never leave the screen. Only the
                // message is wrapped: a field inside a view that gets rebuilt
                // on a re-measure would lose the keyboard mid-edit.
                ViewThatFits(in: .vertical) {
                    messageText(message)
                    ScrollView { messageText(message) }
                }
            }

            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, icon == nil ? 28 : 26)
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    private func messageText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 15))
            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private func iconDisc(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(glyphColor)
            .frame(width: 60, height: 60)
            .background(Circle().fill(discColor))
    }

    private var glyphColor: Color {
        switch tone {
        case .accent: return OrganicPalette.terracotta(colorScheme)
        case .destructive: return OrganicPalette.rust(colorScheme)
        case .success: return OrganicPalette.sageInk(colorScheme)
        }
    }

    private var discColor: Color {
        switch tone {
        case .accent: return OrganicPalette.blush(colorScheme)
        case .destructive: return OrganicPalette.rustWash(colorScheme)
        case .success: return OrganicPalette.sage(colorScheme)
        }
    }

    private func button(for action: OrganicAlertAction) -> some View {
        let kind = resolvedKind(for: action)

        return Button {
            close(action)
        } label: {
            Text(action.title)
                .font(OrganicPalette.title(17))
                .foregroundColor(labelColor(for: kind))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(pillColor(for: kind)))
        }
        .buttonStyle(OrganicAlertButtonStyle())
    }

    private func labelColor(for kind: OrganicAlertAction.Kind) -> Color {
        switch kind {
        case .primary: return OrganicPalette.onTerracotta(colorScheme)
        case .destructive: return OrganicPalette.onRust(colorScheme)
        case .cancel: return OrganicPalette.ink(colorScheme)
        }
    }

    private func pillColor(for kind: OrganicAlertAction.Kind) -> Color {
        switch kind {
        case .primary: return OrganicPalette.terracotta(colorScheme)
        case .destructive: return OrganicPalette.rust(colorScheme)
        case .cancel: return OrganicPalette.field(colorScheme)
        }
    }

    /// Runs the button's work, then takes the card down.
    ///
    /// The action goes first on purpose: most of these alerts are presented off
    /// an optional (`storeToDelete != nil`), and clearing the binding is what
    /// the button reads its subject out of. Dismissing first would hand the
    /// action a nil.
    private func close(_ action: OrganicAlertAction) {
        withAnimation(.easeIn(duration: 0.16)) { isShowing = false }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            action.action()
            isPresented = false
        }
    }
}

// MARK: - Button Style

/// The press feedback the alert's pills share — the same give as the rest of
/// the app's buttons, rather than the system alert's full-width highlight.
private struct OrganicAlertButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
