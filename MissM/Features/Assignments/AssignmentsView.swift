import SwiftUI

// MARK: - Assignments Kanban View (Phase 2)
// 3-column board: To Do · In Progress · Submitted
// Matches docs/design/03-assignments-kanban.html

struct AssignmentsView: View {
    let claudeService: ClaudeService
    @State private var viewModel = AssignmentsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Assignment ")
                    .font(.custom("PlayfairDisplay-Italic", size: 22))
                    .foregroundColor(Theme.Colors.textPrimary)
                + Text("Tracker")
                    .font(.custom("PlayfairDisplay-Italic", size: 22))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Text("Kanban · AI-prioritised")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // AI Priority Banner (glass style per design)
            if let urgent = viewModel.mostUrgent {
                AIBanner(assignment: urgent)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            // Toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: { viewModel.showAddSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New Assignment")
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(RoseButtonStyle())

                    ToolbarFilterButton(icon: "📊", label: "By Subject")
                    ToolbarFilterButton(icon: "📅", label: "By Due Date")
                    ToolbarFilterButton(icon: "✦", label: "AI Prioritise")

                    if viewModel.dueThisWeekCount > 0 {
                        Text("\(viewModel.dueThisWeekCount) Due This Week")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.rosePrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.rosePrimary.opacity(0.11))
                            .cornerRadius(18)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)

            // Kanban columns
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    KanbanColumn(
                        title: "To Do",
                        dotColor: Color.red,
                        assignments: viewModel.todo,
                        cardStyle: .urgent,
                        onMove: { id in viewModel.moveToInProgress(id) }
                    )
                    KanbanColumn(
                        title: "In Progress",
                        dotColor: Color.orange,
                        assignments: viewModel.inProgress,
                        cardStyle: .progress,
                        onMove: { id in viewModel.moveToDone(id) }
                    )
                    KanbanColumn(
                        title: "Submitted",
                        dotColor: Color.green,
                        assignments: viewModel.done,
                        cardStyle: .done,
                        onMove: nil
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Spacer()
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddAssignmentSheet(viewModel: viewModel, claudeService: claudeService)
        }
        .task { await viewModel.loadData() }
    }
}

// MARK: - AI Priority Banner (glass card per design)
struct AIBanner: View {
    let assignment: Assignment

    var body: some View {
        HStack(spacing: 14) {
            // AI avatar
            Text("✦")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(colors: [Theme.Colors.rosePrimary, Theme.Colors.roseDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .shadow(color: Theme.Colors.rosePrimary.opacity(0.3), radius: 6)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                (Text("✦ ").foregroundColor(Theme.Colors.rosePrimary)
                 + Text("AI Priority Insight: ").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.Colors.textPrimary)
                 + Text("\(assignment.title)").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.Colors.textPrimary)
                 + Text(" — \(assignment.daysUntilDue) days left").font(.system(size: 12)).foregroundColor(Theme.Colors.textMedium))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Block Time") {}
                .buttonStyle(RoseButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassCard(padding: 0)
    }
}

// MARK: - Toolbar Filter Button
struct ToolbarFilterButton: View {
    let icon: String
    let label: String
    @State private var isHovered = false

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 4) {
                Text(icon).font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isHovered ? Theme.Colors.rosePrimary : Theme.Colors.textMedium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.white : Color.white.opacity(0.75))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? Theme.Colors.roseMid : Theme.Colors.roseLight, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Kanban Column (per design: colored dot header, glass background)
enum KanbanCardStyle {
    case urgent, progress, done

    var stripColor: Color {
        switch self {
        case .urgent:   return .red
        case .progress: return .orange
        case .done:     return .green
        }
    }

    var badgeBg: Color {
        switch self {
        case .urgent:   return Color.red.opacity(0.12)
        case .progress: return Color.orange.opacity(0.12)
        case .done:     return Color.green.opacity(0.12)
        }
    }

    var badgeColor: Color {
        switch self {
        case .urgent:   return Color(hex: "#B71C1C")
        case .progress: return Color(hex: "#C65200")
        case .done:     return Color(hex: "#2E7D32")
        }
    }
}

struct KanbanColumn: View {
    let title: String
    let dotColor: Color
    let assignments: [Assignment]
    let cardStyle: KanbanCardStyle
    let onMove: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header with dot
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 9, height: 9)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("\(assignments.count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(cardStyle.badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(cardStyle.badgeBg)
                    .cornerRadius(9)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 14)

            if assignments.isEmpty {
                Text("No items")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textXSoft)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .glassCard()
            } else {
                ForEach(assignments) { assignment in
                    AssignmentCard(
                        assignment: assignment,
                        style: cardStyle,
                        onMove: onMove
                    )
                    .padding(.bottom, 10)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .cornerRadius(20)
        .frame(width: 180)
    }
}

// MARK: - Assignment Card (per design: left strip, description, progress, AI button)
struct AssignmentCard: View {
    let assignment: Assignment
    let style: KanbanCardStyle
    let onMove: ((UUID) -> Void)?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Left color strip (3px)
            Rectangle()
                .fill(style.stripColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(assignment.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(style == .done ? Theme.Colors.textSoft : Theme.Colors.textPrimary)
                    .strikethrough(style == .done)
                    .lineLimit(2)
                    .padding(.bottom, 5)

                // Description (if available)
                if let desc = assignment.notes, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(style == .done ? Theme.Colors.textXSoft : Theme.Colors.textSoft)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.bottom, 8)
                }

