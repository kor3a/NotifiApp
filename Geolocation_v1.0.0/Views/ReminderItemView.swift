//
//  StoreReminderView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import SwiftUI

struct ReminderItemView: View {
    let item: Reminder
    let isEditing: Bool
    var isReorderMode: Bool = false
    var onPhotoTap: ((String) -> Void)?
    var onCheckboxTap: (() -> Void)?
    var onCheckboxLongPress: (() -> Void)?
    var onTextTap: (() -> Void)?
    var onTitleCommit: ((String) -> Void)?
    var onReorderTap: (() -> Void)?
    var onAddToFavorites: (() -> Void)?
    var isFavorited: Bool = false
    var availableStores: [UserStoreItem] = []
    var onMoveToStore: ((UserStoreItem) -> Void)?
    var onAddPhoto: (() -> Void)?
    var onAddQuantity: (() -> Void)?
    var isEditingQuantity: Bool = false
    var onQuantityTap: (() -> Void)?
    var onQuantityCommit: ((Int?) -> Void)?
    var category: String?
    var onSetCategory: (() -> Void)?
    var onCheckboxFrameChanged: ((CGRect) -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var autoDeleteEnabled: Bool = false
    /// Store-wide avatar color assignment, forwarded to the shared badge so the
    /// author avatar's color is resolved against every member of the store.
    var avatarColorMap: [String: Color] = [:]
    /// userId → display name for store members, forwarded to the shared badge so
    /// an author's initial can be recovered from their id when the reminder has
    /// no `sharedFrom` name.
    var memberNames: [String: String] = [:]
    @StateObject private var viewModel = ReminderItemViewModel()
    @State private var editText: String = ""
    @State private var editQuantityText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isQuantityFieldFocused: Bool

    // Get current user's info to determine if they created the reminder
    private var currentUserName: String? {
        UserSessionManager.shared.currentUser?.name
    }

    private var currentUserId: String? {
        UserSessionManager.shared.currentUser?.userId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if autoDeleteEnabled {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 20, height: 30)
                        // Visual affordance only. The AutoDeleteSwipeRail overlay
                        // in ReminderView owns the gesture at the ZStack level so
                        // it never competes with the List's scroll recognizer.
                }

                Image(systemName: item.isOutOfStock == true ? "xmark.square" : (item.isDone ? "checkmark.square" : "square"))
                    .foregroundStyle(item.isOutOfStock == true ? .red : .primary)
                    // Animate the symbol swap and add a little pop when the
                    // checkbox is checked/unchecked or toggled out of stock.
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.isDone)
                    .symbolEffect(.bounce, value: item.isOutOfStock)
                    .contentShape(Rectangle())
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    onCheckboxFrameChanged?(geo.frame(in: .global))
                                }
                                .onChange(of: geo.frame(in: .global)) { _, frame in
                                    onCheckboxFrameChanged?(frame)
                                }
                        }
                    )
                    .onTapGesture {
                        onCheckboxTap?()
                    }

                if isEditing {
                    TextField("Reminder", text: $editText)
                        .font(.system(size: 17))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            commitEdit()
                        }
                        .textInputAutocapitalization(.sentences)
                        .onAppear {
                            editText = item.title
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused = true
                            }
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            if !focused && isEditing {
                                commitEdit()
                            }
                        }
                } else {
                    Text(item.title)
                        .font(.system(size: 17))
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: item.isDone)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTextTap?()
                        }
                }

                Spacer()

                // Show quantity badge if quantity is set
                if isEditingQuantity {
                    HStack(spacing: 2) {
                        Text("Qty:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        TextField("", text: $editQuantityText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .keyboardType(.numberPad)
                            .frame(width: 40)
                            .focused($isQuantityFieldFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    if isQuantityFieldFocused {
                                        Spacer()
                                        Button("Done") {
                                            isQuantityFieldFocused = false
                                        }
                                    }
                                }
                            }
                            .onAppear {
                                editQuantityText = item.quantity.map(String.init) ?? ""
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isQuantityFieldFocused = true
                                }
                            }
                            .onChange(of: isQuantityFieldFocused) { _, focused in
                                if !focused && isEditingQuantity {
                                    commitQuantityEdit()
                                }
                            }
                    }
                } else if let quantity = item.quantity, quantity > 0 {
                    Text("Qty: \(quantity)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onQuantityTap?()
                        }
                }

                // Show "Shared" badge if the reminder is shared
                if item.isShared == true {
                    SharedBadge(
                        sharedFrom: item.sharedFrom,
                        sharedFromId: item.sharedFromId,
                        sharedWith: item.sharedWith,
                        currentUserName: currentUserName,
                        currentUserId: currentUserId,
                        avatarColorMap: avatarColorMap,
                        memberNames: memberNames
                    )
                }

                // Star icon for toggling favorite
                if onAddToFavorites != nil {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .foregroundStyle(isFavorited ? .yellow : .secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onAddToFavorites?()
                        }
                }

                // Three vertical dots drag handle for reordering
                if !isReorderMode, onReorderTap != nil {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onReorderTap?()
                        }
                }
            }


            // Photo thumbnails row
            if let photoURLs = item.photoURLs, !photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photoURLs, id: \.self) { urlString in
                            AsyncImage(url: URL(string: urlString)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipped()
                                        .cornerRadius(8)
                                case .failure:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        )
                                case .empty:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                        .overlay(ProgressView())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .onTapGesture {
                                onPhotoTap?(urlString)
                            }
                        }
                    }
                }
            }
        }
        .contextMenu {
            if let onCheckboxLongPress = onCheckboxLongPress {
                Button {
                    onCheckboxLongPress()
                } label: {
                    Label(
                        item.isOutOfStock == true ? "Mark Available" : "Out of Stock",
                        systemImage: item.isOutOfStock == true ? "checkmark.circle" : "xmark.circle"
                    )
                }
            }
            if let onMoveToStore = onMoveToStore, !availableStores.isEmpty {
                Menu {
                    ForEach(availableStores, id: \.id) { store in
                        Button {
                            onMoveToStore(store)
                        } label: {
                            Label(store.store.name, systemImage: "cart")
                        }
                    }
                } label: {
                    Label("Move to Store", systemImage: "arrow.right.square")
                }
            }
            if let onAddPhoto = onAddPhoto {
                Button {
                    onAddPhoto()
                } label: {
                    Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                }
            }
            if let onAddQuantity = onAddQuantity {
                Button {
                    onAddQuantity()
                } label: {
                    Label("Add Quantity", systemImage: "number")
                }
            }
            if let onSetCategory = onSetCategory {
                Button {
                    onSetCategory()
                } label: {
                    Label(
                        category != nil ? "Change Category" : "Set Category",
                        systemImage: "tag"
                    )
                }
            }
        }
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            onTitleCommit?(trimmed)
        } else {
            // Empty text - revert to original
            onTitleCommit?(item.title)
        }
    }

    private func commitQuantityEdit() {
        let trimmed = editQuantityText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Empty text - remove quantity
            onQuantityCommit?(nil)
        } else if let qty = Int(trimmed), qty > 0 {
            onQuantityCommit?(qty)
        } else {
            // Zero or invalid input - remove quantity
            onQuantityCommit?(nil)
        }
    }
}

