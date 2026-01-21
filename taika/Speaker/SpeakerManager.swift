//
//  SpeakerManager.swift
//  taika
//
//  Created by product on 26.12.2025.
//

import Foundation
import SwiftUI
import CryptoKit
import Speech
import AVFoundation

@MainActor
final class SpeakerManager: ObservableObject {

    // MARK: - phase

    enum Phase: Equatable {
        case idle
        case recording
        case analyzing
        case analyzingTranslation
        case hint
        case feedback(score: Int, hint: String)

        var isFeedback: Bool {
            if case .feedback = self { return true }
            return false
        }

        var label: String {
            switch self {
            case .idle: return "готов к записи"
            case .recording: return "запись…"
            case .analyzing: return "анализ…"
            case .analyzingTranslation: return "перевод…"
            case .hint: return "совет"
            case .feedback(let score, _): return "оценка: \(score)"
            }
        }
    }

    // MARK: - published

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var queue: [StepData.SpeakerResolved] = []

    @Published private(set) var current: StepData.SpeakerResolved?
    @Published private(set) var activeFilterId: UUID? = SpeakerMode.current.id

    @Published private(set) var lastAttempt: URL? = nil
    @Published private(set) var attemptCount: Int = 0

    enum LastPlayed: Equatable {
        case none
        case reference
        case attempt
    }

    @Published private(set) var lastPlayed: LastPlayed = .none

    // live ui while recording (mvp)
    @Published var recordingMeter: Double = 0
    @Published var recordingPartialThai: String? = nil
    @Published var recordingPartialTranslit: String? = nil

    // result fields (google-translate style)
    @Published private(set) var heardThai: String? = nil
    @Published private(set) var heardRU: String? = nil

    // taika fm bubble (can show multiple short hints)
    @Published private(set) var taikaHints: [String] = []

    @Published var heardTranslit: String? = nil
    @Published var heardConfidence: Int = 0

    // MARK: - stable ids (for ui carousel selection)

    // must be stable and depend only on ids + canonical index (no face text)
    func resolveId(_ r: StepData.SpeakerResolved) -> UUID {
        // stable across renders and independent of localized text (avoid id drift)
        // key = courseId + lessonId + canonical step order/index
        let key = [
            r.courseId,
            r.lessonId,
            String(r.index)
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(key.utf8))
        var uuidBytes: [UInt8] = Array(digest.prefix(16))

        // UUID v4 + RFC4122 variant
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        return uuidFromBytes(uuidBytes)
    }

    var selectedId: UUID? {
        guard let cur = current else { return nil }
        return resolveId(cur)
    }

    /// small window for the top carousel (current + a few neighbors)
    var carouselItems: [StepData.SpeakerResolved] {
        guard !queue.isEmpty else { return [] }
        guard let cur = current, let i = queue.firstIndex(of: cur) else {
            return Array(queue.prefix(5))
        }

        // centered window: [prev2, prev1, cur, next1, next2]
        let n = queue.count
        if n <= 5 { return queue }

        let i0 = (i - 2 + n) % n
        let i1 = (i - 1 + n) % n
        let i2 = i
        let i3 = (i + 1) % n
        let i4 = (i + 2) % n

        return [queue[i0], queue[i1], queue[i2], queue[i3], queue[i4]]
    }

    func selectCard(by id: UUID) {
        guard !queue.isEmpty else { return }
        if let match = queue.first(where: { resolveId($0) == id }) {
            current = match
            // A1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: match.courseId, lessonId: match.lessonId, stepIndex: match.index)
            
            // B3: restore persisted attempt result for this card
            restoreAttemptResult(for: match)
        }
    }
    
