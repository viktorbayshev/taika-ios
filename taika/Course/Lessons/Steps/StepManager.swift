import SwiftUI
import Combine

// Minimal app-layer models used by StepManager
enum StepKind { case word, phrase, lifehack }

struct StepModel: Identifiable {
    let id: UUID
    var kind: StepKind
    var title: String
    var thai: String?
    var transcriptionRu: String?

    init(id: UUID = UUID(), kind: StepKind, title: String, thai: String? = nil, transcriptionRu: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.thai = thai
        self.transcriptionRu = transcriptionRu
    }
}

/// Orchestrates state for Steps screen (data + actions). No UI here.
@MainActor
final class StepManager: ObservableObject {
    static let shared = StepManager()
    // Flag to indicate if activeIndex was set externally (e.g., from Favorites)
    private var didSetFromExternal = false
    // Hold notification tokens for cleanup
    private var notifTokens: [Any] = []
    private var cancellables: Set<AnyCancellable> = []
    private var isResetting = false

    // Debounced emitter: coalesce UI updates and progress notifications
    private var emitWorkItem: DispatchWorkItem?
    private func scheduleEmitProgress(delay: TimeInterval = 0.12) {
        emitWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.objectWillChange.send()
            self.notifyProgress()
        }
        emitWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // Cache DS items per lesson to avoid recomputing and console spam
    private var dsCache: [String: [SDStepItem]] = [:]
    // Recently printed resolve keys (to throttle duplicate debug logs)
    private var lastResolveKey: String? = nil

    init() {
        let center = NotificationCenter.default
        // Unified reset notification from LessonsManager: .stepStateShouldReset
        // userInfo["courseId"] can be a specific id or "__all__"
        let tReset = center.addObserver(forName: Notification.Name("stepStateShouldReset"), object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self = self else { return }
                let cid = note.userInfo?["courseId"] as? String
                if let cid, cid != "__all__", cid != self.courseId { return }
                self.isResetting = true
                self.learned.removeAll()
                self.favorites.removeAll()
                self.purgeProgressStoreForCurrentLesson()
                self.scheduleEmitProgress()
                self.isResetting = false
            }
        }
        notifTokens.append(tReset)
        
