import SwiftUI

// MARK: - Meal Models

struct MealPlan: Codable {
    var weeks: [WeekPlan] = [WeekPlan()]

    struct WeekPlan: Identifiable, Codable {
        let id: UUID
        var startDate: Date
        var days: [DayMeals]

        init(id: UUID = UUID(), startDate: Date = Date()) {
            self.id = id
            self.startDate = startDate
            self.days = (0..<7).map { DayMeals(dayOffset: $0) }
        }
    }

    struct DayMeals: Identifiable, Codable {
        let id: UUID
        var dayOffset: Int
        var breakfast: String
        var lunch: String
        var dinner: String

        init(id: UUID = UUID(), dayOffset: Int, breakfast: String = "", lunch: String = "", dinner: String = "") {
            self.id = id; self.dayOffset = dayOffset
            self.breakfast = breakfast; self.lunch = lunch; self.dinner = dinner
        }

        var dayName: String {
            let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            return dayOffset < days.count ? days[dayOffset] : "?"
        }
    }
}

// MARK: - Meal Planner ViewModel

@Observable
class MealPlannerViewModel {
    var plan = MealPlan()
    var isGenerating = false
    var dietaryFilter = "Balanced"
    let filters = ["Balanced", "Vegetarian", "High Protein", "Quick Meals"]
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await load() }
    }

    var currentWeek: MealPlan.WeekPlan {
        get { plan.weeks.first ?? MealPlan.WeekPlan() }
        set { if plan.weeks.isEmpty { plan.weeks.append(newValue) } else { plan.weeks[0] = newValue } }
    }

    func generateWeek() async {
        isGenerating = true
        let prompt = """
        Generate a 7-day meal plan (Monday-Sunday) for a busy university student. Diet: \(dietaryFilter).
        Return ONLY a JSON array of 7 objects like: [{"breakfast":"...","lunch":"...","dinner":"..."}]
        Keep meal names short (3-5 words). Include emojis.
        """
        do {
            let response = try await claudeService.ask(prompt)
            if let jsonStart = response.firstIndex(of: "["),
               let jsonEnd = response.lastIndex(of: "]") {
                let jsonStr = String(response[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8),
                   let meals = try? JSONDecoder().decode([MealJSON].self, from: data) {
                    for (i, meal) in meals.prefix(7).enumerated() {
                        currentWeek.days[i].breakfast = meal.breakfast
                        currentWeek.days[i].lunch = meal.lunch
                        currentWeek.days[i].dinner = meal.dinner
                    }
                    save()
                }
            }
        } catch {}
        isGenerating = false
    }

    func load() async {
        plan = await DataStore.shared.loadOrDefault(MealPlan.self, from: "meals.json", default: MealPlan())
    }

    func save() {
        Task { try? await DataStore.shared.save(plan, to: "meals.json") }
    }

    struct MealJSON: Codable { let breakfast: String; let lunch: String; let dinner: String }
}

// MARK: - Meal Planner View

struct MealPlannerView: View {
    let claudeService: ClaudeService
    @State private var viewModel: MealPlannerViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: MealPlannerViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Meal Planner")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Button(action: { Task { await viewModel.generateWeek() } }) {
                        HStack(spacing: 4) {
                            if viewModel.isGenerating { ProgressView().scaleEffect(0.5) }
                            Text(viewModel.isGenerating ? "..." : "\u{2728} AI Plan")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(RoseButtonStyle())
                }
                .padding(.horizontal, 14)

                // Diet Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.filters, id: \.self) { filter in
                            Button(action: { viewModel.dietaryFilter = filter }) {
                                Text(filter)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(viewModel.dietaryFilter == filter ? .white : Theme.Colors.textMedium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(viewModel.dietaryFilter == filter ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(viewModel.dietaryFilter == filter ? Color.clear : Theme.Colors.roseLight, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }

                // 7-Day Grid
                VStack(spacing: 2) {
                    // Header row
                    HStack(spacing: 2) {
                        Text("").frame(width: 36)
                        ForEach(["BF", "Lunch", "Dinner"], id: \.self) { label in
                            Text(label)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Theme.Colors.textXSoft)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    ForEach(Array(viewModel.currentWeek.days.enumerated()), id: \.element.id) { index, day in
                        HStack(spacing: 2) {
                            Text(day.dayName)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.Colors.textSoft)
                                .frame(width: 36)

                            MealCell(meal: $viewModel.currentWeek.days[index].breakfast, onSave: viewModel.save)
                            MealCell(meal: $viewModel.currentWeek.days[index].lunch, onSave: viewModel.save)
                            MealCell(meal: $viewModel.currentWeek.days[index].dinner, onSave: viewModel.save)
                        }
                    }
                }
                .glassCard(padding: 8)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Meal Cell

struct MealCell: View {
    @Binding var meal: String
    let onSave: () -> Void
    @State private var isEditing = false

    var body: some View {
        Group {
            if meal.isEmpty {
                Text("+")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textXSoft)
            } else {
                Text(meal)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(meal.isEmpty ? Theme.Colors.rosePale.opacity(0.3) : Color.white.opacity(0.7))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.glassBorder, lineWidth: 0.5))
        .onTapGesture { isEditing = true }
        .popover(isPresented: $isEditing) {
            VStack(spacing: 8) {
                TextField("Meal...", text: $meal)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .frame(width: 160)
                    .onSubmit { isEditing = false; onSave() }
                Button("Done") { isEditing = false; onSave() }
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }
            .padding(10)
        }
    }
}
