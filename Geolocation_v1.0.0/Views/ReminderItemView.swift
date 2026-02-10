//
//  StoreReminderView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/14/24.
//

import SwiftUI

struct ReminderItemView: View {
    let item: Reminder
    var onPhotoTap: ((String) -> Void)?
    @StateObject private var viewModel = ReminderItemViewModel()

    // Get current user's name to determine if they created the reminder
    private var currentUserName: String? {
        UserSessionManager.shared.currentUser?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        sharedWith: item.sharedWith,
                        currentUserName: currentUserName
                    )
                }
            }

            // Photo thumbnails row
            if let photoURLs = item.photoURLs, !photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photoURLs, id: \.self) { urlString in
                            AsyncImage(url: URL(string: urlString)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipped()
                                        .cornerRadius(8)
                                case .failure:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        )
                                case .empty:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                        .overlay(ProgressView())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .onTapGesture {
                                onPhotoTap?(urlString)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shared Badge

struct SharedBadge: View {
    let sharedFrom: String?
    let sharedWith: [String]?
    let currentUserName: String?

    // Check if current user is the one who shared/created this reminder
    private var isCurrentUserTheSharer: Bool {
        guard let sharedFrom = sharedFrom, !sharedFrom.isEmpty,
              let currentUserName = currentUserName else {
            return false
        }
        return sharedFrom == currentUserName
    }

    // Determine if user is recipient (received from someone else)
    private var isRecipient: Bool {
        // If sharedFrom is set AND it's not the current user, they're a recipient
        if let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            return !isCurrentUserTheSharer
        }
        return false
    }

    private var iconName: String {
        // If user is a recipient (received from someone else), show down arrow
        // If user is the sender/creator, show up arrow
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
        // If current user created/shared this reminder
        if isCurrentUserTheSharer {
            if let sharedWith = sharedWith, !sharedWith.isEmpty {
                return "You shared with: \(sharedWith.joined(separator: ", "))"
            }
            return "You shared this reminder"
        }

        // If sharedFrom is set and it's someone else, user is a recipient
        if let sharedFrom = sharedFrom, !sharedFrom.isEmpty {
            if let sharedWith = sharedWith, !sharedWith.isEmpty {
                return "Shared by \(sharedFrom) with \(sharedWith.count) people"
            }
            return "Shared by \(sharedFrom)"
        }

        // No sharedFrom means user is the original sender (owner added it)
        if let sharedWith = sharedWith, !sharedWith.isEmpty {
            return "Shared with: \(sharedWith.joined(separator: ", "))"
        }

        return "Shared reminder"
    }
}

