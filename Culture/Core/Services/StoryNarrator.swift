//
//  StoryNarrator.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import AVFoundation
import Observation

/// Reads a story aloud with on-device speech (`AVSpeechSynthesizer`): no
/// network, no recorded audio needed. Exposes the same shape a media player
/// would (play/pause, ±15 s, elapsed/duration) so `AudioPlayerCard` drives it.
///
/// Time is estimated from how much text has been spoken, and the pace is
/// re-measured while speaking, so the progress line and "remaining" time
/// settle on the real speed of the chosen voice within a few seconds.
///
/// TODO(audio-team): when recorded narration exists (`Story.audioDurationSeconds`),
/// add an AVPlayer-backed implementation and prefer it over speech.
@Observable
@MainActor
final class StoryNarrator: NSObject {
    private(set) var isPlaying = false
    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 1
    /// Name of the voice reading, e.g. "Daniel (Enhanced)".
    private(set) var voiceName: String?
    /// BCP-47 language of the loaded text, e.g. "en-GB" or "el-GR".
    private(set) var languageID = "en-GB"

    var progress: Double { duration > 0 ? min(elapsed / duration, 1) : 0 }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var text: NSString = ""
    @ObservationIgnored private var voice: AVSpeechSynthesisVoice?
    /// Utterance currently being spoken and the character offset it starts at.
    @ObservationIgnored private var current: (utterance: AVSpeechUtterance, offset: Int)? {
        // Keep the last one alive so its address can't be reused by the next
        // utterance while its late delegate callbacks are still queued.
        willSet { if let old = current?.utterance { retired = old } }
    }
    @ObservationIgnored private var retired: AVSpeechUtterance?
    /// Character offset in `text` of the word being (or about to be) spoken.
    @ObservationIgnored private var position = 0
    /// Characters per second; seeded with a typical English pace, then measured.
    @ObservationIgnored private var pace: Double = 14.5
    @ObservationIgnored private var paceSample: (date: Date, position: Int)?

    private static let rate = AVSpeechUtteranceDefaultSpeechRate * 0.96

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Loading

    /// What gets read for a story: title, subtitle, summary, then the body.
    static func script(for story: Story) -> String {
        "\(story.title). \(story.subtitle).\n\n\(story.summary)\n\n\(story.body)"
    }

    /// Prepares a story to be read in English.
    func load(_ story: Story) {
        load(text: Self.script(for: story))
    }

    /// Prepares `newText` to be read by the best voice for `language` (BCP-47).
    func load(text newText: String, language: String = "en-GB") {
        stop()
        text = newText as NSString
        if voice == nil || Self.base(of: voice?.language ?? "") != Self.base(of: language) {
            voice = Self.preferredVoice(for: language)
        }
        languageID = language
        voiceName = voice.map { Self.displayName(of: $0) }
        position = 0
        updateTimes()
    }

    // MARK: Transport

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard !isPlaying, text.length > 0 else { return }
        activateAudioSession()
        if position >= text.length { position = 0 }
        if synthesizer.isPaused, current != nil {
            synthesizer.continueSpeaking()
        } else {
            speak(from: position)
        }
        isPlaying = true
        paceSample = (.now, position)
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        if !synthesizer.pauseSpeaking(at: .word) { synthesizer.stopSpeaking(at: .immediate); current = nil }
        paceSample = nil
        deactivateAudioSession()
    }

    /// Stops and rewinds to the start.
    func stop() {
        isPlaying = false
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
        position = 0
        paceSample = nil
        updateTimes()
        deactivateAudioSession()
    }

    /// Jumps by roughly `seconds` of speech, landing on a word boundary.
    func skip(by seconds: Double) {
        guard text.length > 0 else { return }
        let target = position + Int(seconds * pace)
        position = Self.wordStart(near: min(max(target, 0), text.length), in: text)
        updateTimes()

        // Restart speech from the new spot; if paused, it resumes from there on play.
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
        if isPlaying {
            if position >= text.length { isPlaying = false; deactivateAudioSession(); return }
            speak(from: position)
            paceSample = (.now, position)
        }
    }

    static func format(_ seconds: Double) -> String {
        let s = max(Int(seconds.rounded(.down)), 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Speech

    private func speak(from offset: Int) {
        let remaining = text.substring(from: offset)
        let utterance = AVSpeechUtterance(string: remaining)
        utterance.voice = voice
        utterance.rate = Self.rate
        utterance.preUtteranceDelay = 0.05
        current = (utterance, offset)
        synthesizer.speak(utterance)
    }

    fileprivate func didReach(_ range: NSRange, in utterance: ObjectIdentifier) {
        guard let current, ObjectIdentifier(current.utterance) == utterance else { return }
        position = current.offset + range.location
        measurePace()
        updateTimes()
    }

    fileprivate func didFinish(_ utterance: ObjectIdentifier) {
        guard let current, ObjectIdentifier(current.utterance) == utterance else { return }
        self.current = nil
        isPlaying = false
        position = text.length
        updateTimes()
        deactivateAudioSession()
    }

    /// Blends the measured speed into `pace` once enough has been spoken.
    private func measurePace() {
        guard let sample = paceSample else { return }
        let seconds = Date.now.timeIntervalSince(sample.date)
        let chars = position - sample.position
        guard seconds > 6, chars > 40 else { return }
        let measured = Double(chars) / seconds
        if (6...30).contains(measured) { pace = pace * 0.4 + measured * 0.6 }
        paceSample = (.now, position)
    }

    private func updateTimes() {
        duration = max(Double(text.length) / pace, 1)
        elapsed = min(Double(position) / pace, duration)
    }

    // MARK: Audio session

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback so it is audible with the silent switch on; spoken-audio mode
            // lets other apps pause (podcasts) instead of mixing.
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            Log.app.error("Audio session failed: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Helpers

    /// "el-GR" → "el"
    private static func base(of language: String) -> String {
        String(language.prefix { $0 != "-" && $0 != "_" })
    }

    /// Best installed voice for `language`: premium > enhanced > default, never
    /// novelty voices. For English, prefers the user's own variant (en-GB, en-US…).
    private static func preferredVoice(for language: String = "en-GB") -> AVSpeechSynthesisVoice? {
        let base = base(of: language)
        let userLanguage = AVSpeechSynthesisVoice.currentLanguageCode()
        let preferredLanguage = base == "en" && userLanguage.hasPrefix("en") ? userLanguage : language
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            Self.base(of: $0.language) == base && !$0.voiceTraits.contains(.isNoveltyVoice)
        }
        let best = candidates.max { a, b in score(a, preferredLanguage) < score(b, preferredLanguage) }
        return best ?? AVSpeechSynthesisVoice(language: preferredLanguage)
    }

    private static func score(_ voice: AVSpeechSynthesisVoice, _ language: String) -> Int {
        voice.quality.rawValue * 10 + (voice.language == language ? 5 : 0) + (voice.language == "en-GB" ? 1 : 0)
    }

    private static func displayName(of voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "\(voice.name) (Premium)"
        case .enhanced: "\(voice.name) (Enhanced)"
        default: voice.name
        }
    }

    /// Start of the word containing `index`, so a skip never starts mid-word.
    private static func wordStart(near index: Int, in text: NSString) -> Int {
        guard index < text.length else { return text.length }
        var i = index
        while i > 0, let scalar = Unicode.Scalar(text.character(at: i - 1)),
              !CharacterSet.whitespacesAndNewlines.contains(scalar) {
            i -= 1
        }
        return i
    }
}

extension StoryNarrator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.didReach(characterRange, in: id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.didFinish(id) }
    }
}
