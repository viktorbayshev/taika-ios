//
//  ProfileManager.swift
//  taika
//
//  Created by product on 19.12.2025.
//

import Foundation
import SwiftUI

@MainActor
final class ProfileManager: ObservableObject {

    // MARK: - shared

    static let shared = ProfileManager()

    // MARK: - state

    // ui selections (view binds to these)
    @Published var progressScopeKey: String = "courses" // "courses" | "lessons"
    @Published var selectedCourseMetricKey: String? = nil
    @Published var selectedLessonMetricKey: String? = nil

    // profile accordions
    @Published var studySelected: PDStudyPanel? = nil

    @Published var activitySelectedDayIndex: Int? = nil

    private var refreshTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    @Published private(set) var coursesMetrics: [PDMetric] = []
    @Published private(set) var lessonsMetrics: [PDMetric] = []

    // series: metricKey -> values
    @Published private(set) var weeklyByCourseMetric: [String: [Double]] = [:]
    @Published private(set) var last7ByCourseMetric: [String: [Double]] = [:]
    @Published private(set) var weeklyByLessonMetric: [String: [Double]] = [:]
    @Published private(set) var last7ByLessonMetric: [String: [Double]] = [:]

    // activity (7-day strip)
    @Published private(set) var activityWeekDays: [PDActivityDay] = []

    // backward-compat alias (remove once all views are migrated)
    @Published private(set) var activityDays: [PDActivityDay] = []

    // MARK: - init

