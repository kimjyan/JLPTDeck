import AVFoundation

/// F16 (G-CardView): minimal AVSpeechSynthesizer wrapper for one-shot
/// headword playback. Singleton so the synthesizer instance survives
/// across cards (avoids cold-start lag on the second tap). NO autoplay
/// — playback is only triggered by the explicit speaker button tap.
///
/// Silent-mode policy: uses `.ambient` audio session so iOS hardware-mute
/// fully silences playback without requiring a separate toggle in the
/// app. Keeps the implementation small and matches user expectation
/// from the Japanese learner ecosystem (Anki, etc.).
@MainActor
enum SpeechManager {
    private static let synthesizer = AVSpeechSynthesizer()

    /// Speak the given Japanese text. Cancels any in-flight utterance
    /// first so rapid successive taps don't queue up.
    static func speak(_ text: String, language: String = "ja-JP") {
        guard !text.isEmpty else { return }
        #if os(iOS)
        // Configure ambient audio session — non-fatal on failure (we just
        // play through whatever default the OS gives us). Ambient honors
        // the hardware silent switch so the speaker stays quiet when the
        // user mutes the device.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        #endif
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// True iff a `ja-JP` voice is installed on the device. Used by the
    /// view layer to disable the speaker button gracefully when the
    /// system has no Japanese TTS voice (rare but possible on stripped
    /// installs / parental-control profiles).
    static var hasJapaneseVoice: Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { v in
            v.language.lowercased().hasPrefix("ja")
        }
    }
}
