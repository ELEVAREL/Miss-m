import SwiftUI

// MARK: - Pomodoro Timer

@Observable
class PomodoroTimer {
    var totalSeconds: Int = 25 * 60
    var remainingSeconds: Int = 25 * 60
    var isRunning = false
    var sessionsCompleted = 0
    var currentMode: Mode = .focus

    enum Mode: String {
        case focus = "Focus"
        case shortBreak = "Break"
        case longBreak = "Long Break"

        var duration: Int {
            switch self {
            case .focus: return 25 * 60
            case .shortBreak: return 5 * 60
            case .longBreak: return 15 * 60
            }
        }

        var color: Color {
            switch self {
            case .focus: return Theme.Colors.rosePrimary
            case .shortBreak: return Color.green
            case .longBreak: return Color.blue
            }
        }
    }

    private var timer: Timer?

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        isRunning = true
        FocusService.shared.enableStudyMode()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.complete()
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        FocusService.shared.disableStudyMode()
    }

    func reset() {
        pause()
        remainingSeconds = totalSeconds
    }


    func skip() {
        complete()
    }

    private func complete() {
        pause()
        if currentMode == .focus {
            sessionsCompleted += 1
            currentMode = sessionsCompleted % 4 == 0 ? .longBreak : .shortBreak
        } else {
            currentMode = .focus
        }
        totalSeconds = currentMode.duration
        remainingSeconds = totalSeconds
    }
}

// MARK: - Study Session

struct StudySession: Identifiable, Codable {
    let id: UUID
    var subject: String
    var date: Date
    var minutesStudied: Int

    init(id: UUID = UUID(), subject: String, date: Date = Date(), minutesStudied: Int = 25) {
        self.id = id; self.subject = subject; self.date = date; self.minutesStudied = minutesStudied
    }
}

// MARK: - Study Planner View

struct StudyPlannerView: View {
    let claudeService: ClaudeService
    @State private var pomodoro = PomodoroTimer()
    @State private var sessions: [StudySession] = []
    @State private var selectedDay = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Study Planner")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Text("\(pomodoro.sessionsCompleted) sessions today")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                }
                .padding(.horizontal, 14)

                // Pomodoro Hero Card
                VStack(spacing: 14) {
                    Text(pomodoro.currentMode.rawValue.uppercased())
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(.white.opacity(0.8))

                    // Timer Ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 6)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: pomodoro.progress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: pomodoro.progress)

                        VStack(spacing: 2) {
                            Text(pomodoro.timeString)
                                .font(.system(size: 28, weight: .light, design: .monospaced))
                                .foregroundColor(.white)
                            Text(pomodoro.currentMode.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    // Session Dots
                    HStack(spacing: 4) {
                        ForEach(0..<8, id: \.self) { i in
                            Circle()
                                .fill(i < pomodoro.sessionsCompleted ? Color.white : Color.white.opacity(0.25))
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Controls
                    HStack(spacing: 16) {
                        Button(action: { pomodoro.reset() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            pomodoro.isRunning ? pomodoro.pause() : pomodoro.start()
                        }) {
                            Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.Colors.rosePrimary)
                                .frame(width: 48, height: 48)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { pomodoro.skip() }) {
                            Image(systemName: "forward.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(Theme.Radius.lg)
                .padding(.horizontal, 14)

                // Week Calendar
                WeekCalendarRow(selectedDay: $selectedDay, sessions: sessions)
                    .padding(.horizontal, 14)

                // Today's Study Plan
                VStack(alignment: .leading, spacing: 8) {
                    Text("TODAY'S PLAN")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    if sessions.isEmpty {
                        HStack {
                            Text("No study sessions yet. Start a Pomodoro!")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textXSoft)
                            Spacer()
                        }
                    } else {
                        ForEach(todaySessions) { session in
                            HStack {
                                Circle()
                                    .fill(Theme.Colors.rosePrimary)
                                    .frame(width: 6, height: 6)
                                Text(session.subject)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                Text("\(session.minutesStudied)m")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSoft)
                            }
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .padding(.top, 10)
        }
    }

    var todaySessions: [StudySession] {
        sessions.filter { Calendar.current.isDateInToday($0.date) }
    }
}

// MARK: - Week Calendar Row

struct WeekCalendarRow: View {
    @Binding var selectedDay: Date
    let sessions: [StudySession]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { date in
                let isToday = Calendar.current.isDateInToday(date)
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDay)
                let sessionCount = sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count

                VStack(spacing: 3) {
                    Text(dayLabel(date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.textXSoft)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 13, weight: isToday ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
                    // Activity dots
                    HStack(spacing: 2) {
                        ForEach(0..<min(sessionCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(Theme.Colors.rosePrimary)
                                .frame(width: 3, height: 3)
                        }
                    }
                    .frame(height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                .cornerRadius(10)
                .onTapGesture { selectedDay = date }
            }
        }
        .glassCard(padding: 6)
    }

    var weekDays: [Date] {
        let cal = Calendar.current
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(3).uppercased()
    }
}
