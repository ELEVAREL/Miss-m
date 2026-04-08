import Speech
import AVFoundation

// MARK: - Voice Input Service (Phase 7)
// SFSpeechRecognizer — live transcription for voice commands

@Observable
class VoiceInputService {
    static let shared = VoiceInputService()

    var isListening = false
    var transcribedText = ""
    var isAuthorized = false
    var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch status {
        case .authorized:
            isAuthorized = true
        case .denied:
            errorMessage = "Speech recognition denied — enable in System Settings → Privacy → Speech Recognition."
        case .restricted:
            errorMessage = "Speech recognition restricted on this device."
        case .notDetermined:
            errorMessage = "Speech recognition not yet authorized."
        @unknown default:
            errorMessage = "Unknown speech recognition status."
        }
    }

    // MARK: - Start Listening

    func startListening() throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available."
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        transcribedText = ""
        errorMessage = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }

    // MARK: - Stop Listening

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
}
