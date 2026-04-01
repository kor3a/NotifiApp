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

enum TutorialStep: Int, CaseIterable {
    case welcome = 0
    case storesFAB
    case storesToolbar
    case messagesCompose
    case friendsAddFriend
    case friendsFamily
    case mapSearch
    case complete

    var targetTab: Int? {
        switch self {
        case .welcome, .storesFAB, .storesToolbar: return 0
        case .messagesCompose: return 1
        case .friendsAddFriend, .friendsFamily: return 2
        case .mapSearch: return 3
        case .complete: return 0
        }
    }

    var elementId: String? {
        switch self {
        case .welcome, .complete: return nil
        case .storesFAB: return "tutorial_fab"
        case .storesToolbar: return "tutorial_toolbar"
        case .messagesCompose: return "tutorial_compose"
        case .friendsAddFriend: return "tutorial_addFriend"
        case .friendsFamily: return "tutorial_friendCard"
        case .mapSearch: return "tutorial_mapSearch"
        }
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome to Allim!"
        case .storesFAB: return "Add Your First Store"
        case .storesToolbar: return "Organize Your Stores"
        case .messagesCompose: return "Message Friends"
        case .friendsAddFriend: return "Add Friends"
        case .friendsFamily: return "Add to Family"
        case .mapSearch: return "Find Stores Nearby"
        case .complete: return "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let's take a quick tour of the key features so you can get the most out of your shopping experience."
        case .storesFAB:
            return "Tap the blue + button to add your favorite grocery stores and start managing shopping reminders."
        case .storesToolbar:
            return "Sort your stores by reminder count, or switch between list and grid view using these toolbar icons."
        case .messagesCompose:
            return "Tap the compose button to start a conversation. Share stores and reminders directly with friends."
        case .friendsAddFriend:
            return "Tap the person+ button to find and add friends. Collaborate on shared shopping lists together."
        case .friendsFamily:
            return "Tap a friend's profile picture to bring up the menu. From there you can add them to your Family group for priority sharing."
        case .mapSearch:
            return "Use the search button to find stores near you on the map. Tap any pin to view or add reminders."
        case .complete:
            return "You're ready to go! Start by tapping the + button to add your first store."
        }
    }

    var buttonLabel: String {
        switch self {
        case .complete: return "Get Started"
        default: return "Next"
        }
    }

    var isLastStep: Bool {
        self == .complete
    }
}

// MARK: - Tutorial Manager

final class TutorialManager: ObservableObject {
    static let shared = TutorialManager()

    @Published var isActive: Bool = false
    @Published var currentStep: TutorialStep = .welcome
    @Published var elementFrames: [String: CGRect] = [:]
    @Published var pendingTabSwitch: Int? = nil
    @Published var showSubscriptionAfterTutorial: Bool = false

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
        currentStep = .welcome
        isActive = true
    }

    func advance() {
        let nextRaw = currentStep.rawValue + 1
        if let next = TutorialStep(rawValue: nextRaw) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = next
            }
            // Signal tab switch if needed
            if let tab = next.targetTab {
                pendingTabSwitch = tab
            }
            if next == .complete {
                // Mark done after a delay so user can read the completion card
            }
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
        showSubscriptionAfterTutorial = true
    }

    /// Resets the tutorial so it will show again on next app launch or call to startIfNeeded().
    /// Intended for debug/testing only.
    func resetTutorial() {
        hasCompletedTutorial = false
        isActive = false
        currentStep = .welcome
        elementFrames = [:]
    }

    func registerFrame(id: String, frame: CGRect) {
        // Only update if meaningfully different to avoid layout loops
        guard frame.width > 0 && frame.height > 0 else { return }
        if elementFrames[id] != frame {
            elementFrames[id] = frame
        }
    }
}

// MARK: - Tutorial Highlight Modifier

struct TutorialHighlightModifier: ViewModifier {
    let id: String
    @ObservedObject private var tutorialManager = TutorialManager.shared

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            tutorialManager.registerFrame(id: id, frame: geo.frame(in: .global))
                        }
                        .onChange(of: geo.frame(in: .global)) { _, frame in
                            tutorialManager.registerFrame(id: id, frame: frame)
                        }
                }
            )
    }
}

extension View {
    func tutorialHighlight(id: String) -> some View {
        modifier(TutorialHighlightModifier(id: id))
    }
}
