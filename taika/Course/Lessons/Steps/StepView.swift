private struct StepChrome: ViewModifier {
    let isOverlay: Bool

    func body(content: Content) -> some View {
        if isOverlay {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            content
        }
    }
}



import SwiftUI
import UIKit
import Combine

// MARK: - BlurView (glossy overlay for overlays and backgrounds)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

#if canImport(StepAnimation)
import StepAnimation
#else
// Fallback shim so this file builds even if StepAnimation module isn't linked
final class StepAnimator: ObservableObject {
    static let shared = StepAnimator()
    @Published var activeIndex: Int = 0
    @Published var learned: Set<Int> = []
    @Published var favorites: Set<Int> = []
    func jump(to i: Int) { activeIndex = max(0, i) }
    func toggleLearned(_ i: Int) {
        if learned.contains(i) { learned.remove(i) } else { learned.insert(i) }
    }
}

#endif

// управление режимом взаимодействия
enum InteractionScope {
    case full       // обычный режим: меняем прогресс/выучено
    case overlay    // read-only: навигация + избранное, без мутирования прогресса
}



extension UserSession {
    /// persist last opened step index for a given course/lesson
    func setLastStepIndex(courseId: String, lessonId: String, index: Int) {
        let key = "lastStepIndex.\(courseId).\(lessonId)"
        UserDefaults.standard.set(index, forKey: key)
    }
}


struct StepView: View {
    let courseId: String?
    let lessonId: String?
    let lessonTitle: String?
    let startIndex: Int?
    let scope: InteractionScope
    let showKinds: [SDStepItem.Kind]?
    /// layout-only flag: when true, show ONLY the central cards (no FM, no progress)
    let layoutCardsOnly: Bool
    /// permission: allow mutating learning/progress
    let allowLearning: Bool
    /// show mini progress bar and its caption (hide it for Favorites overlay)
    let showBottomProgress: Bool
    /// should StepView render its own internal back header (used only for canonical full-screen)
    let showInternalHeader: Bool
    /// should StepView draw its own full-screen background (disable when embedded in external overlays)
    let useInternalBackground: Bool
    /// optional override for back action (e.g., pop to lessons instead of generic dismiss)
    let onBack: (() -> Void)?

    init(
        courseId: String? = nil,
        lessonId: String? = nil,
        lessonTitle: String? = nil,
        startIndex: Int? = nil,
        scope: InteractionScope = .full,
        showKinds: [SDStepItem.Kind]? = nil,
        layoutCardsOnly: Bool = false,
        allowLearning: Bool = true,
        showBottomProgress: Bool = true,
        showInternalHeader: Bool = true,
        useInternalBackground: Bool = true,
        onBack: (() -> Void)? = nil
    ) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.startIndex = startIndex
        self.scope = scope
        self.showKinds = showKinds
        let overlayMode = (scope == .overlay)
        // overlay — про лейаут (карты/без нижнего прогресса), но право на обучение контролируется параметром allowLearning
        self.layoutCardsOnly = layoutCardsOnly || overlayMode
        self.allowLearning = allowLearning
        self.showBottomProgress = showBottomProgress && !overlayMode && !self.layoutCardsOnly
        self.showInternalHeader = showInternalHeader
        self.useInternalBackground = useInternalBackground
        self.onBack = onBack
    }

    @State private var items: [SDStepItem] = []

    // Navigation state for HomeTask
    @State private var goHomeTask: Bool = false
    // Navigation state for Next Lesson
    @State private var goNextLesson: Bool = false

    // Overlay state for lesson summary
    @State private var showLessonSummary: Bool = false
    @State private var didShowSummaryOnce: Bool = false

    @StateObject private var anim = StepAnimator()
    @State private var resetGuardUntil: Date = .distantPast
    @State private var progressRenderNonce: Int = 0 // forces SDStepProgress to fully re-render after resets
    @State private var needsPostResetHydrate: Bool = false
    @State private var progressReady: Bool = false
    @State private var didSetInitialIndex: Bool = false
    @State private var pendingProgressPost: DispatchWorkItem? = nil
    @State private var pendingIndexPersist: DispatchWorkItem? = nil
    @State private var isMounted: Bool = false
    // live favorites sync
    @ObservedObject private var favManager = FavoriteManager.shared

    @Environment(\.dismiss) private var dismiss

    @State private var hints: [String] = []
    @State private var itemTips: [Int: String] = [:]
    @State private var resolvedTitle: String? = nil
    @State private var resolvedLessonId: String = ""
    @State private var resolvedCourseId: String = ""
    // Preloaded next-lesson id for smoother navigation
    @State private var nextLessonPreloadedId: String? = nil
    // Optional override to swap lesson in-place (used for "Следующий урок")
    @State private var overrideLessonId: String? = nil
    // Pending push to another course (used when we advance to next course)
    @State private var pendingNavCourseId: String? = nil
    @State private var pendingNavLessonId: String? = nil
    // Fallback presentation for cross-course navigation (when NavigationStack isn't available)
    @State private var presentNextCourse: Bool = false

    // mapping for progress-only items (exclude tips/dialogs from progress)
    @State private var progressMap: [Int: Int] = [:]          // originalIndex -> compactProgressIndex
    @State private var reverseProgressMap: [Int: Int] = [:]    // compactProgressIndex -> originalIndex

    // mapping between raw StepData indices and filtered UI indices
    @State private var origToUI: [Int: Int] = [:]
    @State private var uiToOrig: [Int: Int] = [:]

    // Detect Xcode Previews for isPreview usage
#if DEBUG
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
#else
    private var isPreview: Bool { false }
