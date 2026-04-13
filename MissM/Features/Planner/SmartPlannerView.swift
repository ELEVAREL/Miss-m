import SwiftUI

// MARK: - Smart Plan Models

struct SmartDayPlan: Identifiable, Codable {
    let id: UUID
    var date: String
    var dayLabel: String
    var schedule: [PlanBlock]
    var meals: PlanMeals
    var workout: PlanWorkout
    var wellnessTip: String
    var cyclePhase: String

    init(id: UUID = UUID(), date: String, dayLabel: String, schedule: [PlanBlock], meals: PlanMeals, workout: PlanWorkout, wellnessTip: String, cyclePhase: String) {
        self.id = id; self.date = date; self.dayLabel = dayLabel; self.schedule = schedule
        self.meals = meals; self.workout = workout; self.wellnessTip = wellnessTip; self.cyclePhase = cyclePhase
    }
}

struct PlanBlock: Identifiable, Codable {
    let id: UUID
    var time: String
    var activity: String
    var category: String // study, class, meal, workout, rest, errand

    init(id: UUID = UUID(), time: String, activity: String, category: String) {
        self.id = id; self.time = time; self.activity = activity; self.category = category
    }
}

struct PlanMeals: Codable {
    var breakfast: String
    var lunch: String
    var dinner: String
    var snack: String
}

struct PlanWorkout: Codable {
    var type: String
    var title: String
    var duration: Int
}

struct SmartWeekPlan: Codable {
    var days: [SmartDayPlan] = []
    var generatedDate: Date = Date()
}

// MARK: - Smart Planner ViewModel

@Observable
class SmartPlannerViewModel {
    var weekPlan = SmartWeekPlan()
    var isGenerating = false
    var expandedDay: UUID?
    var aiAdjustPrompt = ""
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await load() }
    }

    func generatePlan() async {
        isGenerating = true

        // Gather all data sources
        let calendarSummary = await CalendarService.shared.todaySummary()
        let remindersSummary = await RemindersService.shared.todaySummary()
        let cycleData = await DataStore.shared.loadOrDefault(CycleData.self, from: "cycle.json", default: CycleData())
        let fitnessPlan = await DataStore.shared.loadOrDefault(FitnessPlan.self, from: "fitness-plan.json", default: FitnessPlan())
        let sleepHours = await HealthService.shared.sleepHoursLastNight()
        let steps = await HealthService.shared.stepsToday()

        var cyclePhase = "Unknown"
        for phase in CyclePhase.allCases where phase.typicalDays.contains(cycleData.currentDay) {
            cyclePhase = phase.rawValue
            break
        }

        let workoutSummary = fitnessPlan.weekWorkouts.map { "\($0.day): \($0.type.rawValue) - \($0.title) (\($0.duration)m)" }.joined(separator: "\n")

        let prompt = """
        You are Miss M's life planner AI. Create a comprehensive 7-day smart plan that weaves together ALL aspects of her life.

        CURRENT DATA:
        - Calendar today: \(calendarSummary)
        - Tasks/reminders: \(remindersSummary)
        - Cycle: Day \(cycleData.currentDay) (\(cyclePhase) phase), cycle length \(cycleData.cycleLength)
        - Last night sleep: \(String(format: "%.1f", sleepHours))h
        - Steps today: \(steps)
        - Fitness plan: \(workoutSummary.isEmpty ? "None yet" : workoutSummary)

        RULES:
        - Cycle-aware: During menstrual phase, schedule lighter tasks and comfort meals. During ovulation, schedule demanding tasks.
        - Energy-aware: If sleep was < 7h, ease the morning schedule.
        - Weave meals, study blocks, workouts, and rest naturally.
        - Study blocks should be 25-50 min (Pomodoro style) with breaks.
        - Include healthy meal suggestions that match the cycle phase.

        Return EXACTLY this JSON (no markdown, no fences, raw JSON only):
        [
            {
                "date": "2026-04-13",
                "dayLabel": "Monday",
                "schedule": [
                    {"time": "7:30", "activity": "Wake up + morning routine", "category": "rest"},
                    {"time": "8:00", "activity": "Breakfast", "category": "meal"},
                    {"time": "9:00", "activity": "Marketing lecture", "category": "class"}
                ],
                "meals": {
                    "breakfast": "Overnight oats with berries",
                    "lunch": "Chicken salad wrap",
                    "dinner": "Salmon with roasted vegetables",
                    "snack": "Greek yoghurt with honey"
                },
                "workout": {"type": "yoga", "title": "Morning Flow", "duration": 25},
                "wellnessTip": "You're in your follicular phase — energy is rising! Great time for creative projects.",
                "cyclePhase": "\(cyclePhase)"
            }
        ]

        Generate 7 days starting from today. Valid categories: study, class, meal, workout, rest, errand.
        Keep schedule entries realistic — she's a uni student managing a home.
        """

        do {
            let response = try await claudeService.ask(prompt)
            if let data = response.data(using: .utf8),
               let days = try? JSONDecoder().decode([SmartDayPlan].self, from: data) {
                weekPlan.days = days
                weekPlan.generatedDate = Date()
                save()
            }
        } catch {
            // Keep existing plan if generation fails
        }
        isGenerating = false
    }

    func adjustPlan() async {
        guard !aiAdjustPrompt.isEmpty else { return }
        isGenerating = true
        let currentPlanJSON = (try? JSONEncoder().encode(weekPlan.days)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let prompt = """
        Miss M wants to adjust her smart plan. Here is her current plan:
        \(currentPlanJSON)

        Her request: \(aiAdjustPrompt)

        Return the updated full 7-day plan in the same JSON format. Only change what she asked for.
        Return raw JSON only, no markdown.
        """

        do {
            let response = try await claudeService.ask(prompt)
            if let data = response.data(using: .utf8),
               let days = try? JSONDecoder().decode([SmartDayPlan].self, from: data) {
                weekPlan.days = days
                save()
            }
        } catch { }
        aiAdjustPrompt = ""
        isGenerating = false
    }

    func load() async {
        weekPlan = await DataStore.shared.loadOrDefault(SmartWeekPlan.self, from: "smart-plan.json", default: SmartWeekPlan())
    }

    func save() {
        Task { try? await DataStore.shared.save(weekPlan, to: "smart-plan.json") }
    }
}

