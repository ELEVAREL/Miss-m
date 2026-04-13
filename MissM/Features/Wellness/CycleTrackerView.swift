import SwiftUI

// MARK: - Cycle Phase

enum CyclePhase: String, CaseIterable, Codable {
    case menstrual = "Menstrual"
    case follicular = "Follicular"
    case ovulation = "Ovulation"
    case luteal = "Luteal"

    var icon: String {
        switch self {
        case .menstrual: return "\u{1FA78}"
        case .follicular: return "\u{1F331}"
        case .ovulation: return "\u{2728}"
        case .luteal: return "\u{1F319}"
        }
    }

    var color: Color {
        switch self {
        case .menstrual: return Color(hex: "#E91E8C")
        case .follicular: return Color(hex: "#FF6B9D")
        case .ovulation: return Color(hex: "#7C4DFF")
        case .luteal: return Color(hex: "#FF9800")
        }
    }

    var dayRange: String {
        switch self {
        case .menstrual: return "Days 1-5"
        case .follicular: return "Days 6-13"
        case .ovulation: return "Days 14-16"
        case .luteal: return "Days 17-28"
        }
    }

    var typicalDays: ClosedRange<Int> {
        switch self {
        case .menstrual: return 1...5
        case .follicular: return 6...13
        case .ovulation: return 14...16
        case .luteal: return 17...28
        }
    }
}

// MARK: - Cycle Data

struct CycleData: Codable {
    var cycleLength: Int = 28
    var currentDay: Int = 14
    var lastPeriodStart: Date = Date()
    var moodLog: [MoodEntry] = []
    var symptomLog: [SymptomEntry] = []
}

struct MoodEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var mood: String
    var phase: CyclePhase
    var note: String

    init(id: UUID = UUID(), date: Date = Date(), mood: String, phase: CyclePhase, note: String = "") {
        self.id = id; self.date = date; self.mood = mood; self.phase = phase; self.note = note
    }
}

struct SymptomEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var symptoms: [String]

    init(id: UUID = UUID(), date: Date = Date(), symptoms: [String]) {
        self.id = id; self.date = date; self.symptoms = symptoms
    }
}

// MARK: - Cycle Tracker ViewModel

@Observable
class CycleTrackerViewModel {
    var data = CycleData()
    var selectedSymptoms: Set<String> = []
    var aiInsight = ""
    var isLoadingInsight = false
    private let claudeService: ClaudeService

    let allSymptoms = ["Tired", "Energetic", "Cramps", "Bloated", "Happy", "Anxious", "Headache", "Cravings", "Good Skin", "Moody"]

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await load() }
    }

    var currentPhase: CyclePhase {
        for phase in CyclePhase.allCases where phase.typicalDays.contains(data.currentDay) {
            return phase
        }
        return .luteal
    }

    var cycleProgress: Double {
        Double(data.currentDay) / Double(data.cycleLength)
    }

    func logSymptoms() {
        let entry = SymptomEntry(symptoms: Array(selectedSymptoms))
        data.symptomLog.append(entry)
        selectedSymptoms.removeAll()
        save()
    }

    func logMood(_ mood: String) {
        let entry = MoodEntry(mood: mood, phase: currentPhase)
        data.moodLog.append(entry)
        save()
    }

    func generateInsight() async {
        isLoadingInsight = true
        let recentSymptoms = data.symptomLog.suffix(5).flatMap(\.symptoms).joined(separator: ", ")
        do {
            aiInsight = try await claudeService.ask("""
            Miss M is on day \(data.currentDay) of her cycle (\(currentPhase.rawValue) phase).
            Recent symptoms: \(recentSymptoms.isEmpty ? "none logged" : recentSymptoms).
            Give her a brief, warm health tip for this phase (3 sentences max). Include relevant emoji.
            """)
        } catch {
            aiInsight = "Take care of yourself today, Miss M!"
        }
        isLoadingInsight = false
    }

    func load() async {
        data = await DataStore.shared.loadOrDefault(CycleData.self, from: "cycle.json", default: CycleData())
    }

    func save() {
        Task { try? await DataStore.shared.save(data, to: "cycle.json") }
    }

    // Calendar phase for a given day number
    func phaseForDay(_ day: Int) -> CyclePhase {
        for phase in CyclePhase.allCases where phase.typicalDays.contains(day) {
            return phase
        }
        return .luteal
    }
}

// MARK: - Cycle Tracker View

