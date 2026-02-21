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

    // Get current user's name to determine if they created the reminder
    private var currentUserName: String? {
        UserSessionManager.shared.currentUser?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if autoDeleteEnabled {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(width: 20, height: 30)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                                .onChanged { value in
                                    onDragChanged?(value.location)
                                }
                                .onEnded { _ in
                                    onDragEnded?()
                                }
                        )
                }

                Image(systemName: item.isOutOfStock == true ? "xmark.square" : (item.isDone ? "checkmark.square" : "square"))
                    .foregroundStyle(item.isOutOfStock == true ? .red : .primary)
                    .contentShape(Rectangle())
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                onCheckboxFrameChanged?(geo.frame(in: .global))
                            }
                        }
                    )
                    .onTapGesture {
                        onCheckboxTap?()
                    }

                if isEditing {
                    TextField("Reminder", text: $editText)
                        .font(.headline)
                        .bold()
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
                        .font(.headline)
                        .bold()
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
                        sharedWith: item.sharedWith,
                        currentUserName: currentUserName
                    )
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
            if let onAddToFavorites = onAddToFavorites {
                Button {
                    onAddToFavorites()
                } label: {
                    Label(
                        isFavorited ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: isFavorited ? "star.slash" : "star"
                    )
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
    let sharedWith: [String]?
    let currentUserName: String?

    // Check if current user is the one who shared/created this reminder
    private var isCurrentUserTheSharer: Bool {
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

    private var iconName: String {
        // If user is a recipient (received from someone else), show down arrow
        // If user is the sender/creator, show up arrow
        if isRecipient {
            return "arrow.down.backward"
        } else {
            return "arrow.up.forward"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption2)
            Image(systemName: iconName)
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.appAccent.opacity(0.9))
        )
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
            if let sharedWith = sharedWith, !sharedWith.isEmpty {
                return "Shared by \(sharedFrom) with \(sharedWith.count) people"
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