// MARK: - Shared Badge

struct SharedBadge: View {
    let sharedFrom: String?
    let sharedFromId: String?
    let sharedWith: [String]?
    let currentUserName: String?
    let currentUserId: String?
    /// Store-wide deterministic color assignment keyed by author identity, so
    /// members who share a first initial never share a color. Empty when no
    /// store-wide context is available (falls back to the standalone palette).
    var avatarColorMap: [String: Color] = [:]
    /// userId → display name for the store's members, used to recover the
    /// author's name (and therefore initial) when a reminder carries the
    /// author's `sharedFromId` but no `sharedFrom` name.
    var memberNames: [String: String] = [:]

    // Check if current user is the one who shared/created this reminder
    // Uses userId for reliable comparison, falls back to name for old data
    private var isCurrentUserTheSharer: Bool {
        // Prefer ID-based comparison (reliable even after name changes)
        if let sharedFromId = sharedFromId, !sharedFromId.isEmpty,
           let currentUserId = currentUserId {
            return sharedFromId == currentUserId
        }
        // Fallback to name comparison for old reminders without sharedFromId
        guard let sharedFrom = sharedFrom, !sharedFrom.isEmpty,
              let currentUserName = currentUserName else {
            return false
        }
        return sharedFrom == currentUserName
    }

