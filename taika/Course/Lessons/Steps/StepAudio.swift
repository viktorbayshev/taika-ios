import Foundation
import AVFoundation

/// boxed audio helper for step cards (speaker button)
/// usage: StepAudio.shared.speakThai(_:) or .speak(text:language:)
final class StepAudio: NSObject {
    static let shared = StepAudio()

    private let synth = AVSpeechSynthesizer()
    private var sessionConfigured = false
    private var sessionActive = false

    // default voice params
    private let defaultRate: Float = 0.48  // 0.0...1.0 (system maps to AVSpeechUtteranceDefaultSpeechRate scale)
    private let defaultPitch: Float = 1.05 // 0.5...2.0
    private let defaultVolume: Float = 1.0 // 0.0...1.0

    private override init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Public API

    /// speak thai phrase with th-TH voice; falls back gracefully if no thai voice
    func speakThai(_ text: String) {
        speak(text: text, language: "th-TH")
    }

    /// generic speak with BCP-47 language code (e.g., "th-TH", "ru-RU")
    func speak(text: String, language: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        prepareSessionIfNeeded()

        // if already speaking, stop and re-speak fresh
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        let utt = AVSpeechUtterance(string: text)
        utt.voice = bestVoice(for: language)
        utt.rate = mappedRate(defaultRate)
        utt.pitchMultiplier = defaultPitch
        utt.volume = defaultVolume
        synth.speak(utt)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        deactivateSessionIfNeeded()
    }
    var isSpeaking: Bool { synth.isSpeaking }

    // MARK: - Internals

    private func prepareSessionIfNeeded() {
        guard !sessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            // spokenAudio keeps system routing/ducking behavior sane for TTS
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            sessionConfigured = true
            sessionActive = true
            observeInterruptions()
        } catch {
            print("[StepAudio] session error: \(error)")
        }
    }

    private func deactivateSessionIfNeeded() {
        guard sessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            sessionActive = false
        } catch {
            print("[StepAudio] deactivate error: \(error)")
        }
    }

    private func bestVoice(for lang: String) -> AVSpeechSynthesisVoice? {
        // prefer an exact match; otherwise any voice with the same base language
        if let exact = AVSpeechSynthesisVoice(language: lang) { return exact }
        let base = lang.split(separator: "-").first.map(String.init)
        let fallback = AVSpeechSynthesisVoice.speechVoices().first { v in
            guard let base = base else { return false }
            return v.language.hasPrefix(base)
        }
        return fallback ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    private func mappedRate(_ normalized: Float) -> Float {
        // map 0...1 into iOS tts range around default
        let minR = AVSpeechUtteranceMinimumSpeechRate
        let defR = AVSpeechUtteranceDefaultSpeechRate
        let maxR = AVSpeechUtteranceMaximumSpeechRate
        // keep near default for clarity
        return defR + (maxR - defR) * (normalized - 0.5) * 0.6
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            guard let userInfo = note.userInfo,
                  let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
            switch type {
            case .began:
                self.synth.stopSpeaking(at: .immediate)
            case .ended:
                // no auto-resume for now
                self.deactivateSessionIfNeeded()
            @unknown default:
                break
            }
        }
    }
}

extension StepAudio: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // hook for UI state reset if needed
        print("[StepAudio] didFinish: \(utterance.speechString.prefix(20))...")
        deactivateSessionIfNeeded()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("[StepAudio] didCancel")
        deactivateSessionIfNeeded()
    }
}
