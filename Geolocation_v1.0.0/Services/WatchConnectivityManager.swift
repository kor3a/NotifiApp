//
//  WatchConnectivityManager.swift
//  Geolocation_v1.0.0
//
//  The phone's half of the Apple Watch bridge.
//
//  The watch has no Firebase session of its own — putting one there would mean a
//  second sign-in on a device with no keyboard — so the phone stays the source of
//  truth and the watch is a remote control:
//
//    • The store list is pushed with `updateApplicationContext`, which the system
//      delivers even when the watch app isn't running, so opening the app on the
//      wrist shows the right stores immediately.
//    • Reminders are pulled per store when the user taps into one. `sendMessage`
//      background-launches this app on the phone if it isn't already running, so
//      this works from a cold start as long as the phone is in range.
//    • Check-offs come back the same way and are written through
//      ReminderToggleService, so a tap on the wrist is indistinguishable in
//      Firestore from a tap on the phone — including the fan-out to every linked
//      copy of a shared reminder.
//
//  When the watch is out of range it falls back to `transferUserInfo`, which the
//  system queues and delivers later, so a check-off made away from the phone is
//  not lost.
//

import Foundation
import FirebaseFirestore
import WatchConnectivity

/// One user_store document reduced to what the watch payload needs, held while
/// the outstanding-item counts for each store are queried in parallel.
private struct PendingStore {
    let id: String
    let name: String
    let reminderStoreId: String
    let canEdit: Bool
    let sortOrder: Int?
}

final class WatchConnectivityManager: NSObject {

    static let shared = WatchConnectivityManager()

    private let db = Firestore.firestore()

    /// The most recent store list handed over by StoresViewModel. Serves replies
    /// without a round trip to Firestore, and maps a store ID to the ID its
    /// reminders actually live under.
    private var cachedStores: [UserStoreItem] = []

    /// The last payload pushed to the watch, so the repeated calls that come with
    /// every reminder-count change don't each cost a context update.
    private var lastPushedStoreList: WatchStoreListPayload?

    private override init() {
        super.init()
    }

    // MARK: - Activation

    /// Activates the session. Safe to call repeatedly — activating an already
    /// active session is a no-op.
    ///
    /// Call this at launch, including background launches: a message from the
    /// watch only reaches this app if the delegate was set before it arrived.
    func activate() {
        guard WCSession.isSupported() else {
            #if DEBUG
            print("⌚️ WatchConnectivity: not supported on this device")
            #endif
            return
        }

        let session = WCSession.default
        guard session.delegate !== self || session.activationState == .notActivated else { return }

        session.delegate = self
        session.activate()
    }

