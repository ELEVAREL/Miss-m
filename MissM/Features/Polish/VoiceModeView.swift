import SwiftUI
import Speech
import AVFoundation

// MARK: - Voice Mode View
// Full-screen animated voice assistant UI (like ChatGPT voice mode)
// Animated orb that responds to audio levels + speaking state

@Observable
class VoiceModeManager {
    var isActive = false
    var state: VoiceState = .idle
    var transcript = ""
    var response = ""
    var audioLevel: Float = 0

    enum VoiceState: Equatable {
        case idle
        case listening
        case thinking
        case speaking
    }

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var claudeService: ClaudeService?

    func configure(claude: ClaudeService) {
        self.claudeService = claude
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func startListening() {
        guard let recognizer, recognizer.isAvailable else { return }
        transcript = ""
        response = ""
        state = .listening

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            let channelData = buffer.floatChannelData?[0]
            let frames = buffer.frameLength
            if let data = channelData {
                var sum: Float = 0
                for i in 0..<Int(frames) { sum += abs(data[i]) }
                let avg = sum / Float(frames)
                DispatchQueue.main.async { self?.audioLevel = min(avg * 12, 1.0) }
            }
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                DispatchQueue.main.async { self?.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self?.stopListening()
                    if !(self?.transcript.isEmpty ?? true) {
                        self?.processWithAI()
                    }
                }
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        audioLevel = 0
    }

    func processWithAI() {
        guard let claude = claudeService, !transcript.isEmpty else {
            state = .idle
            return
        }
        state = .thinking

        Task { @MainActor in
            do {
                // Gather full context just like chat does
                let context = await gatherContext()
                let contextualPrompt = ClaudeService.buildContextualPrompt(context: context)

                // Check if web search helps
                var extraContext = ""
                let lower = transcript.lowercased()
                let searchTriggers = ["search", "look up", "find", "what is", "latest", "how to", "recipe", "recommend", "research"]
                if searchTriggers.contains(where: { lower.contains($0) }) {
                    let searchResults = await WebSearchService.shared.search(transcript)
                    extraContext = "\n\nWEB SEARCH RESULTS:\n\(searchResults)\n\nSummarize clearly for a voice response. Keep it brief."
                }

                let fullPrompt = contextualPrompt + extraContext + "\n\nIMPORTANT: This is a VOICE response. Keep it conversational and brief (3-4 sentences max). No formatting, no lists, no numbers. Speak naturally as if talking to a friend."

                let result = try await claude.ask(transcript, systemOverride: fullPrompt)
                response = result
                state = .speaking
                ElevenLabsService.shared.speak(result)
                observeSpeechEnd()
            } catch {
                response = "Sorry, I couldn't process that."
                state = .idle
            }
        }
    }

    private func gatherContext() async -> ClaudeService.LiveContext {
        var ctx = ClaudeService.LiveContext()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d yyyy"
        ctx.dateString = formatter.string(from: Date())

        let cycleData = await DataStore.shared.loadOrDefault(CycleData.self, from: "cycle.json", default: CycleData())
        ctx.cycleDay = cycleData.currentDay
        ctx.cycleLength = cycleData.cycleLength
        for phase in CyclePhase.allCases where phase.typicalDays.contains(cycleData.currentDay) {
            ctx.cyclePhase = phase.rawValue; break
        }
        ctx.calendarSummary = await CalendarService.shared.todaySummary()
        ctx.remindersSummary = await RemindersService.shared.todaySummary()
        ctx.sleepHours = await HealthService.shared.sleepHoursLastNight()
        ctx.steps = await HealthService.shared.stepsToday()
        ctx.heartRate = await HealthService.shared.latestHeartRate()

        let foodPrefs = await DataStore.shared.loadOrDefault(FoodPreferences.self, from: "food-prefs.json", default: FoodPreferences())
        let allDislikes = foodPrefs.dislikedFoods + foodPrefs.allergies
        ctx.foodDislikes = allDislikes.isEmpty ? "None" : allDislikes.joined(separator: ", ")

        return ctx
    }

    private func observeSpeechEnd() {
        Task { @MainActor in
            // Poll until speech finishes
            while ElevenLabsService.shared.isSpeaking {
                try? await Task.sleep(for: .milliseconds(200))
            }
            if state == .speaking { state = .idle }
        }
    }

    func cancel() {
        stopListening()
        ElevenLabsService.shared.stop()
        state = .idle
        isActive = false
    }
}

// MARK: - Voice Mode View

struct VoiceModeView: View {
    let claudeService: ClaudeService
    @Binding var isPresented: Bool
    @State private var vm = VoiceModeManager()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#1A0A10"), Color(hex: "#2D0F1E"), Color(hex: "#1A0A10")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        vm.cancel()
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }

                Spacer()

                // Animated Orb
                VoiceOrb(state: vm.state, audioLevel: vm.audioLevel)
                    .frame(width: 180, height: 180)

                // State label
                Text(stateLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 20)

