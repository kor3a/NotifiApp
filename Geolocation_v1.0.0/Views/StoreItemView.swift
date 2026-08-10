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
    /// Reserves room at the trailing edge for the voice command button, which
    /// StoresView overlays on top of the row. The button can't live inside this
    /// view: the row is already the label of a Button, and a nested Button
    /// never receives its own taps.
    var reservesVoiceButtonSpace: Bool = false

    /// Diameter of the voice button, shared with StoresView so the reserved gap
    /// and the overlaid control stay the same size.
    static let voiceButtonSize: CGFloat = 34

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

            if reservesVoiceButtonSpace {
                Color.clear
                    .frame(width: Self.voiceButtonSize, height: Self.voiceButtonSize)
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
        StoreItemView(store: Store(name: "Costco", reminderCount: 12), reservesVoiceButtonSpace: true)
    }
}