    // B3: restore persisted attempt result for a card
    private func restoreAttemptResult(for resolved: StepData.SpeakerResolved) {
        let key = SpeakerAttemptsStore.key(
            courseId: resolved.courseId,
            lessonId: resolved.lessonId,
            stepIndex: resolved.index
        )
        
        if let stored = SpeakerAttemptsStore.load(forKey: key) {
            heardThai = stored.heardThai
            heardTranslit = stored.heardTranslit
            heardConfidence = stored.heardConfidence
            attemptCount = stored.attemptCount
            
            // restore audio URL if file still exists
            if let path = stored.lastAttemptURL,
               let url = URL(string: path),
               FileManager.default.fileExists(atPath: url.path) {
                lastAttemptURL = url
                lastAttempt = url
            } else {
                lastAttemptURL = nil
                lastAttempt = nil
            }
            
            // restore phase based on stored result
            if stored.heardConfidence > 0 {
                // B3: maintain consistency with initial feedback display - clear heardRU to prevent fake RU recognition
                heardRU = nil
                let hint = feedbackHint(for: stored.heardConfidence)
                phase = .feedback(score: stored.heardConfidence, hint: hint)
                taikaHints = [
                    resolved.face.titleRU.isEmpty ? "оценка: \(stored.heardConfidence)" : "фраза: \(resolved.face.titleRU)",
                    "оценка: \(stored.heardConfidence)",
                    hint
                ]
            } else {
                // B3: clear heardRU when score is 0 to prevent stale value from previous card
                heardRU = nil
                phase = .idle
                taikaHints = []
            }
        } else {
            // no stored result - reset to clean state
            heardThai = nil
            heardRU = nil
            heardTranslit = nil
            heardConfidence = 0
            taikaHints = []
            phase = .idle
            lastAttemptURL = nil
            lastAttempt = nil
            attemptCount = 0
        }
        
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil
    }
    
    // B3: helper to generate feedback hint from score
    private func feedbackHint(for score: Int) -> String {
        switch score {
        case 92...100: return "очень похоже. попробуй быстрее и слитно"
        case 78...91: return "норм. добей окончания и тон"
        case 60...77: return "слышно похоже, но есть ошибки. сравни по слогам"
        default: return "пока мимо. включи эталон и повторяй по 1–2 слога"
        }
    }

    // MARK: - deps

    private let session: UserSession
    private let stepData: StepData

    private let recorder: any SpeakerRecording

    // MARK: - state

    private var didLoad: Bool = false
    private var lastAttemptURL: URL?
    private var attemptPlayer: AVAudioPlayer?
    private var meterTimer: Timer?
    private var baseQueue: [StepData.SpeakerResolved] = []

    init(session: UserSession = .shared, stepData: StepData = .shared, recorder: (any SpeakerRecording)? = nil) {
        self.session = session
        self.stepData = stepData
        self.recorder = recorder ?? SpeakerRecorder.shared
    }

    // MARK: - lifecycle

    func loadIfNeeded(force: Bool = false) {
        if didLoad && !force { return }
        didLoad = true
        rebuildQueue()
        pickFirst()
        activeFilterId = SpeakerMode.current.id
    }

    func rebuildQueue() {
        let snap = session.snapshot

        #if DEBUG
        let learnedKeysCount = snap.learnedSteps.keys.count
        let learnedTotal = snap.learnedSteps.values.reduce(0) { $0 + $1.count }
        let startedCoursesCount = snap.startedCourses.count
        let startedLessonsCount = snap.startedLessons.values.reduce(0) { $0 + $1.count }

        let lc = snap.lastCourseId ?? ""
        let ll = (lc.isEmpty ? "" : (snap.lastLessonByCourse[lc] ?? ""))
        let lk = (lc.isEmpty || ll.isEmpty) ? "" : "\(lc)|\(ll)"
        let lstep = lk.isEmpty ? nil : snap.lastStepByLesson[lk]

        print("[speaker] snapshot: learnedKeys=\(learnedKeysCount) learnedTotal=\(learnedTotal) startedCourses=\(startedCoursesCount) startedLessons=\(startedLessonsCount) lastCourse=\(lc) lastLesson=\(ll) lastStep=\(String(describing: lstep))")
        #endif

        var resolved: [StepData.SpeakerResolved] = []
        resolved.reserveCapacity(64)

        // 1) learned steps
        var learned = snap.learnedSteps
        if learned.isEmpty {
            learned = collectLearnedStepsFallback(from: snap)
        }
        for (key, set) in learned {
            guard let ids = StepData.splitLearnedKey(key) else { continue }
            for idx in set.sorted() {
                if let r = stepData.speakerResolved(courseId: ids.courseId, lessonId: ids.lessonId, index: idx) {
                    resolved.append(r)
                }
            }
        }

        // 2) fallback if empty (starter pack / daily picks)
        if resolved.isEmpty {
            let picks = stepData.dailyPicksKeys(count: 18)
            for p in picks {
                if let r = stepData.speakerResolved(courseId: p.courseId, lessonId: p.lessonId, index: p.index) {
                    resolved.append(r)
                }
            }
        }

        // avoid duplicate items → duplicate UUIDs in SwiftUI ForEach
        resolved = dedupResolved(resolved)

        // stable order (course+lesson+index)
        resolved.sort { a, b in
            if a.courseId != b.courseId { return a.courseId < b.courseId }
            if a.lessonId != b.lessonId { return a.lessonId < b.lessonId }
            return a.index < b.index
        }

        #if DEBUG
        print("[speaker] rebuildQueue: resolved=\(resolved.count) (baseQueue) fallbackUsed=\(resolved.isEmpty)")
        #endif
        queue = resolved
        baseQueue = resolved
    }

