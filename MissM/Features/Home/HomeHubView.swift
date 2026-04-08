import SwiftUI

// MARK: - Home Hub View (Phase 4)
// Meal planner, grocery list, budget tracker, email drafter

struct HomeHubView: View {
    let claudeService: ClaudeService
    @State private var selectedFeature: HomeFeature? = nil

    enum HomeFeature: String, CaseIterable {
        case meals = "Meal Planner"
        case grocery = "Grocery List"
        case budget = "Budget"
        case email = "Email Drafter"

        var icon: String {
            switch self {
            case .meals: return "🍽"
            case .grocery: return "🛒"
            case .budget: return "💰"
            case .email: return "📧"
            }
        }

        var description: String {
            switch self {
            case .meals: return "7-day meal plan"
            case .grocery: return "Tap to check off"
            case .budget: return "Track spending & save"
            case .email: return "Draft with tone selector"
            }
        }
    }

    var body: some View {
        if let feature = selectedFeature {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { selectedFeature = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Home")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                featureView(for: feature)
            }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HOME HUB")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text("Home & Life")
                            .font(.custom("PlayfairDisplay-Italic", size: 20))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(HomeFeature.allCases, id: \.self) { feature in
                            Button(action: { selectedFeature = feature }) {
                                VStack(spacing: 8) {
                                    Text(feature.icon)
                                        .font(.system(size: 24))
                                    Text(feature.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text(feature.description)
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textSoft)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .glassCard(padding: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private func featureView(for feature: HomeFeature) -> some View {
        switch feature {
        case .meals: MealPlannerView(claudeService: claudeService)
        case .grocery: GroceryListView()
        case .budget: BudgetView()
        case .email: EmailDrafterView(claudeService: claudeService)
        }
    }
}

// MARK: - Meal Planner View
struct MealPlannerView: View {
    let claudeService: ClaudeService
    @State private var meals: [DayMeal] = DayMeal.emptyWeek()
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("7-DAY MEAL PLAN")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Spacer()
                    Button(action: { Task { await generateMeals() } }) {
                        HStack(spacing: 4) {
                            if isGenerating { ProgressView().scaleEffect(0.5) }
                            else { Image(systemName: "sparkles") }
                            Text("AI Plan")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(RoseButtonStyle())
                    .disabled(isGenerating)
                }
                .padding(.horizontal, 16)

                ForEach(meals) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day.dayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        HStack(spacing: 8) {
                            MealSlot(label: "Breakfast", meal: day.breakfast)
                            MealSlot(label: "Lunch", meal: day.lunch)
                            MealSlot(label: "Dinner", meal: day.dinner)
                        }
                    }
                    .padding(10)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func generateMeals() async {
        isGenerating = true
        defer { isGenerating = false }
        let prompt = """
        Generate a 7-day meal plan for a busy university student. Format as:
        Monday: [breakfast] | [lunch] | [dinner]
        Tuesday: [breakfast] | [lunch] | [dinner]
        ... (through Sunday)
        Keep meals simple, healthy, and budget-friendly. One line per day.
        """
        do {
            let response = try await claudeService.ask(prompt)
            let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let lines = response.split(separator: "\n").map(String.init)
            for (i, day) in days.enumerated() {
                if let line = lines.first(where: { $0.contains(day) }) {
                    let parts = line.replacingOccurrences(of: "\(day):", with: "")
                        .split(separator: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count >= 3, i < meals.count {
                        meals[i].breakfast = parts[0]
                        meals[i].lunch = parts[1]
                        meals[i].dinner = parts[2]
                    }
                }
            }
        } catch {}
    }
}

struct MealSlot: View {
    let label: String
    let meal: String

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Theme.Colors.textXSoft)
            Text(meal.isEmpty ? "—" : meal)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DayMeal: Identifiable {
    let id = UUID()
    let dayName: String
    var breakfast: String
    var lunch: String
    var dinner: String

    static func emptyWeek() -> [DayMeal] {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            .map { DayMeal(dayName: $0, breakfast: "", lunch: "", dinner: "") }
    }
}

// MARK: - Grocery List View
struct GroceryListView: View {
    @State private var items: [GroceryItem] = []
    @State private var newItem = ""
    @State private var selectedSection: GrocerySection = .produce

    enum GrocerySection: String, CaseIterable {
        case produce = "🥬 Produce"
        case dairy = "🧀 Dairy"
        case meat = "🍗 Meat"
        case pantry = "🥫 Pantry"
        case frozen = "🧊 Frozen"
        case other = "📦 Other"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Add item
            HStack(spacing: 8) {
                TextField("Add item...", text: $newItem)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))
                    .onSubmit { addItem() }

                Picker("", selection: $selectedSection) {
                    ForEach(GrocerySection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .frame(width: 100)

                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .buttonStyle(.plain)
                .disabled(newItem.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(GrocerySection.allCases, id: \.self) { section in
                        let sectionItems = items.filter { $0.section == section }
                        if !sectionItems.isEmpty {
                            Text(section.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.textSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                                .padding(.horizontal, 16)

                            ForEach(sectionItems) { item in
                                HStack(spacing: 10) {
                                    Button(action: { toggleItem(item.id) }) {
                                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(item.isChecked ? .green : Theme.Colors.roseLight)
                                    }
                                    .buttonStyle(.plain)

                                    Text(item.name)
                                        .font(.system(size: 12))
                                        .foregroundColor(item.isChecked ? Theme.Colors.textXSoft : Theme.Colors.textPrimary)
                                        .strikethrough(item.isChecked)

                                    Spacer()

                                    Button(action: { removeItem(item.id) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9))
                                            .foregroundColor(Theme.Colors.textXSoft)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }

            // Summary
            HStack {
                Text("\(items.filter { !$0.isChecked }.count) remaining")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Button("Clear Checked") {
                    items.removeAll { $0.isChecked }
                }
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.rosePrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func addItem() {
        guard !newItem.isEmpty else { return }
        items.append(GroceryItem(name: newItem, section: selectedSection))
        newItem = ""
    }

    private func toggleItem(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isChecked.toggle()
    }

    private func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
    }
}

struct GroceryItem: Identifiable {
    let id = UUID()
    let name: String
    let section: GroceryListView.GrocerySection
    var isChecked = false
}

// MARK: - Budget View
struct BudgetView: View {
    @State private var expenses: [Expense] = []
    @State private var budget: Double = 500
    @State private var newName = ""
    @State private var newAmount = ""
    @State private var newCategory: ExpenseCategory = .food

    enum ExpenseCategory: String, CaseIterable {
        case food = "🍕 Food"
        case transport = "🚌 Transport"
        case shopping = "🛍 Shopping"
        case bills = "📱 Bills"
        case entertainment = "🎬 Fun"
        case other = "📦 Other"

        var color: Color {
            switch self {
            case .food: return Theme.Colors.rosePrimary
            case .transport: return Color.blue
            case .shopping: return Color.purple
            case .bills: return Color.orange
            case .entertainment: return Theme.Colors.roseMid
            case .other: return Theme.Colors.textSoft
            }
        }
    }

    private var totalSpent: Double { expenses.reduce(0) { $0 + $1.amount } }
    private var remaining: Double { budget - totalSpent }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Budget overview donut
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Theme.Colors.rosePale, lineWidth: 12)
                            .frame(width: 100, height: 100)
                        Circle()
                            .trim(from: 0, to: min(totalSpent / max(budget, 1), 1))
                            .stroke(Theme.Gradients.rosePrimary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("$\(Int(remaining))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(remaining >= 0 ? Theme.Colors.rosePrimary : .red)
                            Text("left")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                    }

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text("$\(Int(budget))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Budget").font(.system(size: 9)).foregroundColor(Theme.Colors.textSoft)
                        }
                        VStack(spacing: 2) {
                            Text("$\(Int(totalSpent))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            Text("Spent").font(.system(size: 9)).foregroundColor(Theme.Colors.textSoft)
                        }
                    }
                }
                .padding(14)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)

                // Add expense
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("Item", text: $newName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                        TextField("$", text: $newAmount)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .frame(width: 50)
                        Picker("", selection: $newCategory) {
                            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        .frame(width: 80)
                        Button(action: addExpense) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)

                // Expense list
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECENT EXPENSES")
                        .font(.custom("CormorantGaramond-SemiBold", size: 10))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    ForEach(expenses.reversed()) { expense in
                        HStack(spacing: 8) {
                            Circle().fill(expense.category.color).frame(width: 8, height: 8)
                            Text(expense.name)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Text("$\(String(format: "%.2f", expense.amount))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.Colors.textMedium)
                        }
                        .padding(.vertical, 3)
                    }
                }
                .padding(12)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
        }
    }

    private func addExpense() {
        guard !newName.isEmpty, let amount = Double(newAmount) else { return }
        expenses.append(Expense(name: newName, amount: amount, category: newCategory))
        newName = ""
        newAmount = ""
    }
}

struct Expense: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let category: BudgetView.ExpenseCategory
    let date = Date()
}

// MARK: - Email Drafter View
struct EmailDrafterView: View {
    let claudeService: ClaudeService
    @State private var recipient = ""
    @State private var subject = ""
    @State private var context = ""
    @State private var selectedTone: EmailTone = .professional
    @State private var draft = ""
    @State private var isGenerating = false

    enum EmailTone: String, CaseIterable {
        case professional = "Professional"
        case friendly = "Friendly"
        case formal = "Formal"
        case apologetic = "Apologetic"
        case thankful = "Thankful"

        var icon: String {
            switch self {
            case .professional: return "💼"
            case .friendly: return "😊"
            case .formal: return "🎩"
            case .apologetic: return "🙏"
            case .thankful: return "🙏"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Tone selector
                VStack(alignment: .leading, spacing: 6) {
                    Text("TONE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 10))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(EmailTone.allCases, id: \.self) { tone in
                                Button(action: { selectedTone = tone }) {
                                    HStack(spacing: 3) {
                                        Text(tone.icon).font(.system(size: 10))
                                        Text(tone.rawValue).font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedTone == tone ? AnyView(Theme.Gradients.rosePrimary) : AnyView(Color.white.opacity(0.7)))
                                    .foregroundColor(selectedTone == tone ? .white : Theme.Colors.textMedium)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Inputs
                VStack(spacing: 8) {
                    TextField("To (e.g. Professor Smith)", text: $recipient)
                    TextField("Subject", text: $subject)
                    TextField("What do you need to say?", text: $context)
                }
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(10)
                .background(Color.white.opacity(0.7))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                .padding(.horizontal, 16)

                Button(action: { Task { await generateDraft() } }) {
                    HStack(spacing: 4) {
                        if isGenerating { ProgressView().scaleEffect(0.5) }
                        else { Image(systemName: "sparkles") }
                        Text("Draft Email")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(context.isEmpty || isGenerating)

                // Draft output
                if !draft.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("DRAFT")
                                .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(draft, forType: .string)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(draft)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func generateDraft() async {
        isGenerating = true
        defer { isGenerating = false }
        let prompt = """
        Draft an email with a \(selectedTone.rawValue.lowercased()) tone.
        To: \(recipient.isEmpty ? "recipient" : recipient)
        Subject: \(subject.isEmpty ? "N/A" : subject)
        Context: \(context)

        Write the full email including greeting and sign-off.
        Sign off as "Miss M" or just "M".
        Keep it concise and appropriate for a university student.
        """
        do {
            draft = try await claudeService.ask(prompt)
        } catch {
            draft = "Sorry, couldn't generate the draft. Please try again."
        }
    }
}