        // Listen for progress changes via NotificationCenter
        let tProgress = center.addObserver(forName: .progressDidChange, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self = self else { return }
                guard !self.isResetting, !self.courseId.isEmpty, !self.lessonId.isEmpty else { return }
                if let cid = note.userInfo?["courseId"] as? String,
                   let lid = note.userInfo?["lessonId"] as? String,
                   cid == self.courseId, lid == self.lessonId {
                    let new = Set(note.userInfo?["learned"] as? [Int] ?? [])
                    if new != self.learned {
                        self.learned = new
                        self.scheduleEmitProgress()
                    }
                }
            }
        }
        notifTokens.append(tProgress)

        // Listen for favorites changes via NotificationCenter
        let tFav = center.addObserver(forName: .favoritesDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                guard !self.courseId.isEmpty, !self.lessonId.isEmpty else { return }
                self.syncFavoritesFromStore()
                self.scheduleEmitProgress()
            }
        }
        notifTokens.append(tFav)
    }

    deinit {
        notifTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notifTokens.removeAll()
    }
    // Context to build stable favorite IDs
    var courseId: String = "" { didSet { dsCache.removeAll(); reloadFromProgressStore(); syncFavoritesFromStore(); scheduleEmitProgress(); } }
    var lessonId: String = "" { didSet { dsCache.removeAll(); reloadFromProgressStore(); syncFavoritesFromStore(); scheduleEmitProgress(); } }

    // MARK: - Published state
    @Published var hints: [String] = [
        "Фраза благодарности уместна в конце разговора.",
        "Повторяй вслух — так лучше запоминается.",
        "Смотри на ударение в русской транскрипции."
    ]

    /// Source items for the lesson (provided by higher layer in real app)
    @Published var steps: [StepModel] = [] {
        didSet {
            ensureLearnedWithinBounds()
            syncFavoritesFromStore()
            // Clamp active after new steps arrive, then restore saved index if any
            activeIndex = max(0, min(activeIndex, max(0, steps.count - 1)))
            restoreLastActiveIndex()
            // Push initial snapshot so upper layers (LessonsManager/LessonsView) can render header/CTA immediately
            scheduleEmitProgress()
        }
    }

    @Published var activeIndex: Int = 0
    @Published var learned: Set<Int> = []

    // MARK: - Last active index persistence (single source of truth for "Продолжить")
    private func restoreLastActiveIndex() {
        guard !courseId.isEmpty, !lessonId.isEmpty else { return }
        // If activeIndex was set externally (e.g., by configureForFavorites), do not override it
        if didSetFromExternal {
            // Reset the flag after respecting the external set
            didSetFromExternal = false
            return
        }
        if let saved = UserSession.shared.lastStepIndex(courseId: courseId, lessonId: lessonId) {
            // Only set if activeIndex is at default (0)
            if activeIndex == 0 {
                activeIndex = max(0, min(saved, max(0, steps.count - 1)))
            }
        } else {
            // Only set if activeIndex is at default (0)
            if activeIndex == 0 {
                activeIndex = 0
            }
        }
    }

    private func persistLastActiveIndex() {
        guard !courseId.isEmpty, !lessonId.isEmpty else { return }
        let clamped = max(0, min(activeIndex, max(0, steps.count - 1)))
        UserSession.shared.markActive(courseId: courseId, lessonId: lessonId, stepIndex: clamped)
    }

    // MARK: - Context/Steps setters (atomic)
    /// Set course/lesson context; will reload persisted state and resync favorites
    public func setContext(courseId: String, lessonId: String) {
        self.courseId = courseId
        self.lessonId = lessonId
    }

    /// Apply lesson steps in one shot; will clip learned indices and resync favorites
    public func applySteps(_ steps: [StepModel]) {
        self.steps = steps
        restoreLastActiveIndex()
        scheduleEmitProgress()
    }

    /// Atomic configure: set context + steps and push initial snapshot upstream
    public func configure(courseId: String, lessonId: String, steps: [StepModel]) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.steps = steps
        restoreLastActiveIndex()
        // ensure an immediate sync to LessonsManager
        scheduleEmitProgress()
    }

    /// Configure from persistent StepData specifically for Favorites/Mini overlay
    public func configureForFavorites(courseId: String, lessonId: String, startIndex: Int) {
        self.courseId = courseId
        self.lessonId = lessonId
        // Ensure overlay uses fresh DS, not a stale cache (affects both cards and hacks)
        dsCache.removeAll()
        // Map StepData → StepModel using cached DS items for stability
        let dsItems = dsStepsCached(courseId: courseId, lessonId: lessonId)
        let models: [StepModel] = dsItems.map { it in
            let kind: StepKind
            switch it.kind {
            case .word:   kind = .word
            case .phrase: kind = .phrase
            case .tip:    kind = .lifehack
            default:      kind = .word
            }
            return StepModel(kind: kind, title: it.titleRU, thai: it.subtitleTH, transcriptionRu: it.phonetic)
        }
        self.steps = models
        // Respect external desired index; don’t let restoreLastActiveIndex() override it
        self.didSetFromExternal = true
        self.setActive(index: startIndex)
        #if DEBUG
        print("[StepManager] configureForFavorites course=\(courseId) lesson=\(lessonId) start=\(startIndex) steps=\(models.count)")
        #endif
    }

    // MARK: - Progress domain (exclude non-learning items from totals)
    private var progressEligibleIndices: Set<Int> {
        Set(steps.enumerated().compactMap { (i, s) in
            switch s.kind { case .word, .phrase: return i; case .lifehack: return nil }
        })
    }
    /// Indices to exclude from completion/percent logic (e.g. lifehacks)
    private var excludedProgressIndexes: Set<Int> {
        Set(steps.enumerated().compactMap { (i, s) in s.kind == .lifehack ? i : nil })
    }
    private var progressTotal: Int { progressEligibleIndices.count }
    private var learnedProgressCount: Int { learned.intersection(progressEligibleIndices).count }

    /// Notify ProgressManager about a concrete step toggle (analytics/persistence)
    private func notifyProgressStoreStep(index: Int, isLearned: Bool) {
        // Persist single-step change, while telling store which indexes are excluded from completion logic
        ProgressManager.shared.setStepLearned(
            courseId: courseId,
            lessonId: lessonId,
            index: index,
            isLearned: isLearned,
            excludedIndexes: excludedProgressIndexes
        )
        if isLearned {
            ProgressManager.shared.markStarted(courseId: courseId, lessonId: lessonId)
        }
        // After each toggle, re-evaluate lesson completion against current learned set
        ProgressManager.shared.markCompletedIfNeeded(
            courseId: courseId,
            lessonId: lessonId,
            totalSteps: progressTotal,
            excludedIndexes: excludedProgressIndexes
        )
    }

    /// Current lesson progress snapshot
    private var totalSteps: Int { steps.count }

    /// Notify upper layer (LessonsManager) about progress changes
    private func notifyProgress() {
        guard !courseId.isEmpty, !lessonId.isEmpty else {
            #if DEBUG
            print("[StepManager] skip notify — missing context courseId='\(courseId)' lessonId='\(lessonId)'")
            #endif
            return
        }
        // Skip notifying until steps are loaded to avoid progressTotal = 0 snapshots
        guard !steps.isEmpty else { return }
        // Use excludedProgressIndexes to stay consistent with eligibility logic
        let lifehackCount = excludedProgressIndexes.count
        #if DEBUG
        print("[StepManager] progress course=\(courseId) lesson=\(lessonId) learned=\(learnedProgressCount)/\(progressTotal) totalAll=\(totalSteps) lifehacks=\(lifehackCount)")
        if progressTotal == 0 {
            print("[StepManager] warning: progressTotal is 0 (no learnable cards) — header won’t advance")
        }
        #endif
        // Also broadcast a high-level notification so LessonsManager/Views can react
        let learnedIdx = Array(learned.intersection(progressEligibleIndices)).sorted()
        let allIdx = Array(progressEligibleIndices).sorted()
        let hacksIdx = Array(excludedProgressIndexes).sorted()
        NotificationCenter.default.post(
            name: .stepProgressDidChange,
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId,
                // Preferred rich payload with raw indices
                "learnedContent": learnedIdx,
                "allCards": allIdx,
                "lifehacks": hacksIdx,
                // And counts for consumers that only need aggregates
                "learnedCount": learnedProgressCount,
                "totalCount": progressTotal,
                "lifehackCount": hacksIdx.count
            ]
        )
        // Pass full total (including lifehacks) + lifehackCount so LessonsManager can compute effective totals
        LessonsManager.shared.updateLessonProgress(
            courseId: courseId,
            lessonId: lessonId,
            learnedCount: learnedProgressCount,
            total: progressTotal,
            lifehackCount: lifehackCount
        )
        // Also keep completion flag in sync when counts change not from a direct toggle
        ProgressManager.shared.markCompletedIfNeeded(
            courseId: courseId,
            lessonId: lessonId,
            totalSteps: progressTotal,
            excludedIndexes: excludedProgressIndexes
        )
    }
    /// Preview-only mirror; source of truth lives in FavoriteManager
    @Published var favorites: Set<Int> = []

    // MARK: - External resets (used by LessonsManager)
    /// Ensure persistent storage is cleared too (ProgressManager) — defensive, even if upper layer resets as well
    private func purgeProgressStoreForCurrentLesson() {
        guard !courseId.isEmpty, !lessonId.isEmpty else { return }
        // Explicitly mark all indices as not learned in persistence
        for idx in 0..<steps.count {
            ProgressManager.shared.setStepLearned(courseId: courseId, lessonId: lessonId, index: idx, isLearned: false)
        }
    }

    /// Сбросить прогресс текущего менеджера, если он относится к переданному courseId
    public func resetForCourse(_ courseId: String) {
        guard self.courseId == courseId else { return }
        learned.removeAll()
        favorites.removeAll()
        purgeProgressStoreForCurrentLesson()
        scheduleEmitProgress()
    }

    /// Alias for external callers
    public func resetCourse(courseId: String) {
        resetForCourse(courseId)
    }

    /// Полный сброс локального состояния (на случай глобального ресета)
    public func resetAll() {
        learned.removeAll()
        favorites.removeAll()
        purgeProgressStoreForCurrentLesson()
        scheduleEmitProgress()
    }

    // Ensure state is in sync when context/steps change
    private func reloadFromProgressStore() {
        guard !courseId.isEmpty, !lessonId.isEmpty else { return }
        let key = "\(courseId)|\(lessonId)"
        let indices = ProgressManager.shared.snapshot.learned[LessonKey(courseId: courseId, lessonId: lessonId)] ?? []
        let eligible = progressEligibleIndices
        let filtered = Set(indices.filter { eligible.contains($0) })
        if filtered != learned {
            learned = filtered
            ensureLearnedWithinBounds()
            scheduleEmitProgress()
        } else {
            ensureLearnedWithinBounds()
        }
    }

    private func syncFavoritesFromStore() {
        guard !courseId.isEmpty, !lessonId.isEmpty else { favorites.removeAll(); return }
        favorites = Set(steps.enumerated().compactMap { idx, _ in
            return isFavorite(index: idx) ? idx : nil
        })
    }

    private func ensureLearnedWithinBounds() {
        // Keep only indices that exist AND are eligible for progress (exclude lifehacks)
        let eligible = progressEligibleIndices
        learned = Set(learned.filter { steps.indices.contains($0) && eligible.contains($0) })
    }

    // MARK: - Mapping to DS
    /// Convert app models to DS items for rendering
    func dsSteps() -> [SDStepItem] {
        steps.map { s in
            let k: SDStepItem.Kind
            switch s.kind {
            case .word:   k = .word
            case .phrase: k = .phrase
            // DS uses `.tip` for lifehacks
            case .lifehack: k = .tip
            }
            return SDStepItem(
                kind: k,
                titleRU: s.title,
                subtitleTH: s.thai ?? "",
                phonetic: s.transcriptionRu ?? ""
            )
        }
    }

    // Helper to build a cache key for DS items
    private func cacheKey(courseId: String, lessonId: String) -> String {
        "\(courseId)|\(lessonId)"
    }

    /// Returns cached DS items for a lesson, building and caching on first access.
    public func dsStepsCached(courseId: String, lessonId: String) -> [SDStepItem] {
        let key = cacheKey(courseId: courseId, lessonId: lessonId)
        if let cached = dsCache[key] { return cached }
        StepData.shared.preload()
        let raw = StepData.shared.items(for: lessonId)
        let built: [SDStepItem] = raw.map { s in
            let kind = SDStepItem.Kind(rawValue: s.kind.rawValue) ?? .word
            return SDStepItem(
                kind: kind,
                titleRU: s.ru ?? "",
                subtitleTH: s.thai ?? "",
                phonetic: s.phonetic ?? ""
            )
        }
        dsCache[key] = built
        return built
    }

    /// Build DS items directly from StepData for a specific lesson (used by Favorites)
    public func dsSteps(courseId: String, lessonId: String) -> [SDStepItem] {
        dsStepsCached(courseId: courseId, lessonId: lessonId)
    }