    private func collectLearnedStepsFallback(from snap: Any) -> [String: Set<Int>] {
        // defensive fallback: if the canonical `learnedSteps` is empty due to migration/renaming,
        // scan snapshot for any properties shaped like [String: Set<Int>].
        var out: [String: Set<Int>] = [:]

        func merge(_ dict: [String: Set<Int>]) {
            for (k, v) in dict {
                if var cur = out[k] {
                    cur.formUnion(v)
                    out[k] = cur
                } else {
                    out[k] = v
                }
            }
        }

        func walk(_ value: Any) {
            let m = Mirror(reflecting: value)
            for child in m.children {
                if let d = child.value as? [String: Set<Int>] {
                    merge(d)
                }
            }
            if let sup = m.superclassMirror {
                for child in sup.children {
                    if let d = child.value as? [String: Set<Int>] {
                        merge(d)
                    }
                }
            }
        }

        walk(snap)
        return out
    }

    private func pickFirst() {
        current = queue.first
        // A1: keep "current lesson" source-of-truth in sync when picking first card
        if let cur = current {
            session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
        }
    }

    // MARK: - navigation

    func next() {
        guard !queue.isEmpty else {
            current = nil
            return
        }
        guard let cur = current, let i = queue.firstIndex(of: cur) else {
            current = queue.first
            return
        }
        let nextIndex = (i + 1) % queue.count
        current = queue[nextIndex]
        if let cur = current {
            // A1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
            // B3: restore persisted attempt result
            restoreAttemptResult(for: cur)
        }
    }
    
    // C1: prev navigation for player panel
    func prev() {
        guard !queue.isEmpty else {
            current = nil
            return
        }
        guard let cur = current, let i = queue.firstIndex(of: cur) else {
            current = queue.first
            return
        }
        let prevIndex = (i - 1 + queue.count) % queue.count
        current = queue[prevIndex]
        if let cur = current {
            // A1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
            // B3: restore persisted attempt result
            restoreAttemptResult(for: cur)
        }
    }

    func repeatCurrent() {
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = []
        phase = .idle
        lastAttemptURL = nil
        lastAttempt = nil
        attemptCount = 0
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil
    }

    func applyFilter(_ id: UUID) {
        guard let mode = SpeakerMode(id: id) else { return }
        activeFilterId = mode.id

        if baseQueue.isEmpty {
            loadIfNeeded(force: true)
        }

        switch mode {
        case .current:
            let cur = buildCurrentLessonQueue()
            if cur.isEmpty {
                // no context → fall back to base (learned/daily picks)
                queue = baseQueue
                current = queue.first
                heardThai = nil
                heardRU = nil
                taikaHints = ["нет активного урока. открой урок и вернись в практику"]
                phase = .hint
                lastAttemptURL = nil
                lastAttempt = nil
                attemptCount = 0
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
            } else {
                queue = cur
                current = queue.first
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = []
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil
                lastAttempt = nil
                attemptCount = 0
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
                phase = .idle
            }

        case .random:
            queue = baseQueue.shuffled()
            current = queue.first
            heardThai = nil
            heardRU = nil
            heardTranslit = nil
            heardConfidence = 0
            taikaHints = []
            recordingPartialThai = nil
            recordingMeter = 0
            lastAttemptURL = nil
            lastAttempt = nil
            attemptCount = 0
            lastPlayed = .none
            attemptPlayer?.stop()
            attemptPlayer = nil
            phase = .idle

        case .favorites:
            let fav = buildFavoritesQueue()
            if fav.isEmpty {
                // clear any previous state so UI doesn't show stale cards
                stopMeter()
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil

                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = ["в избранном пусто"]

                queue = []
                current = nil
                phase = .hint
                lastAttempt = nil
                attemptCount = 0
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
            } else {
                queue = fav
                current = queue.first
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = []
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil
                lastAttempt = nil
                attemptCount = 0
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
                phase = .idle
            }

        default:
            queue = baseQueue
            current = queue.first
            heardThai = nil
            heardRU = nil
            heardTranslit = nil
            heardConfidence = 0
            taikaHints = []
            recordingPartialThai = nil
            recordingMeter = 0
            lastAttemptURL = nil
            lastAttempt = nil
            attemptCount = 0
            lastPlayed = .none
            attemptPlayer?.stop()
            attemptPlayer = nil
            phase = .idle
        }
    }


