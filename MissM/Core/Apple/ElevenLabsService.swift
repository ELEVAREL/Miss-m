import Foundation
import AVFoundation

// MARK: - ElevenLabs Text-to-Speech Service
// Gives Miss M a real AI voice using ElevenLabs API
// Falls back to Apple TTS if ElevenLabs fails

@Observable
class ElevenLabsService {
    static let shared = ElevenLabsService()

    var isSpeaking = false
    var isLoading = false
    var voiceEnabled = true
    var autoSpeak = false // Auto-speak assistant responses

    private var audioPlayer: AVAudioPlayer?
    private let fallbackTTS = AVSpeechSynthesizer()

    // ElevenLabs config
    private var apiKey: String? { KeychainManager.loadSetting("elevenlabs_key") }
    private let voiceId = "FGY2WhTYpPnrIDTdsKH5" // Laura — Enthusiast, Quirky, Young American
    private let modelId = "eleven_turbo_v2_5"
    private let baseURL = "https://api.elevenlabs.io/v1"

    var isConfigured: Bool { apiKey != nil && !apiKey!.isEmpty }

    private init() {}

    // MARK: - Save API Key

    static func saveAPIKey(_ key: String) {
        KeychainManager.saveSetting("elevenlabs_key", value: key)
    }

    static func loadAPIKey() -> String? {
        KeychainManager.loadSetting("elevenlabs_key")
    }

    // MARK: - Speak Text (ElevenLabs → Apple fallback)

    func speak(_ text: String) {
        guard voiceEnabled, !text.isEmpty else { return }

        // Strip emojis and markdown for cleaner speech
        let cleanText = text
            .replacingOccurrences(of: #"[^\p{L}\p{N}\p{P}\s]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanText.isEmpty else { return }

        if isConfigured {
            Task { await speakWithElevenLabs(cleanText) }
        } else {
            speakWithApple(cleanText)
        }
    }

    // MARK: - ElevenLabs API

    private func speakWithElevenLabs(_ text: String) async {
        guard let key = apiKey else { return }
        isLoading = true

        let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "voice_settings": [
                "stability": 0.4,          // Lower = more expressive/dynamic
                "similarity_boost": 0.8,    // High = stays true to Laura's voice
                "style": 0.4,              // More personality and emotion
                "use_speaker_boost": true
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // Fallback to Apple TTS
                await MainActor.run { speakWithApple(text) }
                isLoading = false
                return
            }

            // Play the audio
            await MainActor.run {
                playAudio(data: data)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                speakWithApple(text)
                isLoading = false
            }
        }
    }

    // MARK: - Audio Playback

    private func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = AudioDelegate.shared
            AudioDelegate.shared.onFinish = { [weak self] in
                self?.isSpeaking = false
            }
            audioPlayer?.play()
            isSpeaking = true
        } catch {
            speakWithApple("") // silent fallback
        }
    }

    // MARK: - Apple TTS Fallback

    private func speakWithApple(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Samantha")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.05
        utterance.volume = 0.9
        fallbackTTS.speak(utterance)
        isSpeaking = true
    }

    // MARK: - Stop

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        fallbackTTS.stopSpeaking(at: .immediate)
        isSpeaking = false
        isLoading = false
    }
}

// MARK: - Audio Delegate (for detecting playback end)

class AudioDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.onFinish?() }
    }
}
