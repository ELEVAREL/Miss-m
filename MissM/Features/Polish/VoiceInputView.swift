import SwiftUI
import Speech
import AVFoundation

// MARK: - Voice Input Manager

@Observable
class VoiceInputManager {
    var isListening = false
    var transcript = ""
    var errorMessage = ""
    var audioLevel: Float = 0

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            // Calculate audio level
            let channelData = buffer.floatChannelData?[0]
            let frames = buffer.frameLength
            if let data = channelData {
                var sum: Float = 0
                for i in 0..<Int(frames) { sum += abs(data[i]) }
                let avg = sum / Float(frames)
                DispatchQueue.main.async { self?.audioLevel = avg * 10 }
            }
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                DispatchQueue.main.async { self?.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self?.stopListening() }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            errorMessage = ""
        } catch {
            errorMessage = "Could not start audio: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        audioLevel = 0
    }
}

// MARK: - Text-to-Speech Manager

@Observable
class TextToSpeechManager {
    var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

// MARK: - Voice Input View

struct VoiceInputView: View {
    let claudeService: ClaudeService
    @State private var voice = VoiceInputManager()
    @State private var tts = TextToSpeechManager()
    @State private var aiResponse = ""
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Voice Assistant")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Voice Button
                VStack(spacing: 14) {
                    // Waveform animation
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Gradients.rosePrimary)
                                .frame(width: 4, height: voice.isListening ? CGFloat.random(in: 8...30) * CGFloat(voice.audioLevel + 0.3) : 8)
                                .animation(.easeInOut(duration: 0.15).delay(Double(i) * 0.05), value: voice.audioLevel)
                        }
                    }
                    .frame(height: 40)

                    // Mic button
                    Button(action: {
                        if voice.isListening {
                            voice.stopListening()
                        } else {
                            Task {
                                let granted = await voice.requestPermission()
                                if granted { voice.startListening() }
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(voice.isListening ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 60, height: 60)
                                .shadow(color: voice.isListening ? Theme.Colors.rosePrimary.opacity(0.4) : Theme.Colors.shadow, radius: 10)
                            Image(systemName: voice.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 22))
                                .foregroundColor(voice.isListening ? .white : Theme.Colors.rosePrimary)
                        }
                    }
                    .buttonStyle(.plain)

                    if voice.isListening {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("Listening...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                    }

                    if !voice.errorMessage.isEmpty {
                        Text(voice.errorMessage)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .glassCard(padding: 16)
                .padding(.horizontal, 14)

                // Transcript
                if !voice.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\u{1F399}\u{FE0F} YOU SAID")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text(voice.transcript)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .textSelection(.enabled)

                        Button(action: { Task { await sendToAI() } }) {
                            HStack(spacing: 4) {
                                if isProcessing { ProgressView().scaleEffect(0.5) }
                                Text(isProcessing ? "Thinking..." : "\u{2728} Ask Miss M")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(RoseButtonStyle())
                        .disabled(isProcessing)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // AI Response
                if !aiResponse.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\u{265B} MISS M")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Button(action: {
                                if tts.isSpeaking { tts.stop() } else { tts.speak(aiResponse) }
                            }) {
                                Image(systemName: tts.isSpeaking ? "speaker.slash" : "speaker.wave.2")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(aiResponse)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }

    func sendToAI() async {
        isProcessing = true
        do {
            aiResponse = try await claudeService.ask(voice.transcript)
        } catch {
            aiResponse = "Sorry, I couldn't process that right now."
        }
        isProcessing = false
    }
}
