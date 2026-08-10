//
//  VoiceCommandViewModel.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 8/10/26.
//
//  Drives the voice command sheet: listen → interpret → confirm → execute.
//
//  Nothing is written to Firestore until the user confirms. The confirmation
//  step is the whole point of the feature — a misheard word should cost a tap,
//  not a deleted list.
//

import AVFoundation
import Foundation

@MainActor
final class VoiceCommandViewModel: ObservableObject {

    enum Phase: Equatable {
        /// Asking for microphone / speech permission.
        case preparing
        case listening
        /// Transcript captured, waiting on the language model.
        case interpreting
        /// Showing the plan, waiting for the user to confirm.
        case confirming
        case executing
        case finished(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .preparing
    /// The final transcript, kept visible through the confirmation step so the
    /// user can see what was heard when the plan looks wrong.
    @Published private(set) var transcript: String = ""
    @Published private(set) var confirmation: String = ""
    @Published private(set) var actions: [VoiceCommandAction] = []
    @Published private(set) var notes: [String] = []

    /// Read the confirmation and result back aloud. Mirrors the store row
    /// button being a hands-free affordance in the first place.
    ///
    /// Restored in the declaration rather than in an initializer: a `didSet`
    /// turns any assignment into a mutation rather than initialization, which
    /// an initializer on this main-actor class can't do from a nonisolated
    /// context.
    @Published var speaksBack: Bool = VoiceCommandViewModel.storedSpeaksBack {
        didSet { UserDefaults.standard.set(speaksBack, forKey: Self.speaksBackKey) }
    }

    private static let speaksBackKey = "voiceCommandSpeaksBack"

    private static var storedSpeaksBack: Bool {
        UserDefaults.standard.object(forKey: speaksBackKey) as? Bool ?? true
    }

    private var store: UserStoreItem?
    private weak var reminderViewModel: ReminderViewModel?
    private var useSmartCategory = false
    private let synthesizer = AVSpeechSynthesizer()

    /// Firestore writes land in the snapshot listener asynchronously, and
    /// `addReminder` derives both its duplicate check and the new item's sort
    /// order from that listener's output. Spacing the writes lets each one be
    /// visible before the next is queued, so a batch of adds keeps the order
    /// they were spoken in.
    private let writeSpacing: Duration = .milliseconds(250)

    var hasActions: Bool { !actions.isEmpty }

    // MARK: - Setup

    func configure(store: UserStoreItem, reminderViewModel: ReminderViewModel, useSmartCategory: Bool) {
        self.store = store
        self.reminderViewModel = reminderViewModel
        self.useSmartCategory = useSmartCategory
    }

    // MARK: - Listening

    /// Requests permission and starts recording. The transcript is interpreted
    /// automatically once the user stops speaking.
    func beginListening(using speech: SpeechRecognitionManager) async {
        phase = .preparing
        transcript = ""
        confirmation = ""
        actions = []
        notes = []

        do {
            try await SpeechRecognitionManager.requestAuthorization()
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }

        do {
            try speech.start { [weak self] finalTranscript in
                guard let self else { return }
                Task { await self.interpret(finalTranscript) }
            }
            phase = .listening
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Called when the user taps to stop early rather than trailing off.
    func stopListening(using speech: SpeechRecognitionManager) {
        speech.stop()
    }

    // MARK: - Interpreting

    private func interpret(_ spoken: String) async {
        transcript = spoken

        guard !spoken.isEmpty else {
            phase = .failed("I didn't catch that. Tap the mic and try again.")
            return
        }
        guard let store, let reminderViewModel else {
            phase = .failed("This store isn't available right now.")
            return
        }

        phase = .interpreting

        let plan: VoiceCommandPlan
        do {
            plan = try await OpenAIService.shared.parseVoiceCommand(
                transcript: spoken,
                storeName: store.store.name,
                reminders: reminderViewModel.reminders
            )
        } catch OpenAIError.invalidResponse {
            phase = .failed("I understood the words but not the request. Try again with something like “add milk”.")
            return
        } catch {
            phase = .failed("I couldn't reach the assistant. Check your connection and try again.")
            return
        }

        let resolution = VoiceCommandPlanner.resolve(plan, against: reminderViewModel.reminders)
        actions = resolution.actions
        notes = resolution.notes

        guard !actions.isEmpty else {
            let explanation = notes.first ?? "I couldn't turn that into a change to this list."
            phase = .failed(explanation)
            speak(explanation)
            return
        }

        // Prefer the model's own sentence; fall back to the action list so the
        // confirmation is never blank.
        confirmation = plan.confirmation.isEmpty ? fallbackConfirmation() : plan.confirmation
        phase = .confirming
        speak(confirmation)
    }

    private func fallbackConfirmation() -> String {
        let summaries = actions.map { $0.summary.lowercased() }
        return "I'll \(summaries.joined(separator: ", "))."
    }

    // MARK: - Confirming

    /// Drops one action from the plan before it runs, so a single misheard item
    /// doesn't force the user to redo the whole request.
    func removeAction(_ action: VoiceCommandAction) {
        actions.removeAll { $0.id == action.id }
        if actions.isEmpty {
            phase = .failed("Nothing left to change. Tap the mic to try again.")
        }
    }

    /// Applies the confirmed plan.
    func confirm() async {
        guard let store, let reminderViewModel, !actions.isEmpty else { return }
        phase = .executing

        for action in actions {
            apply(action, store: store, reminderViewModel: reminderViewModel)
            try? await Task.sleep(for: writeSpacing)
        }

        sendSharedStoreNotificationsIfNeeded(store: store, reminderViewModel: reminderViewModel)

        let summary = resultSummary()
        phase = .finished(summary)
        speak(summary)
    }

    /// Ends the session without writing anything.
    func cancel(using speech: SpeechRecognitionManager) {
        speech.cancel()
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Execution

    private func apply(_ action: VoiceCommandAction, store: UserStoreItem, reminderViewModel: ReminderViewModel) {
        switch action.kind {
        case .add:
            reminderViewModel.addReminder(
                userStoreId: store.reminderStoreId,
                title: action.title,
                sharedWith: sharedWith(for: store, reminderViewModel: reminderViewModel),
                sharedFromName: store.sharedFromName,
                currentUserName: UserSessionManager.shared.currentUser?.name,
                useSmartCategory: useSmartCategory,
                quantity: action.quantity
            )

        case .delete:
            guard let reminder = currentReminder(for: action, in: reminderViewModel) else { return }
            reminderViewModel.deleteReminder(reminder)

        case .check:
            guard let reminder = currentReminder(for: action, in: reminderViewModel), !reminder.isDone else { return }
            reminderViewModel.toggleReminder(reminder)

        case .uncheck:
            guard let reminder = currentReminder(for: action, in: reminderViewModel), reminder.isDone else { return }
            reminderViewModel.toggleReminder(reminder)

        case .setQuantity:
            guard let reminder = currentReminder(for: action, in: reminderViewModel) else { return }
            reminderViewModel.updateReminderQuantity(reminder, newQuantity: action.quantity)

        case .rename:
            guard let reminder = currentReminder(for: action, in: reminderViewModel),
                  let newTitle = action.newTitle else { return }
            reminderViewModel.updateReminderTitle(reminder, newTitle: newTitle)

        case .outOfStock:
            guard let reminder = currentReminder(for: action, in: reminderViewModel),
                  reminder.isOutOfStock != true else { return }
            reminderViewModel.toggleOutOfStock(reminder)
        }
    }

    /// Re-reads the reminder from the view model rather than reusing the copy
    /// captured at plan time — an earlier action in the same batch, or another
    /// device on a shared store, may have changed it since.
    private func currentReminder(for action: VoiceCommandAction, in reminderViewModel: ReminderViewModel) -> Reminder? {
        guard let id = action.reminderId else { return nil }
        return reminderViewModel.reminders.first { $0.id == id }
    }

    /// Recipient names to stamp on newly added reminders, recovered from items
    /// already marked shared when the store snapshot's own list is empty —
    /// the same fallback `ReminderView` uses.
    private func sharedWith(for store: UserStoreItem, reminderViewModel: ReminderViewModel) -> [String]? {
        if let sharedWith = store.sharedWith, !sharedWith.isEmpty {
            return sharedWith
        }
        let currentUserName = UserSessionManager.shared.currentUser?.name
        let recovered = Set(
            reminderViewModel.reminders
                .filter { $0.isShared == true }
                .flatMap { $0.sharedWith ?? [] }
        ).subtracting([currentUserName].compactMap { $0 })
        return recovered.isEmpty ? nil : Array(recovered)
    }

    /// Voice edits reach a shared store the same way typed ones do, so the
    /// people it's shared with are notified before this session's counters are
    /// reset. Mirrors `ReminderView.sendPendingSharedNotificationsIfNeeded`.
    private func sendSharedStoreNotificationsIfNeeded(store: UserStoreItem, reminderViewModel: ReminderViewModel) {
        guard store.isShared,
              reminderViewModel.hasPendingChanges,
              let currentUserId = UserSessionManager.shared.currentUser?.userId,
              let currentUserName = UserSessionManager.shared.currentUser?.name else { return }

        SharedReminderNotificationService.shared.sendNotifications(
            for: store,
            addedCount: reminderViewModel.pendingAdditions,
            otherChangeCount: reminderViewModel.pendingOtherChanges,
            currentUserId: currentUserId,
            currentUserName: currentUserName
        )
        reminderViewModel.resetPendingChanges()
    }

    private func resultSummary() -> String {
        let added = actions.filter { $0.kind == .add }.count
        let removed = actions.filter { $0.kind == .delete }.count
        let checked = actions.filter { $0.kind == .check }.count
        let other = actions.count - added - removed - checked

        var parts: [String] = []
        if added > 0 { parts.append("added \(added) \(added == 1 ? "item" : "items")") }
        if checked > 0 { parts.append("checked off \(checked)") }
        if removed > 0 { parts.append("deleted \(removed)") }
        if other > 0 { parts.append("updated \(other)") }

        guard !parts.isEmpty else { return "Done." }
        return "Done — \(parts.joined(separator: ", "))."
    }

    // MARK: - Speaking

    private func speak(_ text: String) {
        guard speaksBack, !text.isEmpty else { return }

        // The recording session left the route in `.record`; switch to playback
        // so the phone speaker is used instead of the receiver.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