                // Transcript / Response
                ScrollView {
                    VStack(spacing: 12) {
                        if !vm.transcript.isEmpty {
                            Text(vm.transcript)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }

                        if !vm.response.isEmpty {
                            Text(vm.response)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.roseLight)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal, 30)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .padding(.top, 16)

                Spacer()

                // Controls
                HStack(spacing: 30) {
                    // Stop button
                    if vm.state == .speaking {
                        Button(action: {
                            ElevenLabsService.shared.stop()
                            vm.state = .idle
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Main mic button
                    Button(action: {
                        if vm.state == .listening {
                            vm.stopListening()
                            if !vm.transcript.isEmpty { vm.processWithAI() }
                        } else if vm.state == .idle {
                            Task {
                                let status = await withCheckedContinuation { cont in
                                    SFSpeechRecognizer.requestAuthorization { s in cont.resume(returning: s) }
                                }
                                if status == .authorized { vm.startListening() }
                            }
                        }
                    }) {
                        ZStack {
                            // Outer glow ring
                            Circle()
                                .stroke(micRingColor, lineWidth: 2)
                                .frame(width: 72, height: 72)
                                .opacity(vm.state == .listening ? 1 : 0.3)

                            Circle()
                                .fill(micFillColor)
                                .frame(width: 60, height: 60)
                                .shadow(color: micRingColor.opacity(0.5), radius: vm.state == .listening ? 20 : 8)

                            Image(systemName: micIcon)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.state == .thinking)

                    // End session
                    Button(action: {
                        vm.cancel()
                        isPresented = false
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#FF3B30"))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#FF3B30").opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            vm.configure(claude: claudeService)
        }
    }

    var stateLabel: String {
        switch vm.state {
        case .idle: return "Tap the mic to talk"
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .speaking: return "Speaking..."
        }
    }

    var micIcon: String {
        switch vm.state {
        case .listening: return "stop.fill"
        case .thinking: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        default: return "mic.fill"
        }
    }

    var micFillColor: some ShapeStyle {
        vm.state == .listening
            ? AnyShapeStyle(Theme.Gradients.rosePrimary)
            : AnyShapeStyle(Color.white.opacity(0.15))
    }

    var micRingColor: Color {
        switch vm.state {
        case .listening: return Theme.Colors.rosePrimary
        case .thinking: return Theme.Colors.gold
        case .speaking: return Theme.Colors.roseMid
        default: return .white.opacity(0.3)
        }
    }
}

// MARK: - Animated Voice Orb

struct VoiceOrb: View {
    let state: VoiceModeManager.VoiceState
    let audioLevel: Float

    @State private var rotation: Double = 0
    @State private var pulse = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(ringColor.opacity(0.08 + Double(i) * 0.04), lineWidth: 1)
                    .frame(width: ringSize(i), height: ringSize(i))
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .animation(
                        .easeInOut(duration: 1.5 + Double(i) * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.2),
                        value: pulse
                    )
            }

            // Main orb — radial gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: orbColors,
                        center: .center,
                        startRadius: 10,
                        endRadius: orbRadius
                    )
                )
                .frame(width: orbDiameter, height: orbDiameter)
                .shadow(color: ringColor.opacity(0.4), radius: shadowRadius)
                .scaleEffect(breathe ? orbScale : 1.0)
                .animation(.easeInOut(duration: animDuration).repeatForever(autoreverses: true), value: breathe)

            // Inner light
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: orbDiameter * 0.7, height: orbDiameter * 0.7)
                .offset(x: -10, y: -10)
                .blur(radius: 8)

            // Rotating accent for visual interest
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.5), Color.clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: orbDiameter + 20, height: orbDiameter + 20)
                .rotationEffect(.degrees(rotation))

            // State icon
            if state == .thinking {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)
            }
        }
        .onAppear {
            pulse = true
            breathe = true
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    var orbDiameter: CGFloat {
        switch state {
        case .idle: return 100
        case .listening: return 100 + CGFloat(audioLevel) * 30
        case .thinking: return 90
        case .speaking: return 110
        }
    }

    var orbScale: CGFloat {
        switch state {
        case .listening: return 1.0 + CGFloat(audioLevel) * 0.15
        case .speaking: return 1.08
        case .thinking: return 0.95
        default: return 1.03
        }
    }

    var animDuration: Double {
        switch state {
        case .listening: return 0.15
        case .speaking: return 0.6
        case .thinking: return 1.2
        default: return 2.0
        }
    }

    var shadowRadius: CGFloat {
        switch state {
        case .listening: return 25 + CGFloat(audioLevel) * 15
        case .speaking: return 30
        case .thinking: return 15
        default: return 12
        }
    }

    var orbRadius: CGFloat { orbDiameter / 2 }

    func ringSize(_ index: Int) -> CGFloat {
        orbDiameter + CGFloat(index + 1) * 30
    }

    var orbColors: [Color] {
        switch state {
        case .idle:
            return [Theme.Colors.rosePrimary.opacity(0.8), Theme.Colors.roseDark.opacity(0.4), Color(hex: "#1A0A10")]
        case .listening:
            return [Theme.Colors.rosePrimary, Theme.Colors.roseDeep, Theme.Colors.roseDark.opacity(0.6)]
        case .thinking:
            return [Theme.Colors.gold.opacity(0.8), Theme.Colors.rosePrimary.opacity(0.5), Color(hex: "#1A0A10")]
        case .speaking:
            return [Theme.Colors.roseMid, Theme.Colors.rosePrimary, Theme.Colors.roseDeep]
        }
    }

    var ringColor: Color {
        switch state {
        case .listening: return Theme.Colors.rosePrimary
        case .thinking: return Theme.Colors.gold
        case .speaking: return Theme.Colors.roseMid
        default: return Theme.Colors.roseLight
        }
    }
}
