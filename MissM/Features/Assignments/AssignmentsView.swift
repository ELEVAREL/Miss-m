import SwiftUI

// MARK: - Assignments Kanban View (Phase 2)
// 3-column board: To Do · In Progress · Done

struct AssignmentsView: View {
    let claudeService: ClaudeService
    @State private var viewModel = AssignmentsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASSIGNMENTS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("Kanban Board")
                        .font(.custom("PlayfairDisplay-Italic", size: 18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                Spacer()
                Button(action: { viewModel.showAddSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(RoseButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // AI Priority Banner
            if let urgent = viewModel.mostUrgent {
                HStack(spacing: 8) {
                    Text("🎯")
                    Text("Priority: **\(urgent.title)** — \(urgent.daysUntilDue) days left")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(10)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Progress bar
            ProgressSection(assignments: viewModel.assignments)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Kanban columns
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    KanbanColumn(
                        title: "To Do",
                        emoji: "📋",
                        assignments: viewModel.todo,
                        accentColor: Theme.Colors.rosePrimary,
                        onMove: { id in viewModel.moveToInProgress(id) }
                    )
                    KanbanColumn(
                        title: "In Progress",
                        emoji: "⚡",
                        assignments: viewModel.inProgress,
                        accentColor: Color.orange,
                        onMove: { id in viewModel.moveToDone(id) }
                    )
                    KanbanColumn(
                        title: "Done",
                        emoji: "✅",
                        assignments: viewModel.done,
                        accentColor: Color.green,
                        onMove: nil
                    )
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddAssignmentSheet(viewModel: viewModel, claudeService: claudeService)
        }
        .task { await viewModel.loadData() }
    }
}

// MARK: - Progress Section
struct ProgressSection: View {
    let assignments: [Assignment]

    private var doneCount: Int { assignments.filter { $0.status == .done }.count }
    private var progress: Double {
        assignments.isEmpty ? 0 : Double(doneCount) / Double(assignments.count)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(doneCount)/\(assignments.count) complete")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.rosePale)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Gradients.rosePrimary)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Kanban Column
struct KanbanColumn: View {
    let title: String
    let emoji: String
    let assignments: [Assignment]
    let accentColor: Color
    let onMove: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column header
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("\(assignments.count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor)
                    .cornerRadius(8)
            }
            .padding(.bottom, 4)

            if assignments.isEmpty {
                Text("No items")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textXSoft)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .glassCard()
            } else {
                ForEach(assignments) { assignment in
                    AssignmentCard(assignment: assignment, onMove: onMove)
                }
            }
        }
        .frame(width: 130)
    }
}

// MARK: - Assignment Card
struct AssignmentCard: View {
    let assignment: Assignment
    let onMove: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Priority badge
            HStack {
                Text(assignment.priority.rawValue)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: assignment.priority.color))
                    .cornerRadius(6)
                Spacer()
                if assignment.isOverdue {
                    Text("OVERDUE")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.red)
                }
            }

            Text(assignment.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)

            Text(assignment.course)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textSoft)

            HStack {
                Text(dueDateLabel)
                    .font(.system(size: 9))
                    .foregroundColor(assignment.isOverdue ? .red : Theme.Colors.textSoft)
                Spacer()
                if let onMove {
                    Button(action: { onMove(assignment.id) }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .glassCard(padding: 0)
    }

    private var dueDateLabel: String {
        let days = assignment.daysUntilDue
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0 { return "\(abs(days))d overdue" }
        return "\(days)d left"
    }
}

// MARK: - Add Assignment Sheet
struct AddAssignmentSheet: View {
    let viewModel: AssignmentsViewModel
    let claudeService: ClaudeService
    @State private var title = ""
    @State private var course = ""
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var priority: Assignment.AssignmentPriority = .medium
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("New Assignment")
                .font(.custom("PlayfairDisplay-Italic", size: 18))
                .foregroundColor(Theme.Colors.rosePrimary)

            VStack(spacing: 10) {
                TextField("Assignment title", text: $title)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

                TextField("Course name", text: $course)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

                DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])
                    .font(.system(size: 12))

                Picker("Priority", selection: $priority) {
                    ForEach(Assignment.AssignmentPriority.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSoft)
                Button("Add Assignment") {
                    let assignment = Assignment(title: title, course: course, dueDate: dueDate, priority: priority)
                    viewModel.addAssignment(assignment)
                    dismiss()
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 350)
        .background(Theme.Colors.roseUltra)
    }
}

// MARK: - Assignments ViewModel
@Observable
class AssignmentsViewModel {
    var assignments: [Assignment] = []
    var showAddSheet = false

    var todo: [Assignment] { assignments.filter { $0.status == .todo }.sorted { $0.dueDate < $1.dueDate } }
    var inProgress: [Assignment] { assignments.filter { $0.status == .inProgress }.sorted { $0.dueDate < $1.dueDate } }
    var done: [Assignment] { assignments.filter { $0.status == .done }.sorted { $0.dueDate > $1.dueDate } }

    var mostUrgent: Assignment? {
        assignments
            .filter { $0.status != .done }
            .sorted { $0.dueDate < $1.dueDate }
            .first
    }

    func loadData() async {
        let loaded = try? await DataStore.shared.loadAssignments()
        if let loaded { assignments = loaded }
    }

    func saveData() {
        Task { try? await DataStore.shared.saveAssignments(assignments) }
    }

    func addAssignment(_ assignment: Assignment) {
        assignments.append(assignment)
        saveData()
    }

    func moveToInProgress(_ id: UUID) {
        guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[index].status = .inProgress
        saveData()
    }

    func moveToDone(_ id: UUID) {
        guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[index].status = .done
        saveData()
    }

    func deleteAssignment(_ id: UUID) {
        assignments.removeAll { $0.id == id }
        saveData()
    }
}
