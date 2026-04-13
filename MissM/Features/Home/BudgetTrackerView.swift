import SwiftUI

// MARK: - Budget Models

struct BudgetData: Codable {
    var monthlyIncome: Double = 0
    var incomeEntries: [IncomeEntry] = []
    var categories: [BudgetCategory] = BudgetCategory.defaults
    var savingsGoal: Double = 0
    var savingsCurrent: Double = 0
    var selectedMonth: String = ""  // "2026-04" format
}

struct IncomeEntry: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var source: String
    var date: Date
    var month: String  // "2026-04"

    init(id: UUID = UUID(), amount: Double, source: String, date: Date = Date()) {
        self.id = id; self.amount = amount; self.source = source; self.date = date
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        self.month = f.string(from: date)
    }
}

struct BudgetCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var spent: Double
    var budget: Double
    var colorHex: String

    init(id: UUID = UUID(), name: String, icon: String, spent: Double = 0, budget: Double = 0, colorHex: String = "#E91E8C") {
        self.id = id; self.name = name; self.icon = icon; self.spent = spent; self.budget = budget; self.colorHex = colorHex
    }

    var color: Color { Color(hex: colorHex) }
    var progress: Double { budget > 0 ? min(spent / budget, 1.0) : 0 }

    static var defaults: [BudgetCategory] {
        [
            BudgetCategory(name: "Food", icon: "\u{1F354}", colorHex: "#FF6B9D"),
            BudgetCategory(name: "School", icon: "\u{1F4DA}", colorHex: "#7C4DFF"),
            BudgetCategory(name: "Transport", icon: "\u{1F68C}", colorHex: "#26A69A"),
            BudgetCategory(name: "Subscriptions", icon: "\u{1F4F1}", colorHex: "#FF9800"),
            BudgetCategory(name: "Other", icon: "\u{1F4B3}", colorHex: "#78909C"),
        ]
    }
}

struct Expense: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var note: String
    var categoryId: UUID
    var date: Date
    var month: String

    init(id: UUID = UUID(), amount: Double, note: String = "", categoryId: UUID, date: Date = Date()) {
        self.id = id; self.amount = amount; self.note = note; self.categoryId = categoryId; self.date = date
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        self.month = f.string(from: date)
    }
}

// MARK: - Budget ViewModel

@Observable
class BudgetViewModel {
    var data = BudgetData()
    var expenses: [Expense] = []
    var showAddExpense = false
    var showAddIncome = false
    var showEditCategories = false

    init() {
        Task { await load() }
    }

    var currentMonth: String {
        if data.selectedMonth.isEmpty {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM"
            return f.string(from: Date())
        }
        return data.selectedMonth
    }

    var currentMonthLabel: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: currentMonth) else { return currentMonth }
        let display = DateFormatter(); display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }

    var monthlyExpenses: [Expense] { expenses.filter { $0.month == currentMonth } }
    var monthlyIncome: [IncomeEntry] { data.incomeEntries.filter { $0.month == currentMonth } }
    var totalIncome: Double { monthlyIncome.reduce(0) { $0 + $1.amount } }
    var totalSpent: Double { monthlyExpenses.reduce(0) { $0 + $1.amount } }
    var totalBudget: Double { data.categories.reduce(0) { $0 + $1.budget } }
    var remaining: Double { totalIncome - totalSpent }
    var savingsProgress: Double { data.savingsGoal > 0 ? min(data.savingsCurrent / data.savingsGoal, 1.0) : 0 }

    func spentInCategory(_ cat: BudgetCategory) -> Double {
        monthlyExpenses.filter { $0.categoryId == cat.id }.reduce(0) { $0 + $1.amount }
    }

    func addExpense(amount: Double, note: String, categoryIndex: Int) {
        let cat = data.categories[categoryIndex]
        expenses.append(Expense(amount: amount, note: note, categoryId: cat.id))
        save()
    }

    func addIncome(amount: Double, source: String) {
        data.incomeEntries.append(IncomeEntry(amount: amount, source: source))
        save()
    }

    func addCategory(name: String, icon: String, budget: Double, color: String) {
        data.categories.append(BudgetCategory(name: name, icon: icon, budget: budget, colorHex: color))
        save()
    }

    func removeCategory(at index: Int) {
        guard index < data.categories.count else { return }
        data.categories.remove(at: index)
        save()
    }

    func updateSavings(goal: Double, current: Double) {
        data.savingsGoal = goal
        data.savingsCurrent = current
        save()
    }

    func previousMonth() {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        if let date = f.date(from: currentMonth),
           let prev = Calendar.current.date(byAdding: .month, value: -1, to: date) {
            data.selectedMonth = f.string(from: prev)
            save()
        }
    }

    func nextMonth() {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        if let date = f.date(from: currentMonth),
           let next = Calendar.current.date(byAdding: .month, value: 1, to: date) {
            data.selectedMonth = f.string(from: next)
            save()
        }
    }

    func load() async {
        data = await DataStore.shared.loadOrDefault(BudgetData.self, from: "budget.json", default: BudgetData())
        expenses = await DataStore.shared.loadOrDefault([Expense].self, from: "expenses.json", default: [])
    }

    func save() {
        Task {
            try? await DataStore.shared.save(data, to: "budget.json")
            try? await DataStore.shared.save(expenses, to: "expenses.json")
        }
    }
}

