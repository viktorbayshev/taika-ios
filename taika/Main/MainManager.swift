//
//  MainManager.swift
//  taika
//
//  Created by product on 22.10.2025.
//

import Foundation
import SwiftUI

final class MainManager: ObservableObject {
    // Daily Picks payload for MainView → MainDS (pure data; DS draws visuals)
    struct DailyPicksPayload: Equatable {
        struct Ref: Equatable {
            let courseId: String
            let lessonId: String
            let index: Int

            static let proPlaceholder = Ref(courseId: "__pro__", lessonId: "__pro__", index: -1)
        }
        let refs: [Ref]
        let items: [SDStepItem]              // visual items for SDStepCarousel
        let courseShort: [String]            // parallel to items
        let lessonShort: [String]            // parallel to items
        let metaTitles: [String]             // e.g. "Разговорный старт • Урок 4"
        let favorites: [Bool]            // mask per item
        static let empty = DailyPicksPayload(refs: [], items: [], courseShort: [], lessonShort: [], metaTitles: [], favorites: [])
    }

// MARK: - AddCourseToDayRequested observer

    struct DailyCoursePicksPayload {
        let courses: [Course]
        static let empty = DailyCoursePicksPayload(courses: [])
    }

    // Calendar overlay models (MainView uses these for .add(date) and .activity(date) modes)
    struct CourseCardModel: Identifiable, Equatable {
        enum CTA: Equatable {
            case add
            case `continue`

            var title: String {
                switch self {
                case .add: return "добавить"
                case .continue: return "продолжить"
                }
            }

            var hint: String {
                switch self {
                case .add: return "тап → добавить в план"
                case .continue: return "тап → открыть курс"
                }
            }

            var idKey: String {
                switch self {
                case .add: return "add"
                case .continue: return "continue"
                }
            }
        }

        private static func makeId(courseId: String, cta: CTA) -> String {
            "\(courseId)|\(cta.idKey)"
        }

        let id: String
        let courseId: String
        let title: String
        let subtitle: String
        let categoryChip: String?
        let isPro: Bool

        // Optional progress (0…1). `nil` means we intentionally don't show progress for this scenario.
        let progress: Double?

        // Scenario-specific CTA.
        let cta: CTA

        init(
            courseId: String,
            title: String,
            subtitle: String,
            categoryChip: String? = nil,
            isPro: Bool,
            progress: Double? = nil,
            cta: CTA
        ) {
            self.id = Self.makeId(courseId: courseId, cta: cta)
            self.courseId = courseId
            self.title = title
            self.subtitle = subtitle
            self.categoryChip = categoryChip
            self.isPro = isPro
            self.progress = progress
            self.cta = cta
        }
    }

    @Published var dailyPicks: DailyPicksPayload = .empty
    @Published var dailyCoursePicks: DailyCoursePicksPayload = .empty
    @Published var dailyFavMask: [Bool] = []
    @Published var resumeItems: [MainBannerItem] = []
    @Published var weekSummary: [DaySummary] = []   // 7 items, Sun..Sat (or locale order)

    // Cache daily picks list for the current day — keeps learned cards in today's rotation
    private var dailyKeysCache: [(ref: DailyPicksPayload.Ref, item: StepItem)] = []
    private var dailyKeysCacheCount: Int = 0
    private var dailyCourseCache: [Course] = []
    private var dailyCourseCacheCount: Int = 0
    private var dailyCacheDay: Date = MainManager.bangkokCal.startOfDay(for: Date())

    private func invalidateDailyCacheIfDayChanged() {
        let today = Self.bangkokCal.startOfDay(for: Date())
        if today > dailyCacheDay { // new day → drop cache
            dailyKeysCache.removeAll()
            dailyKeysCacheCount = 0
            dailyCourseCache.removeAll()
            dailyCourseCacheCount = 0
            dailyCacheDay = today
        }
    }
    private let freeDailyPicksLimit: Int = 5
    private let proDailyPicksLimit: Int = 10

    private let freeDailyCoursePicksLimit: Int = 5
    private let proDailyCoursePicksLimit: Int = 10

    @MainActor
    private func hasExtraDailyPicks() -> Bool {
        // Feature-gating (more flexible than raw isPro).
        ProManager.shared.can(.dailyPicksExtra)
    }

    @MainActor
    private func effectiveDailyPicksLimit() -> Int {
        hasExtraDailyPicks() ? proDailyPicksLimit : freeDailyPicksLimit
    }

    @MainActor
    private func effectiveDailyCoursePicksLimit() -> Int {
        hasExtraDailyPicks() ? proDailyCoursePicksLimit : freeDailyCoursePicksLimit
    }
    
    static let shared = MainManager()
    
    private var resetObserver: NSObjectProtocol?
    private var favObserver: NSObjectProtocol?
    private var progObserver: NSObjectProtocol?
    private var lessonsObserver: NSObjectProtocol?
    private var coursePlanObserver: NSObjectProtocol?
    private var removeCourseObserver: NSObjectProtocol?
    private var addCourseObserver: NSObjectProtocol?

