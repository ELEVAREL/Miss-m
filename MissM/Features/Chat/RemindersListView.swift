import SwiftUI
import EventKit

// MARK: - Reminders List ViewModel

@Observable
class RemindersListViewModel {
    var allReminders: [EKReminder] = []
    var isLoading = false
    var selectedFilter: ReminderFilter = .today
    var newTitle = ""
    var newPriority = 0
    var showAddForm = false

    enum ReminderFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case scheduled = "Scheduled"
        case flagged = "Flagged"

        var icon: String {
            switch self {
            case .all: return "\u{1F4CB}"
            case .today: return "\u{2600}\u{FE0F}"
            case .scheduled: return "\u{1F4C5}"
            case .flagged: return "\u{1F6A9}"
            }
        }
    }

    func load() async {
        isLoading = true
        allReminders = await RemindersService.shared.getIncompleteReminders()
        isLoading = false
    }

    var filtered: [EKReminder] {
        switch selectedFilter {
        case .all: return allReminders
        case .today:
            let cal = Calendar.current
            return allReminders.filter { r in
                guard let due = r.dueDateComponents, let date = cal.date(from: due) else { return false }
                return cal.isDateInToday(date)
            }
        case .scheduled:
            return allReminders.filter { $0.dueDateComponents != nil }
        case .flagged:
            return allReminders.filter { $0.priority > 0 }
        }
    }

    func addReminder() {
        guard !newTitle.isEmpty else { return }
        try? RemindersService.shared.addReminder(title: newTitle, priority: newPriority)
        newTitle = ""
        newPriority = 0
        showAddForm = false
        Task { await load() }
    }

    func complete(_ reminder: EKReminder) {
        try? RemindersService.shared.completeReminder(reminder)
        Task { await load() }
    }
}

// MARK: - Reminders List View

struct RemindersListView: View {
    @State private var vm = RemindersListViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Reminders")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Button(action: { vm.showAddForm.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(RoseButtonStyle())
                }
                .padding(.horizontal, 14)

                // Filters
                HStack(spacing: 6) {
                    ForEach(RemindersListViewModel.ReminderFilter.allCases, id: \.self) { filter in
                        Button(action: { vm.selectedFilter = filter }) {
                            HStack(spacing: 3) {
                                Text(filter.icon).font(.system(size: 9))
                                Text(filter.rawValue).font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(vm.selectedFilter == filter ? .white : Theme.Colors.textMedium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(vm.selectedFilter == filter ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(vm.selectedFilter == filter ? Color.clear : Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Add form
                if vm.showAddForm {
                    VStack(spacing: 8) {
                        TextField("Reminder title...", text: $vm.newTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                            .onSubmit { vm.addReminder() }
                        HStack {
                            Picker("Priority", selection: $vm.newPriority) {
                                Text("Normal").tag(0)
                                Text("High").tag(1)
                                Text("Urgent").tag(5)
                            }
                            .pickerStyle(.segmented)
                            Spacer()
                            Button("Add") { vm.addReminder() }
                                .buttonStyle(RoseButtonStyle())
                                .disabled(vm.newTitle.isEmpty)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // Reminders list
                if vm.isLoading {
                    HStack { ProgressView().scaleEffect(0.6); Text("Loading...").font(.system(size: 11)).foregroundColor(Theme.Colors.textSoft) }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                } else if vm.filtered.isEmpty {
                    Text("No reminders")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSoft)
                        .glassCard(padding: 14)
                        .padding(.horizontal, 14)
                } else {
                    VStack(spacing: 4) {
                        ForEach(vm.filtered, id: \.calendarItemIdentifier) { reminder in
                            HStack(spacing: 8) {
                                Button(action: { vm.complete(reminder) }) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.Colors.roseLight)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(reminder.title ?? "Untitled")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    if let due = reminder.dueDateComponents, let date = Calendar.current.date(from: due) {
                                        Text(date, style: .date)
                                            .font(.system(size: 9))
                                            .foregroundColor(Theme.Colors.textSoft)
                                    }
                                }
                                Spacer()
                                if reminder.priority > 0 {
                                    Text("\u{1F6A9}")
                                        .font(.system(size: 10))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
        .task { await vm.load() }
    }
}