// MARK: - Budget Tracker View

struct BudgetTrackerView: View {
    @State private var viewModel = BudgetViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Budget")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Button(action: { viewModel.showAddIncome = true }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                Text("Income")
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "#26A69A"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#26A69A").opacity(0.1))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#26A69A").opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.showAddExpense = true }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                Text("Expense")
                            }
                            .font(.system(size: 9, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())
                    }
                }
                .padding(.horizontal, 14)

                // Month Selector
                HStack {
                    Button(action: { viewModel.previousMonth() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Text(viewModel.currentMonthLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()

                    Button(action: { viewModel.nextMonth() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)

                // Income vs Spending Hero
                HStack(spacing: 12) {
                    // Income
                    VStack(spacing: 4) {
                        Text("\u{1F4B0}")
                            .font(.system(size: 16))
                        Text("$\(Int(viewModel.totalIncome))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#26A69A"))
                        Text("Income")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(hex: "#26A69A").opacity(0.08))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#26A69A").opacity(0.2), lineWidth: 1))

                    // Spent
                    VStack(spacing: 4) {
                        Text("\u{1F6D2}")
                            .font(.system(size: 16))
                        Text("$\(Int(viewModel.totalSpent))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        Text("Spent")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Theme.Colors.rosePale.opacity(0.3))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.roseLight, lineWidth: 1))

                    // Remaining
                    VStack(spacing: 4) {
                        Text(viewModel.remaining >= 0 ? "\u{2705}" : "\u{26A0}\u{FE0F}")
                            .font(.system(size: 16))
                        Text("$\(Int(viewModel.remaining))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(viewModel.remaining >= 0 ? Color(hex: "#26A69A") : .red)
                        Text("Left")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                }
                .padding(.horizontal, 14)

                // Category Breakdown
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\u{1F4CA} CATEGORIES")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Button(action: { viewModel.showEditCategories = true }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(viewModel.data.categories) { cat in
                        let spent = viewModel.spentInCategory(cat)
                        let progress = cat.budget > 0 ? min(spent / cat.budget, 1.0) : 0
                        VStack(spacing: 3) {
                            HStack(spacing: 8) {
                                Text(cat.icon).font(.system(size: 12))
                                Text(cat.name)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                Text("$\(Int(spent))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(spent > cat.budget && cat.budget > 0 ? .red : Theme.Colors.textMedium)
                                if cat.budget > 0 {
                                    Text("/ $\(Int(cat.budget))")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textXSoft)
                                }
                            }
                            if cat.budget > 0 {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.rosePale).frame(height: 4)
                                        RoundedRectangle(cornerRadius: 3).fill(cat.color).frame(width: geo.size.width * progress, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Savings Goal
                if viewModel.data.savingsGoal > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\u{1F3AF} SAVINGS GOAL")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Text("$\(Int(viewModel.data.savingsCurrent)) / $\(Int(viewModel.data.savingsGoal))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.rosePale).frame(height: 10)
                                RoundedRectangle(cornerRadius: 6).fill(Theme.Gradients.rosePrimary)
                                    .frame(width: geo.size.width * viewModel.savingsProgress, height: 10)
                            }
                        }
                        .frame(height: 10)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // Recent Transactions
                let recentItems = viewModel.monthlyExpenses.suffix(5).reversed()
                if !recentItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RECENT")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        ForEach(Array(recentItems)) { expense in
                            HStack {
                                if let cat = viewModel.data.categories.first(where: { $0.id == expense.categoryId }) {
                                    Text(cat.icon).font(.system(size: 10))
                                }
                                Text(expense.note.isEmpty ? "Expense" : expense.note)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                Text("-$\(String(format: "%.2f", expense.amount))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.roseDeep)
                            }
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // Income entries
                if !viewModel.monthlyIncome.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\u{1F4B0} INCOME THIS MONTH")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        ForEach(viewModel.monthlyIncome) { entry in
                            HStack {
                                Text(entry.source)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                Text("+$\(String(format: "%.2f", entry.amount))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "#26A69A"))
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
        .sheet(isPresented: $viewModel.showAddExpense) {
            AddExpenseSheet(categories: viewModel.data.categories) { amount, note, catIndex in
                viewModel.addExpense(amount: amount, note: note, categoryIndex: catIndex)
            }
        }
        .sheet(isPresented: $viewModel.showAddIncome) {
            AddIncomeSheet { amount, source in
                viewModel.addIncome(amount: amount, source: source)
            }
        }
        .sheet(isPresented: $viewModel.showEditCategories) {
            EditCategoriesSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Donut Chart

struct DonutChart: View {
    let categories: [BudgetCategory]
    let total: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 8
            var startAngle: Angle = .degrees(-90)

            for cat in categories where cat.spent > 0 {
                let fraction = total > 0 ? cat.spent / total : 0
                let endAngle = startAngle + .degrees(fraction * 360)
                let path = Path { p in
                    p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                }
                context.stroke(path, with: .color(cat.color), lineWidth: 16)
                startAngle = endAngle
            }
        }
    }
}

// MARK: - Add Expense Sheet

struct AddExpenseSheet: View {
    @Environment(\.dismiss) var dismiss
    let categories: [BudgetCategory]
    let onAdd: (Double, String, Int) -> Void
    @State private var amount = ""
    @State private var note = ""
    @State private var selectedCategory = 0

    var body: some View {
        VStack(spacing: 14) {
            Text("Add Expense")
                .font(Theme.Fonts.display(18))
                .foregroundColor(Theme.Colors.rosePrimary)

            TextField("Amount ($)", text: $amount)
                .textFieldStyle(.plain).padding(10)
                .background(Color.white.opacity(0.8)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            TextField("Note (optional)", text: $note)
                .textFieldStyle(.plain).padding(10)
                .background(Color.white.opacity(0.8)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            Picker("Category", selection: $selectedCategory) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                    Text("\(cat.icon) \(cat.name)").tag(index)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button("Cancel") { dismiss() }.foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Button("Add") {
                    if let amt = Double(amount) { onAdd(amt, note, selectedCategory); dismiss() }
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(amount.isEmpty)
            }
        }
        .padding(20).frame(width: 360).background(Theme.Gradients.background)
    }
}

// MARK: - Add Income Sheet

struct AddIncomeSheet: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (Double, String) -> Void
    @State private var amount = ""
    @State private var source = ""

    var body: some View {
        VStack(spacing: 14) {
            Text("Add Income")
                .font(Theme.Fonts.display(18))
                .foregroundColor(Color(hex: "#26A69A"))

            TextField("Amount ($)", text: $amount)
                .textFieldStyle(.plain).padding(10)
                .background(Color.white.opacity(0.8)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#26A69A").opacity(0.4), lineWidth: 1))

            TextField("Source (e.g. Part-time job, Allowance)", text: $source)
                .textFieldStyle(.plain).padding(10)
                .background(Color.white.opacity(0.8)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#26A69A").opacity(0.4), lineWidth: 1))

            HStack {
                Button("Cancel") { dismiss() }.foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Button("Add") {
                    if let amt = Double(amount) { onAdd(amt, source.isEmpty ? "Income" : source); dismiss() }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Color(hex: "#26A69A"))
                .cornerRadius(10)
                .disabled(amount.isEmpty)
            }
        }
        .padding(20).frame(width: 360).background(Theme.Gradients.background)
    }
}

// MARK: - Edit Categories Sheet

struct EditCategoriesSheet: View {
    @Environment(\.dismiss) var dismiss
    let viewModel: BudgetViewModel
    @State private var newName = ""
    @State private var newIcon = "\u{1F4B3}"
    @State private var newBudget = ""

    var body: some View {
        VStack(spacing: 14) {
            Text("Edit Categories")
                .font(Theme.Fonts.display(18))
                .foregroundColor(Theme.Colors.rosePrimary)

            // Existing categories
            ForEach(Array(viewModel.data.categories.enumerated()), id: \.element.id) { index, cat in
                HStack(spacing: 8) {
                    Text(cat.icon).font(.system(size: 14))
                    Text(cat.name)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    if cat.budget > 0 {
                        Text("$\(Int(cat.budget))")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    Button(action: { viewModel.removeCategory(at: index) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Add new category
            Text("Add Category")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.textSoft)

            HStack(spacing: 6) {
                TextField("\u{1F4B3}", text: $newIcon)
                    .textFieldStyle(.plain).frame(width: 36).padding(8)
                    .background(Color.white.opacity(0.8)).cornerRadius(8)

                TextField("Name", text: $newName)
                    .textFieldStyle(.plain).padding(8)
                    .background(Color.white.opacity(0.8)).cornerRadius(8)

                TextField("Budget", text: $newBudget)
                    .textFieldStyle(.plain).frame(width: 60).padding(8)
                    .background(Color.white.opacity(0.8)).cornerRadius(8)

                Button(action: {
                    viewModel.addCategory(name: newName, icon: newIcon, budget: Double(newBudget) ?? 0, color: "#E91E8C")
                    newName = ""; newBudget = ""; newIcon = "\u{1F4B3}"
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .buttonStyle(.plain)
                .disabled(newName.isEmpty)
            }

            Button("Done") { dismiss() }
                .buttonStyle(RoseButtonStyle())
        }
        .padding(20).frame(width: 400).background(Theme.Gradients.background)
    }
}
