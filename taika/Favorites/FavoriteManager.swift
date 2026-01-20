//
//  FavoriteManager.swift
//  taika
//
//  Created by product on 11.09.2025.
//



import Foundation
import Combine
import SwiftUI

extension Notification.Name {
    static let favoritesDidChange = Notification.Name("favoritesDidChange")
    // Back-compat alias: some views subscribe to .favoritesDidUpdate
    static let favoritesDidUpdate = Notification.Name("favoritesDidUpdate")
    // Alias for listeners using capitalized name
    static let FavoritesDidChange = Notification.Name("FavoritesDidChange")
}

// private global: isBootstrapping flag (do nothing, no global needed)

/// Any domain entity that can be added to favorites should conform to this
protocol Favoritable {
    /// globally unique id (e.g. "course:COURSE123" or "step:course.lesson.step")
    var favoriteId: String { get }
    /// main title (e.g. RU phrase or course title)
    var favoriteTitle: String { get }
    /// secondary text (e.g. TH phrase or short description)
    var favoriteSubtitle: String { get }
    /// meta/accent text (e.g. transliteration or stats); can be empty
    var favoriteMeta: String { get }
    /// context ids (keep empty if not applicable)
    var favoriteCourseId: String { get }
    var favoriteLessonId: String { get }
}

extension Favoritable {
    func asFavoriteItem() -> FavoriteItem {
        FavoriteItem(
            id: favoriteId,
            ru: favoriteTitle,
            th: favoriteSubtitle,
            phonetic: favoriteMeta,
            courseId: favoriteCourseId,
            lessonId: favoriteLessonId,
            lessonTitle: nil,
            createdAt: Date()
        )
    }
}

/// manager for user favorites (phrases/words added via StepView)
/// source of truth for FavoriteView and course stats
@MainActor
final class FavoriteManager: ObservableObject {
    static let shared = FavoriteManager()

#if DEBUG
    /// test hook: allow tests to override step index resolution
    static var stepIndexTestOverride: ((String, String, String) -> Int?)?
#endif

    @Published private(set) var items: [FavoriteItem] = []
    /// Fast path for course-like state (so AllCourses UI can bind without scanning array)

    // fast snapshots for UI (non-source-of-truth; derived from `items`)
    @Published private(set) var cards: [FavoriteItem] = []
    @Published private(set) var likedStepIds: Set<String> = []
    @Published private(set) var likedCourses: Set<String> = []

    // DS projection: map stored favorites-cards to view DTOs
    public var cardsDTO: [FDCardDTO] {
        cards.map { it in
            FDCardDTO(
                sourceId: it.id,
                title: it.ru,
                subtitle: it.th,
                meta: it.phonetic,
                lessonTitle: it.lessonTitle ?? "",
                tagText: "",
                addedAt: it.createdAt
            )
        }
    }

    // DS projection: map stored favorites-courses to view DTOs
    public var coursesDTO: [FDCourseDTO] {
        items
            .filter { normalized($0.id).hasPrefix("course:") }
            .sorted { a, b in a.createdAt > b.createdAt }
            .map { it in
                FDCourseDTO(
                    courseId: normalized(it.courseId),
                    title: it.ru,
                    subtitle: it.th,
                    addedAt: it.createdAt
                )
            }
    }

    public var hacksDTO: [FDHackDTO] {
        items
            .filter { it in
                let fid = normalized(it.id)
                return fid.hasPrefix("hack:")
            }
            .sorted { a, b in a.createdAt > b.createdAt }
            .map { it in
                FDHackDTO(
                    sourceId: normalized(it.id),
                    title: it.ru,
                    meta: it.phonetic,
                    lessonTitle: it.lessonTitle ?? "",
                    addedAt: it.createdAt
                )
            }
    }

    @inline(__always)
    private func isCardItem(_ it: FavoriteItem) -> Bool {
        let fid = normalized(it.id)
        if fid.hasPrefix("course:") { return false }
        if fid.hasPrefix("hack:") || it.phonetic.lowercased().hasPrefix("hack:") { return false }
        return fid.hasPrefix("card:") || fid.hasPrefix("step:")
    }

    /// recompute lightweight caches derived from `items`
    private func recomputeCaches() {
        self.cards = self.items
            .filter { isCardItem($0) }
            .sorted { a, b in
                if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
                return a.id > b.id
            }
        var acc: Set<String> = []
        acc.reserveCapacity(items.count)
        for it in items {
            let fid = normalized(it.id)
            if fid.hasPrefix("course:") { continue }
            if fid.hasPrefix("hack:") {
                acc.insert(fid)
            } else if fid.hasPrefix("card:") || fid.hasPrefix("step:") {
                var key = fid
                if key.hasPrefix("card:") { key.removeFirst("card:".count) }
                if !key.hasPrefix("step:") { key = "step:" + key }
                acc.insert(key)
            }
        }
        self.likedStepIds = acc
    }

    // 1️⃣: Recompute likedCourses from items
    private func recomputeLikedCourses() {
        self.likedCourses = Set(
            items
                .map { normalized($0.id) }
                .filter { $0.hasPrefix("course:") }
        )
    }

    // 2️⃣: Public helper to check if a course is liked
    public func isCourseLiked(_ courseId: String) -> Bool {
        likedCourses.contains("course:" + normalized(courseId))
    }

    private let storeKey = "taika.favorites.v1"
    private let orderKey = "taika.favorites.order.v1"

    private var isBootstrapping = false

