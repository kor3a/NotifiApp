//
//  WatchStoreListView.swift
//  AllimWatch Watch App
//
//  The first screen: the user's stores, each with the number of items still to
//  pick up, tapping through to that store's list.
//

import SwiftUI

struct WatchStoreListView: View {

    @EnvironmentObject private var store: WatchDataStore

    var body: some View {
        NavigationStack {
            Group {
                if !store.isSignedIn {
                    WatchMessageView(
                        symbol: "person.crop.circle.badge.exclamationmark",
                        title: "Sign in on iPhone",
                        message: "Open Allim on your iPhone to see your stores here."
                    )
                } else if store.stores.isEmpty {
                    if store.isLoadingStores {
                        ProgressView()
                    } else if store.isPhoneReachable {
                        WatchMessageView(
                            symbol: "cart",
                            title: "No Stores Yet",
                            message: "Add a store in Allim on your iPhone."
                        )
                    } else {
                        // Nothing cached and no phone to ask. Saying "no stores"
                        // here would be a claim we can't actually make.
                        WatchMessageView(
                            symbol: "iphone.slash",
                            title: "iPhone Not Reachable",
                            message: "Your stores will appear once your iPhone is nearby."
                        )
                    }
                } else {
                    storeList
                }
            }
            .navigationTitle("Stores")
            .onAppear { store.refreshStores() }
        }
    }

    private var storeList: some View {
        List {
            WatchStatusRow()

            ForEach(store.stores) { item in
                NavigationLink {
                    WatchReminderListView(store: item)
                } label: {
                    WatchStoreRow(store: item)
                }
            }
        }
        .refreshable { store.refreshStores() }
    }
}

// MARK: - Row

struct WatchStoreRow: View {

    let store: WatchStorePayload

    var body: some View {
        HStack(spacing: 10) {
            WatchStoreLogo(name: store.name, imageURL: store.imageURL)

            Text(store.name)
                .font(.body)
                .lineLimit(2)

            Spacer(minLength: 4)

            if store.reminderCount > 0 {
                Text("\(store.reminderCount)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Logo

/// A store's logo, falling back to its first letter. The URL is whichever one
/// the phone would draw, but a watch fetches it over its own connection — the
/// initial is what shows until that lands, and for stores with no logo at all,
/// so it needs to look deliberate rather than like a failure.
struct WatchStoreLogo: View {

    let name: String
    let imageURL: String?

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.25))

            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                } placeholder: {
                    initialText
                }
            } else {
                initialText
            }
        }
        .frame(width: 28, height: 28)
    }

    private var initialText: some View {
        Text(initial)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.accentColor)
    }
}

// MARK: - Shared Pieces

/// Connection trouble, shown as a list row rather than an alert: it explains why
/// a check-off is taking its time without interrupting someone mid-aisle, and it
/// disappears on its own once the phone answers again.
struct WatchStatusRow: View {

    @EnvironmentObject private var store: WatchDataStore

    var body: some View {
        if let message = store.errorMessage {
            row(message, symbol: "exclamationmark.triangle")
        } else if !store.isPhoneReachable {
            row("iPhone not reachable", symbol: "iphone.slash")
        }
    }

    private func row(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
    }
}

struct WatchMessageView: View {

    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    WatchStoreListView()
        .environmentObject(WatchDataStore.shared)
}
