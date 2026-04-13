import Foundation
import Speech
import AVFoundation

// MARK: - Trigger Word Service
// Listens in the background for "Miss M" or "Hey Miss M" to activate voice mode
// Uses Apple Speech framework for on-device keyword detection

@Observable
class TriggerWordService {
    static let shared = TriggerWordService()

    var isListening = false
    var isEnabled = false
    var onTrigger: (() -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var restartTimer: Timer?

    private let triggerPhrases = ["miss m", "hey miss m", "hey miss em", "miss em", "misem"]

    private init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else { return }

        isEnabled = true
        beginRecognition()
    }

    func stopListening() {
        isEnabled = false
        isListening = false
        restartTimer?.invalidate()
        restartTimer = nil
        tearDown()
    }

    private func beginRecognition() {
        guard isEnabled else { return }

        // Clean up any previous session
        tearDown()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Stay on device for privacy

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString.lowercased()
                // Check if trigger phrase was spoken
                for phrase in self.triggerPhrases {
                    if text.hasSuffix(phrase) || text.contains(phrase) {
                        DispatchQueue.main.async {
                            self.tearDown()
                            self.onTrigger?()
                            // Restart listening after a delay
                            self.restartTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                                self.beginRecognition()
                            }
                        }
                        return
                    }
                }
            }

            // If recognition ended (timeout), restart it
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self.tearDown()
                    // Auto-restart after brief pause
                    if self.isEnabled {
                        self.restartTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            self.beginRecognition()
                        }
                    }
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            isListening = false
        }
    }

    private func tearDown() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
}
