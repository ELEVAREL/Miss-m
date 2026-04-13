import SwiftUI

// MARK: - Pomodoro Models

enum PomodoroState {
    case idle
    case focus
    case shortBreak
    case longBreak
}

// MARK: - Pomodoro ViewModel

@Observable
class PomodoroViewModel {
    var state: PomodoroState = .idle
    var timeRemaining: TimeInterval = 25 * 60
    var totalTime: TimeInterval = 25 * 60
    var sessionsCompleted = 0
    var totalSessions = 4
    var currentTask = "Study session"
    var focusDuration: Int = 25
    var shortBreakDuration: Int = 5
    var longBreakDuration: Int = 15
    var dndEnabled = true
    private var timer: Timer?

    var progress: Double {
        totalTime > 0 ? 1 - (timeRemaining / totalTime) : 0
    }

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var stateLabel: String {
        switch state {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var stateColor: Color {
        switch state {
        case .idle: return Theme.Colors.textSoft
        case .focus: return Theme.Colors.rosePrimary
        case .shortBreak: return Color(hex: "#26A69A")
        case .longBreak: return Color(hex: "#7C4DFF")
        }
    }

    func start() {
        state = .focus
        totalTime = TimeInterval(focusDuration * 60)
        timeRemaining = totalTime
        startTimer()
        if dndEnabled { FocusService.shared.enableStudyMode() }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        startTimer()
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        handleCompletion()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
        timeRemaining = TimeInterval(focusDuration * 60)
        totalTime = timeRemaining
        sessionsCompleted = 0
        if dndEnabled { FocusService.shared.disableStudyMode() }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timer?.invalidate()
                self.handleCompletion()
            }
        }
    }

    private func handleCompletion() {
        switch state {
        case .focus:
            sessionsCompleted += 1
            if sessionsCompleted >= totalSessions {
                state = .longBreak
                totalTime = TimeInterval(longBreakDuration * 60)
            } else {
                state = .shortBreak
                totalTime = TimeInterval(shortBreakDuration * 60)
            }
            timeRemaining = totalTime
            startTimer()
        case .shortBreak, .longBreak:
            if sessionsCompleted >= totalSessions {
                reset()
            } else {
                state = .focus
                totalTime = TimeInterval(focusDuration * 60)
                timeRemaining = totalTime
                startTimer()
            }
        case .idle:
            break
        }
    }

    // DND now handled by FocusService (supports cross-device sync)
}

// MARK: - Pomodoro Menu Bar View

struct PomodoroMenuBarView: View {
    let claudeService: ClaudeService
    @State private var viewModel = PomodoroViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Pomodoro")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Text(viewModel.stateLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(viewModel.stateColor)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 14)

                // Timer Ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Theme.Colors.rosePale, lineWidth: 8)
                        .frame(width: 150, height: 150)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            AngularGradient(colors: [viewModel.stateColor, viewModel.stateColor.opacity(0.5)], center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.progress)

                    // Center text
                    VStack(spacing: 4) {
                        Text(viewModel.timeString)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(viewModel.stateLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(viewModel.stateColor)
                    }
                }
                .frame(height: 170)

                // Session Dots
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.totalSessions, id: \.self) { i in
                        Circle()
                            .fill(i < viewModel.sessionsCompleted ? Theme.Colors.rosePrimary : Theme.Colors.rosePale)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.roseLight, lineWidth: 1)
                            )
                    }
                    Text("\(viewModel.sessionsCompleted)/\(viewModel.totalSessions)")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }

                // Current Task
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{1F4CB} CURRENT TASK")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    TextField("What are you working on?", text: $viewModel.currentTask)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(Color.white.opacity(0.6))
                        .cornerRadius(8)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Controls
                HStack(spacing: 10) {
                    if viewModel.state == .idle {
                        Button(action: viewModel.start) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Start Focus")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())
                    } else {
                        Button(action: viewModel.pause) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textMedium)
                                .padding(10)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button(action: viewModel.resume) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Theme.Gradients.rosePrimary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        Button(action: viewModel.skip) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textMedium)
                                .padding(10)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button(action: viewModel.reset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textMedium)
                                .padding(10)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)

                // Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{2699}\u{FE0F} TIMER SETTINGS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Focus").font(.system(size: 11)).foregroundColor(Theme.Colors.textMedium)
                        HStack(spacing: 8) {
                            ForEach([15, 25, 45, 60], id: \.self) { minutes in
                                Button(action: { viewModel.focusDuration = minutes }) {
                                    Text("\(minutes)m")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(viewModel.focusDuration == minutes ? .white : Theme.Colors.rosePrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            viewModel.focusDuration == minutes
                                                ? AnyShapeStyle(Theme.Gradients.rosePrimary)
                                                : AnyShapeStyle(Color.clear)
                                        )
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Theme.Colors.roseLight, lineWidth: viewModel.focusDuration == minutes ? 0 : 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    HStack {
                        Text("Auto-DND").font(.system(size: 11)).foregroundColor(Theme.Colors.textMedium)
                        Spacer()
                        Toggle("", isOn: $viewModel.dndEnabled)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                    }
                    if viewModel.dndEnabled && !FocusService.shared.isSetupComplete {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 10))
                            Text("Focus shortcut not found")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Focus Setup Guide
                if viewModel.dndEnabled && !FocusService.shared.isSetupComplete {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\u{1F514} FOCUS MODE SETUP")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text("Set up Focus to auto-DND on all your devices when studying")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMedium)

                        ForEach(Array(FocusService.setupSteps.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Theme.Colors.rosePrimary)
                                    .cornerRadius(9)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.step)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text(item.detail)
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textSoft)
                                        .lineSpacing(2)
                                }
                            }
                        }

                        Button(action: { FocusService.shared.checkSetup() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Check Again")
                            }
                            .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }
}
