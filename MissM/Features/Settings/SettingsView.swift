import SwiftUI
import EventKit

// MARK: - Settings View (Phase 1)

struct SettingsView: View {
    @State private var apiKeyMasked: String = maskAPIKey()
    @State private var phoneNumber: String = KeychainManager.loadPhoneNumber() ?? ""
    @State private var showAPIKeyField = false
    @State private var newAPIKey = ""
    @State private var showSavedConfirmation = false
    @State private var calendarStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var remindersStatus = EKEventStore.authorizationStatus(for: .reminder)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Settings")
                    .font(.custom("PlayfairDisplay-Italic", size: 22))
                    .foregroundColor(Theme.Colors.rosePrimary)
                    .padding(.horizontal, 16)

                // API Key Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "CLAUDE API")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("API Key")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            if KeychainManager.loadAPIKey() != nil {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text("Active")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        if showAPIKeyField {
                            HStack(spacing: 8) {
                                SecureField("sk-ant-...", text: $newAPIKey)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))
                                Button("Save") {
                                    guard !newAPIKey.isEmpty else { return }
                                    try? KeychainManager.saveAPIKey(newAPIKey)
                                    apiKeyMasked = maskAPIKey(newAPIKey)
                                    newAPIKey = ""
                                    showAPIKeyField = false
                                    showSavedConfirmation = true
                                }
                                .buttonStyle(RoseButtonStyle())
                                .font(.system(size: 11))
                            }
                        } else {
                            HStack {
                                Text(apiKeyMasked)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.Colors.textSoft)
                                Spacer()
                                Button("Change") { showAPIKeyField = true }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                            }
                        }

                        if showSavedConfirmation {
                            Text("API key updated securely in Keychain")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showSavedConfirmation = false
                                    }
                                }
                        }

                        Text("Stored in macOS Keychain — never in plain text")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Phone Number Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "IMESSAGE")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Phone Number")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)

                        HStack(spacing: 8) {
                            TextField("+1 (555) 000-0000", text: $phoneNumber)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))

                            Button("Save") {
                                try? KeychainManager.savePhoneNumber(phoneNumber)
                            }
                            .buttonStyle(RoseButtonStyle())
                            .font(.system(size: 11))
                        }

                        Text("Used for morning briefings and iMessage auto-replies")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Permissions Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "PERMISSIONS")

                    VStack(spacing: 6) {
                        PermissionRow(
                            icon: "📅",
                            label: "Calendar",
                            status: calendarStatus.displayString,
                            isGranted: calendarStatus == .fullAccess || calendarStatus == .authorized,
                            action: {
                                Task {
                                    _ = try? await CalendarService.shared.requestAccess()
                                    calendarStatus = EKEventStore.authorizationStatus(for: .event)
                                }
                            }
                        )
                        PermissionRow(
                            icon: "🔔",
                            label: "Reminders",
                            status: remindersStatus.displayString,
                            isGranted: remindersStatus == .fullAccess || remindersStatus == .authorized,
                            action: {
                                Task {
                                    _ = try? await RemindersService.shared.requestAccess()
                                    remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
                                }
                            }
                        )
                        PermissionRow(
                            icon: "💬",
                            label: "Messages (AppleScript)",
                            status: "Requires Accessibility",
                            isGranted: true,
                            action: nil
                        )
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // About Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "ABOUT")

                    VStack(alignment: .leading, spacing: 6) {
                        AboutRow(label: "App", value: "Miss M v1.0")
                        AboutRow(label: "Model", value: "Claude Sonnet 4.6")
                        AboutRow(label: "Bundle ID", value: "com.missm.assistant")
                        AboutRow(label: "Platform", value: "macOS 14.0+")
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Delete API Key
                VStack(alignment: .center, spacing: 8) {
                    Button("Delete API Key") {
                        try? KeychainManager.deleteAPIKey()
                        apiKeyMasked = "No key stored"
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Spacer().frame(height: 16)
            }
            .padding(.top, 12)
        }
    }

    private static func maskAPIKey() -> String {
        guard let key = KeychainManager.loadAPIKey(), key.count > 10 else {
            return "No key stored"
        }
        let prefix = String(key.prefix(7))
        let suffix = String(key.suffix(4))
        return "\(prefix)•••••\(suffix)"
    }

    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 10 else { return "•••••" }
        let prefix = String(key.prefix(7))
        let suffix = String(key.suffix(4))
        return "\(prefix)•••••\(suffix)"
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("CormorantGaramond-SemiBold", size: 11))
            .tracking(2.5)
            .foregroundColor(Theme.Colors.textSoft)
            .padding(.horizontal, 16)
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let icon: String
    let label: String
    let status: String
    let isGranted: Bool
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(status)
                    .font(.system(size: 10))
                    .foregroundColor(isGranted ? .green : Theme.Colors.textSoft)
            }
            Spacer()
            if isGranted {
                Text("✓")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            } else if let action {
                Button("Grant") { action() }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.Gradients.rosePrimary)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About Row
struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textSoft)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
        }
    }
}

// MARK: - EKAuthorizationStatus Display
extension EKAuthorizationStatus {
    var displayString: String {
        switch self {
        case .notDetermined: return "Not requested"
        case .restricted: return "Restricted"
        case .denied: return "Denied — open System Settings"
        case .fullAccess: return "Full access granted"
        case .authorized: return "Authorized"
        case .writeOnly: return "Write only"
        @unknown default: return "Unknown"
        }
    }
}
