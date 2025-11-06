//
//  AddReminderView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 5/31/25.
//

import SwiftUI

struct AddReminderView: View {
    @Environment(\.dismiss) var dismiss
    let userStoreId: String
    @ObservedObject var viewModel: ReminderViewModel
    
    @State private var reminderTitle: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Reminder Details")) {
                    TextField("What do you need?", text: $reminderTitle)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section {
                    Button(action: {
                        addReminder()
                    }) {
                        Text("Add Reminder")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .disabled(reminderTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addReminder() {
        let title = reminderTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        viewModel.addReminder(userStoreId: userStoreId, title: title)
        dismiss()
    }
}

#Preview {
    AddReminderView(userStoreId: "preview_user_store", viewModel: ReminderViewModel())
}
