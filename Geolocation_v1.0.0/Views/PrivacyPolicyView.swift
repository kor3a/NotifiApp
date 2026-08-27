//
//  PrivacyPolicyView.swift
//  Geolocation_v1.0.0
//

import SwiftUI

struct PrivacyPolicyView: View {
    /// Set when the policy is presented as a sheet, which is the only time it
    /// needs a stack of its own and a way out. Pushed from About it inherits
    /// both from the screen that pushed it, and supplying a second set stacked
    /// one navigation bar on top of another.
    var isModal: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if isModal {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { dismiss() }
                                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        }
                    }
            }
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Group {
                        sectionHeader("Privacy Policy")
                        bodyText("Last Updated: March 2025")
                        bodyText("This Privacy Policy describes how Kor3a (\"we\", \"us\", or \"our\") collects, uses, and shares information when you use the Allim application (\"App\"). By using Allim, you agree to the practices described in this policy.")
                    }

                    Group {
                        sectionTitle("1. Information We Collect")

                        subsectionTitle("1.1 Account Information")
                        bodyText("When you create an account, we collect:")
                        bulletPoint("Name")
                        bulletPoint("Email address")
                        bulletPoint("Profile picture (optional)")
                        bulletPoint("Account creation date")

                        subsectionTitle("1.2 Location Data")
                        bodyText("With your permission, we collect:")
                        bulletPoint("Precise location (GPS) to trigger notifications when you are near saved stores")
                        bulletPoint("Background location when you have enabled \"Always\" location access for geofencing")
                        bodyText("Location data is processed on-device and used solely to trigger your personal shopping reminders. We do not sell or share your precise location with third parties for advertising.")

                        subsectionTitle("1.3 Content You Create")
                        bodyText("We store content you create in the App, including:")
                        bulletPoint("Store names and addresses")
                        bulletPoint("Shopping list items and categories")
                        bulletPoint("Reminders and notes")
                        bulletPoint("Messages sent to friends")

                        subsectionTitle("1.4 Usage Data")
                        bodyText("We may collect information about how you use the App, including feature usage patterns and error logs, to improve the service.")
                    }

                    Group {
                        sectionTitle("2. How We Use Your Information")
                        bodyText("We use the information we collect to:")
                        bulletPoint("Provide, maintain, and improve the App")
                        bulletPoint("Send location-based notifications when you are near saved stores")
                        bulletPoint("Enable friend connections and list sharing")
                        bulletPoint("Process subscription payments via Apple's App Store")
                        bulletPoint("Respond to support requests")
                        bulletPoint("Detect and prevent fraud or abuse")
                    }

                    Group {
                        sectionTitle("3. Third-Party Services")
                        bodyText("Allim uses the following third-party services that may collect and process your data under their own privacy policies:")

                        subsectionTitle("3.1 Firebase (Google)")
                        bodyText("We use Firebase for authentication, cloud storage, and database services. Firebase processes your account information and app data. Firebase Privacy Policy: https://firebase.google.com/support/privacy")

                        subsectionTitle("3.2 OpenAI (Premium Feature)")
                        bodyText("If you use Smart Recipe or Smart Category (Premium features), your text input (recipe requests, item names) is sent to OpenAI's API for processing. OpenAI may retain this data per their usage policies. OpenAI Privacy Policy: https://openai.com/privacy")

                        subsectionTitle("3.3 Google AdMob (Free Users)")
                        bodyText("Non-subscribed users may see banner advertisements served by Google AdMob, which may collect advertising identifiers and usage data to serve relevant ads. Premium subscribers do not see ads. AdMob Privacy Policy: https://policies.google.com/privacy")

                        subsectionTitle("3.4 Apple App Store")
                        bodyText("Subscription payments are processed entirely by Apple. We do not collect or store your payment card details. Apple's Privacy Policy: https://www.apple.com/legal/privacy")

                        subsectionTitle("3.5 Firebase Cloud Messaging (FCM)")
                        bodyText("We use FCM to deliver push notifications. Your device token is stored to enable notification delivery.")
                    }

                    Group {
                        sectionTitle("4. Data Sharing")
                        bodyText("We do not sell your personal information. We may share your information in the following limited circumstances:")
                        bulletPoint("With friends you have connected with in the App (shared lists, messages)")
                        bulletPoint("With service providers listed in Section 3 to operate the App")
                        bulletPoint("When required by law or to protect legal rights")
                        bulletPoint("In connection with a merger, acquisition, or sale of assets (with prior notice)")
                    }

                    Group {
                        sectionTitle("5. Data Retention")
                        bodyText("We retain your data for as long as your account is active. You may delete your account at any time from the Profile screen, which will permanently remove your personal data from our systems within 30 days. Certain data may be retained longer as required by law.")
                    }

                    Group {
                        sectionTitle("6. Data Security")
                        bodyText("We implement industry-standard security measures to protect your information, including encryption in transit (TLS) and at rest. However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.")
                    }

                    Group {
                        sectionTitle("7. Children's Privacy")
                        bodyText("Allim is not directed to children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that a child under 13 has provided personal information, we will delete it promptly.")
                    }

                    Group {
                        sectionTitle("8. Your Rights")
                        bodyText("Depending on your location, you may have rights including:")
                        bulletPoint("Access: Request a copy of the personal data we hold about you")
                        bulletPoint("Correction: Request correction of inaccurate data")
                        bulletPoint("Deletion: Request deletion of your data by deleting your account in the App")
                        bulletPoint("Portability: Request a copy of your data in a portable format")
                        bodyText("To exercise these rights, contact us at support@allim.app.")
                    }

                    Group {
                        sectionTitle("9. Location Permissions")
                        bodyText("You can manage location permissions at any time in your device's Settings > Privacy & Security > Location Services > Allim. Disabling location access will prevent geofencing notifications from working, but the rest of the App will continue to function.")
                    }

                    Group {
                        sectionTitle("10. Changes to This Policy")
                        bodyText("We may update this Privacy Policy from time to time. We will notify you of significant changes by posting a notice in the App. Your continued use of the App after changes become effective constitutes acceptance of the revised policy.")
                    }

                    Group {
                        sectionTitle("11. Contact Us")
                        bodyText("If you have questions or concerns about this Privacy Policy or our data practices, please contact us:")
                        bodyText("Kor3a\nEmail: support@allim.app")
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(OrganicPalette.canvas(colorScheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Privacy Policy")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                }
            }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(OrganicPalette.display(28))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .padding(.bottom, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(OrganicPalette.display(19))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .padding(.top, 4)
    }

    private func subsectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(OrganicPalette.terracotta(colorScheme))
            .padding(.top, 2)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(OrganicPalette.terracotta(colorScheme).opacity(0.6))
                .frame(width: 5, height: 5)
                .padding(.top, 7)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 8)
    }
}

#Preview {
    PrivacyPolicyView(isModal: true)
}
