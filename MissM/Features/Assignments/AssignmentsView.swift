import SwiftUI

// MARK: - Assignment Model

struct Assignment: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var subject: String
    var dueDate: Date
    var status: Status
    var wordCount: Int
    var targetWords: Int
    var priority: Priority

    init(id: UUID = UUID(), title: String, description: String = "", subject: String = "", dueDate: Date = Date(), status: Status = .todo, wordCount: Int = 0, targetWords: Int = 2000, priority: Priority = .medium) {
        self.id = id
        self.title = title
        self.description = description
        self.subject = subject
        self.dueDate = dueDate
        self.status = status
        self.wordCount = wordCount
        self.targetWords = targetWords
        self.priority = priority
    }

    enum Status: String, Codable, CaseIterable {
        case todo = "To Do"
        case inProgress = "In Progress"
        case submitted = "Submitted"

        var color: Color {
            switch self {
            case .todo: return Theme.Colors.rosePrimary
            case .inProgress: return Color.orange
            case .submitted: return Color.green
            }
        }
    }

    enum Priority: String, Codable, CaseIterable {
        case high, medium, low
        var label: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .green
            }
        }
    }

    var progress: Double {
        guard targetWords > 0 else { return 0 }
        return min(Double(wordCount) / Double(targetWords), 1.0)
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
}

// MARK: - Assignments ViewModel

@Observable
class AssignmentsViewModel {
    var assignments: [Assignment] = []
    var showAddSheet = false

    init() {
        Task { await loadAssignments() }
    }

    func loadAssignments() async {
        assignments = await DataStore.shared.loadOrDefault([Assignment].self, from: "assignments.json", default: [])
    }

    func save() {
        Task { try? await DataStore.shared.save(assignments, to: "assignments.json") }
    }

    func add(_ assignment: Assignment) {
        assignments.append(assignment)
        save()
    }

    func move(_ assignment: Assignment, to status: Assignment.Status) {
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            assignments[index].status = status
            save()
        }
    }

    func delete(_ assignment: Assignment) {
        assignments.removeAll { $0.id == assignment.id }
        save()
    }

    func assignments(for status: Assignment.Status) -> [Assignment] {
        assignments.filter { $0.status == status }
            .sorted { $0.dueDate < $1.dueDate }
    }
}

// MARK: - Assignments Kanban View

struct AssignmentsView: View {
    let claudeService: ClaudeService
    @State private var viewModel = AssignmentsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Assignments")
                    .font(Theme.Fonts.display(18))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Text("\(viewModel.assignments.count) total")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.rosePale)
                    .cornerRadius(10)
                Button(action: { viewModel.showAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // AI Priority Banner
            if let urgent = viewModel.assignments.filter({ $0.status != .submitted }).sorted(by: { $0.dueDate < $1.dueDate }).first {
                HStack(spacing: 8) {
                    Text("\u{1F3AF}")
                        .font(.system(size: 12))
                    Text("Priority: **\(urgent.title)** \u{2014} \(urgent.daysRemaining)d left")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(10)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(12)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            // Kanban Columns
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Assignment.Status.allCases, id: \.self) { status in
                        KanbanColumn(
                            status: status,
                            assignments: viewModel.assignments(for: status),
                            onMove: { assignment, newStatus in viewModel.move(assignment, to: newStatus) },
                            onDelete: { viewModel.delete($0) }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddAssignmentSheet { assignment in
                viewModel.add(assignment)
            }
        }
    }
}

// MARK: - Kanban Column

struct KanbanColumn: View {
    let status: Assignment.Status
    let assignments: [Assignment]
    let onMove: (Assignment, Assignment.Status) -> Void
    let onDelete: (Assignment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                Text(status.rawValue.uppercased())
                    .font(.custom("CormorantGaramond-SemiBold", size: 11))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Text("\(assignments.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(status.color.opacity(0.8))
                    .clipShape(Circle())
                Spacer()
            }

            if assignments.isEmpty {
                Text("No assignments")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textXSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(assignments) { assignment in
                    AssignmentCard(
                        assignment: assignment,
                        onMove: { onMove(assignment, $0) },
                        onDelete: { onDelete(assignment) }
                    )
                }
            }
        }
        .glassCard(padding: 10)
    }
}

// MARK: - Assignment Card

struct AssignmentCard: View {
    let assignment: Assignment
    let onMove: (Assignment.Status) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Priority bar
            RoundedRectangle(cornerRadius: 2)
                .fill(assignment.priority.color)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(assignment.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(assignment.daysRemaining)d")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(assignment.daysRemaining <= 3 ? .red : Theme.Colors.textSoft)
                }

                if !assignment.subject.isEmpty {
                    Text(assignment.subject)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.rosePale)
                        .cornerRadius(6)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.Colors.rosePale)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.Gradients.rosePrimary)
                            .frame(width: geo.size.width * assignment.progress, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(assignment.wordCount)/\(assignment.targetWords) words")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
                    Spacer()
                    // Move buttons
                    if assignment.status != .submitted {
                        let next: Assignment.Status = assignment.status == .todo ? .inProgress : .submitted
                        Button(action: { onMove(next) }) {
                            Text(next == .inProgress ? "Start" : "Submit")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(next.color)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.leading, 8)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.7))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
}

// MARK: - Add Assignment Sheet

struct AddAssignmentSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var subject = ""
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var targetWords = "2000"
    @State private var priority: Assignment.Priority = .medium
    let onAdd: (Assignment) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Assignment")
                .font(Theme.Fonts.display(18))
                .foregroundColor(Theme.Colors.rosePrimary)

            VStack(spacing: 10) {
                TextField("Assignment title", text: $title)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

                TextField("Subject (e.g. Marketing 301)", text: $subject)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    .font(.system(size: 12))

                TextField("Target words", text: $targetWords)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

                Picker("Priority", selection: $priority) {
                    ForEach(Assignment.Priority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Button("Add Assignment") {
                    let assignment = Assignment(
                        title: title,
                        subject: subject,
                        dueDate: dueDate,
                        targetWords: Int(targetWords) ?? 2000,
                        priority: priority
                    )
                    onAdd(assignment)
                    dismiss()
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(title.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Theme.Gradients.background)
    }
}