    private init() {
        // keep Profile in sync with underlying session/progress changes
        let nc = NotificationCenter.default

        observers.append(
            nc.addObserver(forName: Notification.Name("UserSessionActivityDidChange"), object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
        )

        observers.append(
            nc.addObserver(forName: .init("CoursePlanDidChange"), object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
        )

        observers.append(
            nc.addObserver(forName: .init("FavoritesDidChange"), object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
        )

        observers.append(
            nc.addObserver(forName: .init("stepProgressDidChange"), object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
        )
    }

    // MARK: - public

    func setProgressScopeKey(_ key: String) {
        progressScopeKey = key
    }

    func selectCourseMetric(_ key: String) {
        selectedCourseMetricKey = key
    }

    func selectLessonMetric(_ key: String) {
        selectedLessonMetricKey = key
    }

    func selectStudyPanel(_ panel: PDStudyPanel?) {
        studySelected = panel
    }

    func selectActivityDay(index: Int?) {
        activitySelectedDayIndex = index
    }

    /// call on appear (and on any external “did change” triggers)
    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            // tiny coalescing to avoid multiple publishes per frame when several triggers fire
            try? await Task.sleep(nanoseconds: 25_000_000)
            if Task.isCancelled { return }
            await self.rebuildAll()
        }
    }

    // MARK: - build

    private func rebuildAll() async {
        await rebuildActivity()
        await rebuildProgress()
    }

    private func rebuildProgress() async {
        // courses known to the user (best-effort)
        let allCourseIds = UserSession.shared.profileAllKnownCourseIds()

        // 1) metrics (selectors)
        // keep the list small and stable – keys are used as dictionary keys for series.
        let cm: [PDMetric] = await buildCourseMetrics(courseIds: allCourseIds)
        let lm: [PDMetric] = await buildLessonMetrics(courseIds: allCourseIds)

        // keep selection keys valid (first metric by default)
        if selectedCourseMetricKey == nil || !(cm.contains { $0.key == selectedCourseMetricKey }) {
            selectedCourseMetricKey = cm.first?.key
        }
        if selectedLessonMetricKey == nil || !(lm.contains { $0.key == selectedLessonMetricKey }) {
            selectedLessonMetricKey = lm.first?.key
        }

        // 2) series (7-day)
        // derive series from persisted 7-day activity (single source of truth) so charts match reality.
        // NOTE: true per-day progress history is not persisted yet; we map series to activity signals.
        let dayKeys: [String] = {
            if !activityWeekDays.isEmpty {
                return activityWeekDays.map { $0.key }
            }
            // fallback (should match UserSession logic)
            let cal = UserSession.bangkokCal
            let today = cal.startOfDay(for: Date())
            return stride(from: 6, through: 0, by: -1).map {
                let d = cal.date(byAdding: .day, value: -$0, to: today) ?? today
                return UserSession.shared.dayKey(for: d)
            }
        }()

        // raw signals
        let eventsByDay: [Int] = dayKeys.map { UserSession.shared.snapshot.activityLog[$0]?.count ?? 0 }
        let coursesByDay: [Int] = dayKeys.map { UserSession.shared.snapshot.dayCourses[$0]?.count ?? 0 }
        let lessonEventsByDay: [Int] = dayKeys.map {
            let events = UserSession.shared.snapshot.activityLog[$0] ?? []
            return events.reduce(0) { $0 + ($1.lessonId == nil ? 0 : 1) }
        }

        // normalize helpers
        func norm(_ n: Int, maxValue: Int) -> Double {
            guard maxValue > 0 else { return 0 }
            return min(Swift.max(Double(n) / Double(maxValue), 0), 1)
        }

        var activity01: [Double] = eventsByDay.map { norm($0, maxValue: 4) }
        var courses01: [Double] = coursesByDay.map { norm($0, maxValue: 4) }
        var lessons01: [Double] = lessonEventsByDay.map { norm($0, maxValue: 4) }

        // if there is no activity history yet, fall back to stable current progress metrics
        // (prevents tap -> “all zeros” when series dictionaries resolve but inputs are empty)
        let hasAnySignal = (eventsByDay.contains { $0 > 0 }) || (coursesByDay.contains { $0 > 0 }) || (lessonEventsByDay.contains { $0 > 0 })
        if !hasAnySignal {
            let courseProgress = await currentCourseMetricValue(metricKey: "course_progress", courseIds: allCourseIds)
            let coursesCount = await currentCourseMetricValue(metricKey: "courses_count", courseIds: allCourseIds)
            let lessonsDone = await currentLessonMetricValue(metricKey: "lessons_done", courseIds: allCourseIds)

            activity01 = Array(repeating: min(max(courseProgress, 0), 1), count: 7)
            courses01 = Array(repeating: min(max(coursesCount, 0), 1), count: 7)
            lessons01 = Array(repeating: min(max(lessonsDone, 0), 1), count: 7)
        }

        var wCourse: [String: [Double]] = [:]
        var lCourse: [String: [Double]] = [:]
        var wLesson: [String: [Double]] = [:]
        var lLesson: [String: [Double]] = [:]

        for m in cm {
            switch m.key {
            case "course_progress":
                wCourse[m.key] = activity01
                lCourse[m.key] = activity01
            case "courses_count":
                wCourse[m.key] = courses01
                lCourse[m.key] = courses01
            default:
                wCourse[m.key] = activity01
                lCourse[m.key] = activity01
            }
        }

        for m in lm {
            switch m.key {
            case "lessons_done":
                wLesson[m.key] = lessons01
                lLesson[m.key] = lessons01
            default:
                // if a new metric appears but we have no dedicated mapping yet,
                // at least keep a non-empty series.
                wLesson[m.key] = lessons01
                lLesson[m.key] = lessons01
            }
        }

        // commit in one place to minimize UI churn
        self.coursesMetrics = cm
        self.lessonsMetrics = lm

        self.weeklyByCourseMetric = wCourse
        self.last7ByCourseMetric = lCourse
        self.weeklyByLessonMetric = wLesson
        self.last7ByLessonMetric = lLesson
    }

    private func rebuildActivity() async {
        // pull directly from UserSession (single source of truth)
        let days = UserSession.shared.profileActivityWeekDays()

        if let idx = activitySelectedDayIndex {
            if days.isEmpty {
                activitySelectedDayIndex = nil
            } else {
                activitySelectedDayIndex = min(max(idx, 0), days.count - 1)
            }
        }

        self.activityWeekDays = days
        self.activityDays = days
    }

    private static func intensity01(fromCount c: Int) -> Double {
        if c <= 0 { return 0 }
        if c == 1 { return 0.25 }
        if c == 2 { return 0.5 }
        if c <= 4 { return 0.75 }
        return 1
    }

    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func isoDayKey(_ date: Date) -> String {
        isoDayFormatter.string(from: date)
    }

    deinit {
        let nc = NotificationCenter.default
        for o in observers {
            nc.removeObserver(o)
        }
        observers.removeAll()
    }

    // MARK: - metrics builders

    private func buildCourseMetrics(courseIds: [String]) async -> [PDMetric] {
        // stable keys; do not localize keys
        let overall = await overallCourseProgress(courseIds: courseIds)

        return [
            PDMetric(
                key: "course_progress",
                title: "прогресс",
                value7d: percentString(overall),
                delta7d: nil
            ),
            PDMetric(
                key: "courses_count",
                title: "курсы",
                value7d: String(courseIds.count),
                delta7d: nil
            )
        ]
    }

    private func buildLessonMetrics(courseIds: [String]) async -> [PDMetric] {
        let (done, total) = await overallLessonsDoneTotal(courseIds: courseIds)
        let value = total > 0 ? "\(done)/\(total)" : "0"

        return [
            PDMetric(
                key: "lessons_done",
                title: "уроки",
                value7d: value,
                delta7d: nil
            )
        ]
    }

    // MARK: - values (for series)

    private func currentCourseMetricValue(metricKey: String, courseIds: [String]) async -> Double {
        switch metricKey {
        case "course_progress":
            return await overallCourseProgress(courseIds: courseIds)
        case "courses_count":
            // normalize for charts
            return min(Double(courseIds.count) / 10.0, 1.0)
        default:
            return 0
        }
    }

    private func currentLessonMetricValue(metricKey: String, courseIds: [String]) async -> Double {
        switch metricKey {
        case "lessons_done":
            let (done, total) = await overallLessonsDoneTotal(courseIds: courseIds)
            guard total > 0 else { return 0 }
            return min(max(Double(done) / Double(total), 0), 1)
        default:
            return 0
        }
    }

    // MARK: - core aggregations

    private func overallCourseProgress(courseIds: [String]) async -> Double {
        guard !courseIds.isEmpty else { return 0 }

        var sum: Double = 0
        var count: Int = 0

        for cid in courseIds {
            let p = await ProgressManager.shared.progress(for: cid, lessonId: nil)
            sum += min(max(p, 0), 1)
            count += 1
        }

        guard count > 0 else { return 0 }
        return sum / Double(count)
    }

    private func overallLessonsDoneTotal(courseIds: [String]) async -> (done: Int, total: Int) {
        var done = 0
        var total = 0

        for cid in courseIds {
            let lessons = LessonsData.shared.lessons(for: cid)
            total += lessons.count

            // best-effort: derive done from course progress fraction (no per-lesson state here)
            let p = await ProgressManager.shared.progress(for: cid, lessonId: nil)
            let clamped = min(max(p, 0), 1)
            done += Int(round(clamped * Double(lessons.count)))
        }

        return (done, total)
    }

    // MARK: - formatting

    private func percentString(_ v: Double) -> String {
        let clamped = min(max(v, 0), 1)
        return "\(Int(round(clamped * 100)))%"
    }
}


// MARK: - user session helpers (profile)

extension UserSession {

    private static let profileDayFormatterUTC: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func profileISODateKey(_ date: Date) -> String {
        Self.profileDayFormatterUTC.string(from: date)
    }

    
    /// 7-day activity strip (oldest -> newest) derived from persisted session.
    /// This is the single source of truth for Profile DS (intensity + event lines).
    func profileActivityWeekDays() -> [PDActivityDay] {
        let calendar = Self.bangkokCal
        let today = calendar.startOfDay(for: Date())

        var days: [PDActivityDay] = []
        days.reserveCapacity(7)

        for offset in stride(from: 6, through: 0, by: -1) {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let key = bangkokDayKey(for: day)

            // intensity: prefer activity log count; fallback to dayCourses count.
            let events = snapshot.activityLog[key] ?? []
            let courses = snapshot.dayCourses[key] ?? []

            let intensity: Double = {
                let n = events.count
                if n <= 0 {
                    return courses.isEmpty ? 0 : 0.25
                }
                if n == 1 { return 0.25 }
                if n == 2 { return 0.5 }
                if n <= 4 { return 0.75 }
                return 1
            }()

            // lines: minimal “diary” style; UI can render nicer templates later.
            var lines: [String] = []
            if !events.isEmpty {
                // keep short and stable; no weekday names here.
                for e in events.prefix(4) {
                    lines.append(profileLine(for: e))
                }
                if events.count > 4 {
                    lines.append("+\(events.count - 4)")
                }
            } else if !courses.isEmpty {
                lines.append("курсов: \(courses.count)")
            }

            days.append(
                PDActivityDay(
                    key: key,
                    title: "",
                    intensity: intensity,
                    lines: lines,
                    events: []
                )
            )
        }

        return days
    }

    private func profileLine(for e: USActivityEvent) -> String {
        // Keep this resilient: UserSession event schema can evolve.
        // Prefer stable identifiers when present.

        let tag: String
        switch e.kind {
        case .speakerOpened:
            tag = "speaker • открыт"
        case .speakerAttemptCompleted:
            tag = "speaker • попытка"
        default:
            tag = String(describing: e.kind)
        }

        if let cid = e.courseId, let lid = e.lessonId {
            return "\(tag) • \(cid) / \(lid)"
        }
        if let cid = e.courseId {
            return "\(tag) • \(cid)"
        }
        if let lid = e.lessonId {
            return "\(tag) • \(lid)"
        }
        return tag
    }
}
