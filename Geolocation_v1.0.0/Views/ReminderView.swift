//
//  ReminderSummaryView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI

struct ReminderView: View {
    let userStoreItem: UserStoreItem
    @StateObject private var viewModel = ReminderViewModel()
    @State private var isAddingNewReminder = false
    @State private var newReminderText = ""
    @FocusState private var isNewReminderFocused: Bool
    @AppStorage("autoDeleteReminders") private var autoDeleteEnabled = false
    @State private var fadingReminderIds: Set<String> = []
    @State private var reminderToShare: Reminder?
    @State private var reminderToDelete: Reminder?
    @State private var showingSharedInfo: Reminder?
    @State private var reminderForPhoto: Reminder?
    @State private var selectedImage: UIImage?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading reminders...")
            } else if viewModel.reminders.isEmpty && !isAddingNewReminder {
                VStack(spacing: 20) {
                    Image(systemName: "list.bullet.clipboard")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.gray)

                    Text("No Reminders")
                        .font(.title2)
                        .bold()

                    Text("Add reminders for this store")
                        .foregroundStyle(.gray)

                    if userStoreItem.permission != .view {
                        Button {
                            isAddingNewReminder = true
                        } label: {
                            Label("Add Reminder", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal)
                    } else {
                        Text("View only - cannot add reminders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.reminders) { reminder in
                            ReminderItemView(item: reminder)
                                .contentShape(Rectangle())
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    Color.cardBorder(for: colorScheme),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
                                        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5), radius: 2, x: 0, y: -2)
                                        .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                                .opacity(fadingReminderIds.contains(reminder.id) ? 0 : 1)
                                .scaleEffect(fadingReminderIds.contains(reminder.id) ? 0.8 : 1.0)
                                .animation(.easeOut(duration: 0.5), value: fadingReminderIds)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // Delete button (rightmost)
                                    if userStoreItem.permission != .view {
                                        Button(role: .destructive) {
                                            // If shared, show confirmation dialog
                                            if reminder.isShared == true && reminder.sharedReminderId != nil {
                                                reminderToDelete = reminder
                                            } else {
                                                viewModel.deleteReminder(reminder)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }

                                    // Share button
                                    Button {
                                        reminderToShare = reminder
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .tint(.blue)

                                    // Info button (only if reminder is shared)
                                    if reminder.isShared == true {
                                        Button {
                                            showingSharedInfo = reminder
                                        } label: {
                                            Image(systemName: "person.2.fill")
                                        }
                                        .tint(.appAccent)
                                    }
                                }
                                .contextMenu {
                                    if userStoreItem.permission != .view {
                                        Button {
                                            reminderForPhoto = reminder
                                        } label: {
                                            Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                                        }
                                    }
                                }
                                .onTapGesture {
                                    if userStoreItem.permission != .view {
                                        handleReminderTap(reminder)
                                    }
                                }
                        }

                        // Inline add reminder row
                        if userStoreItem.permission != .view {
                            if isAddingNewReminder {
                                HStack {
                                    Image(systemName: "square")
                                        .foregroundStyle(.gray.opacity(0.4))
                                    TextField("What do you need?", text: $newReminderText)
                                        .font(.headline)
                                        .focused($isNewReminderFocused)
                                        .onSubmit {
                                            submitNewReminder()
                                        }
                                        .textInputAutocapitalization(.sentences)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    Color.cardBorder(for: colorScheme),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
                                        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5), radius: 2, x: 0, y: -2)
                                        .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                                .id("inlineAddRow")
                            } else {
                                Button {
                                    isAddingNewReminder = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus")
                                            .foregroundStyle(.gray)
                                        Text("Add item")
                                            .font(.headline)
                                            .foregroundStyle(.gray)
                                        Spacer()
                                    }
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial.opacity(0.5))
                                        .padding(.vertical, 4)
                                )
                                .listRowSeparator(.hidden)
                                .id("inlineAddRow")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(
                        Color.backgroundGradient(for: colorScheme)
                            .ignoresSafeArea()
                    )
                    .onChange(of: isAddingNewReminder) { _, newValue in
                        if newValue {
                            withAnimation {
                                proxy.scrollTo("inlineAddRow", anchor: .bottom)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isNewReminderFocused = true
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(userStoreItem.store.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if userStoreItem.permission != .view {
                    Toggle(isOn: $autoDeleteEnabled) {
                        Label("Auto-delete", systemImage: autoDeleteEnabled ? "trash.fill" : "trash")
                    }
                    .toggleStyle(.button)
                    .labelStyle(.iconOnly)
                    .tint(autoDeleteEnabled ? .red : .gray)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if userStoreItem.permission != .view {
                    Button(action: {
                        isAddingNewReminder = true
                    }) {
                        Image(systemName: "plus")
                            .frame(width: 22, height: 22)
                    }
                    .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
            }
        }
        .onAppear {
            viewModel.fetchReminders(for: userStoreItem.reminderStoreId, sharedFromName: userStoreItem.sharedFromName)
        }
        .onChange(of: autoDeleteEnabled) { oldValue, newValue in
            // When auto-delete is turned ON, clean up already-done reminders
            if newValue && !oldValue {
                deleteCompletedReminders()
            }
        }
        .onChange(of: isNewReminderFocused) { _, focused in
            if !focused && isAddingNewReminder {
                let title = newReminderText.trimmingCharacters(in: .whitespaces)
                if title.isEmpty {
                    isAddingNewReminder = false
                }
            }
        }
        .sheet(item: $reminderToShare) { reminder in
            ShareReminderView(reminder: reminder, store: userStoreItem.store)
        }
        .sheet(item: $reminderForPhoto) { reminder in
            ImagePicker(selectedImage: $selectedImage) { image in
                viewModel.uploadPhoto(for: reminder, image: image)
            }
        }
        .alert("Delete Shared Reminder", isPresented: .init(
            get: { reminderToDelete != nil },
            set: { if !$0 { reminderToDelete = nil } }
        )) {
            Button("Delete for Everyone", role: .destructive) {
                if let reminder = reminderToDelete {
                    viewModel.deleteReminder(reminder)
                    reminderToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                reminderToDelete = nil
            }
        } message: {
            if let reminder = reminderToDelete {
                if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                    Text("This reminder is shared with \(sharedWith.joined(separator: ", ")). Deleting it will remove it for everyone.")
                } else if let sharedFrom = reminder.sharedFrom {
                    Text("This reminder was shared by \(sharedFrom). Deleting it will remove it for everyone.")
                } else {
                    Text("This reminder is shared. Deleting it will remove it for everyone.")
                }
            }
        }
        .alert("Shared Reminder", isPresented: .init(
            get: { showingSharedInfo != nil },
            set: { if !$0 { showingSharedInfo = nil } }
        )) {
            Button("OK", role: .cancel) {
                showingSharedInfo = nil
            }
        } message: {
            if let reminder = showingSharedInfo {
                let currentUserName = UserSessionManager.shared.currentUser?.name
                let isCurrentUserTheSharer = reminder.sharedFrom != nil &&
                    !reminder.sharedFrom!.isEmpty &&
                    reminder.sharedFrom == currentUserName

                if isCurrentUserTheSharer {
                    // Current user created/shared this reminder
                    if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                        Text("You shared this reminder with:\n\(sharedWith.joined(separator: "\n"))\n\nChanges sync automatically.")
                    } else {
                        Text("You shared this reminder.\n\nChanges sync automatically.")
                    }
                } else if let sharedFrom = reminder.sharedFrom, !sharedFrom.isEmpty {
                    // Someone else shared this reminder with the user
                    if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                        Text("Shared by: \(sharedFrom)\nAlso shared with: \(sharedWith.filter { $0 != sharedFrom }.joined(separator: ", "))\n\nChanges sync automatically.")
                    } else {
                        Text("Shared by: \(sharedFrom)\n\nChanges sync automatically.")
                    }
                } else if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                    // No sharedFrom means user is the original owner/sender
                    Text("You shared this reminder with:\n\(sharedWith.joined(separator: "\n"))\n\nChanges sync automatically.")
                } else {
                    Text("This reminder is synced across users.")
                }
            }
        }
    }

    private func submitNewReminder() {
        let title = newReminderText.trimmingCharacters(in: .whitespaces)
        if title.isEmpty {
            // Nothing entered - stop adding
            isAddingNewReminder = false
            newReminderText = ""
            return
        }

        viewModel.addReminder(
            userStoreId: userStoreItem.reminderStoreId,
            title: title,
            sharedWith: userStoreItem.sharedWith,
            sharedFromName: userStoreItem.sharedFromName,
            currentUserName: UserSessionManager.shared.currentUser?.name
        )

        // Clear text and keep focus for next reminder
        newReminderText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNewReminderFocused = true
        }
    }

    private func handleReminderTap(_ reminder: Reminder) {
        // Check if we're marking as done and auto-delete is enabled
        let willMarkAsDone = !reminder.isDone

        if willMarkAsDone && autoDeleteEnabled {
            // Add to fading set for animation
            fadingReminderIds.insert(reminder.id)

            // Delay deletion to show fade animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.deleteReminder(reminder)
                fadingReminderIds.remove(reminder.id)
            }
        } else {
            // Normal toggle behavior
            viewModel.toggleReminder(reminder)
        }
    }

    private func deleteCompletedReminders() {
        // Find all reminders that are already marked as done
        let completedReminders = viewModel.reminders.filter { $0.isDone }

        // Stagger the animations for a cascading effect
        for (index, reminder) in completedReminders.enumerated() {
            let delay = Double(index) * 0.1 // 100ms between each animation

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Start fade animation
                fadingReminderIds.insert(reminder.id)

                // Delete after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.deleteReminder(reminder)
                    fadingReminderIds.remove(reminder.id)
                }
            }
        }
    }
}

#Preview {
    ReminderView(userStoreItem: UserStoreItem(
        id: "preview_user_store",
        store: Store(name: "Trader Joe's"),
        permission: .owner,
        sharedStoreGroupId: nil,
        sourceUserStoreId: nil,
        sharedFromName: nil,
        sharedWith: nil,
        notificationsEnabled: true
    ))
}
