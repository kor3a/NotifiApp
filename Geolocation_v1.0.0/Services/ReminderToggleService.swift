//
//  ReminderToggleService.swift
//  Geolocation_v1.0.0
//
//  The single place that knows how a reminder is checked on or off in Firestore,
//  and how an edit to one is attributed.
//
//  Keeping it in one place means any caller — with or without a ReminderViewModel
//  behind it — writes exactly the same fields: the check-off attribution stamp,
//  the out-of-stock clear, and the batch that keeps every linked copy of a shared
//  reminder in agreement.
//

import Foundation
import FirebaseFirestore

enum ReminderToggleService {

    // MARK: - Field Construction

    /// The Firestore updates for flipping a reminder's `isDone` to `newIsDone`.
    ///
    /// Checking an item on stamps who did it and when — that attribution is
    /// copied into `reminder_history` if the checked item is later deleted — and
    /// clears any out-of-stock flag, since an item you just put in the cart was
    /// evidently in stock. Unchecking removes the stamp so it can't linger.
    static func toggleFields(newIsDone: Bool, wasOutOfStock: Bool) -> [String: Any] {
        var fields: [String: Any] = ["isDone": newIsDone]

        if newIsDone {
            fields["checkedOffAt"] = Date().timeIntervalSince1970
            if let name = UserSessionManager.shared.currentUser?.name, !name.isEmpty {
                fields["checkedOffBy"] = name
            }
            if let userId = UserSessionManager.shared.currentUser?.userId, !userId.isEmpty {
                fields["checkedOffById"] = userId
            }
            if wasOutOfStock {
                fields["isOutOfStock"] = false
            }
        } else {
            fields["checkedOffAt"] = FieldValue.delete()
            fields["checkedOffBy"] = FieldValue.delete()
            fields["checkedOffById"] = FieldValue.delete()
        }

        return fields
    }

    // MARK: - Write

    /// Applies `fields` to a reminder, fanning the write out to every linked copy
    /// when the reminder is shared.
    ///
    /// A shared reminder exists as one document per participant, tied together by
    /// `sharedReminderId`. Writing only the tapped copy would leave the other
    /// people's lists showing the item as still needed, so all copies move
    /// together in one batch. If the fan-out query fails we still write the copy
    /// the user actually tapped rather than dropping their action.
    static func apply(
        fields: [String: Any],
        reminderId: String,
        sharedReminderId: String?,
        db: Firestore = Firestore.firestore(),
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let sharedReminderId else {
            updateSingle(reminderId, fields: fields, db: db, completion: completion)
            return
        }

        db.collection("reminders")
            .whereField("sharedReminderId", isEqualTo: sharedReminderId)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("ReminderToggleService: Error finding linked reminders: \(error.localizedDescription)")
                    #endif
                    updateSingle(reminderId, fields: fields, db: db, completion: completion)
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    updateSingle(reminderId, fields: fields, db: db, completion: completion)
                    return
                }

                let batch = db.batch()
                for doc in documents {
                    batch.updateData(fields, forDocument: doc.reference)
                }

                batch.commit { error in
                    DispatchQueue.main.async {
                        #if DEBUG
                        if let error = error {
                            print("ReminderToggleService: Error syncing toggle: \(error.localizedDescription)")
                        } else {
                            print("ReminderToggleService: Synced toggle across \(documents.count) linked reminders")
                        }
                        #endif
                        completion?(error)
                    }
                }
            }
    }

    // MARK: - Private

    private static func updateSingle(
        _ reminderId: String,
        fields: [String: Any],
        db: Firestore,
        completion: ((Error?) -> Void)?
    ) {
        db.collection("reminders").document(reminderId).updateData(fields) { error in
            DispatchQueue.main.async {
                #if DEBUG
                if let error = error {
                    print("ReminderToggleService: Error updating reminder fields: \(error.localizedDescription)")
                } else {
                    print("ReminderToggleService: Reminder fields updated successfully")
                }
                #endif
                completion?(error)
            }
        }
    }
}

// MARK: - Edit Attribution

/// Stamps who last changed a reminder's content.
///
/// A shared list shows one avatar per row. That avatar used to name the item's
/// original author for life, so a member who renamed, re-quantified or
/// re-categorized someone else's item left no trace on the row. Every
/// user-initiated content edit now stamps the editor, and the avatar follows the
/// stamp — the initial you see is the person whose change you are looking at.
///
/// Checking an item on or off is deliberately not an edit: it carries its own
/// `checkedOffBy` attribution (see `ReminderToggleService.toggleFields`) and
/// shouldn't repaint the row's avatar for what is a shopping action rather than
/// a change to the item. AI auto-categorization isn't an edit either — nobody
/// did it.
enum ReminderEditAttribution {

    /// The Firestore fields marking the signed-in user as this reminder's last
    /// editor. Empty when there is no signed-in identity to credit, so a write
    /// never clears an existing stamp with a half-known one.
    static func stampFields(now: Date = Date()) -> [String: Any] {
        let user = UserSessionManager.shared.currentUser
        let name = user?.name ?? ""
        let userId = user?.userId ?? ""
        guard !name.isEmpty || !userId.isEmpty else { return [:] }

        var fields: [String: Any] = ["lastEditedAt": now.timeIntervalSince1970]
        if !name.isEmpty { fields["lastEditedBy"] = name }
        if !userId.isEmpty { fields["lastEditedById"] = userId }
        return fields
    }

    /// `fields` with the last-editor stamp merged in. Values already present in
    /// `fields` win, so an explicit attribution is never overwritten.
    static func stamped(_ fields: [String: Any], now: Date = Date()) -> [String: Any] {
        fields.merging(stampFields(now: now)) { existing, _ in existing }
    }
}
