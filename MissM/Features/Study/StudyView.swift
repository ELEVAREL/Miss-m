import SwiftUI

// MARK: - Study Planner + Pomodoro View (Phase 2)

struct StudyView: View {
    @State private var viewModel = StudyViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STUDY PLANNER")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text("Focus Time")
                            .font(.custom("PlayfairDisplay-Italic", size: 18))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                // Pomodoro Timer
                PomodoroCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Today's study stats
                StudyStatsCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Week view
                WeekStudyView(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Study sessions list
                StudySessionsList(viewModel: viewModel)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Pomodoro Timer Card (per design: dark gradient, large ring, session dots)
struct PomodoroCard: View {
    let viewModel: StudyViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Timer ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 5)
                    .frame(width: 130, height: 130)

                // Progress ring
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.progress)

                // Time text (per design: large Cormorant)
                Text(viewModel.timeString)
                    .font(.custom("CormorantGaramond-SemiBold", size: 48))
                    .foregroundColor(.white)
            }
            .padding(.top, 4)

            // Phase label
            Text("POMODORO SESSION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.65))
                .padding(.top, 8)

            // Subject label
            if viewModel.isRunning {
                Text(viewModel.currentSubject.isEmpty ? "Study session" : viewModel.currentSubject)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 4)
            } else {
                TextField("What are you studying?", text: $viewModel.currentSubject)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }

            // Controls (per design: white primary, glass secondary)
            HStack(spacing: 10) {
                if viewModel.isRunning {
                    PomodoroButton(label: "⏸ Pause", isPrimary: true) { viewModel.pauseTimer() }
                    PomodoroButton(label: "⏭ Skip", isPrimary: false) { viewModel.resetTimer() }
                    PomodoroButton(label: "⚙", isPrimary: false) {}
                } else {
                    PomodoroButton(label: "▶ Start", isPrimary: true) { viewModel.startTimer() }
                    PomodoroButton(label: "⏭ Skip", isPrimary: false) {}
                    PomodoroButton(label: "⚙", isPrimary: false) {}
                }
            }
            .padding(.top, 16)

            // Session dots (per design)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < viewModel.completedPomodoros ? Color.white : (i == viewModel.completedPomodoros ? Color.white.opacity(0.7) : Color.white.opacity(0.25)))
                        .frame(width: 10, height: 10)
                        .shadow(color: i == viewModel.completedPomodoros ? Color.white.opacity(0.5) : .clear, radius: 4)
                }
            }
            .padding(.top, 14)

            Text("Session \(viewModel.completedPomodoros + 1) of 4 · \(viewModel.phaseLabel)")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 10)

            // Duration selector
            if !viewModel.isRunning && !viewModel.isPaused {
                HStack(spacing: 8) {
                    ForEach([15, 25, 45, 60], id: \.self) { minutes in
                        Button("\(minutes)m") {
                            viewModel.setDuration(minutes)
                        }
                        .font(.system(size: 10, weight: viewModel.durationMinutes == minutes ? .bold : .regular))
                        .foregroundColor(viewModel.durationMinutes == minutes ? Theme.Colors.rosePrimary : .white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(viewModel.durationMinutes == minutes ? Color.white : Color.white.opacity(0.15))
                        .cornerRadius(8)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Theme.Colors.roseDark, Theme.Colors.roseDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(22)
        .shadow(color: Color(hex: "#C2185B").opacity(0.22), radius: 20, x: 0, y: 6)
    }
}

struct PomodoroButton: View {
    let label: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isPrimary ? Theme.Colors.rosePrimary : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isPrimary ? Color.white : Color.white.opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPrimary ? .clear : Color.white.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Study Stats Card
struct StudyStatsCard: View {
    let viewModel: StudyViewModel

    var body: some View {
        HStack(spacing: 0) {
            StatItem(label: "Today", value: "\(viewModel.todayMinutes)m", icon: "⏱")
            Divider().frame(height: 30)
            StatItem(label: "Sessions", value: "\(viewModel.todaySessions)", icon: "📚")
            Divider().frame(height: 30)
            StatItem(label: "Streak", value: "\(viewModel.streak)d", icon: "🔥")
        }
        .padding(10)
        .glassCard(padding: 0)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 14))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.Colors.rosePrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Week Study View (per design: calendar-style day cells with dots)
struct WeekStudyView: View {
    let viewModel: StudyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("THIS WEEK")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2.5)
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Rectangle()
                    .fill(Theme.Colors.rosePrimary.opacity(0.14))
                    .frame(height: 1)
                    .frame(maxWidth: 80)
            }
            .padding(.bottom, 4)

            HStack(spacing: 6) {
                ForEach(viewModel.weekDays, id: \.label) { day in
                    VStack(spacing: 4) {
                        Text(day.label)
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(Theme.Colors.textSoft)

                        Text("\(day.dayNumber)")
                            .font(.custom("CormorantGaramond-SemiBold", size: 20))
                            .foregroundColor(day.isToday ? Theme.Colors.rosePrimary : Theme.Colors.textPrimary)

                        // Activity dots
                        HStack(spacing: 2) {
                            ForEach(0..<min(3, max(1, day.minutes / 25)), id: \.self) { _ in
                                Circle()
                                    .fill(day.isToday ? Theme.Colors.roseMid : Theme.Colors.rosePrimary)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        day.isToday
                        ? LinearGradient(colors: [Theme.Colors.rosePrimary.opacity(0.13), Theme.Colors.roseDeep.opacity(0.07)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(day.isToday ? Theme.Colors.rosePrimary.opacity(0.3) : Theme.Colors.glassBorder, lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .glassCard(padding: 0)
    }
}

// MARK: - Study Sessions List
struct StudySessionsList: View {
    let viewModel: StudyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT SESSIONS")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
            }

            if viewModel.recentSessions.isEmpty {
                Text("No sessions yet — start your first Pomodoro!")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textXSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(viewModel.recentSessions) { session in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(session.isCompleted ? Color.green : Theme.Colors.roseMid)
                            .frame(width: 6, height: 6)
                        Text(session.subject)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(session.durationMinutes)m")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textSoft)
                        Text(sessionTimeLabel(session.date))
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(12)
        .glassCard(padding: 0)
    }

    private func sessionTimeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Study ViewModel
@Observable
class StudyViewModel {
    var durationMinutes = 25
    var remainingSeconds: Int = 25 * 60
    var isRunning = false
    var isPaused = false
    var currentSubject = ""
    var sessions: [StudySession] = []
    var pomodoroPhase: PomodoroPhase = .focus
    var completedPomodoros = 0

    private var timer: Timer?

    enum PomodoroPhase: String {
        case focus = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"
    }

    var timeString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var progress: Double {
        let total = Double(durationMinutes * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / total)
    }

    var phaseLabel: String { pomodoroPhase.rawValue }

    var todayMinutes: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions
            .filter { $0.date >= today }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var todaySessions: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions.filter { $0.date >= today }.count
    }

    var streak: Int {
        // Simple streak: count consecutive days with sessions
        var count = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current

        while true {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            let hasSession = sessions.contains { $0.date >= checkDate && $0.date < dayEnd }
            if hasSession {
                count += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return count
    }

    var recentSessions: [StudySession] {
        Array(sessions.sorted { $0.date > $1.date }.prefix(10))
    }

    struct WeekDay {
        let label: String
        let dayNumber: Int
        let minutes: Int
        let isToday: Bool
    }

    var weekDays: [WeekDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 2), to: today)!
        let labels = ["M", "T", "W", "T", "F", "S", "S"]

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
            let dayNum = calendar.component(.day, from: day)
            let mins = sessions
                .filter { $0.date >= day && $0.date < dayEnd }
                .reduce(0) { $0 + $1.durationMinutes }
            return WeekDay(label: labels[offset], dayNumber: dayNum, minutes: mins, isToday: calendar.isDate(day, inSameDayAs: today))
        }
    }

    func setDuration(_ minutes: Int) {
        durationMinutes = minutes
        remainingSeconds = minutes * 60
    }

    func startTimer() {
        isRunning = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.timerComplete()
            }
        }
    }

    func pauseTimer() {
        isRunning = false
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resetTimer() {
        isRunning = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        remainingSeconds = durationMinutes * 60
    }

    private func timerComplete() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false

        if pomodoroPhase == .focus {
            // Record session
            let session = StudySession(
                subject: currentSubject.isEmpty ? "Study" : currentSubject,
                date: Date(),
                durationMinutes: durationMinutes,
                isCompleted: true
            )
            sessions.append(session)
            Task { try? await DataStore.shared.saveStudyPlans([StudyPlan(title: "Sessions", sessions: sessions)]) }

            completedPomodoros += 1
            // Switch to break
            if completedPomodoros % 4 == 0 {
                pomodoroPhase = .longBreak
                durationMinutes = 15
            } else {
                pomodoroPhase = .shortBreak
                durationMinutes = 5
            }
        } else {
            // Break over, back to focus
            pomodoroPhase = .focus
            durationMinutes = 25
        }
        remainingSeconds = durationMinutes * 60
    }
}
