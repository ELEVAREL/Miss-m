import SwiftUI

// MARK: - Workout Models

enum WorkoutType: String, CaseIterable, Codable {
    case strength = "Strength"
    case cardio = "Cardio"
    case yoga = "Yoga"
    case hiit = "HIIT"
    case walking = "Walking"
    case rest = "Rest Day"

    var icon: String {
        switch self {
        case .strength: return "\u{1F4AA}"
        case .cardio: return "\u{1F3C3}\u{200D}\u{2640}\u{FE0F}"
        case .yoga: return "\u{1F9D8}\u{200D}\u{2640}\u{FE0F}"
        case .hiit: return "\u{26A1}"
        case .walking: return "\u{1F6B6}\u{200D}\u{2640}\u{FE0F}"
        case .rest: return "\u{1F4A4}"
        }
    }

    var color: Color {
        switch self {
        case .strength: return Color(hex: "#E91E8C")
        case .cardio: return Color(hex: "#FF6B9D")
        case .hiit: return Color(hex: "#FF9800")
        case .yoga: return Color(hex: "#7C4DFF")
        case .walking: return Color(hex: "#26A69A")
        case .rest: return Color(hex: "#90A4AE")
        }
    }
}

struct DayWorkout: Identifiable, Codable {
    let id: UUID
    var day: String
    var type: WorkoutType
    var title: String
    var duration: Int // minutes
    var exercises: [String]

    init(id: UUID = UUID(), day: String, type: WorkoutType, title: String, duration: Int, exercises: [String]) {
        self.id = id; self.day = day; self.type = type; self.title = title
        self.duration = duration; self.exercises = exercises
    }
}

struct FitnessPlan: Codable {
    var weekWorkouts: [DayWorkout] = []
    var generatedDate: Date = Date()
    var cyclePhaseWhenGenerated: String = ""
}

// MARK: - Fitness ViewModel

@Observable
class FitnessViewModel {
    var plan = FitnessPlan()
    var isGenerating = false
    var selectedDay: DayWorkout?
    var energyLevel: Int = 3 // 1-5
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await load() }
    }

    func generatePlan(cyclePhase: CyclePhase, sleepHours: Double) async {
        isGenerating = true
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        let prompt = """
        Generate a 7-day fitness plan for Miss M. She is a university student who is busy with classes and studying.

        Current cycle phase: \(cyclePhase.rawValue)
        Last night's sleep: \(String(format: "%.1f", sleepHours)) hours
        Energy level: \(energyLevel)/5

        Cycle-aware guidelines:
        - Menstrual phase: Gentle movement only — yoga, light walking, stretching. Focus on recovery.
        - Follicular phase: Energy is rising — mix of strength and cardio, moderate intensity.
        - Ovulation phase: Peak energy — HIIT, intense strength, challenging cardio.
        - Luteal phase: Gradually reduce intensity — yoga, walking, light strength. More rest days.

        Return EXACTLY this JSON format (no markdown, no code fences, just raw JSON):
        [
            {
                "day": "\(days[0])",
                "type": "yoga",
                "title": "Morning Flow",
                "duration": 30,
                "exercises": ["Sun Salutation x5", "Warrior sequence", "Cool down stretches"]
            }
        ]

        Valid types: strength, cardio, yoga, hiit, walking, rest
        Include 7 entries, one per day. Keep durations between 15-45 minutes. She's busy!
        Include 3-5 specific exercises per workout. Make rest days have ["Rest", "Light stretching if desired"].
        """

        do {
            let response = try await claudeService.ask(prompt)
            if let data = response.data(using: .utf8),
               let workouts = try? JSONDecoder().decode([DayWorkout].self, from: data) {
                plan.weekWorkouts = workouts
                plan.generatedDate = Date()
                plan.cyclePhaseWhenGenerated = cyclePhase.rawValue
                save()
            }
        } catch {
            // Fallback plan
        }
        isGenerating = false
    }

    func load() async {
        plan = await DataStore.shared.loadOrDefault(FitnessPlan.self, from: "fitness-plan.json", default: FitnessPlan())
    }

    func save() {
        Task { try? await DataStore.shared.save(plan, to: "fitness-plan.json") }
    }
}