#endif

    // Helper: are we in overlay mode?
    private var isOverlay: Bool { scope == .overlay }

    // Compact (progress-only) projections
    private var learnedForProgress: Set<Int> {
        Set(anim.learned.compactMap { progressMap[$0] })
    }
    private var favoritesForProgress: Set<Int> {
        Set(anim.favorites.compactMap { progressMap[$0] })
    }
    private var progressTotal: Int { reverseProgressMap.count }

    // Progress-strip indices that correspond to lifehacks (tips)
    private var tipIndicesForProgress: Set<Int> {
        var s: Set<Int> = []
        for (i, it) in items.enumerated() {
            if it.kind == .tip, let mapped = progressMap[i] { s.insert(mapped) }
        }
        return s
    }

    // Original indices for tips, for use with ProgressManager
    private var tipOriginalIndices: Set<Int> {
        var s: Set<Int> = []
        for (i, it) in items.enumerated() {
            if it.kind == .tip { s.insert(i) }
        }
        return s
    }

    // Safe active index for projections (guards against -1 / OOB while data hydrates)
    private var clampedActiveIndex: Int {
        max(0, min(anim.activeIndex, max(0, items.count - 1)))
    }

    // Guard window right after resets: ignore progressDidChange for a short time
    private func beginResetGuard(_ seconds: TimeInterval = 0.7) {
        resetGuardUntil = Date().addingTimeInterval(seconds)
    }
    private var isUnderResetGuard: Bool { Date() < resetGuardUntil }

    // Force a full re-render of the carousel and clear any local visual state
    private func forceColdCarousel() {
        anim.learned.removeAll()
        anim.favorites.removeAll()
    }

    // After a reset, schedule a safe rehydrate from storage (only after guard window ends)
    private func schedulePostResetHydrate() {
        guard needsPostResetHydrate else { return }
        let delay: TimeInterval = 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // If guard window already elapsed, we can safely rehydrate from storage (will be empty after reset)
            if !isUnderResetGuard {
                hydrateLearnedFromSession()
                hydrateFavoritesFromManager()
                progressRenderNonce &+= 1
            } else {
                // Try again shortly after guard ends
                schedulePostResetHydrate()
            }
            needsPostResetHydrate = false
        }
    }


    // Count only learnable cards (exclude tips/intro/summary)
    private var learnableCount: Int {
        items.filter { it in
            switch it.kind { case .word, .phrase, .casual: true; default: false }
        }.count
    }

    // MARK: - Learnability helpers
    private func isLearnable(_ item: SDStepItem) -> Bool {
        switch item.kind { case .word, .phrase, .casual: return true; default: return false }
    }
    private func firstLearnableIndex() -> Int {
        return items.firstIndex(where: { isLearnable($0) }) ?? 0
    }
    private func normalizeToLearnableIndex(_ idx: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        let clamped = max(0, min(idx, items.count - 1))
        if isLearnable(items[clamped]) { return clamped }
        if let fwd = items.indices.dropFirst(clamped).first(where: { isLearnable(items[$0]) }) {
            return fwd
        }
        if let back = items.indices.prefix(clamped).reversed().first(where: { isLearnable(items[$0]) }) {
            return back
        }
        return 0
    }

    private func notifyProgressAfterToggle(stepIndex: Int) {
        let nowLearned = anim.learned.contains(stepIndex)
        let cid = resolvedCourseId.isEmpty ? {
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }() : resolvedCourseId
        let lid = resolvedLessonId

        // Persist via ProgressManager and update lesson status (ignoring tips)
        ProgressManager.shared.setStepLearned(courseId: cid, lessonId: lid, index: stepIndex, isLearned: nowLearned)
        ProgressManager.shared.markStarted(courseId: cid, lessonId: lid)
        ProgressManager.shared.markCompletedIfNeeded(
            courseId: cid,
            lessonId: lid,
            totalSteps: learnableCount,
            tipIndexes: tipOriginalIndices
        )
        // Notify upper layers (LessonsManager / LessonsView)
        scheduleProgressSnapshot()
    }

    private func hydrateLearnedFromSession() {
        let cid = resolvedCourseId.isEmpty ? {
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }() : resolvedCourseId
        let saved = ProgressManager.shared.learnedSet(courseId: cid, lessonId: resolvedLessonId)
        let filtered = saved.filter { idx in
            idx >= 0 && idx < items.count && {
                switch items[idx].kind { case .word, .phrase, .casual: true; default: false }
            }()
        }
        anim.learned = filtered
    }

    private func hydrateFavoritesFromManager() {
        anim.favorites.removeAll()
        let courseId: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        for (i, item) in items.enumerated() {
            let fav = makeStepFav(for: item, index: i)
            let oi = originalIndex(for: i)
            let legacyId = "step:\(courseId):\(resolvedLessonId):idx\(oi)" // old scheme w/o type prefix
            if FavoriteManager.shared.isLiked(id: fav.favoriteId) ||
               FavoriteManager.shared.isLiked(id: legacyId) {
                anim.favorites.insert(i)
            }
        }
    }
    // Map UI (filtered/mapped) index to original raw StepData index using id-stable mapping
    private func originalIndex(for uiIndex: Int) -> Int {
        guard uiIndex >= 0 && uiIndex < items.count else { return uiIndex }
        return uiToOrig[uiIndex] ?? uiIndex
    }

    // Debounced progress snapshot to avoid chatty notifications
    private func scheduleProgressSnapshot(_ delay: TimeInterval = 0.12) {
        // Do not post while we're under a reset guard window
        if isUnderResetGuard { return }
        // Cancel any pending post
        pendingProgressPost?.cancel()
        let work = DispatchWorkItem { [resolvedLessonId] in
            // Double-check lesson is resolved before posting
            guard !resolvedLessonId.isEmpty else { return }
            postStepProgressSnapshot()
        }
        pendingProgressPost = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // Push a snapshot of the current in-lesson progress to LessonsManager/LessonsView
    private func postStepProgressSnapshot() {
        // Compact projection indices for the progress strip
        let learnedIdx = Array(learnedForProgress).sorted()                  // only learnable
        let allIdx = Array(0..<max(0, progressTotal))                        // all progress cells including tips
        let hacksIdx = Array(tipIndicesForProgress).sorted()                 // progress indices that are tips

        // Resolve course id from explicit value or from lesson id prefix
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()

        NotificationCenter.default.post(
            name: .stepProgressDidChange,
            object: nil,
            userInfo: [
                "courseId": cid,
                "lessonId": resolvedLessonId,
                // Preferred rich payload with raw indices
                "learnedContent": learnedIdx,
                "allCards": allIdx,
                "lifehacks": hacksIdx,
                // Aggregates for consumers that only need counts
                "learnedCount": learnedIdx.count,
                "totalCount": allIdx.count,
                "lifehackCount": hacksIdx.count
            ]
        )
    }

    private func rebuildProgressIndexMaps() {
        progressMap.removeAll()
        reverseProgressMap.removeAll()
        var p = 0
        for i in items.indices {
            switch items[i].kind {
            case .word, .phrase, .casual, .tip:
                progressMap[i] = p
                reverseProgressMap[p] = i
                p += 1
            default:
                // intro/dialog/summary — не попадают в мини‑бар
                continue
            }
        }
    }

    // Returns a clamped and projected index for the progress strip, always valid and deterministic
    private func progressActiveIndexForDisplay() -> Int {
        guard !items.isEmpty else { return 0 }
        let ui = max(0, min(anim.activeIndex, items.count - 1))
        if let p = progressMap[ui] { return p }
        // Если текущая карта не проецируется в прогресс: берём ближайшую проецируемую слева, иначе 0
        var j = ui
        while j >= 0 {
            if let p = progressMap[j] { return p }
            j -= 1
        }
        return 0
    }

    // Normalization helper for ids used in favorites storage
    private func normalizedId(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    private func hydratedActiveStartIndex() -> Int {
        guard !resolvedLessonId.isEmpty else { return 0 }
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        // After a reset or when there is no learned progress at all — always start from the first card
        let learnedNow = ProgressManager.shared.learnedSet(courseId: cid, lessonId: resolvedLessonId)
        if isUnderResetGuard || learnedNow.isEmpty { return 0 }
        if let saved = UserSession.shared.lastStepIndex(courseId: cid, lessonId: resolvedLessonId) {
            return max(0, min(saved, max(0, items.count - 1)))
        }
        return 0
    }

    private func loadFromStepData() {
        StepData.shared.preload()
        let lid: String
        if let ov = overrideLessonId, !ov.isEmpty {
            lid = ov
        } else if let lessonId = lessonId, !lessonId.isEmpty {
            lid = lessonId
        } else if let cid = courseId, cid == "course_b_1" {
            lid = "course_b_1_l1"
        } else {
            lid = "course_b_1_l1" // generic fallback to validate steps.json parsing
        }
        // Avoid reloading if the same lesson is already loaded and items are present.
        // BUT: if we came from overlay with a non-nil startIndex and we haven't applied it yet,
        // push that index once and keep the existing items.
        if self.resolvedLessonId == lid && !self.items.isEmpty {
            if let s = self.startIndex, !didSetInitialIndex {
                let clamped = max(0, min(s, max(0, self.items.count - 1)))
                self.anim.jump(to: clamped)
                self.didSetInitialIndex = true
            }
            return
        }
        // debug print removed
        self.resolvedLessonId = lid
        self.resolvedCourseId = self.courseId ?? ""
        // Resolve lesson title early
        self.resolvedTitle = self.lessonTitle ?? LessonsData.shared.lessonTitle(for: lid)
        let raw = StepData.shared.items(for: lid)
        // debug print removed
        // Map StepData.StepItem -> SDStepItem for DS
        let mapped: [SDStepItem] = raw.compactMap { it in
            switch it.kind {
            case .word:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .word, titleRU: ru, subtitleTH: th, phonetic: ph)
                }
            case .phrase:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .phrase, titleRU: ru, subtitleTH: th, phonetic: ph)
                }
            case .casual:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .casual, titleRU: ru, subtitleTH: th, phonetic: ph)
                }
            case .tip:
                if let text = it.text {
                    let title = it.tip ?? "Лайфхак"
                    return SDStepItem(kind: .tip, titleRU: title, subtitleTH: text, phonetic: "")
                }
            case .dialog:
                if let scene = it.scene {
                    return SDStepItem(kind: .tip, titleRU: "Сцена", subtitleTH: scene, phonetic: "")
                }
            }
            return nil
        }
        // Remember original requested start (pre-filter) to keep the same card after filtering
        let originalStart: Int? = self.startIndex.map { max(0, min($0, max(0, mapped.count - 1))) }
        let originalStartId: String? = {
            guard let idx = originalStart,
                  !mapped.isEmpty,
                  idx >= 0, idx < mapped.count else { return nil }
            return mapped[idx].id.uuidString
        }()

        // Effective kinds: explicit showKinds only; otherwise show all kinds, even in overlay
        let effectiveKinds: [SDStepItem.Kind]? = {
            if let explicit = showKinds { return explicit }
            return nil
        }()

        // Filter with preservation of original indices → build mapping UI <-> original
        let filteredPairs: [(orig: Int, item: SDStepItem)] = {
            if let kinds = effectiveKinds {
                return mapped.enumerated().filter { kinds.contains($0.element.kind) }.map { ($0.offset, $0.element) }
            } else {
                return mapped.enumerated().map { ($0.offset, $0.element) }
            }
        }()

        // Build per-UI-index tips from raw StepData items before applying filtered items
        var tipsByUI: [Int: String] = [:]
        for (ui, pair) in filteredPairs.enumerated() {
            let orig = pair.orig
            if orig >= 0 && orig < raw.count, let tip = raw[orig].tip, !tip.isEmpty {
                tipsByUI[ui] = tip
            }
        }
        self.itemTips = tipsByUI

        // Apply filtered items
        self.items = filteredPairs.map { $0.item }

        // Build maps UI → Original and Original → UI (used for favorites & progress projections)
        var u2o: [Int: Int] = [:]
        var o2u: [Int: Int] = [:]
        for (ui, pair) in filteredPairs.enumerated() {
            u2o[ui] = pair.orig
            o2u[pair.orig] = ui
        }
        self.uiToOrig = u2o
        self.origToUI = o2u

        // Clear any stale learned state before rebuilding progress index maps
        self.anim.learned.removeAll()
        rebuildProgressIndexMaps()
        self.hints = StepData.shared.hints(for: lid)

        // Safety fallback: if no data loaded, inject a tiny demo so DS still renders
        if self.items.isEmpty {
            self.items = [
                .init(kind: .word,   titleRU: "Привет",            subtitleTH: "สวัสดี",                    phonetic: "са-ват-ди́"),
                .init(kind: .phrase, titleRU: "Счёт, пожалуйста",  subtitleTH: "เช็คบิล",                   phonetic: "чек-бин"),
                .init(kind: .tip,    titleRU: "Подсказка",         subtitleTH: "Если пусто — проверь steps.json", phonetic: "")
            ]
            print("[StepView] fallback demo injected (empty data)")
        }

        // Immediately hydrate from session and favorites after data load
        self.hydrateLearnedFromSession()
        self.hydrateFavoritesFromManager()

        // Base start index per priority
        let baseStart: Int = {
            if let s = self.startIndex {
                return max(0, min(s, max(0, self.items.count - 1)))
            }
            if let id = originalStartId, let idx = self.items.firstIndex(where: { $0.id.uuidString == id }) {
                return idx
            }
            if self.isOverlay { return 0 }
            return isPreview ? 0 : hydratedActiveStartIndex()
        }()
        // Normalize to a learnable card so mini‑progress and carousel align visually
        let startIdx = normalizeToLearnableIndex(baseStart)

        // Set initial index exactly once and coalesce progress snapshot
        if !didSetInitialIndex {
            self.anim.jump(to: startIdx)
            // Ensure the DS scroll snaps to the same index after layout
            DispatchQueue.main.async { self.anim.jump(to: startIdx) }
            self.didSetInitialIndex = true
        }


        self.progressReady = false
        self.progressRenderNonce &+= 1
        // Post snapshot after the view tree binds to the new index
        DispatchQueue.main.async { self.scheduleProgressSnapshot() }
        self.progressReady = true
    }
    // (Old hydrateActiveIndexFromActivity() removed and replaced by hydratedActiveStartIndex())


    // Split out to reduce type-checking pressure in the main body
    @ViewBuilder
    private func carouselView() -> some View {
        let activeBinding = Binding<Int>(
            get: { anim.activeIndex },
            set: { anim.activeIndex = $0 }
        )

        // заголовок секции берём из резолвнутого названия урока
        let sectionTitle: String = {
            if let t = resolvedTitle, !t.isEmpty {
                return t.uppercased()
            }
            if let t = lessonTitle, !t.isEmpty {
                return t.uppercased()
            }
            // fallback: generic lesson label so header всегда рисуется
            return "УРОК"
        }()

        // простой сабтайтл по количеству карт; при желании можно потом обогатить
        let sectionSubtitle: String? = {
            guard !items.isEmpty else { return nil }
            return "урок • \(items.count) карт"
        }()

        SDStepCarousel(
            title: sectionTitle,
            items: items,
            activeIndex: activeBinding,
            subtitle: sectionSubtitle,
            learned: anim.learned,
            favorites: anim.favorites,
            onTap: { handleTapItem($0) },
            onPlay: { handlePlayItem($0) },
            onFav: { handleFavItem($0) },
            onDone: { handleDoneItem($0) },
            onNext: { handleNextItem($0) },
            isOverlay: isOverlay
        )
    }

    // Split out the Next-Lesson link to reduce type-checking in the main body
    @ViewBuilder
    private func nextLessonLink() -> some View {
        NavigationLink(isActive: $goNextLesson) {
            let cid: String = pendingNavCourseId ?? {
                if !resolvedCourseId.isEmpty { return resolvedCourseId }
                let parts = resolvedLessonId.split(separator: "_")
                if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                return resolvedLessonId
            }()
            let targetId = pendingNavLessonId ?? nextLessonPreloadedId ?? nextLessonId(from: resolvedLessonId) ?? resolvedLessonId
            StepView(courseId: cid, lessonId: targetId, lessonTitle: guessLessonTitle(for: targetId))
        } label: { EmptyView() }
        .hidden()
    }

    @ViewBuilder
    private func bottomProgressView(proxy: GeometryProxy) -> some View {
        if progressTotal > 0 {
            let raw = progressActiveIndexForDisplay()
            // LTR: progress index grows left→right together with carousel
            let p: Int = raw
            let progressView: SDStepProgress = SDStepProgress(
                total: progressTotal,
                activeIndex: p,
                learned: learnedForProgress,
                favorites: favoritesForProgress,
                tipIndices: tipIndicesForProgress,
                onTap: { i in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let original = reverseProgressMap[i] ?? i
                    didSetInitialIndex = true
                    anim.jump(to: original)
                }
            )
            progressView
                .id("progress-\(resolvedLessonId)-\(progressRenderNonce)")
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 12)
        }
    }

    // MARK: - Subviews to reduce type-checking pressure
    @ViewBuilder
    private func summaryOverlayView() -> some View {
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        let advance = CourseNavigator.shared.advance(from: cid, lessonId: resolvedLessonId)

        let config: (title: String, subtitle: String, secondary: String) = {
            switch advance {
            case .nextLesson:
                let t = (resolvedTitle ?? "Урок").uppercased()
                return ("Итоги урока", "\(t) — выучено \(anim.learned.count) из \(learnableCount)", "Следующий урок")
            case .nextCourse(_, let firstLessonId):
                let nextTitle = LessonsData.shared.lessonTitle(for: firstLessonId) ?? "Следующий курс"
                return ("Курс завершён", "Дальше: \(nextTitle)", "Следующий курс")
            case .end:
                return ("Все курсы пройдены", "Можно повторить материал или выбрать раздел", "К курсам")
            }
        }()

        LessonSummaryOverlay(
            title: config.title,
            subtitle: config.subtitle,
            primaryTitle: "Закрепить",
            secondaryTitle: config.secondary,
            onPrimary: {
                withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                goHomeTask = true
            },
            onSecondary: {
                switch advance {
                case .end:
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                case .nextLesson:
                    // same-course advance (in-place swap)
                    prepareNextLessonAndNavigate()
                case .nextCourse(let nextCourseId, let firstLessonId):
                    // use the already computed target to avoid mismatches
                    _ = StepData.shared.items(for: firstLessonId) // warm cache
                    pendingNavCourseId = nextCourseId
                    pendingNavLessonId = firstLessonId
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        presentNextCourse = true
                    }
                }
            },
            onClose: {
                withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
            }
        )
        .transition(.scale.combined(with: .opacity))
        .zIndex(1)
    }

    @ViewBuilder
    private func stepMainContent(_ proxy: GeometryProxy) -> some View {
        let idx = clampedActiveIndex
        let currentTipText: String? = itemTips[idx]
        let stack = VStack(spacing: 0) {
            // скрытый линк на следующий урок (логика остаётся общей)
            nextLessonLink()

            // TOP: taika fm bubble (DS) — только если не просили показывать одни карточки и не в overlay
            if !layoutCardsOnly && !isOverlay {
                TaikaFMBubbleTyping(
                    messages: TaikaFMData.shared
                        .accentMessagesFromStepTip(currentTipText)
                        .map { chunkArray in
                            chunkArray.map { $0.text }.joined()
                        },
                    reactions: TaikaFMData.shared.reactionGroups(for: .step),
                    repeats: true
                )
                .padding(.horizontal, PD.Spacing.inner)
                // чуть ближе к верхнему хедеру, чтобы освободить место для карточек
                .padding(.top, isOverlay ? 4 : 12)
            }

            // MIDDLE: Carousel (нативная высота из StepDS)
            carouselView()
                // поджимаем к FM‑баблу, чтобы карточка сидела выше
                .padding(.top, 8)
                .padding(.horizontal, PD.Spacing.inner)
                .frame(maxWidth: .infinity, alignment: .center)
                .modifier(StepChrome(isOverlay: isOverlay))

            // BOTTOM: Progress (DS)
            if !isOverlay && showBottomProgress {
                bottomProgressView(proxy: proxy)
                    // уменьшаем зазор между карточкой и прогрессом
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)

        stack
            .blur(radius: showLessonSummary ? 12 : 0)
            .saturation(showLessonSummary ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.18), value: showLessonSummary)
            .allowsHitTesting(isOverlay ? true : !showLessonSummary)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                stepMainContent(proxy)
                if showLessonSummary {
                    summaryOverlayView()
                }
            }
            .sheet(isPresented: $goHomeTask) {
                let cid: String = {
                    if !resolvedCourseId.isEmpty { return resolvedCourseId }
                    let parts = resolvedLessonId.split(separator: "_")
                    if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                    return resolvedLessonId
                }()

                ZStack {
                    // glossy blur behind, no black dim, no extra card container
                    taikaGlassBackground()

                    HomeTaskView(courseId: cid, lessonId: resolvedLessonId, embedBackground: false)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 16)
                }
                .presentationDetents([.fraction(0.92)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
                .presentationBackground(.clear)
            }
            .fullScreenCover(isPresented: $presentNextCourse) {
                if let cid = pendingNavCourseId, let lid = pendingNavLessonId {
                    NavigationStack {
                        StepView(courseId: cid, lessonId: lid, lessonTitle: guessLessonTitle(for: lid))
                    }
                    .preferredColorScheme(.dark)
                }
            }

            .onAppear {
                isMounted = true
                // debug print removed
                loadFromStepData()
                if !isOverlay && !resolvedCourseId.isEmpty {
                    UserSession.shared.markActive(courseId: resolvedCourseId, lessonId: resolvedLessonId)
                }
                needsPostResetHydrate = false
                // Hydration now handled inside loadFromStepData()
                // DispatchQueue.main.async { hydrateLearnedFromSession() }
                // DispatchQueue.main.async { hydrateFavoritesFromManager() }
                // Safety net: ensure snapshot after appear
            }
            .onChange(of: startIndex) { newStart in
                // Prevent re-initialization after the first application of startIndex
                guard !didSetInitialIndex else { return }
                guard let s = newStart, !items.isEmpty else { return }
                let clamped = max(0, min(s, max(0, items.count - 1)))
                if anim.activeIndex != clamped {
                    anim.jump(to: clamped)
                    didSetInitialIndex = true
                }
            }
            .onChange(of: anim.activeIndex) { newValue in
                if !isOverlay {
                    // Debounce persisting last step index to avoid chatty writes while scrolling
                    pendingIndexPersist?.cancel()
                    let clamped = max(0, min(newValue, max(0, items.count - 1)))
                    let work = DispatchWorkItem {
                        let cid: String = {
                            if !resolvedCourseId.isEmpty { return resolvedCourseId }
                            let parts = resolvedLessonId.split(separator: "_")
                            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                            return resolvedLessonId
                        }()
                        UserSession.shared.setLastStepIndex(courseId: cid, lessonId: resolvedLessonId, index: clamped)
                    }
                    pendingIndexPersist = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
                }
            }
            .safeAreaInset(edge: .top) {
                if !isOverlay && showInternalHeader {
                    AppBackHeader {
                        if let onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    }
                    .padding(.horizontal, PD.Spacing.inner)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarBackButtonHidden(true)
            .onDisappear { isMounted = false }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .lessonProgressDidReset)) { note in
                // Proactively purge persisted progress for the specific lesson
                do {
                    let cidPurge: String = {
                        if !resolvedCourseId.isEmpty { return resolvedCourseId }
                        let parts = resolvedLessonId.split(separator: "_")
                        if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                        return resolvedLessonId
                    }()
                    let lidPurge = resolvedLessonId
                    if !cidPurge.isEmpty, !lidPurge.isEmpty {
                        ProgressManager.shared.resetLesson(courseId: cidPurge, lessonId: lidPurge)
                    }
                    // No longer forcibly clear the persisted last index for this lesson
                }
                // If the notification carries a lessonId, match it; otherwise clear optimistically.
                if let userInfo = note.userInfo,
                   let lid = userInfo["lessonId"] as? String,
                   !resolvedLessonId.isEmpty,
                   lid != resolvedLessonId {
                    return
                }
                // Clear local state and rebuild maps. Do NOT rehydrate here.
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                rebuildProgressIndexMaps()
                forceColdCarousel()
                progressRenderNonce &+= 1
                beginResetGuard()
                needsPostResetHydrate = true
                schedulePostResetHydrate()
            }
            // Listen to namespaced course progress reset notification
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LessonsManager.courseProgressDidReset"))) { note in
                // Proactively purge persisted progress for the current course
                do {
                    let cidPurge: String = {
                        if !resolvedCourseId.isEmpty { return resolvedCourseId }
                        let parts = resolvedLessonId.split(separator: "_")
                        if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                        return resolvedLessonId
                    }()
                    if !cidPurge.isEmpty {
                        ProgressManager.shared.resetCourse(courseId: cidPurge)
                    }
                    // No longer forcibly clear the persisted last index for this course/lesson
                }
                // If the notification carries a courseId, match it; otherwise clear optimistically.
                if let userInfo = note.userInfo,
                   let cid = userInfo["courseId"] as? String,
                   !resolvedCourseId.isEmpty,
                   cid != resolvedCourseId {
                    return
                }
                // Clear local state immediately and DO NOT rehydrate here to avoid pulling stale snapshot back
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                rebuildProgressIndexMaps()
                forceColdCarousel()
                // Intentionally not calling hydrateLearnedFromSession()/hydrateFavoritesFromManager() here.
                progressRenderNonce &+= 1
                beginResetGuard()
                needsPostResetHydrate = true
                schedulePostResetHydrate()
            }
            // Listen to namespaced lesson progress reset notification
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LessonsManager.lessonProgressDidReset"))) { note in
                // Proactively purge persisted progress for the specific lesson
                do {
                    let cidPurge: String = {
                        if !resolvedCourseId.isEmpty { return resolvedCourseId }
                        let parts = resolvedLessonId.split(separator: "_")
                        if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                        return resolvedLessonId
                    }()
                    let lidPurge = resolvedLessonId
                    if !cidPurge.isEmpty, !lidPurge.isEmpty {
                        ProgressManager.shared.resetLesson(courseId: cidPurge, lessonId: lidPurge)
                    }
                    // No longer forcibly clear the persisted last index for this lesson
                }
                // If the notification carries a lessonId, match it; otherwise clear optimistically.
                if let userInfo = note.userInfo,
                   let lid = userInfo["lessonId"] as? String,
                   !resolvedLessonId.isEmpty,
                   lid != resolvedLessonId {
                    return
                }
                // Clear local state and rebuild maps. Do NOT rehydrate here.
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                rebuildProgressIndexMaps()
                forceColdCarousel()
                progressRenderNonce &+= 1
                beginResetGuard()
                needsPostResetHydrate = true
                schedulePostResetHydrate()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("stepLocalStateShouldReset"))) { note in
                // scope: "all" | "course" | "lesson"
                let scope = (note.userInfo?["scope"] as? String) ?? "all"
                let cid = note.userInfo?["courseId"] as? String
                let lid = note.userInfo?["lessonId"] as? String

                // Filter by scope
                switch scope {
                case "lesson":
                    if let lid, !resolvedLessonId.isEmpty, lid != resolvedLessonId { return }
                case "course":
                    if let cid, !resolvedCourseId.isEmpty, cid != resolvedCourseId { return }
                default:
                    break
                }

                // Clear ONLY local visual state, do not rehydrate synchronously
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                // Removed: do { ... UserSession.shared.setLastStepIndex ... }
                rebuildProgressIndexMaps()
                progressRenderNonce &+= 1
                beginResetGuard()
                needsPostResetHydrate = true
                schedulePostResetHydrate()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("stepProgressDidReset"))) { note in
                // Unified reset hook from LessonsManager / ProgressManager to fully clear local visuals.
                // Accept optional scoping via userInfo, but default to clearing optimistically.
                let cidNote = note.userInfo?["courseId"] as? String
                let lidNote = note.userInfo?["lessonId"] as? String
                if let cidNote, !resolvedCourseId.isEmpty, cidNote != resolvedCourseId { return }
                if let lidNote, !resolvedLessonId.isEmpty, lidNote != resolvedLessonId { return }

                // Clear local state and avoid immediate rehydrate (prevents stale snapshot from popping back visually)
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                // Removed: do { ... UserSession.shared.setLastStepIndex ... }
                rebuildProgressIndexMaps()
                progressRenderNonce &+= 1
                beginResetGuard()
                needsPostResetHydrate = true
                schedulePostResetHydrate()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("usCourseProgressDidReset"))) { note in
                // Mirror the same behavior as non-prefixed reset
                if let userInfo = note.userInfo,
                   let cid = userInfo["courseId"] as? String,
                   !resolvedCourseId.isEmpty,
                   cid != resolvedCourseId {
                    return
                }
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                // Removed: do { ... UserSession.shared.setLastStepIndex ... }
                rebuildProgressIndexMaps()
                progressRenderNonce &+= 1
                beginResetGuard()
                needsPostResetHydrate = true
                schedulePostResetHydrate()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("usLessonProgressDidReset"))) { note in
                if let userInfo = note.userInfo,
                   let lid = userInfo["lessonId"] as? String,
                   !resolvedLessonId.isEmpty,
                   lid != resolvedLessonId {
                    return
                }
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                // Removed: do { ... UserSession.shared.setLastStepIndex ... }
                rebuildProgressIndexMaps()
                progressRenderNonce &+= 1
                beginResetGuard()
                needsPostResetHydrate = true
                schedulePostResetHydrate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .progressDidChange)) { _ in
                // No-op on in-lesson progress changes to avoid resetting the carousel and causing a jump-from-first illusion.
                // We already keep local `anim.learned` in sync on toggle; progress strip reads from it directly.
            }
            .onReceive(NotificationCenter.default.publisher(for: .progressCourseDidReset)) { _ in
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                // Removed: do { ... UserSession.shared.setLastStepIndex ... }
                rebuildProgressIndexMaps()
                progressRenderNonce &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .progressLessonDidReset)) { _ in
                anim.learned.removeAll()
                anim.favorites.removeAll()
                let keep = anim.activeIndex; anim.activeIndex = min(keep, max(0, items.count - 1))
                didSetInitialIndex = true
                // Removed: do { ... UserSession.shared.setLastStepIndex ... }
                rebuildProgressIndexMaps()
                progressRenderNonce &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .favoritesDidChange)) { _ in
                if isMounted { hydrateFavoritesFromManager() }
            }
            .onReceive(favManager.$items) { _ in
                if isMounted { hydrateFavoritesFromManager() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stepProgressDidChange)) { _ in
                guard !isOverlay else { return }
                // If all learnable cards are done, show the canonical summary overlay
                let totalLearnable = learnableCount
                if totalLearnable > 0 {
                    let learnedNowCount = anim.learned.filter { idx in
                        guard idx >= 0 && idx < items.count else { return false }
                        switch items[idx].kind {
                        case .word, .phrase, .casual:
                            return true
                        default:
                            return false
                        }
                    }.count
                    if learnedNowCount >= totalLearnable {
                        if !didShowSummaryOnce {
                            didShowSummaryOnce = true
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                showLessonSummary = true
                            }
                        }
                    } else {
                        // Progress is no longer full → allow the summary to appear again on the next completion
                        didShowSummaryOnce = false
                        if showLessonSummary {
                            withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                        }
                    }
                }
            }
        }
    }

    private func index(of item: SDStepItem) -> Int? {
        items.firstIndex(where: { $0.id == item.id })
    }

    // MARK: - Handlers extracted to reduce type-checking complexity
    private func handleTapItem(_ item: SDStepItem) {
        if let i = index(of: item) {
            anim.jump(to: i)
        }
    }

    private func handlePlayItem(_ item: SDStepItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch item.kind {
        case .word, .phrase, .casual:
            StepAudio.shared.speakThai(item.subtitleTH)
        default:
            break
        }
    }

    private func handleFavItem(_ item: SDStepItem) {
        guard let i = index(of: item) else { return }
        let wasFavorite = anim.favorites.contains(i)
        let fav = makeStepFav(for: item, index: i)
        // instant local UI feedback to avoid visual lag
        if wasFavorite {
            anim.favorites.remove(i)
        } else {
            anim.favorites.insert(i)
        }
        // toggle asynchronously to prevent re-entrant updates during render
        DispatchQueue.main.async {
            Task { @MainActor in
                StepManager.shared.toggleFavorite(fav)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isMounted { hydrateFavoritesFromManager() }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if item.kind == .tip, !wasFavorite, i + 1 < items.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                anim.jump(to: i + 1)
            }
        }
    }

    private func handleDoneItem(_ item: SDStepItem) {
        switch item.kind {
        case .word, .phrase, .casual:
            // Respect read-only flows (e.g., Favorites overlay)
            guard allowLearning else { return }
            guard let i = index(of: item) else { return }
            let wasLearned = anim.learned.contains(i)
            anim.toggleLearned(i)
#if !DEBUG
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
            let nowLearned = anim.learned.contains(i)
            notifyProgressAfterToggle(stepIndex: i)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if isMounted { hydrateLearnedFromSession() }
            }
            // If пользователь снял отметку хотя бы с одной карточки → разрешить повторный показ summary при следующем полном завершении
            if wasLearned && !nowLearned {
                didShowSummaryOnce = false
                if showLessonSummary {
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                }
            }
            if !wasLearned && nowLearned, i < items.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    anim.jump(to: i + 1)
                }
            }
            // Show summary only when user completes ALL learnable cards (transition from not-all to all)
            let totalLearnable = learnableCount
            let learnedNowCount = anim.learned.filter { idx in
                guard idx >= 0 && idx < items.count else { return false }
                switch items[idx].kind { case .word, .phrase, .casual: return true; default: return false }
            }.count
            if !wasLearned && nowLearned && totalLearnable > 0 && learnedNowCount >= totalLearnable && !didShowSummaryOnce {
                didShowSummaryOnce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        showLessonSummary = true
                    }
                }
            } else {
                // If пользователь снял галочку на последней — не показываем оверлей и закрываем, если он вдруг открыт
                if showLessonSummary {
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                }
            }
            let cid: String = {
                if !resolvedCourseId.isEmpty { return resolvedCourseId }
                let parts = resolvedLessonId.split(separator: "_")
                if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                return resolvedLessonId
            }()
            NotificationCenter.default.post(
                name: Notification.Name("stepLearnedDidChange"),
                object: nil,
                userInfo: [
                    "courseId": cid,
                    "lessonId": resolvedLessonId,
                    "index": i,
                    "isLearned": nowLearned
                ]
            )
        case .tip:
            if let i = index(of: item), i + 1 < items.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    anim.jump(to: i + 1)
                }
            }
        default:
            break
        }
    }

    private func handleNextItem(_ item: SDStepItem) {
        if let i = index(of: item), i + 1 < items.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                anim.jump(to: i + 1)
            }
        }
    }

    // Decide where to go next using CourseNavigator; swap in-place for same course, push for next course
    private func prepareNextLessonAndNavigate() {
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        switch CourseNavigator.shared.advance(from: cid, lessonId: resolvedLessonId) {
        case .nextLesson(_, let nextId):
            _ = StepData.shared.items(for: nextId) // warm cache
            nextLessonPreloadedId = nextId
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                didSetInitialIndex = false
                overrideLessonId = nextId
                anim.learned.removeAll(); anim.favorites.removeAll()
                loadFromStepData()
            }
        case .nextCourse(let nextCourseId, let firstLesson):
            _ = StepData.shared.items(for: firstLesson) // warm cache
            pendingNavCourseId = nextCourseId
            pendingNavLessonId = firstLesson
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                // Prefer modal present to avoid dependency on NavigationStack presence
                presentNextCourse = true
            }
        case .end:
            withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
        }
    }

    // Helper to get the next lesson id (robustly increments the lesson number in various formats)
    private func nextLessonId(from lid: String) -> String? {
        // Flexible patterns supported:
        // 1) "..._l3" or "..._l03" or "..._l3_done" → increment the digits right after "_l"
        // 2) fallback: any trailing digits at the end of the string ("lesson12")

        if let lRange = lid.range(of: "_l", options: .backwards) {
            let after = lid[lRange.upperBound...]
            let digitSlice = after.prefix { $0.isNumber }
            if let n = Int(digitSlice), !digitSlice.isEmpty {
                let width = digitSlice.count
                let incremented = String(format: "%0*d", width, n + 1)
                let rest = after.dropFirst(width)
                return String(lid[..<lRange.upperBound]) + incremented + rest
            }
            // if no digits right after _l, fall through to trailing-digits fallback
        }
        // Fallback: increment trailing number at the very end, preserving width
        let trailingDigits = lid.reversed().prefix { $0.isNumber }.reversed()
        if !trailingDigits.isEmpty, let n = Int(String(trailingDigits)) {
            let width = trailingDigits.count
            let base = lid.dropLast(width)
            let incremented = String(format: "%0*d", width, n + 1)
            return String(base) + incremented
        }
        return nil
    }

    private func guessLessonTitle(for lid: String) -> String? {
        switch lid {
        case "course_b_1_l1": return "ПРИВЕТСТВИЯ"
        case "course_b_1_l2": return "ЗНАКОМСТВО"
        case "course_b_1_l3": return "СЕМЬЯ И ОБРАЩЕНИЯ"
        case "course_b_1_l4": return "ВРЕМЯ И ЧИСЛА"
        default: return nil
        }
    }



    private struct StepFavBridge: Favoritable {
        let favoriteId: String
        let favoriteTitle: String
        let favoriteSubtitle: String
        let favoriteMeta: String
        let favoriteCourseId: String
        let favoriteLessonId: String
    }

    private func makeStepFav(for item: SDStepItem, index: Int) -> StepFavBridge {
        let courseId: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        let isHack = (item.kind == .tip)
        let origIndex = originalIndex(for: index)
        let fid = "\(isHack ? "hack" : "card"):step:\(courseId):\(resolvedLessonId):idx\(origIndex)"

        let favTitle: String
        let favSubtitle: String
        let favMeta: String

        if isHack {
            // use lifehack body as subtitle and meta
            let hackText = item.subtitleTH
            favTitle = item.titleRU.isEmpty ? "Лайфхак" : item.titleRU
            favSubtitle = hackText
            favMeta = "hack:" + hackText
        } else {
            favTitle = item.titleRU
            favSubtitle = item.subtitleTH
            favMeta = "card:" + item.phonetic
        }

        return StepFavBridge(
            favoriteId: fid,
            favoriteTitle: favTitle,
            favoriteSubtitle: favSubtitle,
            favoriteMeta: favMeta,
            favoriteCourseId: courseId,
            favoriteLessonId: resolvedLessonId
        )
    }
}




