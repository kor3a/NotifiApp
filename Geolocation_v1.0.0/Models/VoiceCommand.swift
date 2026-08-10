//
//  VoiceCommand.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 8/10/26.
//
//  The data model behind the store row's voice command button: the plan the
//  language model returns for a spoken request, and the resolver that turns
//  that raw plan into actions this app is actually allowed to run.
//
//  Nothing here touches Firestore or the network, so the matching rules — which
//  are the part most likely to go wrong — are plain, testable logic.
//

import Foundation

// MARK: - Actions

/// The operations a spoken request can map onto. Deliberately a closed set:
/// anything the model invents outside this list is discarded rather than
/// guessed at, so an odd transcription can never trigger an unexpected write.
enum VoiceCommandActionKind: String, Codable, CaseIterable {
    case add
    case delete
    case check
    case uncheck
    case setQuantity
    case rename
    case outOfStock
}

/// One concrete change to make to a store's list.
struct VoiceCommandAction: Identifiable, Equatable, Decodable {
    let id: UUID
    var kind: VoiceCommandActionKind
    /// The item as the user referred to it, replaced with the matched
    /// reminder's real title once `VoiceCommandPlanner` resolves it.
    var title: String
    /// The reminder this acts on. Always set except for `.add`.
    var reminderId: String?
    /// Quantity for `.add` and `.setQuantity`.
    var quantity: Int?
    /// Replacement title for `.rename`.
    var newTitle: String?

    init(
        id: UUID = UUID(),
        kind: VoiceCommandActionKind,
        title: String,
        reminderId: String? = nil,
        quantity: Int? = nil,
        newTitle: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.reminderId = reminderId
        self.quantity = quantity
        self.newTitle = newTitle
    }

    // MARK: Decoding the model's reply

    private enum CodingKeys: String, CodingKey {
        case type, title, id, reminderId, quantity, newTitle
    }

