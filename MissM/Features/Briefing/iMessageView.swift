import SwiftUI

// MARK: - iMessage Hub View
// Controls for two-way iMessage AI, briefing settings, and message monitor

struct iMessageView: View {
    let claudeService: ClaudeService
    @State private var monitor: MessageMonitor?
    @State private var scheduler: BriefingScheduler?
    @State private var phoneNumber: String = KeychainManager.loadPhoneNumber() ?? ""
    @State private var isMonitorActive = false
    @State private var showPhoneSetup = false
    @State private var testMessage = ""
    @State private var isSending = false
    @State private var statusMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("iMessage AI")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    // Connection status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isMonitorActive ? Color.green : Theme.Colors.textXSoft)
                            .frame(width: 7, height: 7)
                            .shadow(color: isMonitorActive ? Color.green.opacity(0.6) : .clear, radius: 4)
                        Text(isMonitorActive ? "Listening" : "Inactive")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isMonitorActive ? .green : Theme.Colors.textSoft)
                    }
                }
                .padding(.horizontal, 14)

                // Phone Number Setup
                if phoneNumber.isEmpty {
                    VStack(spacing: 10) {
                        Text("\u{1F4F1}")
                            .font(.system(size: 32))
                        Text("Set up your iPhone number")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Miss M will send briefings and replies to this number via iMessage.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                            .multilineTextAlignment(.center)
                        PhoneNumberInput(phoneNumber: $phoneNumber, onSave: savePhone)
                    }
                    .glassCard()
                    .padding(.horizontal, 14)
                } else {
                    // Phone number display
                    HStack {
                        Text("\u{1F4F1}")
                            .font(.system(size: 14))
                        Text(phoneNumber)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Button("Change") { showPhoneSetup = true }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.roseDeep)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // Two-Way Monitor Control
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TWO-WAY AI")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                    }

                    Text("When enabled, Miss M reads incoming iMessages and auto-replies using Claude AI. Poll interval: 10 seconds.")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textXSoft)

                    HStack {
                        Text("Auto-Reply Monitor")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $isMonitorActive)
                            .toggleStyle(.switch)
                            .tint(Theme.Colors.rosePrimary)
                            .onChange(of: isMonitorActive) { _, newValue in
                                toggleMonitor(newValue)
                            }
                    }
                    .disabled(phoneNumber.isEmpty)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Briefing Schedule Controls
                if let scheduler = scheduler {
                    BriefingControlsView(scheduler: scheduler)
                        .padding(.horizontal, 14)
                }

                // Quick Send Test
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUICK SEND")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    HStack(spacing: 8) {
                        TextField("Send a test message...", text: $testMessage)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(10)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                            .onSubmit { Task { await sendTest() } }

                        Button(action: { Task { await sendTest() } }) {
                            if isSending {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Text("\u{2191}")
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(Theme.Gradients.rosePrimary)
                        .cornerRadius(10)
                        .buttonStyle(.plain)
                        .disabled(testMessage.isEmpty || phoneNumber.isEmpty || isSending)
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 10))
                            .foregroundColor(statusMessage.contains("Sent") ? .green : .red)
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Quick Chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("QUICK MESSAGES")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        QuickMessageChip(text: "\u{2615} Good morning!") { Task { await quickSend("Good morning Miss M! Hope you have a wonderful day ahead \u{2600}\u{FE0F}") } }
                        QuickMessageChip(text: "\u{1F4DA} Study reminder") { Task { await quickSend("Time to study, Miss M! You've got this \u{1F4AA} What are you working on?") } }
                        QuickMessageChip(text: "\u{1F31F} Encouragement") { Task { await quickSend("Just a reminder Miss M \u{2014} you're doing amazing. Keep going! \u{1F31F}") } }
                        QuickMessageChip(text: "\u{1F3E0} Come home") { Task { await quickSend("Hey Miss M! Dinner's ready whenever you are \u{1F3E0}\u{2764}\u{FE0F}") } }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .padding(.top, 10)
        }
        .onAppear { setupScheduler() }
        .sheet(isPresented: $showPhoneSetup) {
            VStack(spacing: 16) {
                Text("Update Phone Number")
                    .font(Theme.Fonts.display(18))
                    .foregroundColor(Theme.Colors.rosePrimary)
                PhoneNumberInput(phoneNumber: $phoneNumber, onSave: savePhone)
                Button("Cancel") { showPhoneSetup = false }
                    .foregroundColor(Theme.Colors.textSoft)
            }
            .padding(24)
            .frame(width: 360)
            .background(Theme.Gradients.background)
        }
    }

    // MARK: - Actions

    private func savePhone() {
        guard !phoneNumber.isEmpty else { return }
        try? KeychainManager.savePhoneNumber(phoneNumber)
        showPhoneSetup = false
        setupScheduler()
    }

    private func setupScheduler() {
        guard !phoneNumber.isEmpty else { return }
        if scheduler == nil {
            scheduler = BriefingScheduler(claudeService: claudeService, phoneNumber: phoneNumber)
            scheduler?.start()
        }
    }

    private func toggleMonitor(_ active: Bool) {
        if active {
            guard !phoneNumber.isEmpty else { return }
            monitor = MessageMonitor(phoneNumber: phoneNumber, claudeService: claudeService)
            monitor?.start()
        } else {
            monitor?.stop()
            monitor = nil
        }
    }

    private func sendTest() async {
        guard !testMessage.isEmpty, !phoneNumber.isEmpty else { return }
        isSending = true
        do {
            try await MessagesService.send(testMessage, to: phoneNumber)
            statusMessage = "Sent \u{2713}"
            testMessage = ""
        } catch {
            statusMessage = "Failed to send"
        }
        isSending = false
    }

    private func quickSend(_ message: String) async {
        guard !phoneNumber.isEmpty else { return }
        try? await MessagesService.send(message, to: phoneNumber)
    }
}