    private var canReachWatchApp: Bool {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    // MARK: - Outbound: Store List

    /// Publishes the user's stores to the watch. Called wherever the widget is
    /// refreshed, so the two stay in step.
    func updateStores(from userStoreItems: [UserStoreItem]) {
        cachedStores = userStoreItems

        let payload = WatchStoreListPayload(
            stores: userStoreItems.map(Self.makeStorePayload),
            isSignedIn: UserSessionManager.shared.currentUser != nil,
            updatedAt: Date().timeIntervalSince1970
        )

        push(storeList: payload)
    }

    private func push(storeList payload: WatchStoreListPayload) {
        guard canReachWatchApp else { return }

        // `updatedAt` changes on every call, so compare the parts that matter.
        if let last = lastPushedStoreList,
           last.stores == payload.stores,
           last.isSignedIn == payload.isSignedIn {
            return
        }

        guard let encoded = try? JSONEncoder().encode(payload) else { return }

        do {
            try WCSession.default.updateApplicationContext([WatchSyncKey.storeList: encoded])
            lastPushedStoreList = payload
            #if DEBUG
            print("⌚️ WatchConnectivity: pushed \(payload.stores.count) stores to the watch")
            #endif
        } catch {
            #if DEBUG
            print("⌚️ WatchConnectivity: failed to push store list — \(error.localizedDescription)")
            #endif
        }
    }

    private static func makeStorePayload(_ item: UserStoreItem) -> WatchStorePayload {
        WatchStorePayload(
            id: item.id,
            name: item.store.name,
            reminderCount: item.store.reminderCount,
            // Most stores carry no `imageURL` of their own — the phone resolves
            // the logo by name through StoreLogoProvider, so the watch gets the
            // same URL the phone would draw rather than falling back to an
            // initial for nearly every store.
            imageURL: item.store.imageURL ?? StoreLogoProvider.shared.logoURL(for: item.store.name),
            canEdit: item.permission != .view
        )
    }

    // MARK: - Inbound: Request Handling

    /// Routes one request from the watch and calls `reply` exactly once.
    private func handle(message: [String: Any], reply: @escaping ([String: Any]) -> Void) {
        let action = message[WatchSyncKey.action] as? String

        switch action {
        case WatchSyncKey.actionRequestStores:
            replyWithStoreList(reply)

        case WatchSyncKey.actionRequestReminders:
            guard let storeId = message[WatchSyncKey.storeId] as? String else {
                reply([WatchSyncKey.error: "Missing storeId"])
                return
            }
            fetchReminders(forStoreId: storeId) { payload in
                guard let payload, let encoded = try? JSONEncoder().encode(payload) else {
                    reply([WatchSyncKey.error: "Could not load reminders"])
                    return
                }
                reply([WatchSyncKey.reminderList: encoded])
            }

        case WatchSyncKey.actionToggleReminder:
            guard let reminderId = message[WatchSyncKey.reminderId] as? String,
                  let isDone = message[WatchSyncKey.isDone] as? Bool else {
                reply([WatchSyncKey.error: "Missing reminderId"])
                return
            }
            let storeId = message[WatchSyncKey.storeId] as? String
            toggleReminder(reminderId: reminderId, isDone: isDone) { [weak self] error in
                guard let self else { return }

                if let error {
                    reply([WatchSyncKey.error: error.localizedDescription])
                    return
                }

                // Reply with the store's refreshed list so the watch replaces its
                // optimistic state with what Firestore actually holds.
                guard let storeId else {
                    reply([:])
                    return
                }
                self.fetchReminders(forStoreId: storeId) { payload in
                    guard let payload, let encoded = try? JSONEncoder().encode(payload) else {
                        reply([:])
                        return
                    }
                    reply([WatchSyncKey.reminderList: encoded])
                }
            }

        default:
            reply([WatchSyncKey.error: "Unknown action"])
        }
    }

    private func replyWithStoreList(_ reply: @escaping ([String: Any]) -> Void) {
        func send(_ stores: [WatchStorePayload], isSignedIn: Bool) {
            let payload = WatchStoreListPayload(
                stores: stores,
                isSignedIn: isSignedIn,
                updatedAt: Date().timeIntervalSince1970
            )
            guard let encoded = try? JSONEncoder().encode(payload) else {
                reply([WatchSyncKey.error: "Could not encode stores"])
                return
            }
            reply([WatchSyncKey.storeList: encoded])
        }

        // A watch message can background-launch this app, in which case
        // StoresViewModel has never run and the cache is empty. Read the list
        // straight from Firestore rather than answering "you have no stores".
        guard cachedStores.isEmpty,
              let userId = UserSessionManager.shared.currentUser?.userId else {
            send(
                cachedStores.map(Self.makeStorePayload),
                isSignedIn: UserSessionManager.shared.currentUser != nil
            )
            return
        }

        fetchStoresFromFirestore(userId: userId) { stores in
            send(stores, isSignedIn: true)
        }
    }

    // MARK: - Firestore Reads

    /// Reads the user's stores directly, for the background-launch case where
    /// StoresViewModel hasn't run. Reminder counts come from a per-store count
    /// query so the watch shows the same "items left" number as the phone.
    private func fetchStoresFromFirestore(
        userId: String,
        completion: @escaping ([WatchStorePayload]) -> Void
    ) {
        db.collection("user_stores")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self, let documents = snapshot?.documents, error == nil else {
                    completion([])
                    return
                }

                let pending: [PendingStore] = documents.compactMap { doc in
                    let data = doc.data()
                    guard let name = data["storeName"] as? String else { return nil }

                    let permission = StorePermission(rawValue: data["permission"] as? String ?? "owner") ?? .owner
                    let sourceUserStoreId = data["sourceUserStoreId"] as? String
                    let sharedStoreGroupId = data["sharedStoreGroupId"] as? String
                    let reminderStoreId = permission == .owner
                        ? doc.documentID
                        : (sourceUserStoreId ?? sharedStoreGroupId ?? doc.documentID)

                    return PendingStore(
                        id: doc.documentID,
                        name: name,
                        reminderStoreId: reminderStoreId,
                        canEdit: permission != .view,
                        sortOrder: data["sortOrder"] as? Int
                    )
                }

                let group = DispatchGroup()
                var counts: [String: Int] = [:]
                let lock = NSLock()

                for reminderStoreId in Set(pending.map(\.reminderStoreId)) {
                    group.enter()
                    self.db.collection("reminders")
                        .whereField("userStoreId", isEqualTo: reminderStoreId)
                        .whereField("isDone", isEqualTo: false)
                        .getDocuments { snapshot, _ in
                            lock.lock()
                            counts[reminderStoreId] = snapshot?.documents.count ?? 0
                            lock.unlock()
                            group.leave()
                        }
                }

                // Back to main: StoreLogoProvider and UserSessionManager are
                // main-actor-ish observable objects the rest of the app only ever
                // touches from the main queue.
                group.notify(queue: .main) {
                    let payloads = pending
                        .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
                        .map { store in
                            WatchStorePayload(
                                id: store.id,
                                name: store.name,
                                reminderCount: counts[store.reminderStoreId] ?? 0,
                                imageURL: StoreLogoProvider.shared.logoURL(for: store.name),
                                canEdit: store.canEdit
                            )
                        }
                    completion(payloads)
                }
            }
    }