    // Run once after load to rewrite legacy ids to canonical form
    private func migrateLegacyIdsIfNeeded() {
        var changed = false
        var rewritten: [FavoriteItem] = []
        rewritten.reserveCapacity(items.count)
        for it in items {
            // base normalization of the raw id
            var nid = normalized(it.id)
            // preserve hack namespace if present in id or phonetic
            let wasHack = nid.hasPrefix("hack:") || it.phonetic.hasPrefix("hack:")
            // if id has no separators at all, treat it as a bare course id and prefix with course:
            if !nid.contains(".") && !nid.contains(":") {
                nid = "course:" + nid
            }

            var course = normalized(it.courseId)
            var lesson = normalized(it.lessonId)
            var title = it.lessonTitle ?? ""

            // try to infer course/lesson from id when they are missing
            func inferFromNamespaced(_ namespaced: String) {
                var body = namespaced
                if body.hasPrefix("step:") { body.removeFirst("step:".count) }
                if body.hasPrefix("hack:") { body.removeFirst("hack:".count) }
                let parts = body.split(separator: ".").map { String($0) }
                if parts.count >= 2 {
                    if course.isEmpty { course = normalized(parts[0]) }
                    if lesson.isEmpty { lesson = normalized(parts[1]) }
                }
            }
            inferFromNamespaced(nid)

            // canonicalize legacy step ids: step:course.lesson.stepSlug  ->  step:courseId:lessonId:idxN
            if nid.hasPrefix("step:") && nid.contains(".") && !nid.contains(":idx") {
                let body = String(nid.dropFirst("step:".count))
                // ensure we have course/lesson extracted
                if course.isEmpty || lesson.isEmpty {
                    let parts = body.split(separator: ".").map { String($0) }
                    if parts.count >= 2 {
                        if course.isEmpty { course = normalized(parts[0]) }
                        if lesson.isEmpty { lesson = normalized(parts[1]) }
                    }
                }
                let idxVal = stepIndex(courseId: course, lessonId: lesson, composedId: body) ?? 0
                nid = wasHack
                    ? canonicalHackFavoriteId(courseId: course, lessonId: lesson, index: idxVal)
                    : canonicalStepFavoriteId(courseId: course, lessonId: lesson, index: idxVal)
            }

            // canonicalize legacy hack ids without step namespace: hack:course.lesson.stepSlug -> hack:step:courseId:lessonId:idxN
            if wasHack && nid.hasPrefix("hack:") && nid.contains(".") && !nid.contains(":idx") {
                let body = String(nid.dropFirst("hack:".count))
                if course.isEmpty || lesson.isEmpty {
                    let parts = body.split(separator: ".").map { String($0) }
                    if parts.count >= 2 {
                        if course.isEmpty { course = normalized(parts[0]) }
                        if lesson.isEmpty { lesson = normalized(parts[1]) }
                    }
                }
                let idxVal = stepIndex(courseId: course, lessonId: lesson, composedId: body) ?? 0
                nid = canonicalHackFavoriteId(courseId: course, lessonId: lesson, index: idxVal)
            }

            // fill missing title from lessonId
            if title.isEmpty && !lesson.isEmpty { title = resolveLessonTitle(courseId: course, lessonId: lesson) }

            // ensure normalized ids
            course = normalized(course)
            lesson = normalized(lesson)

            // ensure hack items always have body in th and prefixed phonetic
            var ru = it.ru
            var th = it.th
            var phon = it.phonetic
            if wasHack {
                let metaBody = phon.hasPrefix("hack:") ? String(phon.dropFirst("hack:".count)).trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let thTrim = th.trimmingCharacters(in: .whitespacesAndNewlines)
                let ruTrim = ru.trimmingCharacters(in: .whitespacesAndNewlines)
                // choose a visible body for hack: prefer th, then meta, then ru
                let body = !thTrim.isEmpty ? thTrim : (!metaBody.isEmpty ? metaBody : ruTrim)
                th = body
                if body.isEmpty {
                    // last resort
                    th = ruTrim.isEmpty ? "Лайфхак" : ruTrim
                }
                // enforce phonetic as "hack:<body>"
                phon = "hack:" + th
                // ensure title is not empty
                if ruTrim.isEmpty { ru = "Лайфхак" }
            }

            // rebuild a fixed FavoriteItem with normalized fields
            let fixed = FavoriteItem(
                id: nid,
                ru: ru,
                th: th,
                phonetic: phon,
                courseId: course,
                lessonId: lesson,
                lessonTitle: title.isEmpty ? nil : title,
                createdAt: it.createdAt
            )

            if fixed != it { changed = true }
            rewritten.append(fixed)
        }
        if changed {
            // coalesce duplicates that may appear after rewrite
            var latest: [String: FavoriteItem] = [:]
            for it in rewritten {
                // hacks: key by normalized full id; cards: key by compareKey(step-equivalent)
                let isHack = self.isHackItem(it)
                let key = isHack ? self.normalized(it.id) : self.compareKey(it.id)
                if let cur = latest[key] {
                    latest[key] = (it.createdAt >= cur.createdAt) ? it : cur
                } else {
                    latest[key] = it
                }
            }
            items = Array(latest.values).sorted { $0.createdAt > $1.createdAt }
            recomputeCaches()
            // 4️⃣: Refresh likedCourses after migration
            recomputeLikedCourses()
            save()
            if isBootstrapping {
                // Defer sync during bootstrap to avoid re-entrant FavoriteManager.shared access from UserSession.init
                DispatchQueue.main.async { [weak self] in
                    self?.syncToUserSession()
                    self?.emit()
                }
            } else {
                syncToUserSession()
                emit()
            }
        }
    }
    private var cancellables = Set<AnyCancellable>()
    // Snapshot of last sync counts to avoid duplicate sync logs
    private var lastSyncCounts: (courses: Int, cards: Int, hacks: Int)?
    // Cache for dsSteps per course/lesson to avoid rebuilding StepManager repeatedly
    private var stepCache: [String: [SDStepItem]] = [:]
    private var didPreloadSteps = false
    private let stepManager = StepManager.shared

@inline(__always) nonisolated private func stepKey(_ c: String, _ l: String) -> String {
    return "\(normalized(c))|\(normalized(l))"
}

    @inline(__always)
    private func steps(courseId: String, lessonId: String) -> [SDStepItem] {
        let key = stepKey(courseId, lessonId)
        if let cached = stepCache[key] { return cached }
        if !didPreloadSteps {
            StepData.shared.preload()
            didPreloadSteps = true
        }
        let list = stepManager.dsSteps(courseId: courseId, lessonId: normalized(lessonId))
        stepCache[key] = list
        return list
    }