#if DEBUG
struct StepView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // каноничный экран урока через курс → lessons → steps (full)
            NavigationStack {
                StepView(
                    courseId: "course_b_1",
                    lessonId: "course_b_1_l1",
                    lessonTitle: "ПРИВЕТСТВИЯ",
                    scope: .full,
                    layoutCardsOnly: false,
                    allowLearning: true,
                    showBottomProgress: true
                )
            }
            .previewDisplayName("step · full (canonical)")

            // тот же урок, но в overlay-режиме, как когда тянем секцию из других экранов
            NavigationStack {
                ZStack {
                    taikaGlassBackground()
                    StepView(
                        courseId: "course_b_1",
                        lessonId: "course_b_1_l1",
                        lessonTitle: "ПРИВЕТСТВИЯ",
                        scope: .overlay,
                        layoutCardsOnly: true,
                        allowLearning: false,
                        showBottomProgress: false
                    )
                }
            }
            .previewDisplayName("step · overlay (cards section)")
        }
        .preferredColorScheme(.dark)
    }
}
#endif






// MARK: - LessonsView stepOverlay backdrop (Fav-style glossy overlay)
@ViewBuilder
func taikaGlassBackground() -> some View {
    BlurView(style: .systemUltraThinMaterialDark)
        .ignoresSafeArea()
        .zIndex(-1)
}

