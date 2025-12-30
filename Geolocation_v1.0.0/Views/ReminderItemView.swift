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

    private var badgeText: String {
        if let sharedWith = sharedWith, !sharedWith.isEmpty {
            // This user is the sender - show who they shared with
            if sharedWith.count == 1 {
                return sharedWith[0]
            } else {
                return "\(sharedWith.count) people"
            }
        } else if let sharedFrom = sharedFrom {
            // This user is the receiver - show who shared it
            return sharedFrom
        }
        return "Shared"
    }

    private var iconName: String {
        if sharedWith != nil && !(sharedWith?.isEmpty ?? true) {
            return "arrow.up.forward"
        } else {
            return "arrow.down.backward"
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
        if let sharedWith = sharedWith, !sharedWith.isEmpty {
            return "Shared with: \(sharedWith.joined(separator: ", "))"
        } else if let sharedFrom = sharedFrom {
            return "Shared by \(sharedFrom)"
        }
        return "Shared reminder"
    }
}

