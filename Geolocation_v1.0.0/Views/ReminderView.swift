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

                    Button {
                        showingAddReminder = true
                    } label: {
                        Label("Add Reminder", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                }
                .padding()
            } else {
                List {
                    ForEach(viewModel.reminders) { reminder in
                        ReminderItemView(item: reminder)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteReminder(reminder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                viewModel.toggleReminder(reminder)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(userStoreItem.store.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddReminder = true
                }) {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .frame(width: 44, height: 44)
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
            viewModel.fetchReminders(for: userStoreItem.id)
        }
    }

    private func addReminder() {
        let title = reminderTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        viewModel.addReminder(userStoreId: userStoreItem.id, title: title)
        reminderTitle = ""
    }
}

#Preview {
    ReminderView(userStoreItem: UserStoreItem(
        id: "preview_user_store",
        store: Store(id: "preview", name: "Trader Joe's", address: "6401 Haven Ave, Rancho Cucamonga, CA 91737")
    ))
}
