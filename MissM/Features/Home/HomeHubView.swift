import SwiftUI

// MARK: - Home Tab Enum

enum HomeTab: String, CaseIterable {
    case hub = "Hub"
    case meals = "Meals"
    case grocery = "Grocery"
    case budget = "Budget"
    case email = "Email"

    var icon: String {
        switch self {
        case .hub: return "\u{1F3E0}"
        case .meals: return "\u{1F35D}"
        case .grocery: return "\u{1F6D2}"
        case .budget: return "\u{1F4B0}"
        case .email: return "\u{1F4E7}"
        }
    }
}

// MARK: - Chore Model

struct Chore: Identifiable, Codable {
    let id: UUID
    var title: String
    var isComplete: Bool
    var day: String // "Monday", "Tuesday", etc. or "Daily"

    init(id: UUID = UUID(), title: String, isComplete: Bool = false, day: String = "Daily") {
        self.id = id; self.title = title; self.isComplete = isComplete; self.day = day
    }
}

struct ChoreData: Codable {
    var chores: [Chore] = []
}

@Observable
class ChoreViewModel {
    var data = ChoreData()
    var newChoreTitle = ""
    var showAddChore = false

    init() { Task { await load() } }

    var todayChores: [Chore] {
        let dayName = {
            let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: Date())
        }()
        return data.chores.filter { $0.day == "Daily" || $0.day == dayName }
    }

    var completedCount: Int { todayChores.filter(\.isComplete).count }

    func addChore(_ title: String, day: String = "Daily") {
        guard !title.isEmpty else { return }
        data.chores.append(Chore(title: title, day: day))
        save()
    }

    func toggleChore(_ id: UUID) {
        if let i = data.chores.firstIndex(where: { $0.id == id }) {
            data.chores[i].isComplete.toggle()
            save()
        }
    }

    func removeChore(_ id: UUID) {
        data.chores.removeAll { $0.id == id }
        save()
    }

    func load() async {
        data = await DataStore.shared.loadOrDefault(ChoreData.self, from: "chores.json", default: ChoreData())
    }

    func save() {
        Task { try? await DataStore.shared.save(data, to: "chores.json") }
    }
}

// MARK: - Home Hub Overview (card grid)

struct HomeHubView: View {
    let claudeService: ClaudeService
    @Binding var selectedTab: HomeTab
    @State private var groceryVM = GroceryViewModel()
    @State private var budgetVM = BudgetViewModel()
    @State private var choreVM = ChoreViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Greeting
                HStack {
                    Text("Home")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Quick Cards Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    HomeCard(icon: "\u{1F35D}", title: "Meals", subtitle: "Plan this week", color: "#FF6B9D") {
                        selectedTab = .meals
                    }
                    HomeCard(icon: "\u{1F6D2}", title: "Grocery", subtitle: "\(groceryVM.totalItems) items", color: "#26A69A") {
                        selectedTab = .grocery
                    }
                    HomeCard(icon: "\u{1F4B0}", title: "Budget", subtitle: budgetVM.totalIncome > 0 ? "$\(Int(budgetVM.remaining)) left" : "Set up", color: "#7C4DFF") {
                        selectedTab = .budget
                    }
                    HomeCard(icon: "\u{1F4E7}", title: "Email", subtitle: "Draft with AI", color: "#FF9800") {
                        selectedTab = .email
                    }
                }
                .padding(.horizontal, 14)

                // Today's Chores (editable)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\u{1F9F9} TODAY'S CHORES")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Text("\(choreVM.completedCount)/\(choreVM.todayChores.count)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }

                    if choreVM.todayChores.isEmpty {
                        Text("No chores yet. Add some below!")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }

                    ForEach(choreVM.todayChores) { chore in
                        HStack(spacing: 8) {
                            Button(action: { choreVM.toggleChore(chore.id) }) {
                                Image(systemName: chore.isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(chore.isComplete ? .green : Theme.Colors.roseLight)
                            }
                            .buttonStyle(.plain)
                            Text(chore.title)
                                .font(.system(size: 12))
                                .foregroundColor(chore.isComplete ? Theme.Colors.textXSoft : Theme.Colors.textPrimary)
                                .strikethrough(chore.isComplete)
                            Spacer()
                            Button(action: { choreVM.removeChore(chore.id) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                                    .foregroundColor(Theme.Colors.textXSoft)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }

                    // Add chore
                    HStack(spacing: 6) {
                        TextField("Add a chore...", text: $choreVM.newChoreTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color.white.opacity(0.6))
                            .cornerRadius(8)
                            .onSubmit {
                                choreVM.addChore(choreVM.newChoreTitle)
                                choreVM.newChoreTitle = ""
                            }
                        Button(action: {
                            choreVM.addChore(choreVM.newChoreTitle)
                            choreVM.newChoreTitle = ""
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(choreVM.newChoreTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Budget Summary
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{1F4B3} BUDGET OVERVIEW")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    if budgetVM.totalIncome > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("$\(Int(budgetVM.totalSpent))")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                Text("spent this month")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textSoft)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("$\(Int(budgetVM.remaining))")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(budgetVM.remaining >= 0 ? .green : .red)
                                Text("remaining")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textSoft)
                            }
                        }
                    } else {
                        Text("Add your income in the Budget tab to start tracking")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Home Card

struct HomeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.7))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: color).opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: Theme.Colors.shadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// ChoreRow removed — chores now managed by ChoreViewModel with persistence
