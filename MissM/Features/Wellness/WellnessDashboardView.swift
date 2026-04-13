import SwiftUI

// MARK: - Wellness Dashboard ViewModel

@Observable
class WellnessDashboardViewModel {
    var steps = 0
    var heartRate = 0.0
    var hrv = 0.0
    var calories = 0
    var exerciseMinutes = 0
    var standHours = 0
    var sleepHours = 0.0
    var mindfulMinutes = 0
    var waterMl = 0
    var sleepWeek: [Double] = []
    var heartRateSamples: [(Date, Double)] = []
    var isLoading = true
    var aiInsight = ""
    private let claudeService: ClaudeService

    // Goals
    let stepsGoal = 8000
    let caloriesGoal = 400
    let exerciseGoal = 30
    let standGoal = 12
    let sleepGoal = 8.0
    let waterGoal = 2000

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func loadAll() async {
        isLoading = true
        let health = HealthService.shared
        if !health.isAuthorized {
            _ = await health.requestAccess()
        }

        async let s = health.stepsToday()
        async let hr = health.latestHeartRate()
        async let h = health.latestHRV()
        async let c = health.caloriesToday()
        async let e = health.exerciseMinutesToday()
        async let st = health.standHoursToday()
        async let sl = health.sleepHoursLastNight()
        async let m = health.mindfulMinutesToday()
        async let w = health.waterToday()
        async let sw = health.sleepDataForWeek()
        async let hrs = health.heartRateSamplesToday()

        steps = await s
        heartRate = await hr
        hrv = await h
        calories = await c
        exerciseMinutes = await e
        standHours = await st
        sleepHours = await sl
        mindfulMinutes = await m
        waterMl = await w
        sleepWeek = await sw
        heartRateSamples = await hrs
        isLoading = false
    }

    func generateInsight() async {
        let summary = """
        Steps: \(steps)/\(stepsGoal), Heart rate: \(Int(heartRate))bpm, HRV: \(Int(hrv))ms,
        Sleep: \(String(format: "%.1f", sleepHours))h, Calories: \(calories)/\(caloriesGoal),
        Exercise: \(exerciseMinutes)/\(exerciseGoal)min, Water: \(waterMl)ml
        """
        do {
            aiInsight = try await claudeService.ask("Give Miss M a brief, encouraging health insight (3 sentences max) based on today's data:\n\(summary)")
        } catch {
            aiInsight = "Keep going, Miss M! Every step counts."
        }
    }
}

// MARK: - Wellness Dashboard View

struct WellnessDashboardView: View {
    let claudeService: ClaudeService
    @State private var vm: WellnessDashboardViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._vm = State(initialValue: WellnessDashboardViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Wellness")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.6)
                    }
                }
                .padding(.horizontal, 14)

                // Hero Card
                VStack(spacing: 6) {
                    Text("\u{2764}\u{FE0F}")
                        .font(.system(size: 24))
                    Text("Your Health Today")
                        .font(Theme.Fonts.display(16))
                        .foregroundColor(.white)
                    HStack(spacing: 16) {
                        HeroStat(value: "\(String(format: "%.1f", vm.sleepHours))h", label: "Sleep")
                        HeroStat(value: "\(vm.steps)", label: "Steps")
                        HeroStat(value: "\(Int(vm.heartRate))", label: "BPM")
                        HeroStat(value: "\(Int(vm.hrv))", label: "HRV")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(Theme.Radius.lg)
                .padding(.horizontal, 14)

                // Activity Rings
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{1F3AF} ACTIVITY RINGS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    HStack(spacing: 12) {
                        ActivityRing(
                            progress: Double(vm.calories) / Double(vm.caloriesGoal),
                            color: Color(hex: "#FF2D55"),
                            icon: "\u{1F525}",
                            value: "\(vm.calories)",
                            label: "Move"
                        )
                        ActivityRing(
                            progress: Double(vm.exerciseMinutes) / Double(vm.exerciseGoal),
                            color: Color(hex: "#76FF03"),
                            icon: "\u{1F3C3}",
                            value: "\(vm.exerciseMinutes)m",
                            label: "Exercise"
                        )
                        ActivityRing(
                            progress: Double(vm.standHours) / Double(vm.standGoal),
                            color: Color(hex: "#00E5FF"),
                            icon: "\u{1F9CD}",
                            value: "\(vm.standHours)h",
                            label: "Stand"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    MetricCard(icon: "\u{1F6B6}", value: "\(vm.steps)", label: "Steps", progress: Double(vm.steps) / Double(vm.stepsGoal), color: "#26A69A")
                    MetricCard(icon: "\u{2764}\u{FE0F}", value: "\(Int(vm.heartRate))", label: "Heart Rate", progress: min(vm.heartRate / 120, 1), color: "#FF2D55")
                    MetricCard(icon: "\u{1F9D8}", value: "\(vm.mindfulMinutes)m", label: "Mindful", progress: Double(vm.mindfulMinutes) / 15, color: "#7C4DFF")
                    MetricCard(icon: "\u{1F525}", value: "\(vm.calories)", label: "Calories", progress: Double(vm.calories) / Double(vm.caloriesGoal), color: "#FF9800")
                    MetricCard(icon: "\u{1F4A7}", value: "\(vm.waterMl)ml", label: "Water", progress: Double(vm.waterMl) / Double(vm.waterGoal), color: "#00B0FF")
                    MetricCard(icon: "\u{1F4C8}", value: "\(Int(vm.hrv))ms", label: "HRV", progress: min(vm.hrv / 80, 1), color: "#E91E8C")
                }
                .padding(.horizontal, 14)

                // Sleep Week Chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\u{1F634} SLEEP THIS WEEK")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Text("Avg: \(String(format: "%.1f", vm.sleepWeek.isEmpty ? 0 : vm.sleepWeek.reduce(0, +) / Double(vm.sleepWeek.count)))h")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }

                    HStack(alignment: .bottom, spacing: 4) {
                        let days = ["M", "T", "W", "T", "F", "S", "S"]
                        ForEach(Array(vm.sleepWeek.enumerated()), id: \.offset) { i, hours in
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(hours >= vm.sleepGoal ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Theme.Colors.rosePale], startPoint: .bottom, endPoint: .top))
                                    .frame(height: max(4, CGFloat(hours / 10) * 50))
                                Text(i < days.count ? days[i] : "")
                                    .font(.system(size: 8))
                                    .foregroundColor(Theme.Colors.textXSoft)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 60)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // AI Insight
                if !vm.aiInsight.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\u{2728} AI HEALTH INSIGHT")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text(vm.aiInsight)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineSpacing(3)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
        .task {
            await vm.loadAll()
            await vm.generateInsight()
        }
    }
}

// MARK: - Hero Stat

struct HeroStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Activity Ring

struct ActivityRing: View {
    let progress: Double
    let color: Color
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Text(icon).font(.system(size: 14))
            }
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    let progress: Double
    let color: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 16))
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textSoft)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: color).opacity(0.15)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: color)).frame(width: geo.size.width * min(progress, 1), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(8)
        .background(Color.white.opacity(0.6))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 0.5))
    }
}
