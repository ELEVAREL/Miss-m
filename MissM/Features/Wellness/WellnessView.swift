import SwiftUI
import HealthKit

// MARK: - Wellness Dashboard View
// Phase 6 — Health data cards, activity ring, mood tracker, wellness summary

struct WellnessView: View {
    @State private var healthService = HealthService.shared
    @State private var selectedMood: MoodLevel? = nil
    @State private var moodNote = ""
    @State private var showMoodSaved = false
    @State private var isLoading = true
    @State private var showPermissionRequest = false

    private let stepsGoal: Double = 10_000
    private let caloriesGoal: Double = 500
    private let sleepGoal: Double = 8.0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.md) {
                // Hero header
                wellnessHeader

                if showPermissionRequest {
                    permissionCard
                } else {
                    // Activity ring + key stats
                    activityRingCard

                    // Health metric cards grid
                    healthMetricsGrid

                    // Mood tracker
                    moodTrackerCard

                    // Wellness summary
                    wellnessSummaryCard
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Gradients.background.ignoresSafeArea())
        .task {
            await loadHealthData()
        }
    }

    // MARK: - Hero Header

    private var wellnessHeader: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("Wellness")
                .font(.custom("PlayfairDisplay-Italic", size: 20))
                .foregroundColor(Theme.Colors.rosePrimary)

            Text("YOUR DAILY HEALTH")
                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                .tracking(2.5)
                .foregroundColor(Theme.Colors.textSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Permission Request Card

    private var permissionCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Gradients.rosePrimary)

            Text("Health Access Needed")
                .font(.custom("PlayfairDisplay-Italic", size: 18))
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Miss M needs access to your health data to show your wellness dashboard with steps, heart rate, sleep, and more.")
                .font(Theme.Fonts.body(12))
                .foregroundColor(Theme.Colors.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            Button(action: {
                Task {
                    do {
                        try await healthService.requestAuthorization()
                        showPermissionRequest = false
                        await healthService.refreshAll()
                        isLoading = false
                    } catch {
                        // Permission denied — stay on permission card
                    }
                }
            }) {
                Text("Grant Health Access")
                    .font(Theme.Fonts.body(13, weight: .semibold))
            }
            .buttonStyle(RoseButtonStyle())
        }
        .glassCard()
    }

    // MARK: - Activity Ring Card

    private var activityRingCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("TODAY'S ACTIVITY")
                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                .tracking(2.5)
                .foregroundColor(Theme.Colors.textSoft)

            HStack(spacing: Theme.Spacing.xl) {
                // Circular progress ring for steps
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Theme.Colors.rosePale, lineWidth: 10)
                        .frame(width: 100, height: 100)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(healthService.todaySteps / stepsGoal, 1.0))
                        .stroke(
                            Theme.Gradients.heroCard,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: healthService.todaySteps)

                    // Inner content
                    VStack(spacing: 2) {
                        Text("\(Int(healthService.todaySteps))")
                            .font(Theme.Fonts.body(18, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("steps")
                            .font(Theme.Fonts.body(10))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                }

                // Side stats
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    activityStatRow(
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(healthService.todayActiveCalories))",
                        unit: "kcal",
                        color: Color(hex: "#FF6B35")
                    )
                    activityStatRow(
                        icon: "bed.double.fill",
                        label: "Sleep",
                        value: formatSleepHours(healthService.todaySleepHours),
                        unit: "",
                        color: Color(hex: "#5C6BC0")
                    )
                    activityStatRow(
                        icon: "brain.head.profile",
                        label: "Mindful",
                        value: "\(Int(healthService.todayMindfulMinutes))",
                        unit: "min",
                        color: Color(hex: "#26A69A")
                    )
                }
            }

            // Steps progress bar label
            HStack {
                Text("\(Int(min(healthService.todaySteps / stepsGoal * 100, 100)))% of daily goal")
                    .font(Theme.Fonts.body(11))
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Text("\(Int(stepsGoal)) steps")
                    .font(Theme.Fonts.body(11))
                    .foregroundColor(Theme.Colors.textXSoft)
            }
        }
        .glassCard()
    }

    private func activityStatRow(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Theme.Fonts.body(10))
                    .foregroundColor(Theme.Colors.textSoft)
                HStack(spacing: 3) {
                    Text(value)
                        .font(Theme.Fonts.body(14, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(Theme.Fonts.body(10))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                }
            }
        }
    }

    // MARK: - Health Metrics Grid

    private var healthMetricsGrid: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("VITAL SIGNS")
                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                .tracking(2.5)
                .foregroundColor(Theme.Colors.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.Spacing.sm) {
                metricCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: healthService.latestHeartRate > 0 ? "\(Int(healthService.latestHeartRate))" : "--",
                    unit: "bpm",
                    iconColor: Color(hex: "#E53935"),
                    progress: min(healthService.latestHeartRate / 180, 1.0)
                )

                metricCard(
                    icon: "waveform.path.ecg",
                    title: "HRV",
                    value: healthService.latestHRV > 0 ? "\(Int(healthService.latestHRV))" : "--",
                    unit: "ms",
                    iconColor: Color(hex: "#7E57C2"),
                    progress: min(healthService.latestHRV / 100, 1.0)
                )
            }

            HStack(spacing: Theme.Spacing.sm) {
                metricCard(
                    icon: "flame.fill",
                    title: "Active Cal",
                    value: "\(Int(healthService.todayActiveCalories))",
                    unit: "kcal",
                    iconColor: Color(hex: "#FF6B35"),
                    progress: min(healthService.todayActiveCalories / caloriesGoal, 1.0)
                )

                metricCard(
                    icon: "moon.zzz.fill",
                    title: "Sleep",
                    value: healthService.todaySleepHours > 0 ? String(format: "%.1f", healthService.todaySleepHours) : "--",
                    unit: "hrs",
                    iconColor: Color(hex: "#5C6BC0"),
                    progress: min(healthService.todaySleepHours / sleepGoal, 1.0)
                )
            }
        }
    }

    private func metricCard(icon: String, title: String, value: String, unit: String, iconColor: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
                    .frame(width: 22, height: 22)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(Theme.Fonts.body(11))
                    .foregroundColor(Theme.Colors.textSoft)
            }

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.Fonts.body(22, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(unit)
                    .font(Theme.Fonts.body(11))
                    .foregroundColor(Theme.Colors.textXSoft)
            }

            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.rosePale)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(iconColor)
                        .frame(width: geometry.size.width * max(0, min(progress, 1.0)), height: 4)
                        .animation(.easeInOut(duration: 0.8), value: progress)
                }
            }
            .frame(height: 4)
        }
        .glassCard(padding: 12)
    }

    // MARK: - Mood Tracker Card

    private var moodTrackerCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("MOOD CHECK-IN")
                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                .tracking(2.5)
                .foregroundColor(Theme.Colors.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showMoodSaved {
                // Saved confirmation
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Mood logged! Take care, Miss M")
                        .font(Theme.Fonts.body(13))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Mood selection row
                Text("How are you feeling right now?")
                    .font(Theme.Fonts.body(13))
                    .foregroundColor(Theme.Colors.textMedium)

                HStack(spacing: Theme.Spacing.md) {
                    ForEach(MoodLevel.allCases) { mood in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMood = mood
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.system(size: selectedMood == mood ? 28 : 22))
                                    .scaleEffect(selectedMood == mood ? 1.1 : 1.0)

                                Text(mood.label)
                                    .font(Theme.Fonts.body(9))
                                    .foregroundColor(
                                        selectedMood == mood
                                        ? Theme.Colors.rosePrimary
                                        : Theme.Colors.textXSoft
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                selectedMood == mood
                                ? Theme.Colors.rosePale
                                : Color.clear
                            )
                            .cornerRadius(Theme.Radius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(
                                        selectedMood == mood
                                        ? Theme.Colors.rosePrimary.opacity(0.4)
                                        : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3), value: selectedMood)
                    }
                }

                // Optional note + save button
                if selectedMood != nil {
                    VStack(spacing: Theme.Spacing.sm) {
                        TextField("Add a note (optional)...", text: $moodNote)
                            .textFieldStyle(.plain)
                            .font(Theme.Fonts.body(12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(Theme.Radius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(Theme.Colors.roseLight, lineWidth: 1)
                            )

                        Button(action: {
                            Task { await saveMood() }
                        }) {
                            Text("Log Mood")
                                .font(Theme.Fonts.body(13, weight: .semibold))
                        }
                        .buttonStyle(RoseButtonStyle())
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .glassCard()
    }

    // MARK: - Wellness Summary Card

    private var wellnessSummaryCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("DAILY SUMMARY")
                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                .tracking(2.5)
                .foregroundColor(Theme.Colors.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                summaryRow(icon: "figure.walk", text: stepsInsight)
                summaryRow(icon: "bed.double.fill", text: sleepInsight)
                summaryRow(icon: "heart.fill", text: heartRateInsight)

                if healthService.todayMindfulMinutes > 0 {
                    summaryRow(
                        icon: "brain.head.profile",
                        text: "You've had \(Int(healthService.todayMindfulMinutes)) mindful minutes today."
                    )
                }
            }
        }
        .glassCard()
        .padding(.bottom, Theme.Spacing.lg)
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.roseMid)
                .frame(width: 20)
            Text(text)
                .font(Theme.Fonts.body(12))
                .foregroundColor(Theme.Colors.textMedium)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Insight Strings

    private var stepsInsight: String {
        let steps = Int(healthService.todaySteps)
        let percentage = Int(min(healthService.todaySteps / stepsGoal * 100, 100))
        if steps == 0 {
            return "No steps recorded yet. Time to get moving, Miss M!"
        } else if percentage >= 100 {
            return "You hit \(steps.formatted()) steps — goal crushed!"
        } else if percentage >= 70 {
            return "\(steps.formatted()) steps so far — almost at your goal (\(percentage)%)!"
        } else {
            return "\(steps.formatted()) steps today (\(percentage)% of goal)."
        }
    }

    private var sleepInsight: String {
        let hours = healthService.todaySleepHours
        if hours == 0 {
            return "No sleep data recorded."
        } else if hours >= 7.5 {
            return "Great rest — \(formatSleepHours(hours)) of sleep last night."
        } else if hours >= 6 {
            return "You got \(formatSleepHours(hours)) of sleep. Try to aim for 7-8 hours."
        } else {
            return "Only \(formatSleepHours(hours)) of sleep. Maybe an early night tonight?"
        }
    }

    private var heartRateInsight: String {
        let hr = Int(healthService.latestHeartRate)
        if hr == 0 {
            return "No heart rate data available."
        } else if hr < 60 {
            return "Resting heart rate is \(hr) bpm — nice and calm."
        } else if hr < 100 {
            return "Heart rate is \(hr) bpm — looking good."
        } else {
            return "Heart rate is \(hr) bpm — you might be active or stressed."
        }
    }

    // MARK: - Helpers

    private func formatSleepHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if m == 0 {
            return "\(h)h"
        }
        return "\(h)h \(m)m"
    }

    private func loadHealthData() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            showPermissionRequest = true
            isLoading = false
            return
        }

        do {
            try await healthService.requestAuthorization()
            await healthService.refreshAll()
            isLoading = false
        } catch {
            showPermissionRequest = true
            isLoading = false
        }
    }

    private func saveMood() async {
        guard let mood = selectedMood else { return }
        do {
            try await healthService.logMood(mood.rawValue, note: moodNote.isEmpty ? nil : moodNote)
            withAnimation(.spring(response: 0.4)) {
                showMoodSaved = true
            }
            // Reset after 3 seconds
            try? await Task.sleep(for: .seconds(3))
            withAnimation {
                showMoodSaved = false
                selectedMood = nil
                moodNote = ""
            }
        } catch {
            // Mood save failed — silently reset
            selectedMood = nil
        }
    }
}
