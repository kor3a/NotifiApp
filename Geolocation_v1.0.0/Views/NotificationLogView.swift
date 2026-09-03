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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            Group {
                if logStore.entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(OrganicPalette.inkMuted(colorScheme))
                        Text("No Notifications Yet")
                            .font(.title2)
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                        Text("Notification alarms will appear here when you get close to stores with reminders.")
                            .font(.subheadline)
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
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
                                .foregroundColor(OrganicPalette.rust(colorScheme))
                        }
                    }
                }
            }
        }
    }
}

struct NotificationLogRowView: View {
    let entry: NotificationLogEntry

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // The warm accent: a log entry is a reminder that fired, which
                // is exactly what the palette holds that tone back for.
                Image(systemName: "bell.fill")
                    .foregroundColor(OrganicPalette.highlight(colorScheme))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.storeName)
                        .font(.headline)
                        .foregroundColor(OrganicPalette.ink(colorScheme))

                    Text(reminderText)
                        .font(.subheadline)
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                }

                Spacer()

                Text(entry.timeAgoString)
                    .font(.caption)
                    .foregroundColor(OrganicPalette.inkMuted(colorScheme))
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
