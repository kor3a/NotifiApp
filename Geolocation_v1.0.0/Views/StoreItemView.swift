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

    var body: some View {
        HStack(spacing: 16) {
            // Store logo or default icon
            storeLogoView

            Text(store.name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

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
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                default:
                    defaultStoreIcon
                }
            }
            .frame(width: 50, height: 50)
        } else {
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
