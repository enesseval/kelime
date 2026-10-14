import AVFoundation

/// Offline en-US pronunciation with `AVSpeechSynthesizer`. No network, no audio files.
@MainActor
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    /// Speech rate multiplier (Ayarlar › Ses ve hız); 1 is the system default.
    var rateMultiplier: Float = 0.9

    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rateMultiplier
        synthesizer.speak(utterance)
    }
}