    // MARK: - reference audio (mvp: tts)

    func playReference() {
        guard let cur = current else { return }
        playReference(resolved: cur)
    }

    func playReference(for id: UUID) {
        guard !queue.isEmpty else { return }
        if let match = queue.first(where: { resolveId($0) == id }) {
            // keep UI context in sync with what is being played
            current = match
            // t1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: match.courseId, lessonId: match.lessonId, stepIndex: match.index)
            playReference(resolved: match)
        } else {
            return
        }
    }

    private func playReference(resolved r: StepData.SpeakerResolved) {
        let thai = r.face.subtitleTH
        if !thai.isEmpty {
            StepAudio.shared.speakThai(thai)
            lastPlayed = .reference
        }
    }

    func playAttempt() {
        guard let url = lastAttempt else { return }
        do {
            attemptPlayer?.stop()
            attemptPlayer = try AVAudioPlayer(contentsOf: url)
            attemptPlayer?.prepareToPlay()
            attemptPlayer?.play()
            lastPlayed = .attempt
        } catch {
            taikaHints = ["не получилось воспроизвести запись"]
            phase = .hint
        }
    }
    
    // MARK: - text input (mvp)

    func submitText(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        // reset any recording ui
        stopMeter()
        recordingPartialThai = nil
        recordingMeter = 0
        lastAttemptURL = nil
        lastAttempt = nil
        lastPlayed = .none

        heardThai = t
        heardTranslit = t
        heardRU = nil
        heardConfidence = 0

        phase = .hint

        if let cur = current {
            heardRU = cur.face.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
            taikaHints = [
                "сравни себя с эталоном",
                "для free: эталон → ты → повтор"
            ]

            session.logActivity(
                .speakerAttemptCompleted,
                courseId: cur.courseId,
                lessonId: cur.lessonId,
                stepIndex: cur.index,
                refId: "free_text:\(cur.courseId):\(cur.lessonId):idx\(cur.index):len\(t.count)"
            )
        } else {
            heardRU = ""
            taikaHints = ["выбери фразу сверху или включи random"]
        }
    }
    // MARK: - attempt (mvp: mock)

    func startAttempt() {
        guard current != nil else { return }
        attemptPlayer?.stop()
        attemptPlayer = nil
        lastPlayed = .none
        lastAttemptURL = nil
        lastAttempt = nil
        phase = .recording
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        heardThai = nil
        heardRU = nil
        startMeter()
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = []
        recorder.start { [weak self] (url: URL?) in
            guard let self = self else { return }

            // If recorder couldn't start (permission denied / init failure), rollback UI state.
            guard let url else {
                self.stopMeter()
                self.recordingPartialThai = nil
                self.recordingPartialTranslit = nil
                self.recordingMeter = 0

                self.lastAttemptURL = nil
                self.lastAttempt = nil
                self.lastPlayed = .none

                self.taikaHints = ["не получилось начать запись. проверь доступ к микрофону"]
                self.phase = .hint
                return
            }

            self.lastAttemptURL = url
            self.lastAttempt = url
        }
    }

