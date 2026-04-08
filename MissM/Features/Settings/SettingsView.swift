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

    // Integration toggles
    @State private var calendarEnabled = true
    @State private var remindersEnabled = true
    @State private var iMessageEnabled = true
    @State private var mailEnabled = false

    // Privacy toggles
    @State private var touchIDEnabled = false
    @State private var localOnlyEnabled = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header (per design: "App Settings" Playfair italic)
                HStack(spacing: 0) {
                    Text("App ")
                        .font(.custom("PlayfairDisplay-Italic", size: 20))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Settings")
                        .font(.custom("PlayfairDisplay-Italic", size: 20))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .padding(.horizontal, 16)

                // AI & API Section (per design: grouped rows)
                SettingsSectionLabel(title: "AI & API")

                SettingsGroup {
                    SettingsRow(icon: "✦", iconBg: Theme.Colors.rosePrimary.opacity(0.12),
                                name: "Model", desc: "Claude Sonnet 4.6") {
                        Text("Sonnet 4.6 ›")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    SettingsRow(icon: "💳", iconBg: Color.green.opacity(0.12),
                                name: "API Credit", desc: "$24.00 remaining · ~5 months") {
                        Text("Top up ›")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    SettingsRow(icon: "🔑", iconBg: Color.blue.opacity(0.1),
                                name: "API Key", desc: showAPIKeyField ? "" : "Stored in Keychain · secure") {
                        if showAPIKeyField {
                            EmptyView()
                        } else {
                            Button("Edit ›") { showAPIKeyField = true }
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // API Key inline edit
                if showAPIKeyField {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(apiKeyMasked)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                        }
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
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Phone Number (compact)
                SettingsSectionLabel(title: "IMESSAGE")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("+1 (555) 000-0000", text: $phoneNumber)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
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

                // Apple Integrations (per design: toggles)
                SettingsSectionLabel(title: "APPLE INTEGRATIONS")

                SettingsGroup {
                    SettingsToggleRow(icon: "📅", iconBg: Theme.Colors.rosePrimary.opacity(0.1),
                                      name: "Apple Calendar", desc: "Read + write access",
                                      isOn: $calendarEnabled)
                    SettingsToggleRow(icon: "🔔", iconBg: Color.orange.opacity(0.1),
                                      name: "Apple Reminders", desc: "Read + write access",
                                      isOn: $remindersEnabled)
                    SettingsToggleRow(icon: "💬", iconBg: Color.green.opacity(0.1),
                                      name: "iMessage AI (Two-Way)", desc: "AppleScript · always listening",
                                      isOn: $iMessageEnabled)
                    SettingsToggleRow(icon: "📧", iconBg: Color.blue.opacity(0.1),
                                      name: "Apple Mail", desc: "Draft + open in Mail app",
                                      isOn: $mailEnabled)
                }
                .padding(.horizontal, 16)

                // Privacy (per design)
                SettingsSectionLabel(title: "PRIVACY")

                SettingsGroup {
                    SettingsToggleRow(icon: "👆", iconBg: Theme.Colors.rosePrimary.opacity(0.1),
                                      name: "Touch ID Lock", desc: "Require Touch ID to open app",
                                      isOn: $touchIDEnabled)
                    SettingsToggleRow(icon: "🔒", iconBg: Color.blue.opacity(0.1),
                                      name: "Local Only", desc: "No cloud — stays on her Mac",
                                      isOn: $localOnlyEnabled)
                    SettingsRow(icon: "🗑", iconBg: Color.red.opacity(0.1),
                                name: "Clear Chat History", desc: "Wipes all local messages") {
                        Text("Clear ›")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)

                // API Cost Estimate (per design: rose info box)
                VStack(alignment: .leading, spacing: 6) {
                    Text("💰 API Cost Estimate")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("At typical daily use: **~$3–6/month**. Your $24 covers **4–8 months** of everything — chat, iMessage AI, briefings, all features. Top up anytime from $5.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMedium)
                        .lineSpacing(4)
                }
                .padding(14)
                .background(Theme.Colors.rosePrimary.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.rosePrimary.opacity(0.14), lineWidth: 1))
                .cornerRadius(14)
                .padding(.horizontal, 16)

                // Delete API Key
                Button(action: {
                    try? KeychainManager.deleteAPIKey()
                    apiKeyMasked = "No key stored"
                }) {
                    Text("Delete API Key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

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

// MARK: - Settings Section Label (per design: uppercase, letter-spaced)
struct SettingsSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(2)
            .foregroundColor(Theme.Colors.textSoft)
            .padding(.horizontal, 16)
    }
}

// MARK: - Settings Group (per design: .sgrp with border-radius, shared bg)
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Theme.Colors.glassWhite)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .shadow(color: Theme.Colors.shadow, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Settings Row (per design: icon bg + name + desc + trailing)
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconBg: Color
    let name: String
    let desc: String
    @ViewBuilder let trailing: () -> Trailing
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                Text(icon)
                    .font(.system(size: 15))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color.white.opacity(0.88) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Settings Toggle Row (per design: .tog green toggle)
struct SettingsToggleRow: View {
    let icon: String
    let iconBg: Color
    let name: String
    let desc: String
    @Binding var isOn: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                Text(icon)
                    .font(.system(size: 15))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(Color(hex: "#34C759"))
                .scaleEffect(0.75)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color.white.opacity(0.88) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Section Header (legacy compat)
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