    @inline(__always)
    private func postChangeNotification() {
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil, userInfo: [
            "total": self.items.count
        ])
        NotificationCenter.default.post(name: .FavoritesDidChange, object: nil, userInfo: [
            "total": self.items.count
        ])
        NotificationCenter.default.post(name: .favoritesDidUpdate, object: nil, userInfo: [
            "total": self.items.count
        ])
    }

    // Re-emit items on the next runloop tick so views see resolved titles immediately
    private var pendingEmit = false
    private func emit() {
        guard !pendingEmit else { return }
        pendingEmit = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pendingEmit = false
            self.postChangeNotification()
        }
    }

    // Manual ping from views if needed
    public func reload() {
        emit()
    }

    /// Force-run migration + persist + resync (for one-off fixes from UI)
    public func migrateNow() {
        migrateLegacyIdsIfNeeded()
        syncToUserSession()
        save()
        emit()
    }

    private func syncToUserSession() {
        // Project the IDs into semantic buckets understood by UserSession
        var courses: Set<String> = []
        var cards: Set<String> = []
        var hacks: Set<String> = []
        for it in items {
            let fid = normalized(it.id)
            let phon = it.phonetic.lowercased()
            let isHack = fid.hasPrefix("hack:") || phon.hasPrefix("hack:")

            if fid.hasPrefix("course:") {
                courses.insert(fid)
                continue
            }

            if isHack {
                // normalize hack id to ensure stable lookup keys
                var hid = fid
                if !hid.hasPrefix("hack:") {
                    if hid.hasPrefix("card:") { hid.removeFirst("card:".count) }
                    // ensure we have step: prefix for core
                    if !hid.hasPrefix("step:") { hid = "step:" + hid }
                    hid = "hack:" + hid
                }
                hacks.insert(normalized(hid))
                continue
            }

            if fid.hasPrefix("card:") || fid.hasPrefix("step:") {
                cards.insert(fid)
            }
        }
        let counts = (courses: courses.count, cards: cards.count, hacks: hacks.count)
#if DEBUG
        if lastSyncCounts == nil || lastSyncCounts! != counts {
            print("[FM.sync] courses=\(counts.courses) cards=\(counts.cards) hacks=\(counts.hacks)")
        }
#endif
        lastSyncCounts = counts
        // 5️⃣: Sync likedCourses from courses set
        likedCourses = courses
        UserSession.shared.setFavorites(course: courses, cards: cards, hacks: hacks)
    }

    /// Normalize incoming favorite ids to a single canonical form
    nonisolated private func normalized(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        var s = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "::", with: ":")
            .replacingOccurrences(of: "..", with: ".")
        // handle accidental "course:step:" by dropping the extra "course:" prefix, but KEEP "step:" namespace
        if s.hasPrefix("course:step:") { s.removeFirst("course:".count) } // now "step:…"
        // do NOT strip "step:" — we need the namespace for routing
        // collapse again in case edits introduced duplicates
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }
        // trim stray separators
        while s.hasPrefix(":") { s.removeFirst() }
        while s.hasSuffix(":") { s.removeLast() }
        while s.hasPrefix(".") { s.removeFirst() }
        while s.hasSuffix(".") { s.removeLast() }
        return s
    }

    private func resolveLessonTitle(courseId: String, lessonId: String) -> String {
        let c = normalized(courseId)
        let l = normalized(lessonId)
        let title = LessonsManager.shared.titleForLesson(courseId: c, lessonId: l)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if l.isEmpty { return "" }
        return l.replacingOccurrences(of: "_", with: " ")
    }

    /// Try to find step index in a lesson by matching the trailing step token in composed id
    private func stepIndex(courseId: String, lessonId: String, composedId: String) -> Int? {
#if DEBUG
        if let hook = FavoriteManager.stepIndexTestOverride {
            if let forced = hook(courseId, normalized(lessonId), composedId) {
                print("[FM.stepIndex][TEST] course=\(courseId) lesson=\(normalized(lessonId)) composed=\(composedId) -> idx=\(forced)")
                return forced
            }
        }
#endif
        let normLesson = normalized(lessonId)
        let items = steps(courseId: courseId, lessonId: normLesson)
        // composedId usually looks like "course.lesson.stepSlug"; extract slug
        let slug = composedId.split(separator: ".").map(String.init).last ?? composedId
#if DEBUG
        print("[FM.stepIndex] course=\(courseId) lesson=\(normLesson) slug=\(slug) items=\(items.count)")
#endif
        for (i, it) in items.enumerated() {
            let rid = String(describing: it.id)
            if rid.hasSuffix("." + slug) || rid == slug {
#if DEBUG
                print("[FM.stepIndex] matched idx=\(i) by rid=\(rid)")
#endif
                return i
            }
        }
#if DEBUG
        print("[FM.stepIndex] NO MATCH — fallback=nil")
#endif
        return nil
    }

    /// Build canonical favorite id for a step: step:courseId:lessonId:idxN
    private func canonicalStepFavoriteId(courseId: String, lessonId: String, index: Int) -> String {
        let c = normalized(courseId)
        let l = normalized(lessonId)
        return "step:\(c):\(l):idx\(index)"
    }

    /// Build canonical favorite id for a hack step: hack:step:courseId:lessonId:idxN
    private func canonicalHackFavoriteId(courseId: String, lessonId: String, index: Int) -> String {
        return "hack:" + canonicalStepFavoriteId(courseId: courseId, lessonId: lessonId, index: index)
    }

    /// Build bare canonical step-id without card/hack prefix: step:courseId:lessonId:idxN
    @inline(__always)
    func idForStep(courseId: String, lessonId: String, index: Int) -> String {
        "step:\(normalized(courseId)):\(normalized(lessonId)):idx\(index)"
    }

    /// canonical favorite id for a hack (tip) step
    func idForHack(courseId: String, lessonId: String, index: Int) -> String {
        return "hack:step:\(normalized(courseId)):\(normalized(lessonId)):idx\(index)"
    }

    /// Resolve a canonical bare step-id for a UI step, using optional explicit order
    /// Returns nil if index cannot be resolved safely
    func idForStep(step: SDStepItem, courseId: String?, lessonId: String?, order: Int?) -> String? {
        var c = courseId ?? ""
        var l = lessonId ?? ""
        if (c.isEmpty || l.isEmpty), let parsed = parseCourseLesson(from: step.id) {
            if c.isEmpty { c = parsed.course }
            if l.isEmpty { l = parsed.lesson }
        }
        c = normalized(c)
        l = normalized(l)
        let base = makeId(step: step, courseId: c, lessonId: l)
        let idx = (order != nil) ? order! : stepIndex(courseId: c, lessonId: l, composedId: base)
        guard let i = idx else { return nil }
        return idForStep(courseId: c, lessonId: l, index: i)
    }

    /// Fast membership check using likedStepIds set
    @inline(__always)
    func contains(stepId: String) -> Bool {
        var key = normalized(stepId)
        if key.hasPrefix("card:") { key.removeFirst("card:".count) }
        if !key.hasPrefix("step:") { key = "step:" + key }
        return likedStepIds.contains(key)
    }

    /// Convenience: membership for concrete SDStepItem
    func contains(step: SDStepItem, courseId: String?, lessonId: String?, order: Int?) -> Bool {
        guard let sid = idForStep(step: step, courseId: courseId, lessonId: lessonId, order: order) else { return false }
        return likedStepIds.contains(sid)
    }

    /// Canonicalize any incoming favorite id to unified form
    ///  - non-hack steps  ->  "card:step:<courseId>:<lessonId>:idx<N>"
    ///  - hack steps      ->  "hack:step:<courseId>:<lessonId>:idx<N>"
    ///  - courses         ->  "course:<courseId>"
    private func canonicalize(_ rawId: String, courseId: String? = nil, lessonId: String? = nil, isHack: Bool? = nil) -> String {
        var s = normalized(rawId)
        // bare token — treat as course
        if !s.contains(":") && !s.contains(".") { return "course:" + s }
        if s.hasPrefix("course:") { return s }

        let hack = isHack ?? s.hasPrefix("hack:")
        if s.hasPrefix("hack:") { s.removeFirst("hack:".count) }
        if s.hasPrefix("card:") { s.removeFirst("card:".count) }
        if s.hasPrefix("step:") { s.removeFirst("step:".count) }

        let hasIdx = s.contains(":idx")
        let compsDot = s.split(separator: ".").map(String.init)

        let course = normalized(courseId ?? compsDot.first ?? "")
        let lesson = normalized(lessonId ?? (compsDot.count >= 2 ? compsDot[1] : ""))

        var idxVal = 0
        if hasIdx, let last = s.split(separator: ":").last, last.hasPrefix("idx"), let n = Int(last.dropFirst(3)) {
            idxVal = n
        } else {
            let composed = compsDot.joined(separator: ".")
            idxVal = stepIndex(courseId: course, lessonId: lesson, composedId: composed) ?? 0
        }

        let core = "step:\(course):\(lesson):idx\(idxVal)"
        return (hack ? "hack:" : "card:") + core
    }

    /// Normalize for comparisons: treat legacy `step:` and new `card:step:` as equivalent for cards
    private func compareKey(_ fid: String) -> String {
        var s = normalized(fid)
        if s.hasPrefix("card:") { s.removeFirst("card:".count) }
        return s
    }

    @inline(__always)
    private func isHackItem(_ it: FavoriteItem) -> Bool {
        let fid = normalized(it.id)
        if fid.hasPrefix("hack:") { return true }
        return it.phonetic.lowercased().hasPrefix("hack:")
    }

    private init() {
        isBootstrapping = true
        load()
        migrateLegacyIdsIfNeeded()
        // Defer cross-singleton wiring to the next runloop tick to avoid re-entrant access crash
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.syncToUserSession()
        }
        // autosave on every change (with debounce + distinct)
        $items
            .map { $0.map { $0.id } } // observe ids order/content only
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard !self.isBootstrapping else { return }
                self.recomputeCaches()
                self.recomputeLikedCourses()
                self.save()
                self.syncToUserSession()
                self.emit()
            }
            .store(in: &cancellables)
        isBootstrapping = false
        // Prewarm step indexes for current favorites to avoid UI hitches on first open
        Task.detached { [weak self] in
            guard let self else { return }
            // Snapshot items on main
            let snapshot: [FavoriteItem] = await MainActor.run { self.items }
            var pairs = Set<String>()
            pairs.reserveCapacity(snapshot.count)
            for it in snapshot {
                var c = self.normalized(it.courseId)
                var l = self.normalized(it.lessonId)
                if (c.isEmpty || l.isEmpty), let parsed = self.parseCourseLesson(from: it.id) {
                    if c.isEmpty { c = self.normalized(parsed.course) }
                    if l.isEmpty { l = self.normalized(parsed.lesson) }
                }
                if !c.isEmpty, !l.isEmpty {
                    pairs.insert(self.stepKey(c, l))
                }
            }
            if !pairs.isEmpty {
                // Preload is main-actor/async in our project — call it on MainActor
                await MainActor.run { StepData.shared.preload() }
                // Mark preloaded on main
                await MainActor.run { self.didPreloadSteps = true }
            }
            // Touch caches off the main thread
            for key in pairs {
                let comps = key.split(separator: "|")
                guard comps.count == 2 else { continue }
                await MainActor.run { _ = self.steps(courseId: String(comps[0]), lessonId: String(comps[1])) }
            }
        }
    }

    // MARK: - Public API

    // speaker integration
    // returns canonical step ids only (no courses, no hacks), in the form: step:courseId:lessonId:idxN
    // order: newest-first (based on stored favorites order)
    public func speakerStepIds() -> [String] {
        var out: [String] = []
        out.reserveCapacity(min(64, items.count))
        var seen = Set<String>()
        seen.reserveCapacity(min(128, items.count))

        // `items` is kept newest-first; preserve that ordering for speaker queue
        for it in items {
            let fid = normalized(it.id)
            let phon = it.phonetic.lowercased()

            // exclude courses
            if fid.hasPrefix("course:") { continue }

            // exclude hacks
            let isHack = fid.hasPrefix("hack:") || phon.hasPrefix("hack:")
            if isHack { continue }

            // accept step/card favorites only
            if !(fid.hasPrefix("step:") || fid.hasPrefix("card:")) { continue }

            var key = fid
            if key.hasPrefix("card:") { key.removeFirst("card:".count) }
            if !key.hasPrefix("step:") { key = "step:" + key }
            key = normalized(key)

            if seen.insert(key).inserted {
                out.append(key)
            }
        }

        return out
    }

    // returns canonical hack step ids only, in the form: hack:step:courseId:lessonId:idxN
    // order: newest-first
    public func speakerHackStepIds() -> [String] {
        var out: [String] = []
        out.reserveCapacity(min(32, items.count))
        var seen = Set<String>()
        seen.reserveCapacity(min(64, items.count))

        for it in items {
            let fid = normalized(it.id)
            let phon = it.phonetic.lowercased()

            let isHack = fid.hasPrefix("hack:") || phon.hasPrefix("hack:")
            if !isHack { continue }

            var key = fid
            if !key.hasPrefix("hack:") {
                // promote to hack namespace if legacy storage missed the prefix
                if key.hasPrefix("card:") { key.removeFirst("card:".count) }
                if !key.hasPrefix("step:") { key = "step:" + key }
                key = "hack:" + key
            }
            key = normalized(key)

            if seen.insert(key).inserted {
                out.append(key)
            }
        }

        return out
    }

    /// Remove all favorites belonging to a specific course and sync session
    func clearForCourse(_ courseId: String) {
        let key = normalized(courseId)
        DispatchQueue.main.async {
            withAnimation {
                self.items.removeAll { it in
                    let nid = self.normalized(it.id)
                    // match by stored courseId, or by canonical id prefix (course.lesson.step), or legacy namespaced ids
                    return it.courseId == key || nid.hasPrefix("\(key).") || nid == "course:\(key)" || nid == key
                }
            }
            // 8️⃣: Refresh likedCourses after removals
            self.recomputeLikedCourses()
            self.syncToUserSession()
            self.save()
            self.emit()
        }
    }

    /// Remove all favorites of any type and sync session
    func clearAll() {
        guard !items.isEmpty else { return }
        DispatchQueue.main.async {
            withAnimation { self.items.removeAll() }
            // 8️⃣: Refresh likedCourses after removals
            self.recomputeLikedCourses()
            self.syncToUserSession()
            self.save()
            self.emit()
        }
    }

    /// Hard reset: clear all favorites in memory and storage, resync session, and notify observers
    func resetAll() {
        DispatchQueue.main.async {
            withAnimation { self.items.removeAll() }
            self.recomputeLikedCourses()
            self.syncToUserSession()
            // remove persisted storage keys entirely
            UserDefaults.standard.removeObject(forKey: self.storeKey)
            UserDefaults.standard.removeObject(forKey: self.orderKey)
            self.save() // persist empty state for consistency
            self.emit() // posts favoritesDidChange/FavoritesDidChange
        }
    }

    /// Toggle a generic favoritable entity
    func toggle(item: Favoritable) {
        // Base normalization of incoming id
        let rawId = normalized(item.favoriteId)

        let isHackFavoritable = rawId.hasPrefix("hack:") || item.favoriteMeta.lowercased().hasPrefix("hack:")

        if isHackFavoritable {
            // Canonicalize any incoming hack id to hack:step:<courseId>:<lessonId>:idxN
            var body = rawId
            if body.hasPrefix("hack:") { body.removeFirst("hack:".count) }
            if body.hasPrefix("card:") { body.removeFirst("card:".count) }
            if body.hasPrefix("step:") { body.removeFirst("step:".count) }

            // Try to derive course/lesson from Favoritable context first, else from id
            var course = normalized(item.favoriteCourseId)
            var lesson = normalized(item.favoriteLessonId)
            let dot = body.split(separator: ".").map(String.init)
            if course.isEmpty, let c = dot.first { course = normalized(c) }
            if lesson.isEmpty, dot.count >= 2, let l = dot.dropFirst().first { lesson = normalized(l) }

            // Resolve index by matching trailing slug
            let idx = stepIndex(courseId: course, lessonId: lesson, composedId: body) ?? 0
            let fid = canonicalHackFavoriteId(courseId: course, lessonId: lesson, index: idx)
#if DEBUG
            print("[FM.toggle(item)] (hack) in=\(rawId) -> fid=\(fid)")
#endif
            if let i = items.firstIndex(where: { normalized($0.id) == fid }) {
                DispatchQueue.main.async {
                    _ = withAnimation { self.items.remove(at: i) }
                    self.sortNewestFirst()
                    // 6️⃣: Refresh likedCourses after mutation
                    self.recomputeLikedCourses()
                    self.syncToUserSession()
                    self.save()
                    self.emit()
                }
            } else {
                let body = item.favoriteSubtitle.isEmpty ? item.favoriteTitle : item.favoriteSubtitle
                let stored = FavoriteItem(
                    id: fid,
                    ru: "Лайфхак",
                    th: body,
                    phonetic: "hack:" + body,
                    courseId: course,
                    lessonId: lesson,
                    lessonTitle: resolveLessonTitle(courseId: course, lessonId: lesson),
                    createdAt: Date()
                )
                DispatchQueue.main.async {
                    withAnimation { self.items.insert(stored, at: 0) }
                    self.sortNewestFirst()
                    // 6️⃣: Refresh likedCourses after mutation
                    self.recomputeLikedCourses()
                    self.syncToUserSession()
                    self.save()
                    self.emit()
                }
            }
            return
        }

        // If this is a step-like id but not in canonical idx form, try to canonicalize using provided context
        func canonicalizeStepIfPossible(_ fid: String) -> String {
            let fid = fid            // Allow forms like: step:course.lesson.stepSlug  OR  course.lesson.stepSlug
            let isStepNamespaced = fid.hasPrefix("step:")
            var body = fid
            if isStepNamespaced { body.removeFirst("step:".count) }

            // If it already looks canonical (contains ":" and has idxN) — keep as-is
            if fid.contains(":idx") { return fid }

            let comps = body.split(separator: ".").map(String.init)
            // Need at least course.lesson.step
            guard comps.count >= 3 else { return fid }

            // Prefer explicit context from Favoritable fields when present
            var course = normalized(item.favoriteCourseId)
            var lesson = normalized(item.favoriteLessonId)
            if course.isEmpty { course = normalized(comps[0]) }
            if lesson.isEmpty { lesson = normalized(comps[1]) }

            // Resolve index in the lesson
            let composed = comps.joined(separator: ".")
            let idx = stepIndex(courseId: course, lessonId: lesson, composedId: composed) ?? 0
            return canonicalStepFavoriteId(courseId: course, lessonId: lesson, index: idx)
        }

        let fid: String = {
            if rawId.hasPrefix("step:") || rawId.contains(".") { return canonicalizeStepIfPossible(rawId) }
            // Courses and hacks keep their namespaces (add default course: for bare ids)
            if !rawId.contains(":") { return "course:" + rawId }
            return rawId
        }()

#if DEBUG
        print("[FM.toggle(item)] in=\(rawId) -> fid=\(fid) course=\(item.favoriteCourseId) lesson=\(item.favoriteLessonId)")
#endif

        // Toggle by canonical id
        if let idx = items.firstIndex(where: { normalized($0.id) == fid }) {
            DispatchQueue.main.async {
                _ = withAnimation { self.items.remove(at: idx) }
                self.sortNewestFirst()
                // 6️⃣: Refresh likedCourses after mutation
                self.recomputeLikedCourses()
                self.syncToUserSession()
                self.save()
                self.emit()
            }
        } else {
            DispatchQueue.main.async {
                withAnimation {
                    self.items.removeAll { self.normalized($0.id) == fid }
                    // Build stored item
                    let title = self.resolveLessonTitle(courseId: item.favoriteCourseId, lessonId: item.favoriteLessonId)
                    let stored = FavoriteItem(
                        id: fid,
                        ru: item.favoriteTitle,
                        th: item.favoriteSubtitle,
                        phonetic: item.favoriteMeta,
                        courseId: self.normalized(item.favoriteCourseId),
                        lessonId: self.normalized(item.favoriteLessonId),
                        lessonTitle: title.isEmpty ? nil : title,
                        createdAt: Date()
                    )
                    self.items.insert(stored, at: 0)
                }
                self.sortNewestFirst()
                // 6️⃣: Refresh likedCourses after mutation
                self.recomputeLikedCourses()
                self.syncToUserSession()
                self.save()
                self.emit()
            }
        }
    }

    /// Check if a favoritable is already liked
    func isLiked(item: Favoritable) -> Bool {
        // Base normalization of incoming id
        let rawId = normalized(item.favoriteId)

        // Hacks: canonicalize to hack:step:course:lesson:idxN
        let isHackFav = rawId.hasPrefix("hack:") || item.favoriteMeta.lowercased().hasPrefix("hack:")
        if isHackFav {
            var body = rawId
            if body.hasPrefix("hack:") { body.removeFirst("hack:".count) }
            if body.hasPrefix("card:") { body.removeFirst("card:".count) }
            if body.hasPrefix("step:") { body.removeFirst("step:".count) }
            var course = normalized(item.favoriteCourseId)
            var lesson = normalized(item.favoriteLessonId)
            let dot = body.split(separator: ".").map(String.init)
            if course.isEmpty, let c = dot.first { course = normalized(c) }
            if lesson.isEmpty, dot.count >= 2, let l = dot.dropFirst().first { lesson = normalized(l) }
            let idx = stepIndex(courseId: course, lessonId: lesson, composedId: body) ?? 0
            let fid = canonicalHackFavoriteId(courseId: course, lessonId: lesson, index: idx)
            return items.contains { normalized($0.id) == normalized(fid) }
        }

        // Steps may arrive in different shapes; canonicalize to step:courseId:lessonId:idxN
        func canonicalizeStepIfPossible(_ fid: String) -> String {
            let fid = fid
            let isStepNamespaced = fid.hasPrefix("step:")
            var body = fid
            if isStepNamespaced { body.removeFirst("step:".count) }

            // Already canonical form
            if fid.contains(":idx") { return fid }

            // Resolve context course/lesson
            let comps = body.split(separator: ".").map(String.init)
            guard comps.count >= 3 else { return fid } // not enough info

            var course = normalized(item.favoriteCourseId)
            var lesson = normalized(item.favoriteLessonId)
            if course.isEmpty { course = normalized(comps[0]) }
            if lesson.isEmpty { lesson = normalized(comps[1]) }

            let composed = comps.joined(separator: ".")
            let idx = stepIndex(courseId: course, lessonId: lesson, composedId: composed) ?? 0
            return canonicalStepFavoriteId(courseId: course, lessonId: lesson, index: idx)
        }

        let fid: String = {
            if rawId.hasPrefix("step:") || rawId.contains(".") {
                return canonicalizeStepIfPossible(rawId)
            }
            // Courses and other entities keep their namespace (add "course:" if bare)
            if !rawId.contains(":") { return "course:" + rawId }
            return rawId
        }()

        return items.contains { normalized($0.id) == normalized(fid) }
    }

    /// Try to extract courseId and lessonId from a composite step id like "course.lesson.step"
    nonisolated private func parseCourseLesson(from rawStepId: Any) -> (course: String, lesson: String)? {
        var sid = String(describing: rawStepId)
        // normalize + strip namespaces we use across favorites
        sid = normalized(sid)
        if sid.hasPrefix("hack:") { sid.removeFirst("hack:".count) }
        if sid.hasPrefix("card:") { sid.removeFirst("card:".count) }
        if sid.hasPrefix("step:") { sid.removeFirst("step:".count) }

        // canonical ids: "courseId:lessonId:idxN" (optionally with extra segments)
        if sid.contains(":") {
            let parts = sid.split(separator: ":").map { String($0) }
            guard parts.count >= 2 else { return nil }
            let course = normalized(parts[0])
            let lesson = normalized(parts[1])
            guard !course.isEmpty, !lesson.isEmpty else { return nil }
            return (course: course, lesson: lesson)
        }

        // legacy ids: "course.lesson.step[.extra]"
        let parts = sid.split(separator: ".").map { String($0) }
        guard parts.count >= 2 else { return nil }
        return (course: normalized(parts[0]), lesson: normalized(parts[1]))
    }

    func toggle(step: SDStepItem, courseId: String?, lessonId: String?, order: Int?) {
        // fast-path: if step.id is already canonical (course:lesson:idxN), extract context directly
        func extractCanonicalContext(from raw: Any) -> (course: String, lesson: String, idx: Int)? {
            var s = String(describing: raw)
            s = normalized(s)
            if s.hasPrefix("hack:") { s.removeFirst("hack:".count) }
            if s.hasPrefix("card:") { s.removeFirst("card:".count) }
            if s.hasPrefix("step:") { s.removeFirst("step:".count) }
            // canonical: courseId:lessonId:idxN
            guard s.contains(":") else { return nil }
            let parts = s.split(separator: ":").map { String($0) }
            guard parts.count >= 3 else { return nil }
            let course = normalized(parts[0])
            let lesson = normalized(parts[1])
            guard !course.isEmpty, !lesson.isEmpty else { return nil }
            if let idxPart = parts.first(where: { $0.hasPrefix("idx") }),
               let n = Int(idxPart.dropFirst(3)) {
                return (course: course, lesson: lesson, idx: n)
            }
            return nil
        }

        // derive missing context from inputs / step.id
        var cId = courseId ?? ""
        var lId = lessonId ?? ""

        let canon = extractCanonicalContext(from: step.id)
        if cId.isEmpty { cId = canon?.course ?? "" }
        if lId.isEmpty { lId = canon?.lesson ?? "" }

        if (cId.isEmpty || lId.isEmpty), let parsed = parseCourseLesson(from: step.id) {
            if cId.isEmpty { cId = parsed.course }
            if lId.isEmpty { lId = parsed.lesson }
        }

        cId = normalized(cId)
        lId = normalized(lId)

        let baseId = makeId(step: step, courseId: cId, lessonId: lId)
        let isHack = (step.kind == .tip)

        // prefer explicit order; else try canonical idx; else resolve via StepData.
        // if we still can't resolve, skip toggling to avoid mapping everything to idx0.
        let resolvedIdx: Int? = {
            if let ord = order { return ord }
            if let n = canon?.idx { return n }
            return stepIndex(courseId: cId, lessonId: lId, composedId: baseId)
        }()

        guard let idx = resolvedIdx else {
#if DEBUG
            print("[FM.toggle(step)] skip: can't resolve index for baseId=\(baseId) course=\(cId) lesson=\(lId) isHack=\(isHack)")
#endif
            return
        }

        let favId: String = isHack
            ? canonicalHackFavoriteId(courseId: cId, lessonId: lId, index: idx)
            : canonicalStepFavoriteId(courseId: cId, lessonId: lId, index: idx)

#if DEBUG
        print("[FM.toggle(step)] baseId=\(baseId) isHack=\(isHack) -> favId=\(favId)")
#endif

        if let existingIndex = items.firstIndex(where: { normalized($0.id) == favId }) {
            DispatchQueue.main.async {
                withAnimation { self.items.remove(at: existingIndex) }
                self.sortNewestFirst()
                self.recomputeLikedCourses()
                self.syncToUserSession()
                self.save()
                self.emit()
            }
        } else {
            DispatchQueue.main.async {
                withAnimation {
                    // remove duplicates by normalized id before inserting
                    if isHack {
                        self.items.removeAll { self.normalized($0.id) == self.normalized(favId) }
                    } else {
                        // for cards, treat legacy `step:` and `card:step:` as the same
                        let key = self.compareKey(favId)
                        self.items.removeAll { self.compareKey($0.id) == key }
                    }

                    let lessonTitle = self.resolveLessonTitle(courseId: cId, lessonId: lId)

                    if isHack {
                        let body = step.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)
                        let ruValue = "Лайфхак"
                        let thValue = body.isEmpty ? (step.titleRU.isEmpty ? step.phonetic : step.titleRU) : body
                        let phoneticValue = "hack:" + thValue
                        let it = FavoriteItem(
                            id: favId,
                            ru: ruValue,
                            th: thValue,
                            phonetic: phoneticValue,
                            courseId: self.normalized(cId),
                            lessonId: self.normalized(lId),
                            lessonTitle: lessonTitle.isEmpty ? nil : lessonTitle,
                            createdAt: Date()
                        )
                        self.items.insert(it, at: 0)
                    } else {
                        let it = FavoriteItem(
                            id: favId,
                            ru: step.titleRU,
                            th: step.subtitleTH,
                            phonetic: "card:" + step.phonetic,
                            courseId: self.normalized(cId),
                            lessonId: self.normalized(lId),
                            lessonTitle: lessonTitle.isEmpty ? nil : lessonTitle,
                            createdAt: Date()
                        )
                        self.items.insert(it, at: 0)
                    }
                }
                self.sortNewestFirst()
                self.recomputeLikedCourses()
                self.syncToUserSession()
                self.save()
                self.emit()
            }
        }
    }

    /// Back-compat: old call sites without explicit order
    func toggle(step: SDStepItem, courseId: String?, lessonId: String?) {
        toggle(step: step, courseId: courseId, lessonId: lessonId, order: nil)
    }

    func remove(id: String) {
        let raw = normalized(id)
        let isHack = raw.hasPrefix("hack:")
        let key = isHack ? raw : compareKey(raw)
        DispatchQueue.main.async {
            let before = self.items.count
            _ = withAnimation {
                self.items.removeAll { it in
                    if isHack { return self.normalized(it.id) == key }
                    return self.compareKey(it.id) == key
                }
            }
            if self.items.count != before {
                // 8️⃣: Refresh likedCourses after removals
                self.recomputeLikedCourses()
                self.syncToUserSession()
                self.save()
                self.emit()
            }
        }
    }

    func remove(item: Favoritable) {
        remove(id: item.favoriteId)
    }

    func isLiked(step: SDStepItem, courseId: String?, lessonId: String?, order: Int?) -> Bool {
        func extractCanonicalContext(from raw: Any) -> (course: String, lesson: String, idx: Int)? {
            var s = String(describing: raw)
            s = normalized(s)
            if s.hasPrefix("hack:") { s.removeFirst("hack:".count) }
            if s.hasPrefix("card:") { s.removeFirst("card:".count) }
            if s.hasPrefix("step:") { s.removeFirst("step:".count) }
            guard s.contains(":") else { return nil }
            let parts = s.split(separator: ":").map { String($0) }
            guard parts.count >= 3 else { return nil }
            let course = normalized(parts[0])
            let lesson = normalized(parts[1])
            guard !course.isEmpty, !lesson.isEmpty else { return nil }
            if let idxPart = parts.first(where: { $0.hasPrefix("idx") }),
               let n = Int(idxPart.dropFirst(3)) {
                return (course: course, lesson: lesson, idx: n)
            }
            return nil
        }
        // Derive missing context from step.id if possible (same as in toggle(step:...))
        var cId = courseId ?? ""
        var lId = lessonId ?? ""

        let canon = extractCanonicalContext(from: step.id)
        if cId.isEmpty { cId = canon?.course ?? "" }
        if lId.isEmpty { lId = canon?.lesson ?? "" }

        if (cId.isEmpty || lId.isEmpty), let parsed = parseCourseLesson(from: step.id) {
            if cId.isEmpty { cId = parsed.course }
            if lId.isEmpty { lId = parsed.lesson }
        }

        cId = normalized(cId)
        lId = normalized(lId)

        let baseId = makeId(step: step, courseId: cId, lessonId: lId)
        let idxOpt = (order != nil) ? order : (canon?.idx ?? stepIndex(courseId: cId, lessonId: lId, composedId: baseId))
        guard let idx = idxOpt else { return false }

        if step.kind == .tip {
            let favId = canonicalHackFavoriteId(courseId: cId, lessonId: lId, index: idx)
            return items.contains { normalized($0.id) == normalized(favId) }
        } else {
            let favId = canonicalStepFavoriteId(courseId: cId, lessonId: lId, index: idx)
            return items.contains { normalized($0.id) == normalized(favId) }
        }
    }

    /// Back-compat: old call sites without explicit order
    func isLiked(step: SDStepItem, courseId: String?, lessonId: String?) -> Bool {
        return isLiked(step: step, courseId: courseId, lessonId: lessonId, order: nil)
    }

    func isLiked(id: String) -> Bool {
        let raw = normalized(id)
        if raw.hasPrefix("hack:") {
            return items.contains { normalized($0.id) == raw }
        }
        let key = compareKey(raw)
        return items.contains { compareKey($0.id) == key }
    }

    /// Возвращает избранные элементы для конкретного урока
    /// - Parameters:
    ///   - courseId: идентификатор курса
    ///   - lessonId: идентификатор урока
    ///   - onlyCards: если true, учитываются только карточки (метка "card:") и игнорируются хак‑советы ("hack:")
    /// - Returns: массив FavoriteItem
    func favoritesForLesson(courseId: String, lessonId: String, onlyCards: Bool = true) -> [FavoriteItem] {
        let cKey = normalized(courseId)
        let lKey = normalized(lessonId)
        return items.filter { it in
            // извлечём course/lesson с бэкапом из составного id
            let itemCourse: String
            let itemLesson: String
            if it.courseId.isEmpty || it.lessonId.isEmpty {
                if let parsed = parseCourseLesson(from: it.id) {
                    itemCourse = normalized(parsed.course)
                    itemLesson = normalized(parsed.lesson)
                } else {
                    itemCourse = normalized(it.courseId)
                    itemLesson = normalized(it.lessonId)
                }
            } else {
                itemCourse = normalized(it.courseId)
                itemLesson = normalized(it.lessonId)
            }
            if itemCourse != cKey || itemLesson != lKey { return false }
            if onlyCards {
                let fid = normalized(it.id)
                let phon = it.phonetic.lowercased()
                let isHack = fid.hasPrefix("hack:") || phon.hasPrefix("hack:")
                if isHack { return false }
                // keep only step/card favorites; exclude courses
                if fid.hasPrefix("course:") { return false }
                return fid.hasPrefix("step:") || fid.hasPrefix("card:")
            }
            return true
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// Количество избранных элементов для конкретного урока (по умолчанию только карточки)
    func countForLesson(courseId: String, lessonId: String, onlyCards: Bool = true) -> Int {
        return favoritesForLesson(courseId: courseId, lessonId: lessonId, onlyCards: onlyCards).count
    }

    /// Количество избранных КАРТОЧЕК (без лайфхаков) для урока — синхронный шорткат
    @inline(__always)
    func countCardsForLesson(courseId: String, lessonId: String) -> Int {
        return favoritesForLesson(courseId: courseId, lessonId: lessonId, onlyCards: true).count
    }

    /// Паблишер, выдающий актуальное количество избранных для конкретного урока
    /// Удобно для DS/Managers: подписались — получаете апдейты без ручного дергания reload
    func favoriteCountPublisher(courseId: String, lessonId: String, onlyCards: Bool = true) -> AnyPublisher<Int, Never> {
        $items
            .map { [weak self] _ in
                guard let self = self else { return 0 }
                return self.countForLesson(courseId: courseId, lessonId: lessonId, onlyCards: onlyCards)
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    /// Reorder items to match the given id sequence; unknown ids keep their relative order at the end
    func applyOrder(_ orderedIds: [String]) {
        DispatchQueue.main.async {
            _ = withAnimation {
                self.sortNewestFirst()
            }
            self.save()
            self.emit()
        }
    }

    // MARK: - Internals

    fileprivate func makeId(step: SDStepItem, courseId: String?, lessonId: String?) -> String {
        let raw = String(describing: step.id)
        // strip optional namespace prefixes like "step:"
        let base: String
        if raw.hasPrefix("step:") {
            base = String(raw.dropFirst("step:".count))
        } else {
            base = raw
        }

        // If step.id already looks like a composite id (course.lesson.step[.extra]) — keep as-is
        let comps = base.split(separator: ".").map { String($0) }
        if comps.count >= 3 {
            return comps.joined(separator: ".")
        }

        // Otherwise, build canonical id: course.lesson.step
        var parts: [String] = []
        if let c = courseId, !c.isEmpty { parts.append(c) }
        if let l = lessonId, !l.isEmpty { parts.append(l) }
        parts.append(base)
        return parts.joined(separator: ".")
    }

    /// Build a namespaced id (e.g. kind:raw)
    private func makeId(kind: String, raw: String) -> String { "\(kind):\(raw)" }

    @inline(__always)
    private func sortNewestFirst() {
        self.items.sort { a, b in
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id > b.id
        }
    }

    private func load() {
        var loaded: [FavoriteItem] = []
        if let data = UserDefaults.standard.data(forKey: storeKey) {
            do { loaded = try JSONDecoder().decode([FavoriteItem].self, from: data) } catch {
                print("[FavoriteManager] load error: \(error)")
                loaded = []
            }
        }
        // de-duplicate by normalized id, keep the newest createdAt
        var latestById: [String: FavoriteItem] = [:]
        for it in loaded {
            let key = normalized(it.id)
            if let cur = latestById[key] {
                latestById[key] = (it.createdAt >= cur.createdAt) ? it : cur
            } else {
                latestById[key] = it
            }
        }
        var unique = Array(latestById.values)
        // Always sort newest first
        unique.sort { $0.createdAt > $1.createdAt }
        self.items = unique
        emit()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storeKey)
            let ord = items.map { normalized($0.id) }
            UserDefaults.standard.set(ord, forKey: orderKey)
        } catch {
            print("[FavoriteManager] save error: \(error)")
        }
    }
}

/// data model for one favorite
struct FavoriteItem: Identifiable, Codable, Hashable {
    let id: String
    let ru: String
    let th: String
    let phonetic: String
    let courseId: String
    let lessonId: String
    let lessonTitle: String? // optional for backward compatibility
    let createdAt: Date
}
