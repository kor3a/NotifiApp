//
//  StoreItemView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 5/26/25.
//

import SwiftUI

struct StoreItemView: View {
    let store: Store
    var isShared: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Store logo (served from disk cache)
            CachedLogoImage(storeName: store.name)

            Text(store.name)
                .font(.system(size: 17))
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

}

#Preview {
    VStack {
        StoreItemView(store: Store(name: "Walmart", reminderCount: 3))
        StoreItemView(store: Store(name: "My Local Shop", reminderCount: 0))
    }
}
