//
//  DEBUG_NotificationTestView.swift
//  Quick test interface for debugging CarPlay notifications
//
//  Add this to your app temporarily to test notifications without driving
//

import SwiftUI

#if DEBUG
struct NotificationDebugView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var testStoreName = "Target"
    @State private var testReminderCount = 3
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            List {
                // Status Section
                Section("Current Status") {
                    StatusRow(
                        label: "Notifications",
                        value: notificationManager.isAuthorized ? "✅ Authorized" : "❌ Not Authorized",
                        color: notificationManager.isAuthorized ? .green : .red
                    )

                    StatusRow(
                        label: "CarPlay",
                        value: notificationManager.isCarPlayConnected ? "🚗 Connected" : "📱 Disconnected",
                        color: notificationManager.isCarPlayConnected ? .blue : .gray
                    )
                }

                // Test Controls
                Section("Test Notification") {
                    TextField("Store Name", text: $testStoreName)

                    Stepper("Reminders: \(testReminderCount)", value: $testReminderCount, in: 1...10)

                    Button(action: testPassive) {
                        TestButton(title: "Test: Passive", icon: "speaker.wave.1", color: .gray)
                    }

                    Button(action: testTimeSensitive) {
                        TestButton(title: "Test: Time Sensitive", icon: "clock.badge.exclamationmark", color: .orange)
                    }

                    Button(action: testCritical) {
                        TestButton(title: "Test: Critical", icon: "exclamationmark.triangle.fill", color: .red)
                    }
                }

                // Debug Actions
                Section("Debug Actions") {
                    Button(action: {
                        Task {
                            await notificationManager.printDetailedSettings()
                        }
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Print Detailed Settings")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }

                    Button(action: {
                        notificationManager.getAllPendingNotificationsDebug()
                    }) {
                        HStack {
                            Image(systemName: "tray.fill")
                            Text("Show Pending Notifications")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }

                    Button(action: {
                        notificationManager.getAllDeliveredNotificationsDebug()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Show Delivered Notifications")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }

                    Button(action: {
                        notificationManager.removeAllPendingNotifications()
                        #if DEBUG
                        print("🗑️ Cleared all pending notifications")
                        #endif
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Pending")
                                .foregroundColor(.red)
                        }
                    }
                }

                // Settings Debug Info
                if !notificationManager.debugInfo.isEmpty {
                    Section("Last Settings Check") {
                        Text(notificationManager.debugInfo)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                // Instructions
                Section("How to Use") {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(
                            number: 1,
                            text: "Connect your iPhone to CarPlay"
                        )

                        InstructionRow(
                            number: 2,
                            text: "Tap one of the test buttons above"
                        )

                        InstructionRow(
                            number: 3,
                            text: "Check if notification appears on CarPlay screen"
                        )

                        InstructionRow(
                            number: 4,
                            text: "Check Xcode console for debug logs"
                        )

                        Divider()

                        Text("Note: Open Console.app on Mac and filter for 'UserNotificationCenter' to see system-level logs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                // Quick Fixes
                Section("Common Issues") {
                    DisclosureGroup("Notifications don't appear on CarPlay") {
                        VStack(alignment: .leading, spacing: 8) {
                            FixItem(text: "Go to Settings → Focus → Driving")
                            FixItem(text: "Add this app to 'Allowed Notifications'")
                            FixItem(text: "Or disable Driving Focus entirely for testing")
                        }
                        .padding(.vertical, 8)
                    }

                    DisclosureGroup("CarPlay shows 'Disconnected'") {
                        VStack(alignment: .leading, spacing: 8) {
                            FixItem(text: "Ensure iPhone is physically connected to car")
                            FixItem(text: "Check if CarPlay is enabled in Settings → General → CarPlay")
                            FixItem(text: "Try disconnecting and reconnecting")
                        }
                        .padding(.vertical, 8)
                    }

                    DisclosureGroup("Critical notifications fail") {
                        VStack(alignment: .leading, spacing: 8) {
                            FixItem(text: "Critical alerts require special Apple entitlement")
                            FixItem(text: "Use for testing only, not production")
                            FixItem(text: "Try Time Sensitive mode instead")
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("🔧 Notification Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        openAppSettings()
                    }
                }
            }
        }
    }

    // MARK: - Test Methods

    private func testPassive() {
        #if DEBUG
        print("\n🧪 Testing PASSIVE notification")
        #endif
        notificationManager.scheduleStoreProximityNotification(
            storeName: testStoreName,
            reminderCount: testReminderCount,
            mode: .passive
        )
    }

    private func testTimeSensitive() {
        #if DEBUG
        print("\n🧪 Testing TIME SENSITIVE notification")
        #endif
        notificationManager.scheduleStoreProximityNotification(
            storeName: testStoreName,
            reminderCount: testReminderCount,
            mode: .timeSensitive
        )
    }

    private func testCritical() {
        #if DEBUG
        print("\n🧪 Testing CRITICAL notification")
        #endif
        notificationManager.scheduleStoreProximityNotification(
            storeName: testStoreName,
            reminderCount: testReminderCount,
            mode: .critical
        )
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct TestButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "paperplane.fill")
                .foregroundColor(color)
                .font(.caption)
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

struct FixItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .padding(.top, 2)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationDebugView()
}
#endif
