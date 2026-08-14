//
//  WatchDataStore.swift
//  AllimWatch Watch App
//
//  Everything the watch app knows, and the only place it talks to the phone.
//
//  The watch holds no Firebase session — the iPhone app is the source of truth
//  and this is a remote control for it. Three things follow from that:
//
//    • The store list arrives unprompted through `didReceiveApplicationContext`,
//      which the system delivers even while this app is closed, so the first
//      screen is already filled in when the user raises their wrist.
//    • Reminders are pulled per store on demand. `sendMessage` background-launches
//      the phone app if it isn't running, so this works without the user opening
//      anything on the phone first.
//    • Every payload that arrives is written to disk, so the app still shows the
//      user's list when the phone is out of range — just without check-off.
//
//  Checking an item off updates local state immediately and sends the change to
//  the phone; out of range, the change is queued with `transferUserInfo`, which
//  the system delivers when the two are back together.
//

import Foundation
import WatchConnectivity

final class WatchDataStore: NSObject, ObservableObject {

    static let shared = WatchDataStore()

    // MARK: - Published State

    @Published private(set) var stores: [WatchStorePayload] = []
    @Published private(set) var reminders: [String: [WatchReminderPayload]] = [:]

    /// False when nobody is signed in on the phone — the watch can't fix that
    /// itself, so the UI says where to go instead of showing an empty list.
    @Published private(set) var isSignedIn = true

    @Published private(set) var isLoadingStores = false
    @Published private(set) var loadingStoreIds: Set<String> = []

    /// Whether the phone is in range. Drives the offline notice and disables
    /// check-off buttons that would only queue up.
    @Published private(set) var isPhoneReachable = false

    /// Set when a request comes back with a problem, shown once and cleared on
    /// the next successful exchange.
    @Published var errorMessage: String?

    /// Check-offs sent while the phone was out of range. Kept so the row can
    /// show that the change hasn't landed yet.
    @Published private(set) var pendingToggleIds: Set<String> = []

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private static let storesCacheKey = "watch.cachedStores"
    private static let remindersCacheKey = "watch.cachedReminders"

    // MARK: - Lifecycle

