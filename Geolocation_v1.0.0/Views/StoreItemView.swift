//
//  StoreItemView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 5/26/25.
//

import SwiftUI

struct StoreItemView: View {
    let store: Store
    var logoURL: String? = nil
    var isShared: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Store logo or default icon
            storeLogoView

            Text(store.name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // Shared icon
            if isShared {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
            }

            // Reminder count badge
            if store.reminderCount > 0 {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 25, height: 25)

                    Text("\(store.reminderCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

        }//:HSTACK
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var storeLogoView: some View {
        if let logoURL = logoURL, let url = URL(string: logoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    #if DEBUG
                    let _ = print("StoreItemView: Successfully loaded logo for '\(store.name)'")
                    #endif
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure(let error):
                    #if DEBUG
                    let _ = print("StoreItemView: Failed to load logo for '\(store.name)': \(error.localizedDescription)")
                    let _ = print("StoreItemView: URL was: \(logoURL)")
                    #endif
                    defaultStoreIcon
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                @unknown default:
                    defaultStoreIcon
                }
            }
            .frame(width: 50, height: 50)
        } else {
            #if DEBUG
            let _ = print("StoreItemView: No logo URL for '\(store.name)' (logoURL param: \(logoURL ?? "nil"))")
            #endif
            defaultStoreIcon
        }
    }

    private var defaultStoreIcon: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            Image(systemName: "storefront")
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    VStack {
        StoreItemView(store: Store(name: "Walmart", reminderCount: 3), logoURL: "https://logo.clearbit.com/walmart.com")
        StoreItemView(store: Store(name: "My Local Shop", reminderCount: 0))
    }
}
