import SwiftUI

// MARK: - Wellness View (Phase 6)
// Health dashboard + mood tracker

struct WellnessView: View {
    @State private var viewModel = WellnessViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("WELLNESS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("Health & Wellbeing")
                        .font(.custom("PlayfairDisplay-Italic", size: 20))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

                // Mood tracker
                MoodCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Health metrics grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    HealthMetricCard(
                        icon: "🚶",
                        label: "Steps",
                        value: "\(viewModel.steps)",
                        goal: "10,000",
                        progress: Double(viewModel.steps) / 10000.0,
                        color: Theme.Colors.rosePrimary
                    )
                    HealthMetricCard(
                        icon: "❤️",
                        label: "Heart Rate",
                        value: viewModel.heartRate > 0 ? "\(viewModel.heartRate)" : "--",
                        goal: "bpm",
                        progress: nil,
                        color: Color.red
                    )
                    HealthMetricCard(
                        icon: "😴",
                        label: "Sleep",
                        value: viewModel.sleepHours > 0 ? String(format: "%.1f", viewModel.sleepHours) : "--",
                        goal: "8h goal",
                        progress: viewModel.sleepHours / 8.0,
                        color: Color.indigo
                    )
                    HealthMetricCard(
                        icon: "🔥",
                        label: "Calories",
                        value: "\(viewModel.activeCalories)",
                        goal: "500 goal",
                        progress: Double(viewModel.activeCalories) / 500.0,
                        color: Color.orange
                    )
                }
                .padding(.horizontal, 16)

                // HRV card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("💓").font(.system(size: 14))
                        Text("HRV")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text(viewModel.hrv > 0 ? "\(viewModel.hrv) ms" : "No data")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    Text("Heart Rate Variability — higher is generally better for recovery")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
                .padding(12)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)

                // Wellness tip
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("💡").font(.system(size: 12))
                        Text("WELLNESS TIP")
                            .font(.custom("CormorantGaramond-SemiBold", size: 10))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    Text(viewModel.wellnessTip)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .padding(12)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)

                // HealthKit status
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("HEALTHKIT")
                            .font(.custom("CormorantGaramond-SemiBold", size: 10))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        if viewModel.isHealthKitAvailable {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Connected")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                            }
                        } else {
                            Button("Connect") {
                                Task { await viewModel.requestAccess() }
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        }
                    }
                    Text("Grant Health access in System Settings for live data")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
                .padding(12)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .task { await viewModel.loadData() }
    }
}

// MARK: - Mood Card
struct MoodCard: View {
    let viewModel: WellnessViewModel

    let moods: [(emoji: String, label: String)] = [
        ("😊", "Great"),
        ("🙂", "Good"),
        ("😐", "Okay"),
        ("😔", "Low"),
        ("😢", "Tough")
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text("How are you feeling, Miss M?")
                .font(.custom("PlayfairDisplay-Italic", size: 14))
                .foregroundColor(Theme.Colors.textPrimary)

            HStack(spacing: 12) {
                ForEach(moods, id: \.label) { mood in
                    Button(action: { viewModel.logMood(mood.label) }) {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.system(size: 24))
                                .scaleEffect(viewModel.currentMood == mood.label ? 1.2 : 1.0)
                            Text(mood.label)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(viewModel.currentMood == mood.label ? Theme.Colors.rosePrimary : Theme.Colors.textSoft)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let mood = viewModel.currentMood {
                Text("Feeling \(mood.lowercased()) today")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }
        }
        .padding(14)
        .background(Theme.Gradients.heroCard)
        .foregroundColor(.white)
        .cornerRadius(Theme.Radius.md)
    }
}

// MARK: - Health Metric Card
struct HealthMetricCard: View {
    let icon: String
    let label: String
    let value: String
    let goal: String
    let progress: Double?
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(icon).font(.system(size: 14))
                Spacer()
                if let progress {
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 3)
                            .frame(width: 24, height: 24)
                        Circle()
                            .trim(from: 0, to: min(progress, 1))
                            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 24, height: 24)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("/ \(goal)")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .glassCard(padding: 0)
    }
}

// MARK: - Wellness ViewModel
@Observable
class WellnessViewModel {
    var steps: Int = 0
    var heartRate: Int = 0
    var sleepHours: Double = 0
    var hrv: Int = 0
    var activeCalories: Int = 0
    var currentMood: String? = nil
    var isHealthKitAvailable = false

    var wellnessTip: String {
        if let mood = currentMood {
            switch mood {
            case "Great", "Good": return "You're doing well! Keep the positive energy going. Maybe a short walk to maintain your streak? 🌟"
            case "Okay": return "A balanced day. Try a 5-minute breathing exercise or a cup of tea to lift your spirits. 🍵"
            case "Low", "Tough": return "Be kind to yourself, Miss M. Rest is productive too. Maybe reach out to NyRiian or listen to your favourite playlist. 💕"
            default: return "Take a moment to check in with yourself today."
            }
        }
        return "Log your mood above to get personalised wellness tips."
    }

    func loadData() async {
        // HealthKit requires macOS with proper entitlements
        // Data will populate when running on a real Mac with HealthKit access
        // For now, the UI is ready and waiting for HealthService integration
    }

    func requestAccess() async {
        // Will connect to HealthService.shared.requestAuthorization()
        // when running on macOS with HealthKit entitlements
    }

    func logMood(_ mood: String) {
        currentMood = mood
    }
}