    /// Resolves the ID a store's reminders are filed under. Recipients of a
    /// shared store read the owner's list, not their own document.
    private func resolveReminderStoreId(
        forStoreId storeId: String,
        completion: @escaping (String?) -> Void
    ) {
        if let cached = cachedStores.first(where: { $0.id == storeId }) {
            completion(cached.reminderStoreId)
            return
        }

        db.collection("user_stores").document(storeId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                completion(nil)
                return
            }

            let permission = StorePermission(rawValue: data["permission"] as? String ?? "owner") ?? .owner
            guard permission != .owner else {
                completion(storeId)
                return
            }
            completion(
                (data["sourceUserStoreId"] as? String)
                    ?? (data["sharedStoreGroupId"] as? String)
                    ?? storeId
            )
        }
    }

    private func fetchReminders(
        forStoreId storeId: String,
        completion: @escaping (WatchReminderListPayload?) -> Void
    ) {
        resolveReminderStoreId(forStoreId: storeId) { [weak self] reminderStoreId in
            guard let self, let reminderStoreId else {
                completion(nil)
                return
            }

            self.db.collection("reminders")
                .whereField("userStoreId", isEqualTo: reminderStoreId)
                .getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents, error == nil else {
                        completion(nil)
                        return
                    }

                    let reminders = documents
                        .compactMap { Self.makeReminderPayload(id: $0.documentID, data: $0.data()) }
                        .sorted { a, b in
                            let orderA = a.sortOrder ?? Int.max
                            let orderB = b.sortOrder ?? Int.max
                            if orderA != orderB { return orderA < orderB }
                            return a.createdAt < b.createdAt
                        }

                    completion(
                        WatchReminderListPayload(
                            storeId: storeId,
                            reminders: reminders,
                            updatedAt: Date().timeIntervalSince1970
                        )
                    )
                }
        }
    }

    private static func makeReminderPayload(id: String, data: [String: Any]) -> WatchReminderPayload? {
        guard let title = data["title"] as? String,
              let isDone = data["isDone"] as? Bool,
              let createdAt = data["createdAt"] as? TimeInterval else { return nil }

        return WatchReminderPayload(
            id: id,
            title: title,
            isDone: isDone,
            quantity: data["quantity"] as? Int,
            isOutOfStock: data["isOutOfStock"] as? Bool ?? false,
            category: data["category"] as? String,
            sortOrder: data["sortOrder"] as? Int,
            createdAt: createdAt
        )
    }

    // MARK: - Firestore Writes

    /// Applies a check-off from the watch. The reminder document is read first so
    /// the write carries the same context a phone tap would have: whether the
    /// item was out of stock, and which shared copies move with it.
    private func toggleReminder(
        reminderId: String,
        isDone: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        db.collection("reminders").document(reminderId).getDocument { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                completion(error)
                return
            }

            guard let data = snapshot?.data(), snapshot?.exists == true else {
                completion(NSError(
                    domain: "WatchConnectivityManager",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Reminder no longer exists"]
                ))
                return
            }

            // Already in the requested state — the watch and phone agree, so
            // there is nothing to write.
            if data["isDone"] as? Bool == isDone {
                completion(nil)
                return
            }

            let fields = ReminderToggleService.toggleFields(
                newIsDone: isDone,
                wasOutOfStock: data["isOutOfStock"] as? Bool == true
            )

            ReminderToggleService.apply(
                fields: fields,
                reminderId: reminderId,
                sharedReminderId: data["sharedReminderId"] as? String,
                db: self.db,
                completion: completion
            )
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if DEBUG
        if let error {
            print("⌚️ WatchConnectivity: activation failed — \(error.localizedDescription)")
        } else {
            print("⌚️ WatchConnectivity: activated (state \(activationState.rawValue), paired: \(session.isPaired), installed: \(session.isWatchAppInstalled))")
        }
        #endif

        guard activationState == .activated else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.cachedStores.isEmpty else { return }
            self.updateStores(from: self.cachedStores)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Reactivate so the session survives the user switching to a different watch.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // A watch that just paired, or just installed the app, holds no
            // context — clearing this makes the next push unconditional.
            self.lastPushedStoreList = nil
            guard !self.cachedStores.isEmpty else { return }
            self.updateStores(from: self.cachedStores)
        }
    }

    /// Delegate callbacks arrive on a background queue; the session state and
    /// logo caches these requests read are main-queue-only, so hop first.
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.handle(message: message, reply: replyHandler)
        }
    }

    /// Queued deliveries — a check-off made while the watch was out of range.
    /// There is nobody waiting on a reply here, so the result is simply written.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { [weak self] in
            self?.handle(message: userInfo) { _ in }
        }
    }
}
