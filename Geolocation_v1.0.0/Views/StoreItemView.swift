//
//  StoreItemView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 5/26/25.
//

import SwiftUI

struct StoreItemView: View {
    let store: Store
    
    var body: some View {
        HStack(spacing: 16) {
            // Store icon with glass effect
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
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(store.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
            }
            

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
}

#Preview {
    VStack {
        StoreItemView(store: Store(id: "1", name: "Example Store", address: "123 Main St, City, Country", reminderCount: 3))
        StoreItemView(store: Store(id: "2", name: "Another Store", address: "456 Oak Ave, Town, Country", reminderCount: 0))
    }
}

