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

    var body: some View {
        Group {
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

                    Button(action: {
                        showingAddReminder = true
                    }) {
                        Label("Add Reminder", systemImage: "plus")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
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
        .navigationBarTitleDisplayMode(.large)
        .animation(.none, value: viewModel.isLoading)
        .animation(.none, value: viewModel.reminders.count)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddReminder = true
                }) {
                    Image(systemName: "plus")
                }
                .fixedSize()
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderView(userStoreId: userStoreItem.id, viewModel: viewModel)
        }
        .onAppear {
            viewModel.fetchReminders(for: userStoreItem.id)
        }
    }
}

#Preview {
    ReminderView(userStoreItem: UserStoreItem(
        id: "preview_user_store",
        store: Store(id: "preview", name: "Trader Joe's", address: "6401 Haven Ave, Rancho Cucamonga, CA 91737")
    ))
}
