import AVFoundation

/// Offline en-US pronunciation with `AVSpeechSynthesizer`. No network, no audio files.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()
    private var prepared = false

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    /// The best installed en-US voice (enhanced or premium when the user has one).
    private lazy var voice: AVSpeechSynthesisVoice? = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language == "en-US" }
        .max { $0.quality.rawValue < $1.quality.rawValue }
        ?? AVSpeechSynthesisVoice(language: "en-US")

    /// Speech rate multiplier (Ayarlar › Ses ve hız); 1 is the system default.
    var rateMultiplier: Float = 0.9

    /// Sets the audio session up and loads the voice ahead of the first word, so the first
    /// tap neither clicks nor waits. Rendering to a buffer warms the engine without sound.
    func prepare() {
        guard !prepared else { return }
        prepared = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        let warmUp = AVSpeechUtterance(string: "a")
        warmUp.voice = voice
        warmUp.volume = 0
        synthesizer.write(warmUp) { _ in }
    }

    func speak(_ text: String) {
        prepare()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // Activating the session before speaking, not inside the synthesizer, avoids the pop
        // at the start of the first word.
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rateMultiplier
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    /// Gives other audio its volume back once a word is spoken.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
