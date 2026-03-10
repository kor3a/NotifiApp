//
//  StoreFloatView.swift
//  Geolocation_v1.0.0
//
//  Created on 3/10/26.
//

import SwiftUI

struct StoreFloatView: View {
    let stores: [UserStoreItem]
    let onStoreTap: (UserStoreItem) -> Void

    @State private var appeared = false

    private let circleSize: CGFloat = 58

    // Dynamically compute radius so circles never overlap,
    // regardless of how many stores the user has saved.
    private var orbitRadius: CGFloat {
        guard stores.count > 1 else { return 0 }
        let minSpacing: CGFloat = circleSize + 14
        let circumferenceNeeded = CGFloat(stores.count) * minSpacing
        let radiusNeeded = circumferenceNeeded / (2 * .pi)
        return max(110, radiusNeeded)
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                ForEach(Array(stores.enumerated()), id: \.element.id) { index, item in
                    let angle = orbitAngle(for: index)
                    let targetX = center.x + orbitRadius * CGFloat(cos(angle))
                    let targetY = center.y + orbitRadius * CGFloat(sin(angle))

                    Button {
                        onStoreTap(item)
                    } label: {
                        storeCircle(for: item)
                    }
                    .buttonStyle(.plain)
                    // Before appearing: all circles cluster at center, invisible and tiny.
                    // After appearing: each flies outward to its ring position.
                    .position(
                        x: appeared ? targetX : center.x,
                        y: appeared ? targetY : center.y
                    )
                    .scaleEffect(appeared ? 1.0 : 0.1)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.70)
                        .delay(Double(index) * 0.06),
                        value: appeared
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            // Brief pause lets SwiftUI settle the initial state before animating.
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }

    // MARK: - Store Circle

    private func storeCircle(for item: UserStoreItem) -> some View {
        ZStack(alignment: .topTrailing) {
            CachedLogoImage(storeName: item.store.name, size: circleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.22), radius: 7, x: 0, y: 3)

            // Reminder count badge
            if item.store.reminderCount > 0 {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 19, height: 19)
                    Text("\(item.store.reminderCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 5, y: -5)
            }
        }
        .frame(width: circleSize, height: circleSize)
    }

    // MARK: - Helpers

    // Angle for each store on the ring, starting from 12 o'clock (−π/2).
    private func orbitAngle(for index: Int) -> Double {
        guard stores.count > 1 else { return 0 }
        let step = (2.0 * .pi) / Double(stores.count)
        return step * Double(index) - (.pi / 2)
    }
}

#Preview {
    func makeItem(id: String, name: String, count: Int) -> UserStoreItem {
        UserStoreItem(
            id: id,
            store: Store(name: name, reminderCount: count),
            permission: .edit,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
    }
    let sampleStores: [UserStoreItem] = [
        makeItem(id: "1", name: "Walmart", count: 3),
        makeItem(id: "2", name: "Target", count: 0),
        makeItem(id: "3", name: "Costco", count: 1),
        makeItem(id: "4", name: "Trader Joe's", count: 5),
        makeItem(id: "5", name: "Whole Foods", count: 0),
    ]
    StoreFloatView(stores: sampleStores, onStoreTap: { _ in })
}
