//
//  TermsOfUseView.swift
//  Geolocation_v1.0.0
//

import SwiftUI

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Group {
                        sectionHeader("Terms of Use")
                        bodyText("Last Updated: March 2025")
                        bodyText("Please read these Terms of Use ("Terms") carefully before using the Allim application ("App") operated by Kor3a ("we", "us", or "our"). By accessing or using the App, you agree to be bound by these Terms.")
                    }

                    Group {
                        sectionTitle("1. Acceptance of Terms")
                        bodyText("By downloading, installing, or using Allim, you confirm that you are at least 13 years old, have read and understood these Terms, and agree to be legally bound by them. If you do not agree, do not use the App.")
                    }

                    Group {
                        sectionTitle("2. Description of Service")
                        bodyText("Allim is a location-aware shopping list and reminder application that allows users to:")
                        bulletPoint("Create and manage shopping lists and store reminders")
                        bulletPoint("Receive location-based notifications when near saved stores")
                        bulletPoint("Share lists and collaborate with friends and family")
                        bulletPoint("Use AI-powered features (Smart Recipe, Smart Category) with an active Premium subscription")
                        bulletPoint("Send and receive messages with connected friends")
                    }

                    Group {
                        sectionTitle("3. User Accounts")
                        bodyText("You must create an account to use Allim. You are responsible for:")
                        bulletPoint("Providing accurate and up-to-date registration information")
                        bulletPoint("Maintaining the confidentiality of your account credentials")
                        bulletPoint("All activity that occurs under your account")
                        bodyText("We reserve the right to suspend or terminate accounts that violate these Terms or that have been inactive for an extended period.")
                    }

                    Group {
                        sectionTitle("4. Allim Premium Subscription")
                        subsectionTitle("4.1 Subscription Details")
                        bodyText("Allim offers an auto-renewable subscription called Allim Premium with the following terms:")
                        bulletPoint("Product Name: Allim Premium")
                        bulletPoint("Subscription Length: 1 month (monthly billing cycle)")
                        bulletPoint("Price: $0.99 USD per month (price may vary by region)")
                        bulletPoint("Free Trial: 7-day free trial for new subscribers")
                        bulletPoint("Billing: Charged to your Apple ID account upon confirmation of purchase. After the free trial, billing occurs monthly unless cancelled.")

                        subsectionTitle("4.2 Auto-Renewal")
                        bodyText("Your subscription automatically renews at the end of each billing period unless you cancel at least 24 hours before the renewal date. Your Apple ID account will be charged for the renewal within 24 hours prior to the end of the current period.")

                        subsectionTitle("4.3 Free Trial")
                        bodyText("If a free trial is offered, you will not be charged during the trial period. The subscription will automatically convert to a paid subscription at the end of the trial unless cancelled before the trial ends. Any unused portion of a free trial will be forfeited when you purchase a subscription.")

                        subsectionTitle("4.4 Cancellation")
                        bodyText("You may cancel your subscription at any time through your Apple ID account settings. Cancellation takes effect at the end of the current billing period. No refunds are provided for the unused portion of any billing period. To cancel: go to Settings > Apple ID > Subscriptions > Allim Premium > Cancel Subscription.")

                        subsectionTitle("4.5 Premium Features")
                        bodyText("Allim Premium unlocks the following features:")
                        bulletPoint("Smart Recipe: AI-powered recipe generation with automatic ingredient list creation")
                        bulletPoint("Smart Category: Automatic AI categorization of shopping list items")
                        bulletPoint("Ad-Free Experience: Removal of all banner advertisements")

                        subsectionTitle("4.6 Price Changes")
                        bodyText("We reserve the right to change the subscription price. We will notify you in advance of any price changes. Continued use of the subscription after a price change constitutes your acceptance of the new price.")
                    }

                    Group {
                        sectionTitle("5. Location Services")
                        bodyText("Allim uses your device's location to provide geofencing-based notifications when you are near saved stores. By using the App, you consent to the collection and use of your location data as described in our Privacy Policy. You can revoke location permissions at any time through your device settings, which will disable location-based features.")
                    }

                    Group {
                        sectionTitle("6. AI Features")
                        bodyText("Premium features including Smart Recipe and Smart Category use third-party AI services (OpenAI). By using these features, you acknowledge that:")
                        bulletPoint("Your input (recipe requests, item names) may be sent to OpenAI's servers for processing")
                        bulletPoint("AI-generated suggestions are provided for convenience and may not always be accurate")
                        bulletPoint("You should review AI-generated content before relying on it")
                        bulletPoint("AI feature availability depends on third-party service uptime")
                    }

                    Group {
                        sectionTitle("7. User Content")
                        bodyText("You retain ownership of content you create within the App (shopping lists, store names, messages). By using the App, you grant us a limited, non-exclusive license to store and process your content solely to provide the Service. You are responsible for ensuring that your content does not violate any applicable laws or third-party rights.")
                    }

                    Group {
                        sectionTitle("8. Prohibited Uses")
                        bodyText("You agree not to:")
                        bulletPoint("Use the App for any unlawful purpose")
                        bulletPoint("Attempt to gain unauthorized access to any part of the App or its infrastructure")
                        bulletPoint("Transmit any harmful, offensive, or disruptive content through the messaging features")
                        bulletPoint("Reverse engineer, decompile, or disassemble the App")
                        bulletPoint("Use automated tools to access or interact with the App")
                        bulletPoint("Share your account credentials with others")
                    }

                    Group {
                        sectionTitle("9. Intellectual Property")
                        bodyText("The App, including its design, code, graphics, and content, is the property of Kor3a and is protected by applicable intellectual property laws. You may not copy, modify, distribute, or create derivative works without our prior written consent.")
                    }

                    Group {
                        sectionTitle("10. Disclaimer of Warranties")
                        bodyText("THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS. YOUR USE OF THE APP IS AT YOUR SOLE RISK.")
                    }

                    Group {
                        sectionTitle("11. Limitation of Liability")
                        bodyText("TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, KOR3A SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING LOSS OF PROFITS, DATA, OR GOODWILL, ARISING FROM OR RELATING TO YOUR USE OF OR INABILITY TO USE THE APP, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.")
                    }

                    Group {
                        sectionTitle("12. Termination")
                        bodyText("We may suspend or terminate your access to the App at any time, with or without cause, with or without notice. Upon termination, your right to use the App will immediately cease. Provisions that by their nature should survive termination will survive, including Sections 9, 10, and 11.")
                    }

                    Group {
                        sectionTitle("13. Changes to Terms")
                        bodyText("We may update these Terms from time to time. We will notify you of significant changes by posting a notice in the App or by other means. Your continued use of the App after changes become effective constitutes your acceptance of the revised Terms.")
                    }

                    Group {
                        sectionTitle("14. Governing Law")
                        bodyText("These Terms are governed by and construed in accordance with applicable laws. Any disputes arising from these Terms or your use of the App shall be resolved through binding arbitration, except where prohibited by law.")
                    }

                    Group {
                        sectionTitle("15. Contact Us")
                        bodyText("If you have any questions about these Terms of Use, please contact us at:")
                        bodyText("Kor3a\nEmail: support@allim.app")
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .padding(.bottom, 4)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontWeight(.bold)
            .padding(.top, 4)
    }

    private func subsectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.top, 2)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 8)
    }
}

#Preview {
    TermsOfUseView()
}
