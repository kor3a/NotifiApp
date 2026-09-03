//
//  VoiceCommandView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 8/10/26.
//
//  The sheet behind the red record button on each store row. Listens, shows
//  what it heard, and asks for confirmation in plain language before touching
//  the list.
//

import SwiftUI

struct VoiceCommandView: View {
    let userStoreItem: UserStoreItem

    @StateObject private var viewModel = VoiceCommandViewModel()
    @StateObject private var speech = SpeechRecognitionManager()
    @StateObject private var reminderViewModel = ReminderViewModel()
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Matches the per-store Smart Category preference set in ReminderView, so
    /// items added by voice are categorized on the same terms as typed ones.
    private var useSmartCategory: Bool {
        let enabled = UserDefaults.standard.object(
            forKey: "smartCategoryEnabled_\(userStoreItem.id)"
        ) as? Bool ?? true
        return subscriptionManager.isSubscribed && enabled
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SurfaceBackground(surface: .stores)

                VStack(spacing: 0) {
                    phaseContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    actionBar
                }
            }
            .navigationTitle(userStoreItem.store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancel(using: speech)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.speaksBack.toggle()
                    } label: {
                        Image(systemName: viewModel.speaksBack ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .accessibilityLabel(viewModel.speaksBack ? "Turn off spoken replies" : "Turn on spoken replies")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            // Start the list listener before listening, so the current items —
            // and their document IDs — are on hand by the time the transcript
            // is interpreted.
            reminderViewModel.fetchReminders(
                for: userStoreItem.reminderStoreId,
                sharedFromName: userStoreItem.sharedFromName
            )
            await viewModel.configure(
                store: userStoreItem,
                reminderViewModel: reminderViewModel,
                useSmartCategory: useSmartCategory
            )
            await viewModel.beginListening(using: speech)
        }
        .onDisappear {
            viewModel.cancel(using: speech)
        }
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .preparing:
            statusView(
                icon: "mic",
                tint: .secondary,
                title: "Getting ready…",
                detail: "Allim needs the microphone to hear your request."
            )

        case .listening:
            listeningView

        case .interpreting:
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                Text("Working out what to change…")
                    .font(.headline)
                if !viewModel.transcript.isEmpty {
                    transcriptBubble(viewModel.transcript)
                }
            }
            .padding(24)

        case .confirming:
            confirmationView

        case .executing:
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                Text("Updating \(userStoreItem.store.name)…")
                    .font(.headline)
            }
            .padding(24)

        case .finished(let summary):
            statusView(
                icon: "checkmark.circle.fill",
                tint: .appSuccess,
                title: summary,
                detail: nil
            )

        case .failed(let message):
            statusView(
                icon: "exclamationmark.triangle.fill",
                tint: .appWarning,
                title: "I couldn't do that",
                detail: message
            )
        }
    }

    // MARK: - Listening

    private var listeningView: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            MicPulse(level: speech.level)
                .onTapGesture { viewModel.stopListening(using: speech) }
                .accessibilityLabel("Stop listening")
                .accessibilityAddTraits(.isButton)

            VStack(spacing: 8) {
                Text(speech.transcript.isEmpty ? "Listening…" : speech.transcript)
                    .font(speech.transcript.isEmpty ? .headline : .title3)
                    .fontWeight(speech.transcript.isEmpty ? .semibold : .regular)
                    .foregroundColor(speech.transcript.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.15), value: speech.transcript)

                Text(speech.transcript.isEmpty
                     ? "Try “add milk and eggs” or “check off bread”"
                     : "Pause when you're done, or tap the mic.")
                    .font(.footnote)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .frame(minHeight: 90, alignment: .top)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.transcript.isEmpty {
                    transcriptBubble(viewModel.transcript)
                }

                Text(viewModel.confirmation)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.actions.enumerated()), id: \.element.id) { index, action in
                        if index > 0 {
                            Divider().padding(.leading, 44)
                        }
                        actionRow(action)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.cardFillTint(for: colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cardBorderStyle(for: colorScheme), lineWidth: 1.5)
                        )
                )

                if !viewModel.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.notes, id: \.self) { note in
                            Label(note, systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func actionRow(_ action: VoiceCommandAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: action.iconName)
                .font(.system(size: 20))
                .foregroundColor(action.isDestructive ? .appError : .appAccent)
                .frame(width: 24)

            Text(action.summary)
                .font(.body)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.removeAction(action)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip \(action.summary)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func transcriptBubble(_ text: String) -> some View {
        Label(text, systemImage: "quote.opening")
            .font(.subheadline)
            .foregroundColor(.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.12))
            )
    }

    private func statusView(icon: String, tint: Color, title: String, detail: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundColor(tint)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var actionBar: some View {
        switch viewModel.phase {
        case .confirming:
            HStack(spacing: 12) {
                Button {
                    Task { @MainActor in await viewModel.beginListening(using: speech) }
                } label: {
                    Label("Redo", systemImage: "mic")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { @MainActor in
                        await viewModel.confirm()
                        // Leave the result on screen long enough to read (and
                        // to be spoken) before the sheet closes itself.
                        try? await Task.sleep(for: .seconds(1.4))
                        dismiss()
                    }
                } label: {
                    Label("Confirm", systemImage: "checkmark")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasActions)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

        case .failed:
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { @MainActor in await viewModel.beginListening(using: speech) }
                } label: {
                    Label("Try Again", systemImage: "mic")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

        case .listening:
            Button {
                viewModel.stopListening(using: speech)
            } label: {
                Text("Done Speaking")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

        case .preparing, .interpreting, .executing, .finished:
            EmptyView()
        }
    }
}

// MARK: - Mic Pulse

/// The listening indicator: a red record button with rings that breathe with
/// the input level, so the user can see the mic is actually picking them up.
private struct MicPulse: View {
    let level: Float

    private var scale: CGFloat { 1 + CGFloat(level) * 0.5 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appError.opacity(0.12))
                .frame(width: 150, height: 150)
                .scaleEffect(scale)

            Circle()
                .fill(Color.appError.opacity(0.22))
                .frame(width: 110, height: 110)
                .scaleEffect(1 + CGFloat(level) * 0.3)

            Circle()
                .fill(Color.appError)
                .frame(width: 84, height: 84)
                .shadow(color: Color.appError.opacity(0.45), radius: 12, y: 4)

            Image(systemName: "mic.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundColor(.white)
        }
        .animation(.easeOut(duration: 0.12), value: level)
        .frame(height: 160)
    }
}

#Preview {
    VoiceCommandView(
        userStoreItem: UserStoreItem(
            id: "us1",
            store: Store(name: "Walmart", reminderCount: 3),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
    )
}
