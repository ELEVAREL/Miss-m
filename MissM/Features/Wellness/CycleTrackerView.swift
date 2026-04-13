import SwiftUI
import Vision
import AppKit

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

    var hasHealthKitData = false
    var isImporting = false
    var importStatus = ""

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await load() }
    }

    /// Imports cycle data from HealthKit (reads Flo-synced menstrual data)
    func importFromHealthKit() async {
        isImporting = true
        importStatus = "Reading HealthKit..."

        let health = HealthService.shared
        if !health.isAuthorized { _ = await health.requestAccess() }

        // Get cycle day and length from HealthKit
        if let cycleDay = await health.currentCycleDay() {
            data.currentDay = min(cycleDay, data.cycleLength)
            hasHealthKitData = true
            importStatus = "Found cycle day: \(cycleDay)"
        }

        if let cycleLength = await health.estimatedCycleLength() {
            data.cycleLength = cycleLength
            importStatus = "Cycle length: \(cycleLength) days"
        }

        if let lastStart = await health.lastMenstrualFlowStart() {
            data.lastPeriodStart = lastStart
        }

        save()
        isImporting = false
        if hasHealthKitData {
            importStatus = "Synced from Health (Flo)"
        } else {
            importStatus = "No cycle data found. Enable Flo \u{2192} Health sync first."
        }
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

    // MARK: - Flo Screenshot Import (Vision OCR + Claude)

    var isScanning = false
    var scanStatus = ""
    var scannedText = ""

    func scanFloScreenshot() {
        let panel = NSOpenPanel()
        panel.title = "Select a Flo App Screenshot"
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await processImage(at: url) }
    }

    func processImage(at url: URL) async {
        isScanning = true
        scanStatus = "Scanning screenshot..."

        // Step 1: Vision OCR
        guard let cgImage = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            scanStatus = "Could not load image"
            isScanning = false
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            scanStatus = "OCR failed"
            isScanning = false
            return
        }

        let recognizedText = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        scannedText = recognizedText
        scanStatus = "Analyzing with Miss M..."

        // Step 2: Claude interprets the OCR text
        do {
            let response = try await claudeService.ask("""
            I scanned a screenshot from the Flo period tracking app. Here is the text found:

            \(recognizedText)

            Extract the following information and return ONLY a JSON object (no markdown):
            {
                "cycleDay": <current day number in cycle, or null>,
                "cycleLength": <total cycle length in days, or null>,
                "lastPeriodStart": "<date in YYYY-MM-DD format, or null>",
                "currentPhase": "<menstrual/follicular/ovulation/luteal, or null>"
            }

            If you can't determine a value, use null. Parse dates from any format you find.
            """)

            // Parse Claude's JSON response
            if let jsonData = response.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                if let day = parsed["cycleDay"] as? Int {
                    data.currentDay = day
                }
                if let length = parsed["cycleLength"] as? Int {
                    data.cycleLength = length
                }
                if let dateStr = parsed["lastPeriodStart"] as? String {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = formatter.date(from: dateStr) {
                        data.lastPeriodStart = date
                    }
                }
                save()
                scanStatus = "Imported from Flo screenshot"
            } else {
                scanStatus = "Could not parse — try a clearer screenshot"
            }
        } catch {
            scanStatus = "Analysis failed — try again"
        }
        isScanning = false
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
                    if vm.hasHealthKitData {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                            Text("Flo Synced")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#26A69A"))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 14)

                // HealthKit / Flo Import
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{1F4F1} SYNC FROM FLO")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    Text("Flo syncs your period data to Apple Health. Miss M reads it from there.")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMedium)
                        .lineSpacing(2)

                    HStack(spacing: 8) {
                        Button(action: {
                            Task { await vm.importFromHealthKit() }
                        }) {
                            HStack(spacing: 4) {
                                if vm.isImporting {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "heart.text.square")
                                }
                                Text(vm.isImporting ? "Importing..." : "Import from Health")
                            }
                            .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())
                        .disabled(vm.isImporting)

                        if !vm.importStatus.isEmpty {
                            Text(vm.importStatus)
                                .font(.system(size: 9))
                                .foregroundColor(vm.hasHealthKitData ? Color(hex: "#26A69A") : Theme.Colors.textSoft)
                        }
                    }

                    // Flo Screenshot Scanner
                    VStack(alignment: .leading, spacing: 6) {
                        Divider().padding(.vertical, 4)
                        Text("Or scan a Flo screenshot if Health sync isn't working:")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textSoft)

                        HStack(spacing: 8) {
                            Button(action: { vm.scanFloScreenshot() }) {
                                HStack(spacing: 4) {
                                    if vm.isScanning {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "camera.viewfinder")
                                    }
                                    Text(vm.isScanning ? "Scanning..." : "Scan Flo Screenshot")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.rosePrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.Colors.rosePale)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isScanning)

                            if !vm.scanStatus.isEmpty {
                                Text(vm.scanStatus)
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.textMedium)
                            }
                        }

                        if vm.isScanning {
                            HStack(spacing: 8) {
                                SkeletonView(height: 12)
                                SkeletonView(height: 12).frame(width: 80)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .glassCard(padding: 10)
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
