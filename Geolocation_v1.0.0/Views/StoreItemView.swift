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

            Text(store.name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // TODO: replace text that displays the number of reminders
//            if(store.reminderCount > 0){
//                Text("\(store.reminderCount)")
//                    .foregroundColor(.white)
//                    .background(
//                        Circle()
//                            .fill(.red)
//                            .frame(width: 25, height: 25)
//                    )
//            }

        }//:HSTACK
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

