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
    @State private var showContent = false

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
                }
                .padding(.horizontal, 14)

                if vm.isLoading {
                    // Skeleton Loading State
                    VStack(spacing: 12) {
                        SkeletonView(height: 110, cornerRadius: Theme.Radius.lg)
                            .padding(.horizontal, 14)
                        HStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonView(height: 90, cornerRadius: 12)
                            }
                        }
                        .padding(.horizontal, 14)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(0..<6, id: \.self) { _ in
                                SkeletonView(height: 70, cornerRadius: 10)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                } else {
                    // Hero Card (with pulse animation)
                    HeroHealthCard(vm: vm)
                        .staggerAppear(index: 0)
                        .padding(.horizontal, 14)

                    // Activity Rings (animated fill)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\u{1F3AF} ACTIVITY RINGS")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)

                        HStack(spacing: 12) {
                            AnimatedActivityRing(
                                targetProgress: Double(vm.calories) / Double(vm.caloriesGoal),
                                color: Color(hex: "#FF2D55"),
                                icon: "\u{1F525}",
                                value: vm.calories,
                                label: "Move",
                                unit: "cal"
                            )
                            AnimatedActivityRing(
                                targetProgress: Double(vm.exerciseMinutes) / Double(vm.exerciseGoal),
                                color: Color(hex: "#76FF03"),
                                icon: "\u{1F3C3}",
                                value: vm.exerciseMinutes,
                                label: "Exercise",
                                unit: "min"
                            )
                            AnimatedActivityRing(
                                targetProgress: Double(vm.standHours) / Double(vm.standGoal),
                                color: Color(hex: "#00E5FF"),
                                icon: "\u{1F9CD}",
                                value: vm.standHours,
                                label: "Stand",
                                unit: "hrs"
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                    .staggerAppear(index: 1)

                    // Metrics Grid (rich cards)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        AnimatedMetricCard(icon: "\u{1F6B6}", value: vm.steps, label: "Steps", progress: Double(vm.steps) / Double(vm.stepsGoal), color: "#26A69A", index: 0)
                        AnimatedMetricCard(icon: "\u{2764}\u{FE0F}", value: Int(vm.heartRate), label: "Heart Rate", progress: min(vm.heartRate / 120, 1), color: "#FF2D55", index: 1, suffix: "bpm")
                        AnimatedMetricCard(icon: "\u{1F9D8}", value: vm.mindfulMinutes, label: "Mindful", progress: Double(vm.mindfulMinutes) / 15, color: "#7C4DFF", index: 2, suffix: "min")
                        AnimatedMetricCard(icon: "\u{1F525}", value: vm.calories, label: "Calories", progress: Double(vm.calories) / Double(vm.caloriesGoal), color: "#FF9800", index: 3)
                        AnimatedMetricCard(icon: "\u{1F4A7}", value: vm.waterMl, label: "Water", progress: Double(vm.waterMl) / Double(vm.waterGoal), color: "#00B0FF", index: 4, suffix: "ml")
                        AnimatedMetricCard(icon: "\u{1F4C8}", value: Int(vm.hrv), label: "HRV", progress: min(vm.hrv / 80, 1), color: "#E91E8C", index: 5, suffix: "ms")
                    }
                    .padding(.horizontal, 14)

                    // Sleep Week Chart (animated bars)
                    AnimatedSleepChart(sleepWeek: vm.sleepWeek, sleepGoal: vm.sleepGoal)
                        .padding(.horizontal, 14)
                        .staggerAppear(index: 3)

                    // AI Insight
                    if !vm.aiInsight.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("\u{2728}")
                                    .font(.system(size: 14))
                                    .pulseGlow(Theme.Colors.gold, radius: 8)
                                Text("AI HEALTH INSIGHT")
                                    .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.textSoft)
                            }
                            Text(vm.aiInsight)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineSpacing(3)
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                        .staggerAppear(index: 4)
                    }

                    Spacer().frame(height: 14)
                }
            }
            .padding(.top, 10)
        }
        .task {
            await vm.loadAll()
            await vm.generateInsight()
        }
    }
}

// MARK: - Hero Health Card (with pulse heart)

struct HeroHealthCard: View {
    let vm: WellnessDashboardViewModel
    @State private var heartPulse = false

