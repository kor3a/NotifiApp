//
//  AboutView.swift
//  Geolocation_v1.0.0
//

import SwiftUI

struct AboutView: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "cart.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.blue)
                        .padding(.top, 16)

                    Text("Allim Smart Shopping List")
                        .font(.title2)
                        .bold()

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section(header: Text("About")) {
                Text("Allim Smart Shopping List helps you manage your grocery lists with location-based reminders, so you never forget an item when you're near a store.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Section(header: Text("Legal")) {
                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
