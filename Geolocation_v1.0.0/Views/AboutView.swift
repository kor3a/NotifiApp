//
//  AboutView.swift
//  Geolocation_v1.0.0
//

import SwiftUI

struct AboutView: View {

    @Environment(\.colorScheme) private var colorScheme

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero

                    VStack(alignment: .leading, spacing: 10) {
                        OrganicSectionLabel(title: "What it does")

                        Text("Allim keeps your grocery lists tied to the places you actually shop. Save a store, add what you need, and Allim reminds you when you're nearby — so nothing gets left behind.")
                            .font(.system(size: 16))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(OrganicCardBackground(colorScheme: colorScheme))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        OrganicSectionLabel(title: "Legal")

                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            OrganicNavRow(
                                systemImage: "hand.raised.fill",
                                title: "Privacy Policy",
                                subtitle: "What we collect, and what we never do with it"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("About")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart.fill")
                .font(.system(size: 40))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 96, height: 96)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("Allim")
                .font(OrganicPalette.display(30))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Text("Smart Shopping List")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.system(size: 13))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
