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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.headline)

                Text(store.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

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
        .padding()
    }
}

