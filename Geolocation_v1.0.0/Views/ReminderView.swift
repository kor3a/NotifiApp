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
    @State private var showingAddReminder = false
    @State private var reminderTitle: String = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading reminders...")
            } else if viewModel.reminders.isEmpty {
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
                            showingAddReminder = true
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
                            .swipeActions(edge: .trailing) {
                                if userStoreItem.permission != .view {
                                    Button(role: .destructive) {
                                        viewModel.deleteReminder(reminder)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onTapGesture {
                                if userStoreItem.permission != .view {
                                    viewModel.toggleReminder(reminder)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    Color.backgroundGradient(for: colorScheme)
                        .ignoresSafeArea()
                )
            }
        }
        .navigationTitle(userStoreItem.store.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if userStoreItem.permission != .view {
                    Button(action: {
                        showingAddReminder = true
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
        .animation(.none)
        .alert("Add a New Item", isPresented: $showingAddReminder) {
            TextField("What do you need?", text: $reminderTitle)
                .textInputAutocapitalization(.sentences)

            Button("Add") {
                addReminder()
            }
            .disabled(reminderTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            

            Button("Cancel", role: .cancel) {
                reminderTitle = ""
            }
        } message: {
            Text("Enter the item name you wish to add.")
        }
        .onAppear {
            viewModel.fetchReminders(for: userStoreItem.reminderStoreId)
        }
    }

    private func addReminder() {
        let title = reminderTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        viewModel.addReminder(userStoreId: userStoreItem.reminderStoreId, title: title)
        reminderTitle = ""
    }
}

#Preview {
    ReminderView(userStoreItem: UserStoreItem(
        id: "preview_user_store",
        store: Store(id: "preview", name: "Trader Joe's", address: "6401 Haven Ave, Rancho Cucamonga, CA 91737"),
        permission: .owner,
        sharedStoreGroupId: nil,
        sourceUserStoreId: nil
    ))
}