// MARK: - Phone Number Input

struct PhoneNumberInput: View {
    @Binding var phoneNumber: String
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("+1 (555) 000-0000", text: $phoneNumber)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            Button("Save") { onSave() }
                .buttonStyle(RoseButtonStyle())
                .disabled(phoneNumber.isEmpty)
        }
    }
}

// MARK: - Briefing Controls

struct BriefingControlsView: View {
    @Bindable var scheduler: BriefingScheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AUTOMATED MESSAGES")
                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                .tracking(2)
                .foregroundColor(Theme.Colors.textSoft)

            Toggle(isOn: $scheduler.isEnabled) {
                Text("All Briefings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .toggleStyle(.switch)
            .tint(Theme.Colors.rosePrimary)

            if scheduler.isEnabled {
                BriefingToggle(
                    icon: "\u{2600}\u{FE0F}",
                    title: "Morning Briefing",
                    subtitle: "Weekdays 7:30 AM",
                    isOn: $scheduler.morningEnabled
                )
                BriefingToggle(
                    icon: "\u{1F319}",
                    title: "Evening Wind-Down",
                    subtitle: "Daily 9:00 PM",
                    isOn: $scheduler.eveningEnabled
                )
                BriefingToggle(
                    icon: "\u{1F4C5}",
                    title: "Sunday Weekly Plan",
                    subtitle: "Sundays 7:00 PM",
                    isOn: $scheduler.sundayPlanEnabled
                )
                BriefingToggle(
                    icon: "\u{26A0}\u{FE0F}",
                    title: "Deadline Warnings",
                    subtitle: "3 days, 1 day, and morning of",
                    isOn: $scheduler.deadlineWarningsEnabled
                )
            }
        }
        .glassCard(padding: 10)
    }
}

// MARK: - Briefing Toggle Row

struct BriefingToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textXSoft)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(Theme.Colors.rosePrimary)
                .scaleEffect(0.8)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Quick Message Chip

struct QuickMessageChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.7))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
