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

            // Show "Shared" badge if the reminder was shared from another user
            if item.isShared == true {
                SharedBadge(sharedFrom: item.sharedFrom)
            }
        }
    }
}

// MARK: - Shared Badge

struct SharedBadge: View {
    let sharedFrom: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption2)
            Text("Shared")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.appAccent.opacity(0.9))
        )
        .help(sharedFrom != nil ? "Shared by \(sharedFrom!)" : "Shared reminder")
    }
}