    // Cached formatters and calendar helpers
    // MARK: - Thailand canonical calendar (Asia/Bangkok)
    private static let bangkokTZ: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current

    private static var bangkokCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = bangkokTZ
        return cal
    }()
    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = bangkokTZ
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let uiDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.timeZone = bangkokTZ
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private var weekSummaryReloadWork: DispatchWorkItem?

    private func scheduleWeekSummaryReload() {
        weekSummaryReloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                await self.rebuildWeekSummary()
            }
        }
        weekSummaryReloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private init() {
        resetObserver = NotificationCenter.default.addObserver(
            forName: .init("AppResetAll"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
            self.scheduleWeekSummaryReload()
        }
        favObserver = NotificationCenter.default.addObserver(
            forName: .init("FavoritesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.reloadDailyPicks() }
            self.scheduleWeekSummaryReload()
        }
        progObserver = NotificationCenter.default.addObserver(
            forName: .init("ProgressDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // do not rebuild the set on progress change; keep today's list stable
            self.invalidateDailyCacheIfDayChanged()
            self.scheduleDailyPicksReload()
            self.scheduleWeekSummaryReload()
        }
        lessonsObserver = NotificationCenter.default.addObserver(
            forName: .init("LessonsDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.scheduleWeekSummaryReload()
        }
        coursePlanObserver = NotificationCenter.default.addObserver(
            forName: .init("CoursePlanDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let day = note.userInfo?["day"] as? Date {
                Task { @MainActor in
                    await self.applyPlannedQuickUpdate(for: day)
                }
            }
            self.scheduleWeekSummaryReload()
        }
        addCourseObserver = NotificationCenter.default.addObserver(
            forName: .init("AddCourseToDayRequested"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let courseId = note.userInfo?["courseId"] as? String else { return }
            let day = (note.userInfo?["day"] as? Date) ?? Self.bangkokCal.startOfDay(for: Date())
            let dayStart = Self.bangkokCal.startOfDay(for: day)

            Task { @MainActor in
                let isProUser = ProManager.shared.isPro
                if isProUser {
                    UserSession.shared.togglePlannedCourse(courseId: courseId, on: dayStart)
                } else {
                    // free-tier: do not overwrite an existing planned course; keep the first one.
                    let existing = UserSession.shared.plannedCourseIds(on: dayStart)
                    if existing.isEmpty {
                        UserSession.shared.setPlannedCourses(on: dayStart, courseIds: Set([courseId]))
                    } else {
                        // if the user taps the same course again, treat it as no-op (UI toggling is handled elsewhere)
                        if existing.contains(courseId) {
                            // no-op
                        } else {
                            // keep existing selection (prevents "rewrite" effect)
                            // optional upsell can be added later without changing storage semantics
                        }
                    }
                }

                NotificationCenter.default.post(
                    name: .init("CoursePlanDidChange"),
                    object: nil,
                    userInfo: ["day": dayStart]
                )
                UserSession.shared.logActivity(.coursePlannedAdded, courseId: courseId, ts: dayStart)
            }
        }
        removeCourseObserver = NotificationCenter.default.addObserver(
            forName: .init("RemoveCourseFromDayRequested"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let courseId = note.userInfo?["courseId"] as? String else { return }
            let day = (note.userInfo?["day"] as? Date) ?? Self.bangkokCal.startOfDay(for: Date())
            let dayStart = Self.bangkokCal.startOfDay(for: day)
            Task { @MainActor in
                UserSession.shared.removePlannedCourse(courseId: courseId, on: dayStart)
                NotificationCenter.default.post(
                    name: .init("CoursePlanDidChange"),
                    object: nil,
                    userInfo: ["day": dayStart]
                )
                UserSession.shared.logActivity(.coursePlannedRemoved, courseId: courseId, ts: dayStart)
            }
        }
    }

    deinit {
        if let token = resetObserver { NotificationCenter.default.removeObserver(token) }
        if let token = favObserver { NotificationCenter.default.removeObserver(token) }
        if let token = progObserver { NotificationCenter.default.removeObserver(token) }
        if let token = lessonsObserver { NotificationCenter.default.removeObserver(token) }
        if let token = coursePlanObserver { NotificationCenter.default.removeObserver(token) }
        if let token = removeCourseObserver { NotificationCenter.default.removeObserver(token) }
        if let token = addCourseObserver { NotificationCenter.default.removeObserver(token) }
        dailyReloadWork?.cancel()
        weekSummaryReloadWork?.cancel()
    }
    
    private var cacheInvalidated = false

    private var dailyReloadWork: DispatchWorkItem?

    private func scheduleDailyPicksReload() {
        dailyReloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                await self.reloadDailyPicks()
            }
        }
        dailyReloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: work)
    }
    
    @MainActor
    func refresh() async {
        // Derive recent pairs from UserSession snapshot (no recentActivity API)
        let snap = await UserSession.shared.snapshot
        var recent: [(courseId: String, lessonId: String?)] = []

        // 1) last lesson per course (most precise signal)
        for (cid, lid) in snap.lastLessonByCourse {
            recent.append((courseId: cid, lessonId: lid))
        }
        // 2) fallback: started courses if nothing else
        if recent.isEmpty {
            for cid in snap.startedCourses {
                recent.append((courseId: cid, lessonId: nil))
            }
        }

        // Stable priority: entries with lessonId first, then by courseId
        recent.sort { lhs, rhs in
            if (lhs.lessonId != nil) != (rhs.lessonId != nil) { return lhs.lessonId != nil }
            return lhs.courseId < rhs.courseId
        }

        // Select up to last 2 lessons and last 2 courses
        let lessonsOnly = recent.filter { $0.lessonId != nil }
        let coursesOnly = recent.filter { $0.lessonId == nil }
        let pickLessons = Array(lessonsOnly.prefix(2))
        let pickCourses = Array(coursesOnly.prefix(2))

        // Desired order: course, lesson, course, lesson (fallback gracefully)
        var ordered: [(courseId: String, lessonId: String?)] = []
        func appendIfAny(_ item: (courseId: String, lessonId: String?)?) { if let it = item { ordered.append(it) } }
        appendIfAny(pickCourses.indices.contains(0) ? pickCourses[0] : nil)
        appendIfAny(pickLessons.indices.contains(0) ? pickLessons[0] : nil)
        appendIfAny(pickCourses.indices.contains(1) ? pickCourses[1] : nil)
        appendIfAny(pickLessons.indices.contains(1) ? pickLessons[1] : nil)

        // If still less than 4, top up from the remaining recent items (keeping order)
        if ordered.count < 4 {
            for pair in recent where !ordered.contains(where: { $0.courseId == pair.courseId && $0.lessonId == pair.lessonId }) {
                ordered.append(pair)
                if ordered.count == 4 { break }
            }
        }

        // Map to banner items — use real course progress; for lessons leave 0.0 for now (will add Steps meta next)
        let now = Date()
        var mapped: [(id: String, date: Date, title: String, kind: MainBannerItem.Kind, progress: Double)] = []
        for pair in ordered {
            let LM = LessonsManager.shared
            let id = pair.lessonId != nil ? "\(pair.courseId):\(pair.lessonId!)" : pair.courseId
            let title: String = {
                if let lid = pair.lessonId {
                    // prefer lesson title; fallback to raw id if unavailable
                    return LM.lessonTitle(for: lid) ?? lid
                } else {
                    // safe course title via helper
                    return LM.courseTitle(for: pair.courseId)
                }
            }()
            let kind: MainBannerItem.Kind = (pair.lessonId != nil) ? .lesson : .course
            let progress: Double
            if pair.lessonId == nil {
                // average course progress from ProgressManager
                progress = await ProgressManager.shared.progress(for: pair.courseId, lessonId: nil)
            } else if let lid = pair.lessonId {
                // use LessonsManager helper (0…1)
                progress = await LessonsManager.shared.lessonPercent(courseId: pair.courseId, lessonId: lid)
            } else {
                progress = 0.0
            }
            mapped.append((id: id, date: now, title: title, kind: kind, progress: progress))
        }

        // Deduplicate by id (just in case) and keep order
        var seen = Set<String>()
        let unique = mapped.filter { item in
            if seen.contains(item.id) { return false }
            seen.insert(item.id)
            return true
        }

        let bannerItems = unique.map { MainBannerItem(id: $0.id, title: $0.title, kind: $0.kind, progress: $0.progress) }

        // Skip publishing (and logs) if nothing changed to avoid notification loops & log spam
        if bannerItems == self.resumeItems {
            #if DEBUG
            print("[MainManager] skip reload (unchanged)")
            #endif
            return
        }

        #if DEBUG
        print("[MainManager] order -> \(ordered.map{ $0.lessonId == nil ? "C" : "L" }.joined())")
        print("[MainManager] reload banners \(bannerItems.count) items (derived from snapshot)")
        let dbg = mapped.map { String(format: "%@ %.0f%%", $0.kind == .course ? "C" : "L", $0.progress * 100) }.joined(separator: ", ")
        print("[MainManager] progress map -> \(dbg)")
        print("[MainManager] titles -> \(bannerItems.map{ $0.title }.joined(separator: " | "))")
        #endif

        self.resumeItems = bannerItems
        await rebuildWeekSummary()
    }
    
}

struct MainBannerItem: Identifiable, Equatable {
    let id: String
    let title: String
    let kind: Kind
    let progress: Double
    
    enum Kind: Equatable {
        case course
        case lesson
    }
}

// MARK: - Weekly day summaries (calendar mini-cards)
struct DaySummary: Identifiable, Equatable {
    let id: String            // "YYYY-MM-DD"
    let date: Date
    let courses: [String]     // up to 2 last active courses
    let totalCourses: Int     // total courses interacted with that day (or planned count for planned-only)
    let progress: Double      // aggregated progress for that day

    // explicit scenario flag for CardDS (planned-only day, including missed plan in the past)
    let isPlanned: Bool
}


// MARK: - Daily Picks reload
extension MainManager {
    @MainActor
    func reloadDailyPicks() async {
        let limit = effectiveDailyPicksLimit()
        await reloadDailyPicks(count: limit)
    }

    @MainActor
    private func courseProgressFraction(courseId: String) async -> Double {
        // single source of truth: ProgressManager
        let raw = await ProgressManager.shared.progress(for: courseId, lessonId: nil)
        let clamped = min(max(raw, 0.0), 1.0)

        // if course was started but progress is still ~0, show minimal visible progress
        let snap = await UserSession.shared.snapshot
        let isStarted =
            snap.startedCourses.contains(courseId) ||
            snap.lastLessonByCourse[courseId] != nil

        if isStarted && clamped <= 0.0001 {
            return 0.02
        }

        return clamped
    }
    @MainActor
    private func shortCourseName(_ courseId: String) -> String {
        let title = LessonsManager.shared.courseTitle(for: courseId)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return title.isEmpty ? courseId : title
    }

    @MainActor
    private func shortCourseSubtitle(_ courseId: String, course: Course) -> String {
        // Prefer a real subtitle from the Course model if present; otherwise fall back to an empty string.
        let m = Mirror(reflecting: course)
        for c in m.children {
            guard let label = c.label?.lowercased() else { continue }
            if label == "subtitle" || label.contains("subtitle") {
                if let s = c.value as? String {
                    return s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            // sometimes stored as description/summary
            if label == "summary" || label.contains("summary") || label == "desc" || label.contains("description") {
                if let s = c.value as? String {
                    return s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return ""
    }

    @MainActor
    private func courseOutcomePreview(_ courseId: String) -> String? {
        // Prefer outcomes from lessons.json (LessonsData) for course previews.
        // Rule: take the first non-empty outcome from the first lesson that has outcomes.
        let m = LessonsData.shared
        // Try to access lessons for course (expected API in LessonsData).
        let lessons = m.lessons(for: courseId)
        for lesson in lessons {
            let outcomes = lesson.outcomes
            if let first = outcomes.first {
                let s = first.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { return s }
            }
        }
        return nil
    }

    // Best-effort PRO flag resolver without hard dependencies on Course model fields.
    private func resolveIsProCourse(_ course: Course) -> Bool {
        let m = Mirror(reflecting: course)
        for c in m.children {
            guard let label = c.label?.lowercased() else { continue }
            if label == "ispro" || label == "pro" || label.contains("is_pro") || label.contains("isprocourse") {
                if let b = c.value as? Bool { return b }
                if let s = c.value as? String { return s.lowercased().contains("pro") }
                if let i = c.value as? Int { return i != 0 }
            }
            if label == "tier" || label.contains("tier") {
                if let s = c.value as? String { return s.lowercased().contains("pro") }
                if let i = c.value as? Int { return i > 0 }
            }
        }
        return false
    }

    // Best-effort category resolver (chip text) without hard dependencies on Course model fields.
    private func resolveCourseCategoryChip(_ course: Course) -> String? {
        let m = Mirror(reflecting: course)
        for c in m.children {
            guard let label = c.label?.lowercased() else { continue }

            // common variants: category, level, kind, section
            if label == "category" || label.contains("category") || label == "level" || label.contains("level") || label == "kind" || label.contains("kind") || label == "section" || label.contains("section") {
                if let s = c.value as? String {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
            }

            // sometimes category comes as tags: [String]
            if label == "tags" || label.contains("tags") {
                if let arr = c.value as? [String], let first = arr.first {
                    let t = first.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
            }
        }
        return nil
    }

    /// Source for `.add(date)` overlay: free courses first, then a randomized PRO showcase (disabled for non-PRO users).
    @MainActor
    func availableCoursesForAdd(isProUser: Bool, proShowcaseLimit: Int = 8) async -> [CourseCardModel] {
        let all = CourseData.shared.featuredCourses
        guard !all.isEmpty else { return [] }

        // Map → models (title falls back to id)
        let snap = await UserSession.shared.snapshot
        let startedIds = snap.startedCourses

        let mapped: [CourseCardModel] = all.map { c in
            let cid = c.id
            let title = shortCourseName(cid)
            let subtitle = courseOutcomePreview(cid) ?? shortCourseSubtitle(cid, course: c)
            let isProCourse = resolveIsProCourse(c)
            let cta: CourseCardModel.CTA = startedIds.contains(cid) ? .continue : .add
            return CourseCardModel(
                courseId: cid,
                title: title,
                subtitle: subtitle,
                categoryChip: resolveCourseCategoryChip(c),
                isPro: isProCourse,
                progress: nil,
                cta: cta
            )
        }

        let free = mapped.filter { !$0.isPro }
        let pro  = mapped.filter { $0.isPro }

        // For non-PRO users: show only a subset of PRO courses as a showcase (disabled in UI).
        // For PRO users: show all PRO courses.
        let proPart: [CourseCardModel]
        if isProUser {
            proPart = pro
        } else {
            proPart = Array(pro.shuffled().prefix(max(0, proShowcaseLimit)))
        }

        // final order: free first, then PRO
        return free + proPart
    }

    /// Source for `.activity(date)` overlay: courses active on that day, prepared for CardDS.
    /// View must not filter/compute; it only renders the returned models.
    @MainActor
    func activeCoursesForDay(_ date: Date, limit: Int = 8) async -> [CourseCardModel] {
        let resolved = await dayState(for: date)

        var ids: [String] = []
        switch resolved.state {
        case .active:
            ids = resolved.activeIds
        case .plannedOnly:
            ids = resolved.plannedIds
        case .empty:
            ids = []
        }

        if ids.count > limit { ids = Array(ids.prefix(limit)) }
        guard !ids.isEmpty else { return [] }

        // Best-effort lookup for subtitles / PRO flags from featured courses.
        let featured = CourseData.shared.featuredCourses
        func featuredCourse(by id: String) -> Course? {
            featured.first(where: { $0.id == id })
        }

        var out: [CourseCardModel] = []
        out.reserveCapacity(ids.count)

        for cid in ids {
            let title = shortCourseName(cid)
            let subtitle: String = {
                if let outcome = courseOutcomePreview(cid) {
                    return outcome
                }
                if let c = featuredCourse(by: cid) {
                    let s = shortCourseSubtitle(cid, course: c)
                    return s.isEmpty ? CourseCardModel.CTA.continue.hint : s
                }
                return CourseCardModel.CTA.continue.hint
            }()

            let isProCourse: Bool = {
                if let c = featuredCourse(by: cid) { return resolveIsProCourse(c) }
                return false
            }()

            let categoryChip: String? = {
                if let c = featuredCourse(by: cid) { return resolveCourseCategoryChip(c) }
                return nil
            }()

            let p = await courseProgressFraction(courseId: cid)

            out.append(
                CourseCardModel(
                    courseId: cid,
                    title: title,
                    subtitle: subtitle,
                    categoryChip: categoryChip,
                    isPro: isProCourse,
                    progress: p,
                    cta: .continue
                )
            )
        }

        return out
    }

    /// public resolver for UI: returns course title (fallbacks to id)
    @MainActor
    func courseTitle(for courseId: String) async -> String {
        shortCourseName(courseId)
    }

    @MainActor
    private func shortLessonName(_ lessonId: String) -> String {
        let title = LessonsManager.shared.lessonTitle(for: lessonId)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !title.isEmpty { return title }
        // fallback: parse "course_b_1_l4" → "урок 4"
        if let r = lessonId.split(separator: "_").last, r.first == "l", let n = Int(r.dropFirst()) {
            return "урок \(n)"
        }
        return lessonId
    }
    @MainActor
    func reloadDailyPicks(count: Int = 5) async {
        // keep today's picks stable: rebuild only when cache is empty or day changed or count changes
        invalidateDailyCacheIfDayChanged()
        if dailyKeysCache.isEmpty || dailyKeysCacheCount != count {
            let keys = await StepData.shared.dailyPicksKeys(count: count)
            dailyKeysCache = keys.map { k in
                let r = DailyPicksPayload.Ref(courseId: k.courseId, lessonId: k.lessonId, index: k.index)
                return (ref: r, item: k.item)
            }
            dailyKeysCacheCount = count
        }

        var refs: [DailyPicksPayload.Ref] = []
        var visuals: [SDStepItem] = []
        var courseShort: [String] = []
        var lessonShort: [String] = []
        var metaTitles: [String] = []

        for pair in dailyKeysCache {
            let r = pair.ref
            refs.append(r)
            visuals.append(sd(from: pair.item))

            let finalCourse = shortCourseName(r.courseId)
            let finalLesson = shortLessonName(r.lessonId)
            courseShort.append(finalCourse)
            lessonShort.append(finalLesson)
            metaTitles.append("\(finalCourse) • \(finalLesson)")
        }

        // --- PRO gates (visual-only): add before first and after last for Daily Picks.
        // These are not real learning items and must not affect favorites/progress ids.
        let hasExtra = await hasExtraDailyPicks()
        if !visuals.isEmpty && !hasExtra {
            let before = SDStepItem(
                kind: .word,
                titleRU: "расширь подборку",
                subtitleTH: "открой ещё 12 карточек",
                phonetic: "нужно pro",
                isPro: true
            )
            let after = SDStepItem(
                kind: .word,
                titleRU: "открой ещё",
                subtitleTH: "ещё 12 карточек",
                phonetic: "нужно pro",
                isPro: true
            )

            refs.insert(.proPlaceholder, at: 0)
            visuals.insert(before, at: 0)
            courseShort.insert("", at: 0)
            lessonShort.insert("", at: 0)
            metaTitles.insert("", at: 0)

            refs.append(.proPlaceholder)
            visuals.append(after)
            courseShort.append("")
            lessonShort.append("")
            metaTitles.append("")
        }

        // sync favorite mask with current daily items order (real FavoriteManager state)
        let fm = FavoriteManager.shared
        var favMask: [Bool] = []
        favMask.reserveCapacity(refs.count)
        for (i, r) in refs.enumerated() {
            if i < visuals.count, visuals[i].isPro {
                favMask.append(false)
                continue
            }
            let isTip = i < visuals.count && visuals[i].kind == .tip
            let id = isTip
                ? fm.idForHack(courseId: r.courseId, lessonId: r.lessonId, index: r.index)
                : fm.idForStep(courseId: r.courseId, lessonId: r.lessonId, index: r.index)
            favMask.append(fm.contains(stepId: id))
        }
        let newPayload = DailyPicksPayload(refs: refs, items: visuals, courseShort: courseShort, lessonShort: lessonShort, metaTitles: metaTitles, favorites: favMask)
        if newPayload == self.dailyPicks { return }
        self.dailyPicks = newPayload
        self.dailyFavMask = favMask

        self.cacheInvalidated = false

        #if DEBUG
        let courses = Set(refs.map{ $0.courseId }).count
        let lessons = Set(refs.map{ $0.lessonId }).count
        print("[MainManager] daily picks → items=\(refs.count) courses=\(courses) lessons=\(lessons)")
        #endif
    }

    private func sd(from item: StepItem) -> SDStepItem {
        let f = StepData.shared.face(for: item)
        let kind: SDStepItem.Kind = {
            switch f.kind {
            case .word:   return .word
            case .phrase: return .phrase
            case .casual: return .casual
            case .tip:    return .tip
            case .dialog: return .phrase // dialogs не идут в daily, но визуально безопасный фолбэк
            }
        }()
        return SDStepItem(
            kind: kind,
            titleRU: f.titleRU,
            subtitleTH: f.subtitleTH,
            phonetic: f.phonetic
        )
    }
}

// MARK: - Week Summary (last 7 days)
extension MainManager {
    enum DayState: Equatable {
        case empty
        case plannedOnly
        case active
    }

    /// single source of truth for calendar day scenario (active/planned/empty)
    @MainActor
    func dayState(for date: Date) async -> (state: DayState, dayStart: Date, activeIds: [String], plannedIds: [String]) {
        let cal = Self.bangkokCal
        let dayStart = cal.startOfDay(for: date)

        // activity ids (recorded learning for the day)
        var activeIds = await courseIds(for: dayStart, limit: Int.max)

        // planned ids (explicit planning)
        let plannedIds = UserSession.shared.plannedCourseIds(on: dayStart)


        if !activeIds.isEmpty { return (.active, dayStart, activeIds, plannedIds) }
        if !plannedIds.isEmpty { return (.plannedOnly, dayStart, [], plannedIds) }
        return (.empty, dayStart, [], [])
    }
    /// Public entry to rebuild summaries for the last 7 days.
    @MainActor
    func rebuildWeekSummary(reference: Date = Date()) async {
        let days = last7Days(endingAt: reference)
        var out: [DaySummary] = []
        out.reserveCapacity(days.count)

        for day in days {
            let resolved = await dayState(for: day)
            let id = isoDayId(resolved.dayStart)

            switch resolved.state {
            case .active:
                let courses = await courseTitlesFromIds(resolved.activeIds, limit: 2)
                let progress = await dailyProgressFromActiveIds(resolved.activeIds)
                out.append(DaySummary(
                    id: id,
                    date: resolved.dayStart,
                    courses: courses,
                    totalCourses: resolved.activeIds.count,
                    progress: progress,
                    isPlanned: false
                ))

            case .plannedOnly:
                let titles = await courseTitlesFromIds(resolved.plannedIds, limit: 2)
                out.append(DaySummary(
                    id: id,
                    date: resolved.dayStart,
                    courses: titles,
                    totalCourses: resolved.plannedIds.count,
                    progress: 0.0,
                    isPlanned: true
                ))

            case .empty:
                out.append(DaySummary(
                    id: id,
                    date: resolved.dayStart,
                    courses: [],
                    totalCourses: 0,
                    progress: 0.0,
                    isPlanned: false
                ))
            }
        }

        // Keep order as returned by last7Days (oldest...newest) — UI may center today's card.
        if out != self.weekSummary {
            self.weekSummary = out
        }
    }
    @MainActor
    private func courseTitlesFromIds(_ ids: [String], limit: Int) async -> [String] {
        guard limit > 0 else { return [] }
        guard !ids.isEmpty else { return [] }
        var out: [String] = []
        out.reserveCapacity(min(ids.count, limit))
        for cid in ids {
            out.append(await shortCourseName(cid))
            if out.count == limit { break }
        }
        return out
    }

    @MainActor
    private func applyPlannedQuickUpdate(for dayStart: Date) async {
        let d = Self.bangkokCal.startOfDay(for: dayStart)
        let id = isoDayId(d)
        // If weekSummary hasn't been built yet (e.g. first entry without refresh),
        // build an empty 7-day scaffold so the quick update can apply immediately.
        if weekSummary.isEmpty {
            let days = last7Days(endingAt: Date())
            var scaffold: [DaySummary] = []
            scaffold.reserveCapacity(days.count)
            for day in days {
                let dayStart = Self.bangkokCal.startOfDay(for: day)
                scaffold.append(DaySummary(
                    id: isoDayId(dayStart),
                    date: dayStart,
                    courses: [],
                    totalCourses: 0,
                    progress: 0.0,
                    isPlanned: false
                ))
            }
            weekSummary = scaffold
        }
        guard let idx = weekSummary.firstIndex(where: { isSameCalendarDay($0.date, d) }) else { return }

        // If there is real activity already (progress > tiny), keep it (full rebuild will refresh later).
        if weekSummary[idx].progress > 0.0001 { return }

        let plannedIds = UserSession.shared.plannedCourseIds(on: d)

        var copy = weekSummary
        if plannedIds.isEmpty {
            copy[idx] = DaySummary(id: id, date: d, courses: [], totalCourses: 0, progress: 0.0, isPlanned: false)
            if copy != weekSummary { weekSummary = copy }
            return
        }

        let titles = Task { await courseTitlesFromIds(plannedIds, limit: 2) }
        let resolvedTitles = await titles.value
        copy[idx] = DaySummary(
            id: id,
            date: d,
            courses: resolvedTitles,
            totalCourses: plannedIds.count,
            progress: 0.0,
            isPlanned: true
        )
        if copy != weekSummary { weekSummary = copy }
    }

    @MainActor
    private func dailyProgressFromActiveIds(_ ids: [String]) async -> Double {
        guard !ids.isEmpty else { return 0.0 }
        var sum: Double = 0
        var count: Int = 0
        for cid in ids {
            let p = await courseProgressFraction(courseId: cid)
            sum += p
            count += 1
        }
        guard count > 0 else { return 0.0 }
        let avg = sum / Double(count)
        let clamped = min(max(avg, 0.0), 1.0)
        // If there is explicit activity ids for the day but progress is ~0, keep a tiny visible signal.
        if clamped <= 0.0001 { return 0.02 }
        return clamped
    }

    /// adapter for CardDS: provide compact counters for a given date
    @MainActor
    func daySummary(for date: Date) -> CardDS_DaySummary? {
        // prefer the already-built weekSummary (cheap lookup by day)
        if let s = weekSummary.first(where: { isSameCalendarDay($0.date, date) }) {
            let id = UserSession.shared.dayKey(for: s.date)
            let events = UserSession.shared.snapshot.activityLog[id] ?? []
            let learned = events.filter { $0.kind == USActivityEventKind.stepLearned }.count
            let favs = events.filter { $0.kind == USActivityEventKind.favoriteAdded }.count
            let audio = 0

            // Decide overlay mode by calendar content:
            // - active day: there are active courses (weekSummary.progress has a tiny visible minimum) → return non-nil
            // - planned-only day: courses planned but no learning progress (progress ~0) → return nil to open add overlay
            // - empty day: no courses at all → nil
            if s.totalCourses == 0 { return nil }

            let isPlannedOnly = (s.progress <= 0.0001)
            if isPlannedOnly {
                // planned-only days:
                // - today/future: treat as "add" overlay (nil)
                // - past: treat as "missed" (non-nil) so UI opens activity overlay / renders scenario
                let todayStart = Self.bangkokCal.startOfDay(for: Date())
                let isPast = s.date < todayStart
                if s.isPlanned && isPast {
                    return CardDS_DaySummary(learned: learned, favs: favs, audioMinutes: audio)
                }
                return nil
            }

            return CardDS_DaySummary(learned: learned, favs: favs, audioMinutes: audio)
        }

        // fallback: build from UserSession activity log
        let id = UserSession.shared.dayKey(for: date)
        let events = UserSession.shared.snapshot.activityLog[id] ?? []
        let learned = events.filter { $0.kind == USActivityEventKind.stepLearned }.count
        let favs = events.filter { $0.kind == USActivityEventKind.favoriteAdded }.count
        let audio = 0 // no audio aggregation yet

        // If we have no counters at all, treat the day as empty.
        if learned == 0 && favs == 0 && audio == 0 {
            return nil
        }

        // Counters-only fallback is always "activity" (planned-only must be decided via weekSummary above).
        return CardDS_DaySummary(learned: learned, favs: favs, audioMinutes: audio)
    }

    // MARK: helpers (scaffolding)
    private func last7Days(endingAt ref: Date) -> [Date] {
        // canonical UI range: today -3 ... today +3 (Bangkok day)
        let cal = Self.bangkokCal
        let center = cal.startOfDay(for: ref)
        return (-3...3).compactMap { delta in
            cal.date(byAdding: .day, value: delta, to: center)
        }
    }

    private func isoDayId(_ date: Date) -> String {
        Self.isoDayFormatter.string(from: date)
    }

    // Helper to compare if two dates are the same calendar day.
    private func isSameCalendarDay(_ a: Date, _ b: Date) -> Bool {
        let cal = Self.bangkokCal
        return cal.isDate(cal.startOfDay(for: a), inSameDayAs: cal.startOfDay(for: b))
    }

    // The following providers intentionally return zeros/empty data.
    // They will be wired to real sources in subsequent micro-steps (M2+).
    private func dailyLearnedCount(on date: Date) async -> Int {
        0
    }
    private func dailyFavoritesCount(on date: Date) async -> Int {
        0
    }
    private func dailyAudioMinutes(on _: Date) async -> Int { 0 }
    @MainActor
    private func dailyProgress(on date: Date) async -> Double {
        let day = Self.bangkokCal.startOfDay(for: date)
        let ids = await courseIds(for: day, limit: Int.max)
        return await dailyProgressFromActiveIds(ids)
    }

    private func dailyUniqueItemsCount(on date: Date) async -> Int {
        // Use today's cached daily picks; historical aggregation will be added in later steps.
        if isSameCalendarDay(date, Date()) {
            invalidateDailyCacheIfDayChanged()
            // ensure cache is populated at least once
            if dailyKeysCache.isEmpty {
                let keys = await StepData.shared.dailyPicksKeys(count: 5)
                dailyKeysCache = keys.map { k in
                    let r = DailyPicksPayload.Ref(courseId: k.courseId, lessonId: k.lessonId, index: k.index)
                    return (ref: r, item: k.item)
                }
            }
            return dailyKeysCache.count
        }
        return 0
    }

    private func dailyTopCoursesTitles(on date: Date, limit: Int) async -> [String] {
        guard limit > 0 else { return [] }
        let day = Self.bangkokCal.startOfDay(for: date)
        let ids = await UserSession.shared.courseIds(on: day)
        guard !ids.isEmpty else { return [] }

        var out: [String] = []
        out.reserveCapacity(min(ids.count, limit))
        for cid in ids {
            out.append(await shortCourseName(cid))
            if out.count == limit { break }
        }
        return out
    }


    /// ids of courses that were active on a given day.
    /// mvp: returns real data only for today (derived from stable daily cache).
    @MainActor
    func courseIds(for date: Date, limit: Int = 10) async -> [String] {
        guard limit > 0 else { return [] }
        let day = Self.bangkokCal.startOfDay(for: date)
        let all = await UserSession.shared.courseIds(on: day)
        guard !all.isEmpty else { return [] }

        // DO NOT drop zero-progress courses. If the course is recorded in dayCourses, it counts as activity for that day.
        // We only sort by progress to keep "most relevant" first.
        var scored: [(String, Double)] = []
        scored.reserveCapacity(all.count)
        for cid in all {
            let p = await courseProgressFraction(courseId: cid)
            scored.append((cid, p))
        }
        scored.sort { $0.1 > $1.1 }

        let ids = scored.map { $0.0 }
        if ids.count <= limit { return ids }
        return Array(ids.prefix(limit))
    }

    /// display titles for courses that were active on a given day.
    /// uses LessonsManager titles; falls back to raw id if title is missing.
    @MainActor
    func courseTitles(for date: Date, limit: Int = 10) async -> [String] {
        let ids = await courseIds(for: date, limit: limit)
        guard !ids.isEmpty else { return [] }
        return await withTaskGroup(of: String.self) { group in
            for cid in ids {
                group.addTask { [cid] in
                    await self.shortCourseName(cid)
                }
            }
            var out: [String] = []
            out.reserveCapacity(ids.count)
            for await t in group { out.append(t) }
            return out
        }
    }

    /// first course title for a day (handy for calendar mini-cards).
    @MainActor
    func firstCourseTitle(for date: Date) async -> String? {
        (await courseTitles(for: date, limit: 1)).first
    }

    /// helper: whether there is any activity for a given day.
    @MainActor
    func hasCourses(on date: Date) async -> Bool {
        !(await UserSession.shared.courseIds(on: date)).isEmpty
    }
}



extension MainManager {
    @MainActor
    func reloadDailyCoursePicks() async {
        let limit = effectiveDailyCoursePicksLimit()
        await reloadDailyCoursePicks(count: limit)
    }

    @MainActor
    func reloadDailyCoursePicks(count: Int = 5) async {
        // keep today's course picks stable: rebuild only when cache is empty or day changed or count changes
        invalidateDailyCacheIfDayChanged()

        if dailyCourseCache.isEmpty || dailyCourseCacheCount != count {
            let all = CourseData.shared.featuredCourses
            if all.isEmpty {
                dailyCoursePicks = .empty
                return
            }
            let limited = Array(all.shuffled().prefix(count))
            dailyCourseCache = limited
            dailyCourseCacheCount = count
        }

        let payload = DailyCoursePicksPayload(courses: dailyCourseCache)
        dailyCoursePicks = payload

        #if DEBUG
        print("[MainManager] daily course picks → \(dailyCourseCache.count) courses")
        #endif
    }


    @MainActor
    func randomCourseForToday(isProUser: Bool) async -> Course? {
        let all = CourseData.shared.featuredCourses
        guard !all.isEmpty else { return nil }

        let snap = await UserSession.shared.snapshot
        let startedIds = snap.startedCourses

        let filtered = all.filter { course in
            let isProCourse = resolveIsProCourse(course)
            return isProUser || !isProCourse
        }

        guard !filtered.isEmpty else { return nil }

        let notStarted = filtered.filter { !startedIds.contains($0.id) }
        if let pick = notStarted.randomElement() {
            return pick
        }

        return filtered.randomElement()
    }
}
