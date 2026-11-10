//
//  TutorialManager.swift
//  Geolocation_v1.0.0
//
//  Manages the new-user onboarding tutorial state.
//

import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Tutorial Step

/// The tutorial is a short playable story rather than a tour of the live UI:
/// an opening page, five hands-on chapters the user actually taps, drags and
/// holds their way through, and a closing cheat sheet.
enum TutorialStep: Int, CaseIterable {
    case intro = 0
    case addStore
    case smartSort
    case nearby
    case shortcuts
    case share
    case finale

    /// The hands-on chapters, in order. These are what the progress bar counts.
    static let chapters: [TutorialStep] = [.addStore, .smartSort, .nearby, .shortcuts, .share]

    var isChapter: Bool { Self.chapters.contains(self) }

    /// 1-based position among the chapters, for the "02" in the eyebrow.
    var chapterNumber: Int? {
        Self.chapters.firstIndex(of: self).map { $0 + 1 }
    }

    /// The one-word subject that sits beside the chapter number.
    var eyebrow: String {
        switch self {
        case .intro: return "Welcome to Allim"
        case .addStore: return "Stores"
        case .smartSort: return "Smart Category"
        case .nearby: return "Nearby alerts"
        case .shortcuts: return "Shortcuts"
        case .share: return "Sharing"
        case .finale: return "That's the tour"
        }
    }

    var title: String {
        switch self {
        case .intro: return "Your list knows\nwhere you are."
        case .addStore: return "Start with a store."
        case .smartSort: return "Add items.\nAllim sorts them."
        case .nearby: return "Get nudged when you're close."
        case .shortcuts: return "Everything is one press away."
        case .share: return "Shop together."
        case .finale: return "You're all set."
        }
    }

    var description: String {
        switch self {
        case .intro:
            return "Take the one-minute tour. Nothing to read through — you'll try each thing yourself."
        case .addStore:
            return "Every list in Allim belongs to a place you shop. The + button adds one."
        case .smartSort:
            return "Type things in any order. Smart Category files each one under Produce, Dairy, Bakery and so on."
        case .nearby:
            return "When you come near a saved store, Allim sends your list for it — before you drive past."
        case .shortcuts:
            return "Touch and hold an item to mark it out of stock, move it, or add a photo. The ⓘ button holds the list's settings."
        case .share:
            return "Share a store with friends, and keep Family at the front of the line. They see changes as you make them."
        case .finale:
            return "Here's where everything lives. Add your first store and Allim takes it from there."
        }
    }

    /// What the user is asked to do in the chapter's demo.
    var hint: String {
        switch self {
        case .addStore: return "Tap the + button"
        case .smartSort: return "Tap a few items to add them"
        case .nearby: return "Drag yourself to the store"
        case .shortcuts: return "Touch and hold an item, or tap ⓘ"
        case .share: return "Tap someone to share the list"
        case .intro, .finale: return ""
        }
    }

    var hintIcon: String {
        switch self {
        case .nearby: return "hand.draw.fill"
        case .shortcuts: return "hand.tap.fill"
        default: return "hand.point.up.left.fill"
        }
    }

    /// What replaces the hint once they have done it.
    var doneNote: String {
        switch self {
        case .addStore: return "That's it — your first store"
        case .smartSort: return "Sorted, without lifting a finger"
        case .nearby: return "Right on time"
        case .shortcuts: return "Found it"
        case .share: return "Shared — they'll see it live"
        case .intro, .finale: return ""
        }
    }
}

// MARK: - Tutorial Manager

final class TutorialManager: ObservableObject {
    static let shared = TutorialManager()

    @Published var isActive: Bool = false
    @Published var currentStep: TutorialStep = .intro
    /// Chapters whose demo the user has played through. Drives the hint under
    /// the demo and how loudly the Next button asks to be pressed; it never
    /// gates anything — every chapter can be passed without playing it.
    @Published private(set) var completedSteps: Set<TutorialStep> = []
    @Published var pendingTabSwitch: Int? = nil

    private(set) var currentUserId: String?
    private(set) var currentAuthUid: String?
    private var cancellable: AnyCancellable?

    private var tutorialKey: String? {
        guard let uid = currentAuthUid else { return nil }
        return "hasCompletedTutorial_auth_\(uid)"
    }

    var hasCompletedTutorial: Bool {
        get {
            // Use the Auth UID key exclusively — the legacy username-based key
            // is unreliable because usernames can be reused across accounts.
            guard let key = tutorialKey else { return false }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            guard let key = tutorialKey else { return }
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    private init() {
        // Subscribe to UserSessionManager.currentUser so the tutorial starts
        // reliably regardless of HomeView's lifecycle (permission dialogs on
        // physical devices can tear down / recreate the view and reset @State).
        cancellable = UserSessionManager.shared.$currentUser
            .compactMap { $0 }                       // wait until non-nil
            .map(\.userId)
            .filter { !$0.isEmpty }
            .first()                                 // only react once
            .delay(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] userId in
                guard let self else { return }
                #if DEBUG
                print("🎓 TutorialManager: Combine auto-start for userId=\(userId)")
                #endif
                self.startIfNeeded(userId: userId)
            }
    }

    func startIfNeeded(userId: String) {
        currentUserId = userId
        currentAuthUid = Auth.auth().currentUser?.uid
        #if DEBUG
        print("🎓 TutorialManager.startIfNeeded: userId=\(userId), authUid=\(currentAuthUid ?? "nil"), key=\(tutorialKey ?? "nil"), hasCompleted=\(hasCompletedTutorial), isActive=\(isActive)")
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.contains("Tutorial") || $0.contains("tutorial") }
        print("🎓 TutorialManager: All tutorial-related UserDefaults keys: \(allKeys)")
        for key in allKeys {
            print("🎓   \(key) = \(UserDefaults.standard.bool(forKey: key))")
        }
        #endif
        guard !hasCompletedTutorial, !isActive else {
            #if DEBUG
            print("🎓 TutorialManager.startIfNeeded: BLOCKED — hasCompleted=\(hasCompletedTutorial), isActive=\(isActive)")
            #endif
            return
        }
        #if DEBUG
        print("🎓 TutorialManager.startIfNeeded: ACTIVATING tutorial ✅")
        #endif
        currentStep = .intro
        completedSteps = []
        isActive = true
    }

    func advance() {
        guard let next = TutorialStep(rawValue: currentStep.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
            currentStep = next
        }
    }

    func back() {
        guard let previous = TutorialStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
            currentStep = previous
        }
    }

    /// Called by a chapter's demo the first time the user completes it.
    func markDone(_ step: TutorialStep) {
        guard !completedSteps.contains(step) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            _ = completedSteps.insert(step)
        }
    }

    func skip() {
        completeTutorial()
    }

    func finish() {
        completeTutorial()
    }

    private func completeTutorial() {
        withAnimation(.easeOut(duration: 0.4)) {
            isActive = false
        }
        hasCompletedTutorial = true
        // The tutorial covers the whole screen, so whatever tab was underneath
        // is a surprise; land on Stores, where the first thing to do is.
        pendingTabSwitch = 0
        // New users are not shown the paywall here — the subscription sheet is
        // only presented when they actually hit a gated feature or open it from
        // Profile.
    }

    /// Resets the tutorial so it will show again on next app launch or call to startIfNeeded().
    /// Intended for debug/testing only.
    func resetTutorial() {
        hasCompletedTutorial = false
        isActive = false
        currentStep = .intro
        completedSteps = []
    }
}
