//
//  CachedLogoImage.swift
//  Geolocation_v1.0.0
//
//  Created on 2/21/26.
//

import SwiftUI

/// Displays a store logo from the local disk cache, falling back to a network
/// download only when no cached image is available. This prevents repeated
/// downloads when navigating between views.
struct CachedLogoImage: View {
    let storeName: String
    let size: CGFloat
    @ObservedObject private var logoProvider = StoreLogoProvider.shared
    @Environment(\.colorScheme) private var colorScheme

    init(storeName: String, size: CGFloat = 50) {
        self.storeName = storeName
        self.size = size
    }

    var body: some View {
        Group {
            if let image = logoProvider.cachedImage(for: storeName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if logoProvider.logoURL(for: storeName) != nil {
                // URL exists but image isn't cached yet — show placeholder while downloading
                ProgressView()
                    .tint(OrganicPalette.terracotta(colorScheme))
                    .frame(width: size, height: size)
            } else {
                defaultStoreIcon
            }
        }
        .frame(width: size, height: size)
    }

    /// Stand-in for a store with no logo. A flat blush disc carrying a
    /// terracotta storefront, so a store without a logo still sits in the same
    /// palette as the rest of the row rather than under a blue-purple gradient.
    private var defaultStoreIcon: some View {
        ZStack {
            Circle()
                .fill(OrganicPalette.blush(colorScheme))
                .frame(width: size, height: size)

            Image(systemName: "storefront")
                .font(.system(size: size * 0.44))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
        }
    }
}