    private override init() {
        super.init()
        loadCache()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Requests

    /// Asks the phone for a fresh store list. Falls back silently to the cached
    /// list when the phone is out of range — the user still gets their stores.
    func refreshStores() {
        guard WCSession.default.activationState == .activated else { return }

        guard WCSession.default.isReachable else {
            isPhoneReachable = false
            return
        }

        isLoadingStores = true
        WCSession.default.sendMessage(
            [WatchSyncKey.action: WatchSyncKey.actionRequestStores],
            replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    self?.isLoadingStores = false
                    self?.apply(reply: reply)
                }
            },
            errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoadingStores = false
                    self?.errorMessage = Self.friendlyMessage(for: error)
                }
            }
        )
    }

    /// Asks the phone for one store's reminders.
    func refreshReminders(for storeId: String) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            isPhoneReachable = false
            return
        }

        loadingStoreIds.insert(storeId)
        WCSession.default.sendMessage(
            [
                WatchSyncKey.action: WatchSyncKey.actionRequestReminders,
                WatchSyncKey.storeId: storeId
            ],
            replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    self?.loadingStoreIds.remove(storeId)
                    self?.apply(reply: reply)
                }
            },
            errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.loadingStoreIds.remove(storeId)
                    self?.errorMessage = Self.friendlyMessage(for: error)
                }
            }
        )
    }

    // MARK: - Check Off

    /// Checks an item on or off.
    ///
    /// The row flips immediately — waiting on a round trip to the phone before
    /// showing the tap registered would make the watch feel broken — and the
    /// phone's reply, which carries the store's real state, replaces the guess.
    func toggle(reminderId: String, in storeId: String) {
        guard var list = reminders[storeId],
              let index = list.firstIndex(where: { $0.id == reminderId }) else { return }

        let newIsDone = !list[index].isDone
        list[index] = list[index].settingIsDone(newIsDone)
        reminders[storeId] = list
        adjustCachedCount(for: storeId, by: newIsDone ? -1 : 1)
        saveCache()

        let message: [String: Any] = [
            WatchSyncKey.action: WatchSyncKey.actionToggleReminder,
            WatchSyncKey.reminderId: reminderId,
            WatchSyncKey.storeId: storeId,
            WatchSyncKey.isDone: newIsDone
        ]

        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            // Out of range: hand it to the system to deliver later, and mark the
            // row so the user can see it hasn't reached the phone yet.
            pendingToggleIds.insert(reminderId)
            WCSession.default.transferUserInfo(message)
            isPhoneReachable = false
            return
        }

        WCSession.default.sendMessage(
            message,
            replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    self?.pendingToggleIds.remove(reminderId)
                    self?.apply(reply: reply)
                }
            },
            errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    // The message didn't get through. Queue it instead of
                    // reverting — the user's intent is worth more than the
                    // instant confirmation.
                    self.pendingToggleIds.insert(reminderId)
                    WCSession.default.transferUserInfo(message)
                    self.errorMessage = Self.friendlyMessage(for: error)
                }
            }
        )
    }

    // MARK: - Applying Payloads

    private func apply(reply: [String: Any]) {
        if let error = reply[WatchSyncKey.error] as? String {
            errorMessage = error
            return
        }

        // An answer arrived, so the phone is plainly in range — trust that over
        // whatever the last reachability notification said.
        errorMessage = nil
        isPhoneReachable = true

        if let data = reply[WatchSyncKey.storeList] as? Data {
            applyStoreList(data)
        }
        if let data = reply[WatchSyncKey.reminderList] as? Data {
            applyReminderList(data)
        }
    }

    private func applyStoreList(_ data: Data) {
        guard let payload = try? JSONDecoder().decode(WatchStoreListPayload.self, from: data) else { return }
        stores = payload.stores
        isSignedIn = payload.isSignedIn

        // Drop reminders for stores that are gone so a deleted store's items
        // can't resurface.
        let liveIds = Set(payload.stores.map(\.id))
        reminders = reminders.filter { liveIds.contains($0.key) }

        saveCache()
    }

    private func applyReminderList(_ data: Data) {
        guard let payload = try? JSONDecoder().decode(WatchReminderListPayload.self, from: data) else { return }
        reminders[payload.storeId] = payload.reminders

        // The phone's answer is authoritative, so anything still marked pending
        // for this store has now been accounted for.
        let ids = Set(payload.reminders.map(\.id))
        pendingToggleIds.subtract(ids)

        // Keep the store's badge in step with the list the user is looking at.
        if let index = stores.firstIndex(where: { $0.id == payload.storeId }) {
            stores[index] = stores[index].settingReminderCount(
                payload.reminders.filter { !$0.isDone }.count
            )
        }

        saveCache()
    }

    /// Nudges a store's outstanding-item badge after a local check-off, so the
    /// store list agrees with the list the user just changed.
    private func adjustCachedCount(for storeId: String, by delta: Int) {
        guard let index = stores.firstIndex(where: { $0.id == storeId }) else { return }
        let newCount = max(0, stores[index].reminderCount + delta)
        stores[index] = stores[index].settingReminderCount(newCount)
    }

    // MARK: - Offline Cache

    private func loadCache() {
        if let data = defaults.data(forKey: Self.storesCacheKey),
           let cached = try? JSONDecoder().decode([WatchStorePayload].self, from: data) {
            stores = cached
        }
        if let data = defaults.data(forKey: Self.remindersCacheKey),
           let cached = try? JSONDecoder().decode([String: [WatchReminderPayload]].self, from: data) {
            reminders = cached
        }
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(stores) {
            defaults.set(data, forKey: Self.storesCacheKey)
        }
        if let data = try? JSONEncoder().encode(reminders) {
            defaults.set(data, forKey: Self.remindersCacheKey)
        }
    }

    // MARK: - Helpers

    /// "The counterpart app is not reachable" is not something to put in front of
    /// someone standing in a shop aisle.
    private static func friendlyMessage(for error: Error) -> String {
        guard let code = (error as? WCError)?.code else {
            return error.localizedDescription
        }

        switch code {
        case .notReachable, .deviceNotPaired, .companionAppNotInstalled, .sessionNotActivated:
            return "iPhone not reachable"
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchDataStore: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPhoneReachable = session.isReachable
            guard activationState == .activated else { return }
            self.refreshStores()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPhoneReachable = session.isReachable
            // Back in range — pick up anything that changed on the phone while
            // the two were apart.
            if session.isReachable {
                self.refreshStores()
            }
        }
    }

    /// The phone's unprompted store-list push. Delivered even when this app was
    /// closed, so it is usually what fills the first screen.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let data = applicationContext[WatchSyncKey.storeList] as? Data else { return }
            self?.applyStoreList(data)
        }
    }
}

// MARK: - Payload Mutation

private extension WatchStorePayload {
    func settingReminderCount(_ count: Int) -> WatchStorePayload {
        WatchStorePayload(
            id: id,
            name: name,
            reminderCount: count,
            imageURL: imageURL,
            canEdit: canEdit
        )
    }
}

private extension WatchReminderPayload {
    func settingIsDone(_ done: Bool) -> WatchReminderPayload {
        WatchReminderPayload(
            id: id,
            title: title,
            isDone: done,
            quantity: quantity,
            // Checking an item off means it was in stock after all — the same
            // rule the phone applies when it writes the change.
            isOutOfStock: done ? false : isOutOfStock,
            category: category,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }
}
