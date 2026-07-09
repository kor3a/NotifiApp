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
                        currentUserId: currentUserId
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

    // Determine if user is recipient (received from someone else)
    private var isRecipient: Bool {
        // If sharedFrom is set AND it's not the current user, they're a recipient
        if let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            return !isCurrentUserTheSharer
        }
        return false
    }

    /// The other people involved in this share (excluding the current user),
    /// shown as small initial avatars. A recipient sees the person who shared
    /// it; an owner/sharer sees whoever it's shared with.
    private var participantNames: [String] {
        var names: [String] = []

        // Recipient perspective: lead with the person who shared it.
        if isRecipient, let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            names.append(sharedFrom)
        }

        // Everyone this reminder is shared with, minus the current user and
        // anyone already added (case-insensitive de-dupe).
        let others = (sharedWith ?? []).filter {
            $0.lowercased() != (currentUserName ?? "").lowercased()
        }
        for name in others where !names.contains(where: { $0.lowercased() == name.lowercased() }) {
            names.append(name)
        }

        // Fallback so a shared reminder always shows at least one avatar.
        if names.isEmpty, let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            names.append(sharedFrom)
        }
        return names
    }

    var body: some View {
        let names = participantNames
        let shown = Array(names.prefix(3))
        let overflow = names.count - shown.count

        return HStack(spacing: -6) {
            if shown.isEmpty {
                // Shared but no known participant name — keep a visible indicator.
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.appAccent))
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { index, name in
                InitialAvatar(name: name)
                    .zIndex(Double(shown.count - index))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.secondary))
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

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? "?").uppercased()
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(SharedAvatarPalette.color(for: name)))
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
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

    static func color(for name: String) -> Color {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var hash: UInt64 = 5381
        for scalar in key.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return colors[Int(hash % UInt64(colors.count))]
    }
}

