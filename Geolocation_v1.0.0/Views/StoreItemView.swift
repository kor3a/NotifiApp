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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            // Store logo (served from disk cache)
            CachedLogoImage(storeName: store.name, size: 48)

            Text(store.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .lineLimit(1)

            Spacer(minLength: 8)

            // Shared icon — sage is this screen's one non-terracotta idea, so a
            // store somebody else is on is the only thing wearing it.
            if isShared {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OrganicPalette.sageInk(colorScheme))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(OrganicPalette.sage(colorScheme)))
            }

            // Reminder count badge
            if store.reminderCount > 0 {
                OrganicCountBadge(count: store.reminderCount, fontSize: 14)
            }

        }//:HSTACK
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

}

#Preview {
    VStack {
        StoreItemView(store: Store(name: "Walmart", reminderCount: 3))
        StoreItemView(store: Store(name: "My Local Shop", reminderCount: 0))
    }
}
