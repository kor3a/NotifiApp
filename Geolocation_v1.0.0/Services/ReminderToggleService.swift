//
//  ReminderToggleService.swift
//  Geolocation_v1.0.0
//
//  The single place that knows how a reminder is checked on or off in Firestore.
//
//  Checking an item off is no longer something only the reminder list does —
//  the Apple Watch app checks items off too, through WatchConnectivityManager,
//  and that path has no ReminderViewModel behind it. Both routes call in here so
//  a watch tap writes exactly the fields a phone tap writes: the check-off
//  attribution stamp, the out-of-stock clear, and the batch that keeps every
//  linked copy of a shared reminder in agreement.
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