    func stopAttemptAndAnalyze() {
        guard let cur = current else { return }
        // t1: keep "current lesson" source-of-truth in sync
        session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
        guard phase == .recording else { return }

        let url = recorder.stop()
        stopMeter()
        recordingPartialThai = nil
        recordingMeter = 0

        lastAttemptURL = url
        lastAttempt = url

        // if we failed to create audio, clear attempt state and show explicit error
        guard url != nil else {
            lastAttemptURL = nil
            lastAttempt = nil
            lastPlayed = .none
            attemptPlayer?.stop()
            attemptPlayer = nil

            taikaHints = ["не получилось записать. проверь доступ к микрофону"]
            phase = .hint
            return
        }

        attemptCount += 1
        lastPlayed = .none

        // run lightweight ASR scoring (free v0)
        phase = .analyzing
        taikaHints = ["слушаю…"]

        let refThai = cur.face.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            guard let self else { return }

            do {
                let heard = try await self.recognizeThai(url: url)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // store fields for UI
                self.heardThai = heard.isEmpty ? nil : heard
                self.heardTranslit = nil
                // v0: don't fake RU recognition; DS must not infer match from RU string
                self.heardRU = nil

                if heard.isEmpty || refThai.isEmpty {
                    let ru = cur.face.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.taikaHints = [
                        ru.isEmpty ? "не получилось распознать речь" : "фраза: \(ru)",
                        "не получилось распознать речь",
                        "free: эталон → ты → повтор"
                    ]
                    self.phase = .hint
                } else {
                    // B2: calculate similarity and score (0-100)
                    let sim = self.similarity(a: heard, b: refThai)
                    let score = Int((sim * 100.0).rounded())
                    self.heardConfidence = score

                    // B2: match threshold (70) - only scores >= 70 are considered matches
                    let matchThreshold = 70
                    let isMatch = score >= matchThreshold

                    let hint: String
                    switch score {
                    case 92...100:
                        hint = "очень похоже. попробуй быстрее и слитно"
                    case 78...91:
                        hint = "норм. добей окончания и тон"
                    case 60...77:
                        hint = "слышно похоже, но есть ошибки. сравни по слогам"
                    default:
                        hint = "пока мимо. включи эталон и повторяй по 1–2 слога"
                    }

                    let ru = cur.face.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.taikaHints = [
                        ru.isEmpty ? "оценка: \(score)" : "фраза: \(ru)",
                        "оценка: \(score)",
                        hint
                    ]
                    // B2: feedback phase includes score; DS will check threshold for match verdict
                    self.phase = .feedback(score: score, hint: hint)
                    
                    // B3: persist attempt result
                    self.saveAttemptResult(
                        courseId: cur.courseId,
                        lessonId: cur.lessonId,
                        stepIndex: cur.index,
                        heardThai: heard,
                        heardTranslit: nil,
                        heardConfidence: score,
                        attemptCount: self.attemptCount,
                        lastAttemptURL: url
                    )
                }

                // analytics
                let attemptId = url?.lastPathComponent ?? "no-audio"
                self.session.logActivity(
                    .speakerAttemptCompleted,
                    courseId: cur.courseId,
                    lessonId: cur.lessonId,
                    stepIndex: cur.index,
                    refId: "free_asr:\(cur.courseId):\(cur.lessonId):idx\(cur.index):\(attemptId):try\(self.attemptCount):score\(self.heardConfidence)"
                )

            } catch {
                // graceful fallback: keep AB training, explain why score is unavailable
                self.heardThai = nil
                self.heardTranslit = nil
                // v0: no RU recognition in free mode fallback
                self.heardRU = nil
                self.heardConfidence = 0

                let ru = cur.face.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
                self.taikaHints = [
                    ru.isEmpty ? "оценка недоступна" : "фраза: \(ru)",
                    "оценка недоступна (нет доступа к распознаванию)",
                    "free: эталон → ты → повтор"
                ]
                self.phase = .hint

                let attemptId = url?.lastPathComponent ?? "no-audio"
                self.session.logActivity(
                    .speakerAttemptCompleted,
                    courseId: cur.courseId,
                    lessonId: cur.lessonId,
                    stepIndex: cur.index,
                    refId: "free_ab_noasr:\(cur.courseId):\(cur.lessonId):idx\(cur.index):\(attemptId):try\(self.attemptCount)"
                )
            }
        }
    }

    // MARK: - asr (v0)

    private func recognizeThai(url: URL?) async throws -> String {
        guard let url else { return "" }

        // speech permission
        let auth = SFSpeechRecognizer.authorizationStatus()
        if auth == .notDetermined {
            let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    c.resume(returning: status == .authorized)
                }
            }
            if !granted { throw NSError(domain: "speaker.asr", code: 1) }
        } else if auth != .authorized {
            throw NSError(domain: "speaker.asr", code: 2)
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")) else {
            throw NSError(domain: "speaker.asr", code: 3)
        }
        if !recognizer.isAvailable {
            throw NSError(domain: "speaker.asr", code: 4)
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false

        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    c.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    c.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func normalizeThai(_ s: String) -> String {
        // keep thai letters + digits; drop spaces/punct
        let scalars = s.unicodeScalars.filter { sc in
            if CharacterSet.whitespacesAndNewlines.contains(sc) { return false }
            if CharacterSet.punctuationCharacters.contains(sc) { return false }
            if CharacterSet.symbols.contains(sc) { return false }
            return true
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    private func similarity(a: String, b: String) -> Double {
        let x = normalizeThai(a)
        let y = normalizeThai(b)
        if x.isEmpty && y.isEmpty { return 1.0 }
        if x.isEmpty || y.isEmpty { return 0.0 }
        let d = levenshtein(x, y)
        let m = max(x.count, y.count)
        if m == 0 { return 1.0 }
        return max(0.0, 1.0 - (Double(d) / Double(m)))
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var prev = Array(0...b.count)
        var cur = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                let cost = (a[i - 1] == b[j - 1]) ? 0 : 1
                cur[j] = min(
                    prev[j] + 1,        // delete
                    cur[j - 1] + 1,     // insert
                    prev[j - 1] + cost  // substitute
                )
            }
            prev = cur
        }
        return prev[b.count]
    }

    func resetToIdle() {
        phase = .idle
        taikaHints = []
    }


    // MARK: - live meter (mvp)

    private func startMeter() {
        stopMeter()
        recordingMeter = 0
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            // unified metering via protocol
            self.recordingMeter = max(0, min(1, self.recorder.recordingMeter))
            if self.phase == .recording {
                let raw = self.recorder.partialText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.recordingPartialThai = raw.isEmpty ? nil : raw
                // translit will be added later; keep it nil for now
                self.recordingPartialTranslit = nil
            }
        }
    }

    private func stopMeter() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    // MARK: - current lesson filter

    private func buildCurrentLessonQueue() -> [StepData.SpeakerResolved] {
        guard let ids = resolveCurrentLessonIds() else { return [] }

        // A2: Resolve steps of the lesson by probing indices until we stop finding items.
        // No hardcoded 0..<200: we derive a reasonable bound from session state.
        var out: [StepData.SpeakerResolved] = []
        out.reserveCapacity(64)

        // bound hint from snapshot (last known step index for this lesson)
        let lessonKey = "\(ids.courseId)|\(ids.lessonId)"
        let lastIdx = session.snapshot.lastStepByLesson[lessonKey] ?? 0

        // A2: Start from 0-based index, scan until we hit a streak of misses.
        // Use lastIdx as a hint, but continue scanning beyond it if we find content.
        // Maximum reasonable bound: 200 steps per lesson (safety limit).
        let maxBound = 200
        let initialUpperBound = min(maxBound, max(32, lastIdx + 32)) // at least 32, or lastIdx+32

        var missStreak = 0
        // A2: Always start from 0 to ensure we don't miss steps at the beginning of the lesson
        // The lastIdx hint is used for initialUpperBound calculation, not for starting position
        var idx = 0
        var foundAny = false
        
        // Scan from 0 to maxBound, or until we hit a streak of misses after finding content
        while idx < maxBound {
            if let r = stepData.speakerResolved(courseId: ids.courseId, lessonId: ids.lessonId, index: idx) {
                out.append(r)
                missStreak = 0
                foundAny = true
            } else {
                missStreak += 1
                // A2: If we found content and then hit a streak of 8 misses, stop (tolerate small holes)
                if foundAny && missStreak >= 8 {
                    break
                }
                // A2: If we haven't found anything yet and we're past initialUpperBound, stop
                if !foundAny && idx >= initialUpperBound {
                    break
                }
            }
            idx += 1
        }

        out = dedupResolved(out)
        // A2: stable order by canonical index (0-based)
        out.sort { $0.index < $1.index }
        return out
    }

    private func resolveCurrentLessonIds() -> (courseId: String, lessonId: String)? {
        let snap = session.snapshot

        // source of truth: UserSession snapshot
        if let courseId = snap.lastCourseId, !courseId.isEmpty {
            if let lessonId = snap.lastLessonByCourse[courseId], !lessonId.isEmpty {
                return (courseId, lessonId)
            }
            // if we have a last course but no last lesson mapped yet, fall back to any started lesson
            if let lessons = snap.startedLessons[courseId], let lessonId = lessons.sorted().first {
                return (courseId, lessonId)
            }
        }

        // fallback: any started lesson (deterministic)
        if let courseId = snap.startedLessons.keys.sorted().first,
           let lessons = snap.startedLessons[courseId],
           let lessonId = lessons.sorted().first {
            return (courseId, lessonId)
        }

        // final fallback: any lastLessonByCourse entry (deterministic)
        if let courseId = snap.lastLessonByCourse.keys.sorted().first {
            let lessonId = snap.lastLessonByCourse[courseId] ?? ""
            if !lessonId.isEmpty {
                return (courseId, lessonId)
            }
        }

        return nil
    }

    private func buildFavoritesQueue() -> [StepData.SpeakerResolved] {
        let refIds = FavoriteManager.shared.speakerStepIds()
        guard !refIds.isEmpty else { return [] }

        var resolved: [StepData.SpeakerResolved] = []
        resolved.reserveCapacity(min(refIds.count, 64))

        for ref in refIds {
            guard let key = parseStepRefId(ref) else { continue }
            if let r = stepData.speakerResolved(courseId: key.courseId, lessonId: key.lessonId, index: key.index) {
                resolved.append(r)
            }
        }

        resolved = dedupResolved(resolved)
        // stable order
        resolved.sort { a, b in
            if a.courseId != b.courseId { return a.courseId < b.courseId }
            if a.lessonId != b.lessonId { return a.lessonId < b.lessonId }
            return a.index < b.index
        }

        return resolved
    }


    private func parseStepRefId(_ ref: String) -> (courseId: String, lessonId: String, index: Int)? {
        // expected: step:<courseId>:<lessonId>:idx<index>[:...]
        let parts = ref.split(separator: ":").map(String.init)
        guard parts.count >= 4 else { return nil }
        guard parts[0] == "step" else { return nil }

        let courseId = parts[1]
        let lessonId = parts[2]

        let idxPart = parts[3]
        // idx12 or 12
        let digits = idxPart.filter { $0.isNumber }
        guard let index = Int(digits) else { return nil }

        return (courseId, lessonId, index)
    }

    private func uuidFromBytes(_ bytes: [UInt8]) -> UUID {
        let b = bytes + Array(repeating: 0, count: max(0, 16 - bytes.count))
        return UUID(uuid: (
            b[0], b[1], b[2], b[3],
            b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11],
            b[12], b[13], b[14], b[15]
        ))
    }

    // B3: save attempt result to persistence
    private func saveAttemptResult(
        courseId: String,
        lessonId: String,
        stepIndex: Int,
        heardThai: String?,
        heardTranslit: String?,
        heardConfidence: Int,
        attemptCount: Int,
        lastAttemptURL: URL?
    ) {
        let key = SpeakerAttemptsStore.key(
            courseId: courseId,
            lessonId: lessonId,
            stepIndex: stepIndex
        )
        
        let result = SpeakerAttemptResult(
            courseId: courseId,
            lessonId: lessonId,
            stepIndex: stepIndex,
            heardThai: heardThai,
            heardTranslit: heardTranslit,
            heardConfidence: heardConfidence,
            attemptCount: attemptCount,
            lastAttemptURL: lastAttemptURL?.absoluteString,
            timestamp: Date()
        )
        
        SpeakerAttemptsStore.save(attempt: result, forKey: key)
    }

    // MARK: - dedup

    private func dedupResolved(_ items: [StepData.SpeakerResolved]) -> [StepData.SpeakerResolved] {
        var seen = Set<String>()
        var out: [StepData.SpeakerResolved] = []
        out.reserveCapacity(items.count)

        for r in items {
            let k = "\(r.courseId)|\(r.lessonId)|\(r.index)"
            if seen.insert(k).inserted {
                out.append(r)
            }
        }
        return out
    }
}
