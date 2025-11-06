//
//  ReminderSummaryView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI

struct ReminderView: View {
    let store: Store

    //TODO: get the actual reminders for this ReminderView from Firestore
    @State private var reminders = [
        Reminder(userStoreId: "kor3a", title: "Coke", isDone: false),
        Reminder(userStoreId: "kor3a", title: "Eggs", isDone: false),
        Reminder(userStoreId: "kor3a", title: "Pancake", isDone: false)
    ]
    
    var body: some View {
        NavigationStack {
            listView
                .padding()
                .listStyle(.plain)
                .navigationTitle("\(store.name)")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        addButton
                    }
                }
        }
    }//:BODY
            
    // Extracted List view
    private var listView: some View {
        List {
            ForEach(reminders) { reminder in
                ReminderItemView(item: reminder)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                                reminders.remove(at: index)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
            
    // Extracted NavigationLink for Add button
    private var addButton: some View {
        NavigationLink(destination: AddReminderView()) {
            Image(systemName: "plus")
                .imageScale(.large)
        }
    }
    
}

#Preview {
    ReminderView(store: Store(id: "preview", name: "Trader Joe's", address: "6401 Haven Ave, Rancho Cucamonga, CA 91737"))
}