// MARK: - Smart Planner View

struct SmartPlannerView: View {
    let claudeService: ClaudeService
    @State private var vm: SmartPlannerViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._vm = State(initialValue: SmartPlannerViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Planner")
                            .font(Theme.Fonts.display(18))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        Text("Your week, intelligently planned")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    Spacer()
                    if vm.isGenerating {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 14)

                // Hero Card — Generate/Regenerate
                VStack(spacing: 10) {
                    if vm.weekPlan.days.isEmpty {
                        Text("\u{1F9E0}")
                            .font(.system(size: 28))
                        Text("Miss M, let me plan your perfect week")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("I'll look at your calendar, cycle, meals, fitness, and tasks to create one smart plan")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\u{2728} Plan Active")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Generated \(relativeDate(vm.weekPlan.generatedDate))")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Spacer()
                        }
                    }

                    Button(action: {
                        Task { await vm.generatePlan() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: vm.weekPlan.days.isEmpty ? "sparkles" : "arrow.clockwise")
                            Text(vm.weekPlan.days.isEmpty ? "Generate Smart Plan" : "Regenerate")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isGenerating)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(Theme.Radius.lg)
                .padding(.horizontal, 14)

                // Week Day Cards
                if !vm.weekPlan.days.isEmpty {
                    ForEach(vm.weekPlan.days) { day in
                        DayPlanCard(day: day, isExpanded: vm.expandedDay == day.id) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.expandedDay = vm.expandedDay == day.id ? nil : day.id
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }

                // Adjust Plan
                if !vm.weekPlan.days.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\u{1F4AC} ADJUST PLAN")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        HStack(spacing: 8) {
                            TextField("e.g. Move workout to evening, add more study time...", text: $vm.aiAdjustPrompt)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .padding(8)
                                .background(Color.white.opacity(0.6))
                                .cornerRadius(8)
                            Button(action: {
                                Task { await vm.adjustPlan() }
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Theme.Gradients.rosePrimary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.aiAdjustPrompt.isEmpty || vm.isGenerating)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }

    func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Day Plan Card

struct DayPlanCard: View {
    let day: SmartDayPlan
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            Button(action: onTap) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.dayLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(day.date)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }

                    Spacer()

                    // Quick badges
                    HStack(spacing: 4) {
                        PlanBadge(icon: day.workout.type == "rest" ? "\u{1F4A4}" : "\u{1F4AA}", text: "\(day.workout.duration)m")
                        PlanBadge(icon: phaseIcon(day.cyclePhase), text: day.cyclePhase)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
            }
            .buttonStyle(.plain)
            .padding(10)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Schedule
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SCHEDULE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textXSoft)
                        ForEach(day.schedule) { block in
                            HStack(spacing: 6) {
                                Text(block.time)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(Theme.Colors.textSoft)
                                    .frame(width: 35, alignment: .trailing)
                                Circle()
                                    .fill(categoryColor(block.category))
                                    .frame(width: 5, height: 5)
                                Text(block.activity)
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                    }

                    // Meals Row
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEALS")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textXSoft)
                        HStack(spacing: 6) {
                            MealChip(icon: "\u{2600}\u{FE0F}", text: day.meals.breakfast)
                            MealChip(icon: "\u{1F33F}", text: day.meals.lunch)
                            MealChip(icon: "\u{1F319}", text: day.meals.dinner)
                        }
                    }

                    // Wellness Tip
                    HStack(spacing: 6) {
                        Text("\u{1F496}")
                        Text(day.wellnessTip)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMedium)
                            .lineSpacing(2)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(Theme.Colors.glassWhite)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.Radius.md)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .shadow(color: Theme.Colors.shadow, radius: 6, x: 0, y: 3)
    }

    func categoryColor(_ category: String) -> Color {
        switch category {
        case "study": return Color(hex: "#E91E8C")
        case "class": return Color(hex: "#7C4DFF")
        case "meal": return Color(hex: "#FF9800")
        case "workout": return Color(hex: "#26A69A")
        case "rest": return Color(hex: "#90A4AE")
        case "errand": return Color(hex: "#1976D2")
        default: return Theme.Colors.textSoft
        }
    }

    func phaseIcon(_ phase: String) -> String {
        switch phase.lowercased() {
        case "menstrual": return "\u{1FA78}"
        case "follicular": return "\u{1F331}"
        case "ovulation": return "\u{2728}"
        case "luteal": return "\u{1F319}"
        default: return "\u{1F4AB}"
        }
    }
}

struct PlanBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Text(icon).font(.system(size: 8))
            Text(text).font(.system(size: 8, weight: .medium))
        }
        .foregroundColor(Theme.Colors.textMedium)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Theme.Colors.rosePale)
        .cornerRadius(6)
    }
}

struct MealChip: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 2) {
            Text(icon).font(.system(size: 10))
            Text(text)
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textMedium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(Color.white.opacity(0.5))
        .cornerRadius(6)
    }
}