    /// Whether the avatar's author resolves to the current user — the signal for
    /// styling the badge as "yours." Strictly ID-based: an item is the viewer's
    /// only on an exact `sharedFromId == currentUserId` match. Items that carry
    /// no author id are NOT claimed (name is used only for truly legacy data
    /// that never recorded ids). This deliberately avoids the earlier
    /// "author-less ⇒ mine" default, which mis-marked another user's items as
    /// the viewer's whenever their copies arrived without attribution (e.g. from
    /// a stale cache or an unsynced field).
    private var isAuthoredByCurrentUser: Bool {
        if let sharedFromId = sharedFromId, !sharedFromId.isEmpty {
            guard let currentUserId = currentUserId, !currentUserId.isEmpty else {
                return false
            }
            return sharedFromId == currentUserId
        }
        // Legacy item with no author id: fall back to a name match.
        if let sharedFrom = sharedFrom, !sharedFrom.isEmpty,
           let currentUserName = currentUserName, !currentUserName.isEmpty {
            return sharedFrom.caseInsensitiveCompare(currentUserName) == .orderedSame
        }
        // No author recorded — unknown, so never claim it as the current user's.
        return false
    }

    /// Best-known display name for this reminder's author, independent of who is
    /// viewing. Prefers the recorded `sharedFrom`; when that's missing but an
    /// author id is present, recovers the name from the store member map. This
    /// is what drives the avatar's initial, so it always reflects the *author*.
    private var resolvedAuthorName: String? {
        if let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            return sharedFrom
        }
        if let id = sharedFromId, !id.isEmpty,
           let name = memberNames[id], !name.isEmpty {
            return name
        }
        return nil
    }

    /// The person who created/shared this reminder — its author. Everyone (the
    /// sharer and every recipient) sees the same author initial for a given item.
    ///
    /// For the current user's own items we prefer the live session name so a name
    /// change reflects immediately; for others we use the resolved author name.
    /// Critically, this never falls back to the current user's name for an item
    /// that isn't theirs — an unknown author yields nil (a neutral avatar), not
    /// the viewer's initial.
    private var authorName: String? {
        if isAuthoredByCurrentUser,
           let currentUserName = currentUserName, !currentUserName.isEmpty {
            return currentUserName
        }
        return resolvedAuthorName
    }

    /// Stable color identity for this reminder's author (userId-based), so the
    /// avatar color is distinct per account even when two members share a name.
    /// Uses the resolved author name so the initial matches even when only the
    /// author id was recorded on the reminder.
    private var avatarIdentity: (key: String, name: String)? {
        SharedAvatarPalette.authorIdentity(
            sharedFrom: isAuthoredByCurrentUser ? currentUserName : resolvedAuthorName,
            sharedFromId: sharedFromId,
            currentUserName: currentUserName,
            currentUserId: currentUserId
        )
    }

    var body: some View {
        Group {
            if let identity = avatarIdentity {
                InitialAvatar(
                    name: identity.name,
                    color: SharedAvatarPalette.color(forKey: identity.key, in: avatarColorMap),
                    isCurrentUser: isAuthoredByCurrentUser
                )
            } else if let name = authorName,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                InitialAvatar(
                    name: name,
                    isCurrentUser: isAuthoredByCurrentUser
                )
            } else {
                // Shared but no known author — keep a visible indicator.
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.appAccent))
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            }
        }
        .help(tooltipText)
    }

    private var tooltipText: String {
        // If current user created/shared this reminder
        if isCurrentUserTheSharer {
            if let sharedWith = sharedWith, !sharedWith.isEmpty {
                return "You shared with: \(sharedWith.joined(separator: ", "))"
            }
            return "You shared this reminder"
        }

        // If sharedFrom is set and it's someone else, user is a recipient
        if let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            // Exclude the viewer from the recipient list — they already know
            // they received it, and "Shared by X with 1 people" reads badly.
            let otherRecipients = (sharedWith ?? []).filter {
                $0.lowercased() != (currentUserName ?? "").lowercased()
            }
            if !otherRecipients.isEmpty {
                return "Shared by \(sharedFrom) with \(otherRecipients.joined(separator: ", "))"
            }
            return "Shared by \(sharedFrom)"
        }

        // No sharedFrom means user is the original sender (owner added it)
        if let sharedWith = sharedWith, !sharedWith.isEmpty {
            return "Shared with: \(sharedWith.joined(separator: ", "))"
        }

        return "Shared reminder"
    }
}

