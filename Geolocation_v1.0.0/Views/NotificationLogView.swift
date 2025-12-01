//
//  NotificationLogView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

struct NotificationLogView: View {
    @ObservedObject private var logStore = NotificationLogStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if logStore.entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Notifications Yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Notification alarms will appear here when you get close to stores with reminders.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(logStore.entries) { entry in
                            NotificationLogRowView(entry: entry)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notification Log")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !logStore.entries.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            logStore.clearAll()
                        } label: {
                            Text("Clear All")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
}

struct NotificationLogRowView: View {
    let entry: NotificationLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.storeName)
                        .font(.headline)

                    Text(reminderText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(entry.timeAgoString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var reminderText: String {
        if entry.reminderCount == 1 {
            return "1 reminder"
        } else {
            return "\(entry.reminderCount) reminders"
        }
    }
}

#Preview {
    NotificationLogView()
}
