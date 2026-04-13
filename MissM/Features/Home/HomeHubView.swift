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

// MARK: - Home Hub Overview (card grid)

struct HomeHubView: View {
    let claudeService: ClaudeService
    @Binding var selectedTab: HomeTab
    @State private var groceryVM = GroceryViewModel()
    @State private var budgetVM = BudgetViewModel()

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
                    HomeCard(icon: "\u{1F4B0}", title: "Budget", subtitle: "$\(Int(budgetVM.totalSpent)) spent", color: "#7C4DFF") {
                        selectedTab = .budget
                    }
                    HomeCard(icon: "\u{1F4E7}", title: "Email", subtitle: "Draft with AI", color: "#FF9800") {
                        selectedTab = .email
                    }
                }
                .padding(.horizontal, 14)

                // Today's Chores
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{1F9F9} TODAY'S CHORES")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    ChoreRow(title: "Laundry", isComplete: false)
                    ChoreRow(title: "Dishes", isComplete: true)
                    ChoreRow(title: "Vacuum living room", isComplete: false)
                    ChoreRow(title: "Water plants", isComplete: false)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Budget Summary
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{1F4B3} BUDGET OVERVIEW")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

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
                            Text("$\(Int(budgetVM.totalBudget - budgetVM.totalSpent))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.green)
                            Text("remaining")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Theme.Colors.rosePale).frame(height: 6)
                            RoundedRectangle(cornerRadius: 4).fill(Theme.Gradients.rosePrimary)
                                .frame(width: geo.size.width * (budgetVM.totalBudget > 0 ? min(budgetVM.totalSpent / budgetVM.totalBudget, 1.0) : 0), height: 6)
                        }
                    }
                    .frame(height: 6)
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

// MARK: - Chore Row

struct ChoreRow: View {
    let title: String
    @State var isComplete: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { isComplete.toggle() }) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isComplete ? .green : Theme.Colors.roseLight)
            }
            .buttonStyle(.plain)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isComplete ? Theme.Colors.textXSoft : Theme.Colors.textPrimary)
                .strikethrough(isComplete)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
