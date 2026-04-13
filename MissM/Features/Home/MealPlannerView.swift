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

// MARK: - Food Preferences

struct FoodPreferences: Codable {
    var dislikedFoods: [String] = []
    var allergies: [String] = []
}

// MARK: - Meal Planner ViewModel

@Observable
class MealPlannerViewModel {
    var plan = MealPlan()
    var isGenerating = false
    var dietaryFilter = "Balanced"
    let filters = ["Balanced", "Vegetarian", "High Protein", "Quick Meals"]
    var foodPrefs = FoodPreferences()
    var newDislike = ""
    var newAllergy = ""
    var showPreferences = false
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await load(); await loadPrefs() }
    }

    var currentWeek: MealPlan.WeekPlan {
        get { plan.weeks.first ?? MealPlan.WeekPlan() }
        set { if plan.weeks.isEmpty { plan.weeks.append(newValue) } else { plan.weeks[0] = newValue } }
    }

    func addDislike(_ food: String) {
        let trimmed = food.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !foodPrefs.dislikedFoods.contains(trimmed) else { return }
        foodPrefs.dislikedFoods.append(trimmed)
        savePrefs()
    }

    func removeDislike(_ food: String) {
        foodPrefs.dislikedFoods.removeAll { $0 == food }
        savePrefs()
    }

    func addAllergy(_ food: String) {
        let trimmed = food.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !foodPrefs.allergies.contains(trimmed) else { return }
        foodPrefs.allergies.append(trimmed)
        savePrefs()
    }

    func removeAllergy(_ food: String) {
        foodPrefs.allergies.removeAll { $0 == food }
        savePrefs()
    }

    func loadPrefs() async {
        foodPrefs = await DataStore.shared.loadOrDefault(FoodPreferences.self, from: "food-prefs.json", default: FoodPreferences())
    }

    func savePrefs() {
        Task { try? await DataStore.shared.save(foodPrefs, to: "food-prefs.json") }
    }

    func generateWeek() async {
        isGenerating = true
        let dislikesStr = foodPrefs.dislikedFoods.isEmpty ? "None" : foodPrefs.dislikedFoods.joined(separator: ", ")
        let allergiesStr = foodPrefs.allergies.isEmpty ? "None" : foodPrefs.allergies.joined(separator: ", ")
        let prompt = """
        Generate a 7-day meal plan (Monday-Sunday) for a busy university student. Diet: \(dietaryFilter).
        IMPORTANT — She DISLIKES these foods (never include them): \(dislikesStr)
        ALLERGIES (absolutely never include): \(allergiesStr)
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

                // Diet Filters + Preferences Toggle
                HStack(spacing: 6) {
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
                    }
                    Button(action: { viewModel.showPreferences.toggle() }) {
                        Image(systemName: viewModel.showPreferences ? "xmark" : "slider.horizontal.3")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.rosePrimary)
                            .padding(6)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)

                // Food Preferences Panel
                if viewModel.showPreferences {
                    VStack(alignment: .leading, spacing: 10) {
                        // Dislikes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\u{1F6AB} FOODS I DON'T LIKE")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)

                            if !viewModel.foodPrefs.dislikedFoods.isEmpty {
                                FlowLayout(spacing: 4) {
                                    ForEach(viewModel.foodPrefs.dislikedFoods, id: \.self) { food in
                                        HStack(spacing: 3) {
                                            Text(food)
                                                .font(.system(size: 9, weight: .medium))
                                            Button(action: { viewModel.removeDislike(food) }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 7, weight: .bold))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .foregroundColor(Theme.Colors.roseDeep)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.Colors.rosePale)
                                        .cornerRadius(8)
                                    }
                                }
                            }

                            HStack(spacing: 6) {
                                TextField("e.g. mushrooms, olives...", text: $viewModel.newDislike)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11))
                                    .padding(6)
                                    .background(Color.white.opacity(0.6))
                                    .cornerRadius(6)
                                    .onSubmit {
                                        viewModel.addDislike(viewModel.newDislike)
                                        viewModel.newDislike = ""
                                    }
                                Button(action: {
                                    viewModel.addDislike(viewModel.newDislike)
                                    viewModel.newDislike = ""
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Theme.Colors.rosePrimary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.newDislike.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }

                        Divider()

                        // Allergies
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\u{26A0}\u{FE0F} ALLERGIES")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)

                            if !viewModel.foodPrefs.allergies.isEmpty {
                                FlowLayout(spacing: 4) {
                                    ForEach(viewModel.foodPrefs.allergies, id: \.self) { food in
                                        HStack(spacing: 3) {
                                            Text(food)
                                                .font(.system(size: 9, weight: .medium))
                                            Button(action: { viewModel.removeAllergy(food) }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 7, weight: .bold))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }

                            HStack(spacing: 6) {
                                TextField("e.g. peanuts, gluten...", text: $viewModel.newAllergy)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11))
                                    .padding(6)
                                    .background(Color.white.opacity(0.6))
                                    .cornerRadius(6)
                                    .onSubmit {
                                        viewModel.addAllergy(viewModel.newAllergy)
                                        viewModel.newAllergy = ""
                                    }
                                Button(action: {
                                    viewModel.addAllergy(viewModel.newAllergy)
                                    viewModel.newAllergy = ""
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.red)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.newAllergy.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                    .glassCard(padding: 10)
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

// MARK: - Flow Layout (for food tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
