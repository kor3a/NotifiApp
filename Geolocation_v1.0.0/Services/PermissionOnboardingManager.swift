//
//  PermissionOnboardingManager.swift
//  Geolocation_v1.0.0
//
//  Drives the two permission primer screens a brand-new account sees after it
//  has a username and name, and before the tutorial and the Stores tab: first
//  location, then notifications.
//
//  iOS shows each system prompt once per install. Firing them straight at a user
//  who just finished signing up spends that single ask before they know what the
//  app does with either permission, so each one is introduced by a screen that
//  explains it and asks the user to tap through to the real prompt themselves.
//

import SwiftUI
import CoreLocation
import UserNotifications
import FirebaseAuth

final class PermissionOnboardingManager: ObservableObject {
    static let shared = PermissionOnboardingManager()

    enum Step: Int, CaseIterable {
        case location
        case notifications
    }

    /// Where the signed-in account sits in the walkthrough. `MainView` switches
    /// on this once the profile is ready.
    enum State: Equatable {
        /// Still working out whether this account needs the walkthrough at all.
        /// `MainView` holds a neutral screen here rather than guessing, the same
        /// way it does while the profile lookup runs — guessing "finished" would
        /// flash the app before the primer appeared.
        case evaluating
        case active(Step)
        case finished
    }

    @Published private(set) var state: State = .evaluating

    /// True once the walkthrough has actually put a screen on screen in this app
    /// session. `HomeView` reads it to stay quiet about a permission the user
    /// just declined — its "Notifications Are Disabled" alert would otherwise
    /// land on top of the tutorial seconds after the decline.
    private(set) var didRunThisSession = false

    /// Every step this account was shown, in order — kept for the progress dots.
    private(set) var steps: [Step] = []

    /// Steps still ahead of the user.
    private var remainingSteps: [Step] = []

    /// The account `state` describes. Signing into a different one re-evaluates
    /// from scratch, so a second account on the same device gets its own primer.
    private var evaluatedUid: String?

    private var authHandle: AuthStateDidChangeListenerHandle?

    /// Keyed by Auth UID rather than username: usernames can be reused across
    /// accounts, and the walkthrough is about this device's permission prompts.
    private static func completionKey(_ uid: String) -> String {
        "hasCompletedPermissionOnboarding_auth_\(uid)"
    }

    private init() {
        // Fires immediately with the current user, so `state` is always driven by
        // a real account instead of sitting at `.evaluating` forever.
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            DispatchQueue.main.async {
                self?.accountChanged(uid: uid)
            }
        }
    }

    // MARK: - Progress

    /// 1-based position of `step` for the progress dots.
    func position(of step: Step) -> Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }

    var stepCount: Int { steps.count }

    // MARK: - Evaluation

    private func accountChanged(uid: String?) {
        guard uid != evaluatedUid else { return }
        evaluatedUid = uid
        didRunThisSession = false

        guard let uid = uid else {
            // Signed out. Nothing to route; the next sign-in re-evaluates.
            state = .evaluating
            steps = []
            remainingSteps = []
            return
        }

        guard !hasCompleted(uid: uid) else {
            state = .finished
            return
        }

        state = .evaluating
        // The location status is read here, on the main thread, rather than
        // inside the task: CLLocationManager expects to be used from the thread
        // it was created on.
        let locationStatus = LocationMonitoringManager.shared.checkLocationPermission()
        Task { await evaluateSteps(uid: uid, locationStatus: locationStatus) }
    }

    private func hasCompleted(uid: String) -> Bool {
        #if DEBUG
        if forceAllSteps { return false }
        #endif
        return UserDefaults.standard.bool(forKey: Self.completionKey(uid))
    }

    /// A step is only worth showing while its system prompt can still appear.
    /// Everyone who has already answered — including an existing user updating
    /// into this build, whose permissions were settled long ago — drops straight
    /// into the app with nothing to tap through.
    private func evaluateSteps(uid: String, locationStatus: CLAuthorizationStatus) async {
        var needed: [Step] = []

        if locationStatus == .notDetermined {
            needed.append(.location)
        }
        if await NotificationManager.shared.authorizationStatus() == .notDetermined {
            needed.append(.notifications)
        }

        #if DEBUG
        if forceAllSteps { needed = Step.allCases }
        #endif

        let resolved = needed
        await MainActor.run {
            // The account can change while the notification settings lookup is in
            // flight; that evaluation now belongs to nobody.
            guard self.evaluatedUid == uid else { return }

            self.steps = resolved
            self.remainingSteps = resolved

            guard let first = resolved.first else {
                self.markComplete(uid: uid)
                return
            }

            self.didRunThisSession = true
            self.state = .active(first)
        }
    }

    // MARK: - Flow

    /// Called by a primer screen once its system prompt has been answered —
    /// granted *or* denied. iOS won't ask twice either way, so a decline still
    /// moves the walkthrough along rather than trapping the user on the screen.
    func advance(from step: Step) {
        guard case .active(let current) = state, current == step else { return }
        guard let uid = evaluatedUid else { return }

        remainingSteps.removeAll { $0 == step }

        withAnimation(.easeInOut(duration: 0.35)) {
            if let next = remainingSteps.first {
                state = .active(next)
            } else {
                markComplete(uid: uid)
            }
        }
    }

    private func markComplete(uid: String) {
        #if DEBUG
        // One replay per request; don't leave the screens pinned on.
        forceAllSteps = false
        #endif
        UserDefaults.standard.set(true, forKey: Self.completionKey(uid))
        remainingSteps = []
        // `steps` is deliberately left alone: the outgoing screen is still on
        // screen for the exit transition and reads it for its progress dots.
        state = .finished
    }

    #if DEBUG
    /// Shows both primers again on the next evaluation regardless of the real
    /// authorization statuses, so the screens can be reviewed without deleting
    /// and reinstalling the app. The system prompts themselves stay one-shot —
    /// tapping the button on an already-answered permission just advances.
    private var forceAllSteps = false

    func replayForDebug() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        forceAllSteps = true
        UserDefaults.standard.removeObject(forKey: Self.completionKey(uid))
        evaluatedUid = nil
        accountChanged(uid: uid)
    }
    #endif
}