struct CycleTrackerView: View {
    let claudeService: ClaudeService
    @State private var vm: CycleTrackerViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._vm = State(initialValue: CycleTrackerViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Cycle Tracker")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Cycle Ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Theme.Colors.rosePale, lineWidth: 10)
                        .frame(width: 140, height: 140)

                    // Phase segments
                    ForEach(CyclePhase.allCases, id: \.self) { phase in
                        let startFraction = Double(phase.typicalDays.lowerBound - 1) / Double(vm.data.cycleLength)
                        let endFraction = Double(phase.typicalDays.upperBound) / Double(vm.data.cycleLength)
                        Circle()
                            .trim(from: startFraction, to: endFraction)
                            .stroke(phase.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                    }

                    // Current position marker
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: Theme.Colors.shadow, radius: 4)
                        .offset(y: -70)
                        .rotationEffect(.degrees(vm.cycleProgress * 360))

                    // Center text
                    VStack(spacing: 2) {
                        Text("Day \(vm.data.currentDay)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(vm.currentPhase.icon + " " + vm.currentPhase.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(vm.currentPhase.color)
                    }
                }
                .frame(height: 160)

                // Phase Cards
                HStack(spacing: 6) {
                    ForEach(CyclePhase.allCases, id: \.self) { phase in
                        VStack(spacing: 3) {
                            Text(phase.icon).font(.system(size: 16))
                            Text(phase.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(vm.currentPhase == phase ? .white : Theme.Colors.textMedium)
                            Text(phase.dayRange)
                                .font(.system(size: 7))
                                .foregroundColor(vm.currentPhase == phase ? .white.opacity(0.7) : Theme.Colors.textXSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(vm.currentPhase == phase ? AnyView(phase.color) : AnyView(Color.white.opacity(0.6)))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(phase.color.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 14)

                // Mood Correlation
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{1F60A} MOOD BY PHASE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    ForEach(CyclePhase.allCases, id: \.self) { phase in
                        let moodsForPhase = vm.data.moodLog.filter { $0.phase == phase }
                        HStack(spacing: 8) {
                            Text(phase.icon).font(.system(size: 12))
                            Text(phase.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.textMedium)
                                .frame(width: 65, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(phase.color.opacity(0.3))
                                    .frame(height: 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(phase.color)
                                            .frame(width: geo.size.width * min(Double(moodsForPhase.count) / 10, 1), height: 6),
                                        alignment: .leading
                                    )
                            }
                            .frame(height: 6)
                            Text("\(moodsForPhase.count)")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textXSoft)
                                .frame(width: 20)
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Cycle Calendar
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{1F4C5} CYCLE CALENDAR")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                        ForEach(1...vm.data.cycleLength, id: \.self) { day in
                            let phase = vm.phaseForDay(day)
                            Text("\(day)")
                                .font(.system(size: 9, weight: day == vm.data.currentDay ? .bold : .regular))
                                .foregroundColor(day == vm.data.currentDay ? .white : Theme.Colors.textPrimary)
                                .frame(width: 24, height: 24)
                                .background(day == vm.data.currentDay ? phase.color : phase.color.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }

                    // Legend
                    HStack(spacing: 10) {
                        ForEach(CyclePhase.allCases, id: \.self) { phase in
                            HStack(spacing: 3) {
                                Circle().fill(phase.color).frame(width: 6, height: 6)
                                Text(phase.rawValue)
                                    .font(.system(size: 8))
                                    .foregroundColor(Theme.Colors.textXSoft)
                            }
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Log Today
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{1F4DD} LOG TODAY")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    // Symptom chips
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 4) {
                        ForEach(vm.allSymptoms, id: \.self) { symptom in
                            Button(action: {
                                if vm.selectedSymptoms.contains(symptom) {
                                    vm.selectedSymptoms.remove(symptom)
                                } else {
                                    vm.selectedSymptoms.insert(symptom)
                                }
                            }) {
                                Text(symptom)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(vm.selectedSymptoms.contains(symptom) ? .white : Theme.Colors.textMedium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(vm.selectedSymptoms.contains(symptom) ? AnyView(Theme.Gradients.rosePrimary) : AnyView(Color.white.opacity(0.6)))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !vm.selectedSymptoms.isEmpty {
                        Button(action: vm.logSymptoms) {
                            Text("Save Log")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // AI Phase Insight
                if vm.isLoadingInsight {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.6)
                        Text("Getting phase insight...")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                } else if !vm.aiInsight.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\u{2728} PHASE INSIGHT")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text(vm.aiInsight)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineSpacing(3)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
        .task {
            await vm.generateInsight()
        }
    }
}