    var body: some View {
        VStack(spacing: 8) {
            Text("\u{2764}\u{FE0F}")
                .font(.system(size: 24))
                .scaleEffect(heartPulse ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: heartPulse)

            Text("Your Health Today")
                .font(Theme.Fonts.display(16))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                HeroStatAnimated(value: String(format: "%.1f", vm.sleepHours), label: "Sleep", unit: "h", index: 0)
                HeroStatAnimated(value: "\(vm.steps)", label: "Steps", unit: "", index: 1)
                HeroStatAnimated(value: "\(Int(vm.heartRate))", label: "BPM", unit: "", index: 2)
                HeroStatAnimated(value: "\(Int(vm.hrv))", label: "HRV", unit: "ms", index: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Theme.Gradients.heroCard)
        .cornerRadius(Theme.Radius.lg)
        .shadow(color: Theme.Colors.roseDeep.opacity(0.3), radius: 12, x: 0, y: 6)
        .onAppear { heartPulse = true }
    }
}

struct HeroStatAnimated: View {
    let value: String
    let label: String
    let unit: String
    let index: Int
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(Double(index) * 0.1)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Animated Activity Ring

struct AnimatedActivityRing: View {
    let targetProgress: Double
    let color: Color
    let icon: String
    let value: Int
    let label: String
    let unit: String
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 6)
                    .frame(width: 50, height: 50)

                // Animated progress ring with glow
                Circle()
                    .trim(from: 0, to: min(animatedProgress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: 4)

                Text(icon).font(.system(size: 14))
            }

            AnimatedCounter(value: value, font: .system(size: 11, weight: .bold), color: Theme.Colors.textPrimary)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textSoft)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedProgress = targetProgress
            }
        }
    }
}

// MARK: - Animated Metric Card

struct AnimatedMetricCard: View {
    let icon: String
    let value: Int
    let label: String
    let progress: Double
    let color: String
    let index: Int
    var suffix: String = ""
    @State private var animatedProgress: Double = 0
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 16))
            HStack(spacing: 1) {
                AnimatedCounter(value: value, font: .system(size: 13, weight: .bold), color: Theme.Colors.textPrimary)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 8))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textSoft)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color).opacity(0.12))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color))
                        .frame(width: geo.size.width * min(animatedProgress, 1), height: 3)
                        .shadow(color: Color(hex: color).opacity(0.3), radius: 2)
                }
            }
            .frame(height: 3)
        }
        .padding(8)
        .background(Color.white.opacity(0.6))
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: color).opacity(0.15), lineWidth: 1))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(Double(index) * 0.06)) {
                isVisible = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3 + Double(index) * 0.06)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Animated Sleep Chart

struct AnimatedSleepChart: View {
    let sleepWeek: [Double]
    let sleepGoal: Double
    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\u{1F634} SLEEP THIS WEEK")
                    .font(.custom("CormorantGaramond-SemiBold", size: 11))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Text("Avg: \(String(format: "%.1f", sleepWeek.isEmpty ? 0 : sleepWeek.reduce(0, +) / Double(sleepWeek.count)))h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }

            ZStack(alignment: .bottom) {
                // Goal line
                GeometryReader { geo in
                    let goalY = geo.size.height - (CGFloat(sleepGoal / 10) * geo.size.height)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: goalY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(Theme.Colors.roseLight)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    let days = ["M", "T", "W", "T", "F", "S", "S"]
                    ForEach(Array(sleepWeek.enumerated()), id: \.offset) { i, hours in
                        let isToday = i == sleepWeek.count - 1
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    hours >= sleepGoal
                                    ? Theme.Gradients.rosePrimary
                                    : LinearGradient(colors: [Theme.Colors.rosePale], startPoint: .bottom, endPoint: .top)
                                )
                                .frame(height: max(4, barHeights[i]))
                                .shadow(color: isToday ? Theme.Colors.rosePrimary.opacity(0.3) : Color.clear, radius: 4)

                            Text(i < days.count ? days[i] : "")
                                .font(.system(size: 8, weight: isToday ? .bold : .regular))
                                .foregroundColor(isToday ? Theme.Colors.rosePrimary : Theme.Colors.textXSoft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 60)
        }
        .glassCard(padding: 10)
        .onAppear {
            for (i, hours) in sleepWeek.enumerated() {
                withAnimation(.easeOut(duration: 0.6).delay(Double(i) * 0.05)) {
                    barHeights[i] = max(4, CGFloat(hours / 10) * 50)
                }
            }
        }
    }
}