// MARK: - Fitness View

struct FitnessView: View {
    let claudeService: ClaudeService
    @State private var vm: FitnessViewModel
    @State private var cyclePhase: CyclePhase = .follicular
    @State private var sleepHours: Double = 7.0

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._vm = State(initialValue: FitnessViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Smart Fitness")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    if !vm.plan.weekWorkouts.isEmpty {
                        Text(vm.plan.cyclePhaseWhenGenerated)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.rosePrimary.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 14)

                // Energy Level
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{26A1} ENERGY LEVEL")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { level in
                            Button(action: { vm.energyLevel = level }) {
                                VStack(spacing: 2) {
                                    Text(energyEmoji(level))
                                        .font(.system(size: 20))
                                    Text(energyLabel(level))
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundColor(vm.energyLevel == level ? .white : Theme.Colors.textXSoft)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(vm.energyLevel == level ? AnyView(Theme.Gradients.rosePrimary) : AnyView(Color.white.opacity(0.6)))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: vm.energyLevel == level ? 0 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Generate Button
                if vm.plan.weekWorkouts.isEmpty || vm.isGenerating {
                    VStack(spacing: 10) {
                        if vm.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Creating your personalized plan...")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        } else {
                            Text("Generate a cycle-aware fitness plan tailored to your energy and schedule")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textMedium)
                                .multilineTextAlignment(.center)
                            Button(action: {
                                Task { await vm.generatePlan(cyclePhase: cyclePhase, sleepHours: sleepHours) }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("Generate Fitness Plan")
                                }
                                .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(RoseButtonStyle())
                        }
                    }
                    .glassCard(padding: 16)
                    .padding(.horizontal, 14)
                }

                // Weekly Plan Grid
                if !vm.plan.weekWorkouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\u{1F4C5} THIS WEEK")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Button(action: {
                                Task { await vm.generatePlan(cyclePhase: cyclePhase, sleepHours: sleepHours) }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh")
                                }
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(vm.plan.weekWorkouts) { workout in
                            Button(action: { vm.selectedDay = workout }) {
                                HStack(spacing: 10) {
                                    Text(workout.type.icon)
                                        .font(.system(size: 20))
                                        .frame(width: 36, height: 36)
                                        .background(workout.type.color.opacity(0.15))
                                        .cornerRadius(10)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(workout.day)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text(workout.title)
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.Colors.textMedium)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(workout.type.rawValue)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(workout.type.color)
                                        Text("\(workout.duration)m")
                                            .font(.system(size: 9))
                                            .foregroundColor(Theme.Colors.textXSoft)
                                    }
                                }
                                .padding(8)
                                .background(
                                    vm.selectedDay?.id == workout.id
                                    ? AnyView(workout.type.color.opacity(0.08))
                                    : AnyView(Color.clear)
                                )
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // Workout Detail
                if let selected = vm.selectedDay {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selected.type.icon)
                                .font(.system(size: 18))
                            Text(selected.title.uppercased())
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Text("\(selected.duration) min")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selected.type.color)
                        }

                        ForEach(Array(selected.exercises.enumerated()), id: \.offset) { index, exercise in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(selected.type.color)
                                    .cornerRadius(9)
                                Text(exercise)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                            }
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
        .task {
            // Load cycle phase from stored data
            let cycleData = await DataStore.shared.loadOrDefault(CycleData.self, from: "cycle.json", default: CycleData())
            for phase in CyclePhase.allCases where phase.typicalDays.contains(cycleData.currentDay) {
                cyclePhase = phase
                break
            }
            sleepHours = await HealthService.shared.sleepHoursLastNight()
        }
    }

    func energyEmoji(_ level: Int) -> String {
        switch level {
        case 1: return "\u{1F634}"
        case 2: return "\u{1F971}"
        case 3: return "\u{1F642}"
        case 4: return "\u{1F60A}"
        case 5: return "\u{1F525}"
        default: return "\u{1F642}"
        }
    }

    func energyLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Exhausted"
        case 2: return "Low"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Okay"
        }
    }
}
