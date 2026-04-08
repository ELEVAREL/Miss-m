import AVFoundation

// MARK: - Text-to-Speech Service (Phase 7)
// AVSpeechSynthesizer — reads AI responses aloud

@Observable
class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TextToSpeechService()

    var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Speak Text

    func speak(_ text: String, rate: Float = 0.5) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05
        utterance.volume = 0.9

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    // MARK: - Stop

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
