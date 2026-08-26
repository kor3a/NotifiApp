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
    /// avatar's color is resolved against every member of the store.
    var avatarColorMap: [String: Color] = [:]
    /// userId → display name for store members, forwarded to the shared badge so
    /// a participant's initial can be recovered from their id when the reminder
    /// carries no matching name.
    var memberNames: [String: String] = [:]
    @StateObject private var viewModel = ReminderItemViewModel()
    @State private var editText: String = ""
    @State private var editQuantityText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isQuantityFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    // Get current user's info to determine if they created the reminder
    private var currentUserName: String? {
        UserSessionManager.shared.currentUser?.name
    }

    private var currentUserId: String? {
        UserSessionManager.shared.currentUser?.userId
    }

    /// Reports the checkbox's global frame so the AutoDeleteSwipeRail can
    /// hit-test rows during a rail drag.
    ///
    /// Rendered only when a handler is actually attached (i.e. auto-delete is
    /// on). `geo.frame(in: .global)` changes on every displayed frame while the
    /// list scrolls, so an always-installed GeometryReader made every visible
    /// row do coordinate-space work — and fire a callback — at up to 120Hz for
    /// a feature that is off by default.
    @ViewBuilder
    private var checkboxFrameReporter: some View {
        if let onCheckboxFrameChanged = onCheckboxFrameChanged {
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        onCheckboxFrameChanged(geo.frame(in: .global))
                    }
                    .onChange(of: geo.frame(in: .global)) { _, frame in
                        onCheckboxFrameChanged(frame)
                    }
            }
        }
    }

    /// Rust for out of stock, the soft ink for a checked item, full ink for one
    /// still waiting — so the three states read at a glance without the system
    /// red the rest of the screen has left behind.
    private var checkboxColor: Color {
        if item.isOutOfStock == true {
            return OrganicPalette.rust(colorScheme)
        }
        return item.isDone
            ? OrganicPalette.inkSoft(colorScheme)
            : OrganicPalette.ink(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if autoDeleteEnabled {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(OrganicPalette.rust(colorScheme).opacity(0.8))
                        .frame(width: 20, height: 30)
                        // Visual affordance only. The AutoDeleteSwipeRail overlay
                        // in ReminderView owns the gesture at the ZStack level so
                        // it never competes with the List's scroll recognizer.
                }

                Image(systemName: item.isOutOfStock == true ? "xmark.square" : (item.isDone ? "checkmark.square" : "square"))
                    .font(.system(size: 24))
                    .foregroundColor(checkboxColor)
                    // Animate the symbol swap and add a little pop when the
                    // checkbox is checked/unchecked or toggled out of stock.
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.isDone)
                    .symbolEffect(.bounce, value: item.isOutOfStock)
                    // Slightly larger than the 24pt symbol so taps just outside
                    // the icon still register, without padding out the row.
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .background(checkboxFrameReporter)
                    .onTapGesture {
                        onCheckboxTap?()
                    }

                if isEditing {
                    TextField("Reminder", text: $editText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
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
                        .font(.system(size: 17, weight: .semibold))
                        .strikethrough(item.isDone, color: OrganicPalette.inkSoft(colorScheme))
                        .foregroundColor(
                            item.isDone
                                ? OrganicPalette.inkSoft(colorScheme)
                                : OrganicPalette.ink(colorScheme)
                        )
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        TextField("", text: $editQuantityText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(OrganicPalette.field(colorScheme)))
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
                        lastEditedBy: item.lastEditedBy,
                        lastEditedById: item.lastEditedById,
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
                        .font(.system(size: 15))
                        .foregroundColor(
                            isFavorited
                                ? OrganicPalette.terracotta(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme).opacity(0.7)
                        )
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
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
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
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(OrganicPalette.field(colorScheme))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                        )
                                case .empty:
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(OrganicPalette.field(colorScheme))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            ProgressView()
                                                .tint(OrganicPalette.terracotta(colorScheme))
                                        )
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
    /// Name and id of the member who last edited this reminder's content, when
    /// anyone has. The avatar names them instead of the author — see
    /// `attributedParticipant`.
    var lastEditedBy: String? = nil
    var lastEditedById: String? = nil
    let sharedWith: [String]?
    let currentUserName: String?
    let currentUserId: String?
    /// Store-wide deterministic color assignment keyed by participant identity,
    /// so members who share a first initial never share a color. Empty when no
    /// store-wide context is available (falls back to the standalone palette).
    var avatarColorMap: [String: Color] = [:]
    /// userId → display name for the store's members, used to recover a
    /// participant's name (and therefore initial) when a reminder carries their
    /// id but no name.
    var memberNames: [String: String] = [:]

    @Environment(\.colorScheme) private var colorScheme

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

    /// The person this avatar stands for — the last editor when there is one,
    /// the author otherwise. See `SharedAvatarPalette.attributedParticipant`.
    private var attributedParticipant: (id: String?, name: String?) {
        SharedAvatarPalette.attributedParticipant(
            sharedFrom: sharedFrom,
            sharedFromId: sharedFromId,
            lastEditedBy: lastEditedBy,
            lastEditedById: lastEditedById,
            memberNames: memberNames
        )
    }

    /// Whether the avatar resolves to the current user — the signal for styling
    /// the badge as "yours." Strictly ID-based: the row is the viewer's only on
    /// an exact id match. Items that carry no id are NOT claimed (name is used
    /// only for truly legacy data that never recorded ids). This deliberately
    /// avoids the earlier "author-less ⇒ mine" default, which mis-marked another
    /// user's items as the viewer's whenever their copies arrived without
    /// attribution (e.g. from a stale cache or an unsynced field).
    private var isAttributedToCurrentUser: Bool {
        let participant = attributedParticipant
        if let id = participant.id, !id.isEmpty {
            guard let currentUserId = currentUserId, !currentUserId.isEmpty else {
                return false
            }
            return id == currentUserId
        }
        // Legacy item with no recorded id: fall back to a name match.
        if let name = participant.name, !name.isEmpty,
           let currentUserName = currentUserName, !currentUserName.isEmpty {
            return name.caseInsensitiveCompare(currentUserName) == .orderedSame
        }
        // Nobody recorded — unknown, so never claim it as the current user's.
        return false
    }

    /// The name whose initial the avatar draws.
    ///
    /// For the current user we prefer the live session name so a name change
    /// reflects immediately; for others we use the resolved name. Critically,
    /// this never falls back to the current user's name for a row that isn't
    /// theirs — an unknown participant yields nil (a neutral avatar), not the
    /// viewer's initial.
    private var attributedName: String? {
        if isAttributedToCurrentUser,
           let currentUserName = currentUserName, !currentUserName.isEmpty {
            return currentUserName
        }
        return attributedParticipant.name
    }

    /// Stable color identity for the attributed participant (userId-based), so
    /// the avatar color is distinct per account even when two members share a
    /// name. Uses the resolved name so the initial matches even when only an id
    /// was recorded on the reminder.
    private var avatarIdentity: (key: String, name: String)? {
        SharedAvatarPalette.participantIdentity(
            name: isAttributedToCurrentUser ? currentUserName : attributedParticipant.name,
            id: attributedParticipant.id,
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
                    isCurrentUser: isAttributedToCurrentUser
                )
            } else if let name = attributedName,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                InitialAvatar(
                    name: name,
                    isCurrentUser: isAttributedToCurrentUser
                )
            } else {
                // Shared but nobody known — keep a visible indicator.
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(OrganicPalette.terracotta(colorScheme)))
                    .overlay(Circle().stroke(OrganicPalette.surface(colorScheme), lineWidth: 1.5))
            }
        }
        .help(tooltipText)
    }

    /// Whether the last edit was made by the person viewing the row.
    private var isEditedByCurrentUser: Bool {
        guard let editorId = lastEditedById, !editorId.isEmpty,
              let currentUserId = currentUserId, !currentUserId.isEmpty else {
            return false
        }
        return editorId == currentUserId
    }

    private var tooltipText: String {
        // Once someone has edited the item the avatar shows them rather than the
        // author, so the tooltip has to name them — otherwise the initial and
        // the "Shared by …" text disagree.
        guard let editor = SharedAvatarPalette.displayName(
            id: lastEditedById,
            name: lastEditedBy,
            in: memberNames
        ) else {
            return sharingTooltip
        }
        let who = isEditedByCurrentUser ? "you" : editor
        return "\(sharingTooltip) · Last edited by \(who)"
    }

    /// Who shared this reminder with whom, independent of who last edited it.
    private var sharingTooltip: String {
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

    @Environment(\.colorScheme) private var colorScheme

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? "?").uppercased()
    }

    private var fillColor: Color {
        color ?? SharedAvatarPalette.color(for: name)
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.5, weight: .bold, design: .serif))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(fillColor))
            // Separator ring in the card's own paper, so the avatar reads as
            // punched out of the row rather than outlined against it.
            .overlay(Circle().strokeBorder(OrganicPalette.surface(colorScheme), lineWidth: 1.5))
            // The viewer's own items get a bold accent "story" ring around the
            // avatar so they stand out at a glance from other members' items.
            .overlay {
                if isCurrentUser {
                    Circle().stroke(OrganicPalette.terracotta(colorScheme), lineWidth: 2.5)
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
    /// Ten muted, earthy fills rather than the system's saturated set — these
    /// avatars sit on paper cards, and a full-strength `.cyan` next to a
    /// terracotta badge reads as a different app. Kept in the same order as
    /// `colorFamilies` below, which the collision solver indexes into.
    static let colors: [Color] = [
        Color(red: 0.35, green: 0.47, blue: 0.60), // dusty blue
        Color(red: 0.40, green: 0.51, blue: 0.33), // olive
        Color(red: 0.76, green: 0.42, blue: 0.21), // terracotta
        Color(red: 0.47, green: 0.36, blue: 0.53), // plum
        Color(red: 0.72, green: 0.44, blue: 0.43), // clay rose
        Color(red: 0.26, green: 0.49, blue: 0.48), // deep teal
        Color(red: 0.35, green: 0.36, blue: 0.55), // slate indigo
        Color(red: 0.66, green: 0.26, blue: 0.20), // brick
        Color(red: 0.38, green: 0.54, blue: 0.62), // steel blue
        Color(red: 0.47, green: 0.60, blue: 0.44), // moss
    ]

    /// Perceptual family for each palette color, parallel to `colors`. Colors in
    /// the same family look alike (e.g. red/pink/orange are all "warm"), so when
    /// two members share a first initial we make sure they land in *different*
    /// families — otherwise "James" in red and "John" in pink still read as the
    /// same avatar. Families: 0 = cool, 1 = green, 2 = warm, 3 = purple.
    private static let colorFamilies: [Int] = [
        0, // dusty blue   → cool
        1, // olive        → green
        2, // terracotta   → warm
        3, // plum         → purple
        2, // clay rose    → warm
        0, // deep teal    → cool
        0, // slate indigo → cool
        2, // brick        → warm
        0, // steel blue   → cool
        1  // moss         → green
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

    /// Stable color identity for a participant. Prefers the account's userId so two
    /// *different* users who happen to share a display name still resolve to
    /// different identities (and, below, different colors). Falls back to the
    /// normalized name only for legacy data that never recorded an id.
    static func identityKey(id: String?, name: String) -> String {
        if let id = id, !id.isEmpty { return "id:\(id)" }
        return "name:\(key(for: name))"
    }

    /// Best-known display name for a participant recorded as an (id, name) pair.
    /// Prefers the name stamped on the reminder; when that's missing, recovers it
    /// from the store member map so an id alone still yields an initial.
    static func displayName(id: String?, name: String?, in memberNames: [String: String]) -> String? {
        if let name = name, !name.isEmpty {
            return name
        }
        if let id = id, !id.isEmpty,
           let recovered = memberNames[id], !recovered.isEmpty {
            return recovered
        }
        return nil
    }

    /// The participant a reminder's avatar stands for: whoever last edited the
    /// item when someone has, and its author otherwise. So when user A edits an
    /// item user B created, the row switches to A's initial — for everyone, since
    /// the edit stamp is written to every linked copy of the shared reminder.
    ///
    /// Falls back to the author whenever the editor can't be named (a stamp that
    /// arrived without a name and whose id isn't in the member map), so an edit
    /// never blanks a row that could still show its author.
    static func attributedParticipant(
        sharedFrom: String?,
        sharedFromId: String?,
        lastEditedBy: String?,
        lastEditedById: String?,
        memberNames: [String: String] = [:]
    ) -> (id: String?, name: String?) {
        if let editorName = displayName(id: lastEditedById, name: lastEditedBy, in: memberNames) {
            return (lastEditedById, editorName)
        }
        return (sharedFromId, displayName(id: sharedFromId, name: sharedFrom, in: memberNames))
    }

    /// Resolves the color identity for the participant a reminder's avatar names
    /// — its last editor when it has one, its author otherwise — using the same
    /// attribution rules that draw the avatar, so the color computed when
    /// building the store-wide map matches the one looked up at render time.
    /// Returns the identity key plus the display name (used for the initial).
    static func participantIdentity(
        name participantName: String?,
        id participantId: String?,
        currentUserName: String?,
        currentUserId: String?
    ) -> (key: String, name: String)? {
        // Is the current user this participant? Strictly ID-based when they have
        // an id (so a same-named other account is not mistaken for the viewer,
        // and an unattributed copy is never claimed); name-based only for legacy
        // data without ids.
        let isMine: Bool = {
            if let pid = participantId, !pid.isEmpty {
                guard let cid = currentUserId, !cid.isEmpty else { return false }
                return pid == cid
            }
            if let pn = participantName, !pn.isEmpty, let cn = currentUserName, !cn.isEmpty {
                return pn.caseInsensitiveCompare(cn) == .orderedSame
            }
            return false
        }()

        if isMine {
            guard let name = currentUserName, !name.isEmpty else { return nil }
            return (identityKey(id: currentUserId, name: name), name)
        }
        guard let name = participantName, !name.isEmpty else { return nil }
        return (identityKey(id: participantId, name: name), name)
    }

    /// Builds a store-wide color assignment keyed by participant identity so two
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