// MARK: - Initial Avatar

/// A small circle showing a person's first initial, colored deterministically
/// from their name so the same person always gets the same "random" color.
struct InitialAvatar: View {
    let name: String
    var size: CGFloat = 22
    /// Explicit color override (e.g. a store-wide, collision-resolved color).
    /// When nil, falls back to the standalone deterministic palette color.
    var color: Color? = nil
    /// Marks the viewer's own authored item so it reads differently from items
    /// authored by other members of the shared store.
    var isCurrentUser: Bool = false

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? "?").uppercased()
    }

    private var fillColor: Color {
        color ?? SharedAvatarPalette.color(for: name)
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(fillColor))
            // Neutral separator ring for every avatar (drawn inside the bounds).
            .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 1.5))
            // The viewer's own items get a bold accent "story" ring around the
            // avatar so they stand out at a glance from other members' items.
            .overlay {
                if isCurrentUser {
                    Circle().stroke(Color.appAccent, lineWidth: 2.5)
                        .padding(-2.5)
                }
            }
            // Reserve room so the accent ring never clips against neighbouring
            // controls in the row.
            .padding(isCurrentUser ? 3 : 0)
    }
}

/// Deterministic name → color mapping for participant avatars. Uses a stable
/// djb2 hash (not `String.hashValue`, which is randomized per launch) so a
/// given name maps to the same color across app launches and devices.
enum SharedAvatarPalette {
    static let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .teal, .indigo, .red, .cyan, .mint
    ]

    /// Perceptual family for each palette color, parallel to `colors`. Colors in
    /// the same family look alike (e.g. red/pink/orange are all "warm"), so when
    /// two members share a first initial we make sure they land in *different*
    /// families — otherwise "James" in red and "John" in pink still read as the
    /// same avatar. Families: 0 = cool, 1 = green, 2 = warm, 3 = purple.
    private static let colorFamilies: [Int] = [
        0, // blue   → cool
        1, // green  → green
        2, // orange → warm
        3, // purple → purple
        2, // pink   → warm
        0, // teal   → cool
        0, // indigo → cool
        2, // red    → warm
        0, // cyan   → cool
        1  // mint   → green
    ]

    /// Normalized lookup key for a display name.
    static func key(for name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hashIndex(for key: String) -> Int {
        var hash: UInt64 = 5381
        for scalar in key.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return Int(hash % UInt64(colors.count))
    }

    /// Standalone deterministic color, used when no store-wide context exists.
    /// Same name → same color across launches and devices.
    static func color(for name: String) -> Color {
        colors[hashIndex(for: key(for: name))]
    }

    /// Stable color identity for an author. Prefers the account's userId so two
    /// *different* users who happen to share a display name still resolve to
    /// different identities (and, below, different colors). Falls back to the
    /// normalized name only for legacy data that never recorded an id.
    static func identityKey(id: String?, name: String) -> String {
        if let id = id, !id.isEmpty { return "id:\(id)" }
        return "name:\(key(for: name))"
    }

    /// Resolves the color identity for a reminder's author using the same
    /// attribution rules that draw the avatar, so the color computed when
    /// building the store-wide map matches the one looked up at render time.
    /// Returns the identity key plus the display name (used for the initial).
    static func authorIdentity(
        sharedFrom: String?,
        sharedFromId: String?,
        currentUserName: String?,
        currentUserId: String?
    ) -> (key: String, name: String)? {
        // Is the current user the author? Strictly ID-based when the author has
        // an id (so a same-named other account is not mistaken for the viewer,
        // and an unattributed copy is never claimed); name-based only for legacy
        // data without ids.
        let isMine: Bool = {
            if let sid = sharedFromId, !sid.isEmpty {
                guard let cid = currentUserId, !cid.isEmpty else { return false }
                return sid == cid
            }
            if let sf = sharedFrom, !sf.isEmpty, let cn = currentUserName, !cn.isEmpty {
                return sf.caseInsensitiveCompare(cn) == .orderedSame
            }
            return false
        }()

        if isMine {
            guard let name = currentUserName, !name.isEmpty else { return nil }
            return (identityKey(id: currentUserId, name: name), name)
        }
        guard let name = sharedFrom, !name.isEmpty else { return nil }
        return (identityKey(id: sharedFromId, name: name), name)
    }

    /// Builds a store-wide color assignment keyed by author identity so that two
    /// members sharing the same first initial get *visibly* different colors —
    /// not merely different palette entries, but different color families (so no
    /// red-vs-pink lookalikes). Each identity starts from its own deterministic
    /// hash color (keeping the "random per person" feel and a stable color for
    /// unique initials); only later members within a shared initial are nudged
    /// to an unused family. Identities are deduplicated and sorted first, so a
    /// given member set yields the same colors on every device.
    static func colorMap(for identities: [(key: String, name: String)]) -> [String: Color] {
        var seen = Set<String>()
        let distinct = identities
            .filter { seen.insert($0.key).inserted }
            .compactMap { entry -> (key: String, initial: Character)? in
                let normalized = key(for: entry.name)
                guard !normalized.isEmpty else { return nil }
                return (entry.key, normalized.first ?? "?")
            }
            .sorted { $0.key < $1.key }

        var result: [String: Color] = [:]
        // Per first-initial group, track the color families and exact indices
        // already handed out so same-initial members stay distinct.
        var usedFamilies: [Character: Set<Int>] = [:]
        var usedIndices: [Character: Set<Int>] = [:]

        for entry in distinct {
            let initial = entry.initial
            var families = usedFamilies[initial] ?? []
            var indices = usedIndices[initial] ?? []
            var index = hashIndex(for: entry.key)

            // If another member with this initial already uses this color's
            // family, probe forward for a color in an unused family. Fall back
            // to any unused index, then (groups larger than the palette) to the
            // hash color — an unavoidable repeat at that point.
            if families.contains(colorFamilies[index]) {
                var chosen: Int?
                for step in 1...colors.count {
                    let candidate = (index + step) % colors.count
                    if !families.contains(colorFamilies[candidate]),
                       !indices.contains(candidate) {
                        chosen = candidate
                        break
                    }
                }
                if chosen == nil {
                    for step in 1...colors.count {
                        let candidate = (index + step) % colors.count
                        if !indices.contains(candidate) {
                            chosen = candidate
                            break
                        }
                    }
                }
                if let chosen { index = chosen }
            }

            families.insert(colorFamilies[index])
            indices.insert(index)
            usedFamilies[initial] = families
            usedIndices[initial] = indices
            result[entry.key] = colors[index]
        }
        return result
    }

    /// Looks up an identity's color in a precomputed store-wide map, falling
    /// back to a deterministic hash of the identity key when it isn't present.
    static func color(forKey identityKey: String, in map: [String: Color]) -> Color {
        map[identityKey] ?? colors[hashIndex(for: identityKey)]
    }
}

