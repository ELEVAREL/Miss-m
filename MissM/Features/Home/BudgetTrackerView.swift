import SwiftUI

// MARK: - Budget Models

struct BudgetData: Codable {
    var monthlyIncome: Double = 0
    var categories: [BudgetCategory] = BudgetCategory.defaults
    var savingsGoal: Double = 500
    var savingsCurrent: Double = 0
}

struct BudgetCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var spent: Double
    var budget: Double
    var colorHex: String

    init(id: UUID = UUID(), name: String, icon: String, spent: Double = 0, budget: Double = 100, colorHex: String = "#E91E8C") {
        self.id = id; self.name = name; self.icon = icon; self.spent = spent; self.budget = budget; self.colorHex = colorHex
    }

    var color: Color { Color(hex: colorHex) }
    var progress: Double { budget > 0 ? min(spent / budget, 1.0) : 0 }

    static var defaults: [BudgetCategory] {
        [
            BudgetCategory(name: "Food", icon: "\u{1F354}", budget: 200, colorHex: "#FF6B9D"),
            BudgetCategory(name: "School", icon: "\u{1F4DA}", budget: 100, colorHex: "#7C4DFF"),
            BudgetCategory(name: "Transport", icon: "\u{1F68C}", budget: 80, colorHex: "#26A69A"),
            BudgetCategory(name: "Subscriptions", icon: "\u{1F4F1}", budget: 50, colorHex: "#FF9800"),
            BudgetCategory(name: "Other", icon: "\u{1F4B3}", budget: 120, colorHex: "#78909C"),
        ]
    }
}

struct Expense: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var note: String
    var categoryId: UUID
    var date: Date

    init(id: UUID = UUID(), amount: Double, note: String = "", categoryId: UUID, date: Date = Date()) {
        self.id = id; self.amount = amount; self.note = note; self.categoryId = categoryId; self.date = date
    }
}

// MARK: - Budget ViewModel

@Observable
class BudgetViewModel {
    var data = BudgetData()
    var expenses: [Expense] = []
    var showAddExpense = false

    init() {
        Task { await load() }
    }

    var totalSpent: Double { data.categories.reduce(0) { $0 + $1.spent } }
    var totalBudget: Double { data.categories.reduce(0) { $0 + $1.budget } }
    var savingsProgress: Double { data.savingsGoal > 0 ? min(data.savingsCurrent / data.savingsGoal, 1.0) : 0 }

    func addExpense(amount: Double, note: String, categoryIndex: Int) {
        let cat = data.categories[categoryIndex]
        expenses.append(Expense(amount: amount, note: note, categoryId: cat.id))
        data.categories[categoryIndex].spent += amount
        save()
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
                    Button(action: { viewModel.showAddExpense = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Expense")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(RoseButtonStyle())
                }
                .padding(.horizontal, 14)

                // Donut Chart
                VStack(spacing: 8) {
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Theme.Colors.rosePale, lineWidth: 16)
                            .frame(width: 120, height: 120)

                        // Category segments
                        DonutChart(categories: viewModel.data.categories, total: viewModel.totalBudget)
                            .frame(width: 120, height: 120)

                        // Center label
                        VStack(spacing: 2) {
                            Text("$\(Int(viewModel.totalSpent))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("of $\(Int(viewModel.totalBudget))")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                    }
                    .frame(height: 140)

                    // Category breakdown
                    ForEach(Array(viewModel.data.categories.enumerated()), id: \.element.id) { _, cat in
                        HStack(spacing: 8) {
                            Text(cat.icon).font(.system(size: 12))
                            Text(cat.name)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Text("$\(Int(cat.spent))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.textMedium)
                            Text("/ $\(Int(cat.budget))")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textXSoft)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.rosePale).frame(height: 4)
                                RoundedRectangle(cornerRadius: 3).fill(cat.color).frame(width: geo.size.width * cat.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .glassCard(padding: 12)
                .padding(.horizontal, 14)

                // Savings Goal
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

                    Text("\(Int(viewModel.savingsProgress * 100))% of goal reached")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Recent Expenses
                if !viewModel.expenses.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RECENT")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        ForEach(viewModel.expenses.suffix(5).reversed()) { expense in
                            HStack {
                                Text(expense.note.isEmpty ? "Expense" : expense.note)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                Text("-$\(String(format: "%.2f", expense.amount))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red)
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
                    if let amt = Double(amount) {
                        onAdd(amt, note, selectedCategory)
                        dismiss()
                    }
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(amount.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(Theme.Gradients.background)
    }
}