    /// Lenient on purpose. The model is asked for an exact shape, but a reply
    /// with a missing field or an unknown action type should cost us one
    /// action, not the whole request — so unusable entries throw and are
    /// dropped by `VoiceCommandPlan`'s decoder.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawType = (try? container.decode(String.self, forKey: .type)) ?? ""
        guard let kind = VoiceCommandActionKind(rawValue: rawType) else {
            throw VoiceCommandDecodingError.unsupportedAction(rawType)
        }
        self.kind = kind
        self.id = UUID()
        self.title = ((try? container.decode(String.self, forKey: .title)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // The prompt asks for "id"; accept "reminderId" too so a reasonable
        // paraphrase of the schema still lands.
        let rawReminderId = (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(String.self, forKey: .reminderId))
        self.reminderId = rawReminderId?
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        // Quantities sometimes come back as "2" rather than 2.
        if let quantity = try? container.decode(Int.self, forKey: .quantity) {
            self.quantity = quantity
        } else if let text = try? container.decode(String.self, forKey: .quantity) {
            self.quantity = Int(text.trimmingCharacters(in: .whitespaces))
        } else {
            self.quantity = nil
        }

        self.newTitle = (try? container.decode(String.self, forKey: .newTitle))?
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    /// One-line description shown in the confirmation list.
    var summary: String {
        switch kind {
        case .add:
            if let quantity = quantity, quantity > 1 {
                return "Add \(quantity) × \(title)"
            }
            return "Add \(title)"
        case .delete:
            return "Delete \(title)"
        case .check:
            return "Check off \(title)"
        case .uncheck:
            return "Uncheck \(title)"
        case .setQuantity:
            return "Set \(title) to \(quantity ?? 1)"
        case .rename:
            return "Rename \(title) to \(newTitle ?? "")"
        case .outOfStock:
            return "Mark \(title) as out of stock"
        }
    }

    var iconName: String {
        switch kind {
        case .add: return "plus.circle.fill"
        case .delete: return "trash.circle.fill"
        case .check: return "checkmark.circle.fill"
        case .uncheck: return "arrow.uturn.backward.circle.fill"
        case .setQuantity: return "number.circle.fill"
        case .rename: return "pencil.circle.fill"
        case .outOfStock: return "exclamationmark.circle.fill"
        }
    }

    /// Deletions are the only irreversible action, so they're called out in red.
    var isDestructive: Bool { kind == .delete }
}

enum VoiceCommandDecodingError: Error {
    case unsupportedAction(String)
}

/// What the model returns for one spoken request.
struct VoiceCommandPlan: Equatable, Decodable {
    /// A natural-language restatement of the request, read back to the user
    /// before anything is written ("I'll add milk and check off bread").
    var confirmation: String
    var actions: [VoiceCommandAction]
    /// Anything the model couldn't act on, phrased for the user.
    var notes: [String]

    init(confirmation: String = "", actions: [VoiceCommandAction] = [], notes: [String] = []) {
        self.confirmation = confirmation
        self.actions = actions
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case confirmation, actions, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.confirmation = ((try? container.decode(String.self, forKey: .confirmation)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = ((try? container.decode([String].self, forKey: .notes)) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Decode actions one at a time so a single malformed entry doesn't
        // throw away the ones that parsed fine.
        var actions: [VoiceCommandAction] = []
        if var list = try? container.nestedUnkeyedContainer(forKey: .actions) {
            while !list.isAtEnd {
                let indexBeforeDecode = list.currentIndex
                if let action = try? list.decode(VoiceCommandAction.self) {
                    actions.append(action)
                    continue
                }
                // Whether a failed decode consumes the entry is a decoder
                // implementation detail, so only step past it when the cursor
                // actually stayed put — and give up if it still won't move,
                // rather than spinning on the same element.
                guard list.currentIndex == indexBeforeDecode else { continue }
                _ = try? list.decode(AnyDecodableValue.self)
                if list.currentIndex == indexBeforeDecode { break }
            }
        }
        self.actions = actions
    }
}

/// Throwaway box used only to skip over an action entry that failed to decode.
private struct AnyDecodableValue: Decodable {
    init(from decoder: Decoder) throws {
        _ = try? decoder.singleValueContainer()
    }
}

// MARK: - Planner

/// Turns the model's raw plan into actions that are safe to run against the
/// store's current list.
///
/// Two things make this necessary. The model is given the list's real document
/// IDs but can still return one that doesn't exist, and speech transcription
/// rarely matches a stored title exactly ("eggs" vs "Egg"). Every action is
/// re-matched here against live data; anything that can't be matched becomes a
/// note the user sees instead of a silent no-op.
enum VoiceCommandPlanner {

    /// Upper bound on actions from a single utterance — a runaway reply can't
    /// turn into dozens of writes.
    static let maxActions = 25

    struct Resolution: Equatable {
        var actions: [VoiceCommandAction]
        var notes: [String]
    }

    static func resolve(_ plan: VoiceCommandPlan, against reminders: [Reminder]) -> Resolution {
        var resolved: [VoiceCommandAction] = []
        var notes = plan.notes
        // Titles already spoken for, so "add milk and milk" doesn't trip the
        // view model's duplicate guard on the second one.
        var claimedTitles = Set(reminders.map { normalize($0.title) })
        // Reminders already targeted, so two actions can't fight over one item.
        var claimedIds = Set<String>()

        for action in plan.actions {
            guard resolved.count < maxActions else {
                notes.append("Only the first \(maxActions) changes were kept.")
                break
            }

            switch action.kind {
            case .add:
                guard !action.title.isEmpty else { continue }
                let key = normalize(action.title)
                guard !key.isEmpty else { continue }
                if claimedTitles.contains(key) {
                    notes.append("\(action.title) is already on this list.")
                    continue
                }
                claimedTitles.insert(key)
                var add = action
                // Ignore a nonsensical count rather than writing it.
                add.quantity = (action.quantity ?? 1) > 1 ? action.quantity : nil
                resolved.append(add)

            case .delete, .check, .uncheck, .setQuantity, .rename, .outOfStock:
                guard let match = match(action, in: reminders, excluding: claimedIds) else {
                    notes.append(unmatchedNote(for: action))
                    continue
                }
                guard let refined = refine(action, for: match, notes: &notes) else { continue }
                claimedIds.insert(match.id)
                resolved.append(refined)
            }
        }

        return Resolution(actions: resolved, notes: notes)
    }

    // MARK: Matching

    /// Finds the reminder an action refers to, preferring the ID the model
    /// returned and falling back to progressively looser title matching.
    private static func match(
        _ action: VoiceCommandAction,
        in reminders: [Reminder],
        excluding claimedIds: Set<String>
    ) -> Reminder? {
        let candidates = reminders.filter { !claimedIds.contains($0.id) }

        if let id = action.reminderId,
           let byId = candidates.first(where: { $0.id == id }) {
            return byId
        }

        let spoken = normalize(action.title)
        guard !spoken.isEmpty else { return nil }

        if let exact = candidates.first(where: { normalize($0.title) == spoken }) {
            return exact
        }

        // "eggs" said for a stored "Egg", and vice versa.
        let singular = singularized(spoken)
        if let plural = candidates.first(where: { singularized(normalize($0.title)) == singular }) {
            return plural
        }

        // Only accept a substring match when it's unambiguous — "milk" must not
        // silently pick one of "Whole milk" and "Oat milk".
        let partial = candidates.filter {
            let title = normalize($0.title)
            return title.contains(spoken) || spoken.contains(title)
        }
        return partial.count == 1 ? partial.first : nil
    }

    /// Applies the per-kind rules once a target is known, dropping actions that
    /// would be a no-op (checking off something already checked off) or invalid.
    private static func refine(
        _ action: VoiceCommandAction,
        for reminder: Reminder,
        notes: inout [String]
    ) -> VoiceCommandAction? {
        var refined = action
        refined.reminderId = reminder.id
        // Show the stored title, not the transcription, so the confirmation
        // matches what the user sees on the list.
        refined.title = reminder.title

        switch action.kind {
        case .check where reminder.isDone:
            notes.append("\(reminder.title) is already checked off.")
            return nil
        case .uncheck where !reminder.isDone:
            notes.append("\(reminder.title) isn't checked off.")
            return nil
        case .outOfStock where reminder.isOutOfStock == true:
            notes.append("\(reminder.title) is already marked out of stock.")
            return nil
        case .setQuantity:
            guard let quantity = action.quantity, quantity > 0 else {
                notes.append("No quantity was given for \(reminder.title).")
                return nil
            }
            refined.quantity = quantity
        case .rename:
            guard let newTitle = action.newTitle,
                  normalize(newTitle) != normalize(reminder.title) else {
                notes.append("No new name was given for \(reminder.title).")
                return nil
            }
            refined.newTitle = newTitle
        default:
            break
        }

        return refined
    }

    private static func unmatchedNote(for action: VoiceCommandAction) -> String {
        action.title.isEmpty
            ? "One request didn't name an item on this list."
            : "\(action.title) isn't on this list."
    }

    // MARK: Text normalization

    /// Lowercased, punctuation-free, single-spaced — the form titles are
    /// compared in so "Eggs," and "eggs" are the same item.
    static func normalize(_ text: String) -> String {
        let stripped = text.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(stripped)
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Crude but sufficient plural folding for shopping items. Only trims a
    /// trailing "s" on words long enough that doing so can't erase the word.
    static func singularized(_ text: String) -> String {
        text.split(separator: " ").map { word -> String in
            guard word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") else {
                return String(word)
            }
            if word.hasSuffix("es"), word.dropLast(2).last.map({ "sxz".contains($0) }) == true {
                return String(word.dropLast(2))
            }
            return String(word.dropLast())
        }
        .joined(separator: " ")
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
