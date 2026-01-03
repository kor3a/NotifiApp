//
//  StoreReminderView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import SwiftUI

struct ReminderItemView: View {
    let item: Reminder
    @StateObject private var viewModel = ReminderItemViewModel()

    var body: some View {
        HStack {
            Image(systemName: item.isDone ? "checkmark.square" : "square")

            Text(item.title)
                .font(.headline)
                .bold()

            Spacer()

            // Show "Shared" badge if the reminder is shared
            if item.isShared == true {
                SharedBadge(
                    sharedFrom: item.sharedFrom,
                    sharedWith: item.sharedWith
                )
            }
        }
    }
}

// MARK: - Shared Badge

struct SharedBadge: View {
    let sharedFrom: String?
    let sharedWith: [String]?

    // Check sharedFrom FIRST to determine if user is recipient or sender
    private var isRecipient: Bool {
        sharedFrom != nil && !sharedFrom!.isEmpty
    }

    private var iconName: String {
        // If sharedFrom is set, user is a recipient (received from someone)
        // If sharedFrom is NOT set, user is the sender (shared with others)
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
        // Check sharedFrom FIRST - if set, user is a recipient
        if let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            if let sharedWith = sharedWith, !sharedWith.isEmpty {
                return "Shared by \(sharedFrom) with \(sharedWith.count) people"
            }
            return "Shared by \(sharedFrom)"
        } else if let sharedWith = sharedWith, !sharedWith.isEmpty {
            // No sharedFrom means user is the sender
            return "Shared with: \(sharedWith.joined(separator: ", "))"
        }
        return "Shared reminder"
    }
}