// MARK: - Route resolver (card → course/lesson/step)
/// Parse favorite card identifier of the form:
///   "step:<courseId>:<lessonId>:idx<index>"
/// and return routing tuple for StepView/MiniStep.
public func resolveRoute(fromFavoriteId fid: String) -> (courseId: String, lessonId: String, stepIndex: Int)? {
#if DEBUG
    let rk = fid
    if rk != lastResolveKey { print("[StepManager] resolveRoute in:", fid); lastResolveKey = rk }
#endif
    // Make sure step data is ready so we can clamp index deterministically
    StepData.shared.preload()

    // Accept a few shapes:
    // 1) step:courseId:lessonId:idxN   (canonical)
    // 2) step:courseId:lessonId:N      (legacy)
    // 3) courseId.lessonId.idxN        (very old)
    // 4) courseId.lessonId             (default index = 0)
    var raw = fid.trimmingCharacters(in: .whitespacesAndNewlines)
    // Remember whether original id was a lifehack – we need this to remap index to TIP-only space
    let originalLower = raw.lowercased()
    let wasHack = originalLower.hasPrefix("hack:") || originalLower.contains(":hack:")
    // work on a lowercase mirror for robust prefix/index parsing
    var rawL = raw.lowercased()

    // Pre-extract :idxN if present; strip it before splitting
    var preParsedIdx: Int? = nil
    if let r = rawL.range(of: ":idx") {
        let tail = rawL[r.upperBound...]
        let digits = tail.prefix { $0.isNumber }
        if let n = Int(digits) { preParsedIdx = n }
        rawL = String(rawL[..<r.lowerBound])
        raw  = String(raw[..<r.lowerBound])
    }

    // strip optional wrapper prefixes like "card:" / "hack:" / "fav:" (can be nested)
    while rawL.hasPrefix("card:") || rawL.hasPrefix("hack:") || rawL.hasPrefix("fav:") {
        if rawL.hasPrefix("card:") { raw.removeFirst("card:".count); rawL.removeFirst("card:".count) }
        else if rawL.hasPrefix("hack:") { raw.removeFirst("hack:".count); rawL.removeFirst("hack:".count) }
        else if rawL.hasPrefix("fav:")  { raw.removeFirst("fav:".count);  rawL.removeFirst("fav:".count) }
    }

    // Helper to parse an index token like "idx3", "3", or "idx12foo"
    func parseIndex(_ token: Substring) -> Int? {
        var t = token
        if t.hasPrefix("idx") { t = t.dropFirst(3) }
        // take leading digits only
        let digits = t.prefix { $0.isNumber }
        return Int(digits)
    }
    // Helper to normalize lesson id (align with StepData keys)
    func normLesson(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }
    // Helper to normalize course id (align with StepData keys)
    func normCourse(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }
    // Helper to clamp index against actual lesson items count
    func clampIndex(course: String, lesson: String, idx: Int) -> Int {
        let count = StepData.shared.items(for: lesson).count
        let clamped = max(0, min(idx, max(0, count - 1)))
        #if DEBUG
        let key = "\(course).\(lesson).\(idx)"
        if key != lastResolveKey { print("[StepManager] resolveRoute clamp:", course, lesson, "idx=", idx, "→", clamped, "(count=", count, ")"); lastResolveKey = key }
        #endif
        return clamped
    }

    // Case 1/2: colon-separated with optional "step:" prefix
    let colonParts = rawL.split(separator: ":", omittingEmptySubsequences: false)
    if colonParts.count >= 3 {
        // Accept either: step:course:lesson[:idxN]  OR  course:lesson[:idxN]
        let start = (colonParts.first == "step") ? 1 : 0
        // Ensure we still have course and lesson after adjusting the start index
        if colonParts.count >= start + 2 {
            let course = normCourse(String(colonParts[start]))
            let lesson = normLesson(String(colonParts[start + 1]))
            let rawIdx: Int = {
                if let n = preParsedIdx { return n } // explicit :idxN always wins
                if colonParts.count >= start + 3, let n = parseIndex(colonParts[start + 2]) { return n }
                return UserSession.shared.lastStepIndex(courseId: course, lessonId: lesson) ?? 0
            }()
            let idx = clampIndex(course: course, lesson: lesson, idx: rawIdx)
            // If this favorite came from a lifehack, remap absolute idx → position within TIP-only items
            let finalIdx: Int = {
                guard wasHack else { return idx }
                let ds = dsStepsCached(courseId: course, lessonId: lesson)
                let tips = ds.enumerated().compactMap { $0.element.kind == .tip ? $0.offset : nil }
                if let pos = tips.firstIndex(of: idx) {
                    return pos
                } else {
                    return 0
                }
            }()
            #if DEBUG
            let ok = "out:\(course).\(lesson).\(finalIdx)"
            if ok != lastResolveKey { print("[StepManager] resolveRoute out:", course, lesson, finalIdx); lastResolveKey = ok }
            #endif
            return (course, lesson, finalIdx)
        }
    }

    // Case 3/4: dot-separated legacy id (course.lesson[.idxN])
    let dotParts = rawL.split(separator: ".")
    if dotParts.count >= 2 {
        let course = normCourse(String(dotParts[0]))
        let lesson = normLesson(String(dotParts[1]))
        let rawIdx: Int = {
            if let n = preParsedIdx { return n } // explicit :idxN always wins
            if dotParts.count >= 3, let n = parseIndex(dotParts[2]) { return n }
            return UserSession.shared.lastStepIndex(courseId: course, lessonId: lesson) ?? 0
        }()
        let idx = clampIndex(course: course, lesson: lesson, idx: rawIdx)
        // If this favorite came from a lifehack, remap absolute idx → position within TIP-only items
        let finalIdx: Int = {
            guard wasHack else { return idx }
            let ds = dsStepsCached(courseId: course, lessonId: lesson)
            let tips = ds.enumerated().compactMap { $0.element.kind == .tip ? $0.offset : nil }
            if let pos = tips.firstIndex(of: idx) {
                return pos
            } else {
                return 0
            }
        }()
        #if DEBUG
        let ok = "out:\(course).\(lesson).\(finalIdx)"
        if ok != lastResolveKey { print("[StepManager] resolveRoute out:", course, lesson, finalIdx); lastResolveKey = ok }
        #endif
        return (course, lesson, finalIdx)
    }

    #if DEBUG
    print("[StepManager] resolveRoute: nil for", fid)
    #endif
    return nil
}
    // MARK: - Favorite bridge
    private struct StepFavoritable: Favoritable {
        let favoriteId: String
        let favoriteTitle: String
        let favoriteSubtitle: String
        let favoriteMeta: String
        let favoriteCourseId: String
        let favoriteLessonId: String
    }

    private func asFavoritable(index: Int, _ s: StepModel) -> Favoritable {
        let isHack = (s.kind == .lifehack)
        let meta: String = {
            if isHack {
                return "hack:" + (s.thai ?? "")
            } else {
                return "card:" + (s.transcriptionRu ?? "")
            }
        }()
        return StepFavoritable(
            favoriteId: "step:\(courseId):\(lessonId):idx\(index)",
            favoriteTitle: isHack ? (s.thai ?? s.title) : s.title,
            favoriteSubtitle: (s.thai ?? ""),
            favoriteMeta: meta,
            favoriteCourseId: courseId,
            favoriteLessonId: lessonId
        )
    }

    func isFavorite(index: Int) -> Bool {
        guard steps.indices.contains(index) else { return false }
        let stepId = "step:\(courseId):\(lessonId):idx\(index)"
        // For lifehacks, normalize id by stripping "hack:" if present
        func normalize(_ s: String) -> String {
            if s.lowercased().hasPrefix("hack:") {
                return String(s.dropFirst("hack:".count))
            }
            return s
        }
        return FavoriteManager.shared.items.contains {
            normalize($0.id) == stepId ||
            normalize($0.phonetic) == stepId
        }
    }

    // MARK: - Actions
    // Favorite bridge helper (actor-isolated)
    func toggleFavorite(_ fav: Favoritable) {
        // For lifehacks, normalize id/meta to store as "step:..." not "hack:step:..."
        var item = fav
        if fav.favoriteMeta.hasPrefix("hack:") {
            var id = fav.favoriteId
            if id.hasPrefix("hack:") {
                id = String(id.dropFirst("hack:".count))
            }
            var meta = fav.favoriteMeta
            if meta.hasPrefix("hack:") {
                meta = String(meta.dropFirst("hack:".count))
            }
            struct MutFavoritable: Favoritable {
                var favoriteId: String
                var favoriteTitle: String
                var favoriteSubtitle: String
                var favoriteMeta: String
                var favoriteCourseId: String
                var favoriteLessonId: String
            }
            item = MutFavoritable(
                favoriteId: id,
                favoriteTitle: fav.favoriteTitle,
                favoriteSubtitle: fav.favoriteSubtitle,
                favoriteMeta: meta,
                favoriteCourseId: fav.favoriteCourseId,
                favoriteLessonId: fav.favoriteLessonId
            )
        }
        FavoriteManager.shared.toggle(item: item)
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        NotificationCenter.default.post(name: .favoritesDidUpdate, object: nil)
    }
    func setActive(index: Int, fromOverlay: Bool = false) {
        guard !steps.isEmpty else { return }
        didSetFromExternal = fromOverlay
        activeIndex = max(0, min(index, steps.count - 1))
        persistLastActiveIndex()
        scheduleEmitProgress()
    }

    /// External jump that won’t be overridden by restoreLastActiveIndex()
    public func externalJump(to index: Int) {
        self.didSetFromExternal = true
        self.setActive(index: index)
    }

    func playCurrent() {
        // hook for TTS / audio; no-op in DS-preview layer
    }

    func toggleFavorite() {
        guard steps.indices.contains(activeIndex) else { return }
        let model = steps[activeIndex]
        // Toggle via central manager on next runloop to avoid re-entrant UI updates
        DispatchQueue.main.async {
            self.toggleFavorite(self.asFavoritable(index: self.activeIndex, model))
        }
        // Re-sync local preview mirror a bit later (and only if still on same lesson)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.syncFavoritesFromStore()
        }
    }

    /// Toggle learned state for the current active step and notify
    func markAsLearned() {
        guard steps.indices.contains(activeIndex) else { return }
        if learned.contains(activeIndex) { learned.remove(activeIndex) } else { learned.insert(activeIndex) }
        let nowLearned = learned.contains(activeIndex)
        persistLastActiveIndex()
        notifyProgressStoreStep(index: activeIndex, isLearned: nowLearned)
        scheduleEmitProgress()
    }

    /// Explicit setter used by DS (e.g., long-press or menu actions)
    func setLearned(index: Int, _ isLearned: Bool) {
        guard steps.indices.contains(index) else { return }
        if isLearned { learned.insert(index) } else { learned.remove(index) }
        let nowLearned = learned.contains(index)
        persistLastActiveIndex()
        notifyProgressStoreStep(index: index, isLearned: nowLearned)
        scheduleEmitProgress()
    }

    // MARK: - Aggregates (preview-friendly)
    /// Returns all steps available in the current lesson context.
    /// Used by MainDS preview to build daily picks without touching data layer.
    public func allSteps() -> [StepModel] {
        return steps
    }

    /// Bridge for consumers that expect lesson titles from the steps domain
    @MainActor
    public func titleForLesson(courseId: String, lessonId: String) -> String {
        StepData.shared.titleForLesson(courseId: courseId, lessonId: lessonId)
    }
}