                // Subject badge + due date
                HStack(spacing: 6) {
                    Text(assignment.course)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(style == .done ? Theme.Colors.textSoft : Theme.Colors.rosePrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            style == .done
                            ? Theme.Colors.rosePrimary.opacity(0.07)
                            : Theme.Colors.rosePrimary.opacity(0.1)
                        )
                        .cornerRadius(7)

                    if style != .done {
                        HStack(spacing: 3) {
                            Text("📅")
                                .font(.system(size: 9))
                            Text(dueDateLabel)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                    }

                    if assignment.priority == .high && style == .urgent {
                        Text("⚠️ Urgent")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "#B71C1C"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(18)
                    }
                }
                .padding(.bottom, 8)

                // Done state: show submitted text
                if style == .done {
                    Text("✓ Completed")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.top, 2)
                } else {
                    // Progress bar
                    VStack(spacing: 0) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.rosePrimary.opacity(0.1))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.Colors.rosePrimary, Theme.Colors.roseMid],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * assignment.progressValue, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.bottom, 8)

                    // Footer: status + AI button
                    HStack {
                        Text(assignment.progressLabel)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textXSoft)
                        Spacer()
                        if let onMove {
                            Button(action: { onMove(assignment.id) }) {
                                Text("✦ Move →")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Theme.Colors.rosePrimary.opacity(0.08))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Theme.Colors.rosePrimary.opacity(0.18), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(isHovered ? Color.white : Color.white.opacity(0.82))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .shadow(
            color: isHovered ? Color(hex: "#C2185B").opacity(0.13) : Color(hex: "#C2185B").opacity(0.05),
            radius: isHovered ? 14 : 4,
            x: 0, y: isHovered ? 5 : 2
        )
        .offset(y: isHovered ? -3 : 0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .clipped()
    }

    private var dueDateLabel: String {
        let days = assignment.daysUntilDue
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0 { return "\(abs(days))d overdue" }
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM"
        return df.string(from: assignment.dueDate)
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

// MARK: - Add Assignment Sheet
struct AddAssignmentSheet: View {
    let viewModel: AssignmentsViewModel
    let claudeService: ClaudeService
    @State private var title = ""
    @State private var course = ""
    @State private var notes = ""
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

                TextField("Course name (e.g. MKT302)", text: $course)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

                TextField("Description (optional)", text: $notes)
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
                    let assignment = Assignment(
                        title: title,
                        course: course,
                        dueDate: dueDate,
                        priority: priority,
                        notes: notes.isEmpty ? nil : notes
                    )
                    viewModel.addAssignment(assignment)
                    dismiss()
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
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

    var dueThisWeekCount: Int {
        let cal = Calendar.current
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return assignments.filter { $0.status != .done && $0.dueDate <= endOfWeek }.count
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
