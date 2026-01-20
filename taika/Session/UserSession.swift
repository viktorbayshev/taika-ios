//
//  UserSession.swift
//  taika
//
//  Created by product on 13.09.2025.
//

import Foundation
import Combine

extension Notification.Name {
    static let usStepLearnedSetDidChange = Notification.Name("us.stepLearnedSetDidChange")
    static let usCourseProgressDidReset = Notification.Name("us.courseProgressDidReset")
    static let usLessonProgressDidReset = Notification.Name("us.lessonProgressDidReset")
    static let usActivityLogDidChange = Notification.Name("us.activityLogDidChange")
    static let activityDidChange = Notification.Name("ActivityDidChange")
}

/// Тип избранного для простого аудита
public enum USFavoriteKind: String, Codable { case course, card, hack }

// MARK: - activity log (profile "моя активность")

public enum USActivityEventKind: String, Codable {
    case coursePlannedAdded
    case coursePlannedRemoved
    case courseOpened
    case lessonOpened
    case stepLearned
    case stepUnlearned
    case favoriteAdded
    case favoriteRemoved

    // speaker (pro)
    case speakerOpened
    case speakerAttemptCompleted
}

public struct USActivityEvent: Codable, Equatable, Hashable {
    public var id: String
    public var kind: USActivityEventKind
    public var ts: Date

    public var courseId: String?
    public var lessonId: String?
    public var stepIndex: Int?
    public var refId: String?

    public init(
        id: String = UUID().uuidString,
        kind: USActivityEventKind,
        ts: Date = Date(),
        courseId: String? = nil,
        lessonId: String? = nil,
        stepIndex: Int? = nil,
        refId: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.ts = ts
        self.courseId = courseId
        self.lessonId = lessonId
        self.stepIndex = stepIndex
        self.refId = refId
    }
}

public typealias USDailyActivityLog = [String: [USActivityEvent]]

/// Снимок состояния пользовательской сессии (персистится в UserDefaults)
public struct USSnapshot: Codable, Equatable {
    // Ключевые идентификаторы
    public var startedCourses: Set<String> = []                         // courseId
    public var startedLessons: [String: Set<String>] = [:]              // courseId -> {lessonId}
    public var completedLessons: [String: Set<String>] = [:]            // courseId -> {lessonId}

    // Шаги: learned индексы по уроку
    public var learnedSteps: [String: Set<Int>] = [:]                   // compound "courseId|lessonId" -> indices

    // Избранное (дублируем для аналитики; источником правды остаётся FavoriteManager)
    public var favorites: [USFavoriteKind: Set<String>] = [
        .course: [], .card: [], .hack: []
    ]

    // Сырой прогресс по урокам (для быстрых вычислений)
    public var lessonProgress: [String: [String: LessonProgress]] = [:] // courseId -> lessonId -> LessonProgress

    // дневная активность: yyyy-mm-dd -> {courseId}
    public var dayCourses: [String: Set<String>] = [:]

    // дневник активности: yyyy-mm-dd -> events
    public var activityLog: USDailyActivityLog = [:]

    // дневной план: yyyy-mm-dd -> {courseId}
    public var plannedDayCourses: [String: Set<String>] = [:]
    // last planned course (for UX ordering in add overlay): yyyy-mm-dd -> courseId
    public var plannedDayLastCourseId: [String: String] = [:]

    // Последние активные сущности
    public var lastCourseId: String? = nil                         // последний открытый курс
    public var lastLessonByCourse: [String: String] = [:]          // courseId -> last lessonId
    public var lastStepByLesson: [String: Int] = [:]               // "courseId|lessonId" -> last step index

    // Метаданные
    public var sessionStartedAt: Date = Date()
    public var lastEventAt: Date = Date()

    // подписка (source of truth for gating)
    public var isProUser: Bool = false
}

/// Единая точка учёта пользовательских действий (читает менеджеров и хранит снэпшот)
@MainActor public final class UserSession: ObservableObject {
    public static let shared = UserSession()

    @Published public private(set) var snapshot: USSnapshot = USSnapshot()
    /// Server/entitlement-driven PRO flag (observable). Nil means "unknown / not resolved yet".
    @Published public private(set) var isProFromServer: Bool? = nil

    private let storeKey = "UserSession.snapshot.v1"

    // MARK: - Thailand canonical calendar (match MainManager/MainView)
    private static let bangkokTZ: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    public static let bangkokCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = bangkokTZ
        return cal
    }()

    // legacy (older builds): UTC day keys
    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal
    }()


    private func dayKey(for date: Date, cal: Calendar) -> String {
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public func bangkokDayKey(for date: Date) -> String {
        dayKey(for: date, cal: Self.bangkokCal)
    }

    /// Canonical day key used by `snapshot.activityLog` and `snapshot.dayCourses`.
    /// Public so UI managers can lookup per-day activity without duplicating key logic.
    public func dayKey(for date: Date) -> String {
        bangkokDayKey(for: Self.bangkokCal.startOfDay(for: date))
    }

    /// Planned-course storage key candidates.
    /// Canonical is Bangkok dayKey; legacy is UTC-based key used by older builds.
    private func plannedKeyCandidates(for day: Date) -> (canonical: String, legacy: String) {
        let canonicalDay = Self.bangkokCal.startOfDay(for: day)
        let canonical = bangkokDayKey(for: canonicalDay)

        // legacy: UTC start-of-day for the same wall-clock day input (older logic)
        let legacyDay = Self.utcCal.startOfDay(for: day)
        let legacy = dayKey(for: legacyDay, cal: Self.utcCal)

        return (canonical, legacy)
    }

    /// If we find legacy planned data, migrate it to canonical key (best-effort).
    private func migrateLegacyPlannedIfNeeded(for day: Date) {
        // Variant A: migration runs once in init/load (migrateLegacyPlannedAll()).
        // Keep this as a no-op to prevent mutations during view updates.
        return
    }

    /// One-time migration: move any legacy UTC planned keys into canonical Bangkok keys.
    /// Must run only during init/load (never from view getters).
    private func migrateLegacyPlannedAll() {
        guard !snapshot.plannedDayCourses.isEmpty else { return }

        var didChange = false

        // Copy to avoid mutating while iterating.
        let legacyMap = snapshot.plannedDayCourses
        for (key, set) in legacyMap {
            // Legacy keys are UTC-based yyyy-mm-dd; canonical is Bangkok-based yyyy-mm-dd.
            // If key already matches canonical storage (Bangkok), keep it.
            // If key is legacy but canonical already exists, just drop legacy.

            // Parse yyyy-mm-dd
            let parts = key.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]),
                  let m = Int(parts[1]),
                  let d = Int(parts[2])
            else { continue }

            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = d

            // Legacy key was produced in UTC calendar.
            guard let legacyDay = Self.utcCal.date(from: comps) else { continue }

            // Canonical key uses Bangkok calendar start-of-day.
            let canonicalDay = Self.bangkokCal.startOfDay(for: legacyDay)
            let canonicalKey = bangkokDayKey(for: canonicalDay)

            if canonicalKey == key {
                // already canonical
                continue
            }

            if snapshot.plannedDayCourses[canonicalKey] == nil {
                snapshot.plannedDayCourses[canonicalKey] = set
            }

            // Migrate last planned course id if present
            if let last = snapshot.plannedDayLastCourseId[key] {
                if snapshot.plannedDayLastCourseId[canonicalKey] == nil {
                    snapshot.plannedDayLastCourseId[canonicalKey] = last
                }
                snapshot.plannedDayLastCourseId.removeValue(forKey: key)
            }

            snapshot.plannedDayCourses.removeValue(forKey: key)
            didChange = true
        }

        if didChange {
            snapshot.lastEventAt = Date()
            saveDebounced()
        }
    }

    private func legacyDayKeys(for date: Date) -> [String] {
        // canonical: thailand only (avoid cross-day aliasing that creates duplicates)
        [bangkokDayKey(for: date)]
    }

    private func removeLegacyKeysIfNeeded(_ dict: inout [String: Set<String>], for date: Date, keep keyToKeep: String) {
        // legacy disabled: keep only the canonical key
        for k in dict.keys where k != keyToKeep {
            // do nothing here; we do not want to wipe other days
            // (call sites pass the current day key; other keys may be other days)
        }
    }

    private func resolveDaySet(_ dict: [String: Set<String>], day: Date) -> Set<String> {
        let d = Self.bangkokCal.startOfDay(for: day)
        let key = bangkokDayKey(for: d)
        return dict[key] ?? []
    }
    private var bag = Set<AnyCancellable>()
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        load()
        migrateLegacyPlannedAll()
        // hydrate observable PRO flag from persisted snapshot
        isProFromServer = snapshot.isProUser
        wireManagers()
    }

    // MARK: - Wiring

    /// Подписки на менеджеры (изменение прогресса/избранного)
    private func wireManagers() {
        // Подписка на прогресс уроков
        LessonsManager.shared.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progressMap in
                guard let self else { return }
                self.objectWillChange.send()
                self.snapshot.lessonProgress = progressMap
                // Обновляем started/completed множества для быстрого доступа
                var started: [String: Set<String>] = self.snapshot.startedLessons
                var completed: [String: Set<String>] = self.snapshot.completedLessons
                for (courseId, lessons) in progressMap {
                    var startedSet = started[courseId] ?? []
                    var completedSet = completed[courseId] ?? []
                    for (lessonId, p) in lessons {
                        if p.learned > 0 { startedSet.insert(lessonId) }
                        switch p.status {
                        case .completed: completedSet.insert(lessonId)
                        default: completedSet.remove(lessonId)
                        }
                    }
                    started[courseId] = startedSet
                    completed[courseId] = completedSet
                    if !startedSet.isEmpty { self.snapshot.startedCourses.insert(courseId) }
                }
                self.snapshot.startedLessons = started
                self.snapshot.completedLessons = completed
                self.touchAndSave()
            }
            .store(in: &bag)

        // Подписка на избранное: классификация по id и маркеру "hack:" в phonetic
        FavoriteManager.shared.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.objectWillChange.send()
                var c: Set<String> = []
                var s: Set<String> = []
                var h: Set<String> = []
                for it in items {
                    // FavoriteItem has no sourceId; rely on normalized id only
                    // if fid.isEmpty { continue } // (keep fid as-is)
                    let fid = it.id

                    // Detect hacks either by id prefix or by phonetic marker "hack:"
                    let phon = it.phonetic.lowercased()
                    let isHack = fid.hasPrefix("hack:") || phon.hasPrefix("hack:")

                    if fid.hasPrefix("course:") {
                        c.insert(fid)
                        continue
                    }

                    if isHack {
                        // normalize hack id to start with "hack:" for consistent lookups
                        var hid = fid
                        if !hid.hasPrefix("hack:") {
                            if hid.hasPrefix("card:") {
                                hid = "hack:" + hid.dropFirst("card:".count)
                            } else if hid.hasPrefix("step:") {
                                hid = "hack:" + hid
                            } else {
                                hid = "hack:" + hid
                            }
                        }
                        h.insert(String(hid))
                        continue
                    }

                    // default: treat as card/step
                    if fid.hasPrefix("card:") || fid.hasPrefix("step:") {
                        s.insert(fid)
                    }
                }
                self.snapshot.favorites[.course] = c
                self.snapshot.favorites[.card]   = s
                self.snapshot.favorites[.hack]   = h
                self.touchAndSave()
            }
            .store(in: &bag)

        // react to admin full reset (ProfileView posts "AppResetAll")
        NotificationCenter.default.addObserver(forName: .init("AppResetAll"), object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.objectWillChange.send()
            self.snapshot = USSnapshot()
            self.save()
        }

        // unified activity logging (MainManager -> UserSession)
        NotificationCenter.default.addObserver(forName: .init("ActivityLogRequested"), object: nil, queue: .main) { [weak self] n in
            guard let self else { return }
            let ui = n.userInfo ?? [:]

            let kindRaw = (ui["kind"] as? String) ?? ""
            let courseId = ui["courseId"] as? String
            let lessonId = ui["lessonId"] as? String
            let stepIndex = ui["stepIndex"] as? Int
            let refId = ui["refId"] as? String
            let ts = (ui["day"] as? Date) ?? Date()

            // keep "last opened" pointers in sync with app navigation events
            // (Speaker "current" filter relies on these; without them it falls back to lesson 1)
            if kindRaw == "courseOpened", let cid = courseId {
                self.objectWillChange.send()
                self.snapshot.lastCourseId = cid
                self.snapshot.startedCourses.insert(cid)
                self.snapshot.lastEventAt = Date()
                self.saveDebounced()
            }

            if kindRaw == "lessonOpened", let cid = courseId, let lid = lessonId {
                self.objectWillChange.send()
                self.snapshot.lastCourseId = cid
                self.snapshot.lastLessonByCourse[cid] = lid
                self.snapshot.startedCourses.insert(cid)
                self.snapshot.startedLessons[cid, default: []].insert(lid)
                self.snapshot.lastEventAt = Date()
                self.saveDebounced()
            }

            if kindRaw == "stepProgressChanged", let cid = courseId, let lid = lessonId, let idx = stepIndex {
                // best-effort: remember last interacted step for the lesson
                self.objectWillChange.send()
                self.snapshot.lastCourseId = cid
                self.snapshot.lastLessonByCourse[cid] = lid
                let key = self.compoundLessonKey(courseId: cid, lessonId: lid)
                self.snapshot.lastStepByLesson[key] = idx
                self.snapshot.lastEventAt = Date()
                self.saveDebounced()
            }

            func k(_ v: Bool, yes: USActivityEventKind, no: USActivityEventKind) -> USActivityEventKind { v ? yes : no }

            let kind: USActivityEventKind? = {
                switch kindRaw {
                case "coursePlannedAdded": return .coursePlannedAdded
                case "coursePlannedRemoved": return .coursePlannedRemoved
                case "courseOpened": return .courseOpened
                case "lessonOpened": return .lessonOpened
                case "stepProgressChanged":
                    let isLearned = (ui["isLearned"] as? Bool) ?? false
                    return k(isLearned, yes: .stepLearned, no: .stepUnlearned)
                case "favoriteToggled":
                    let isFavorite = (ui["isFavorite"] as? Bool) ?? false
                    return k(isFavorite, yes: .favoriteAdded, no: .favoriteRemoved)
                default:
                    return nil
                }
            }()

            guard let kind else { return }
            self.logActivity(kind, courseId: courseId, lessonId: lessonId, stepIndex: stepIndex, refId: refId, ts: ts)
        }

        // learned steps sync (source can be Step/Progress layers)
        // keep `snapshot.learnedSteps` populated so features like Speaker can build queues from real learned data.
        let learnedSetNames: [Notification.Name] = [
            .usStepLearnedSetDidChange,
            Notification.Name("stepLearnedSetDidChange")
        ]

        for name in learnedSetNames {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in
                guard let self else { return }
                let ui = n.userInfo ?? [:]
                guard let courseId = ui["courseId"] as? String,
                      let lessonId = ui["lessonId"] as? String
                else { return }

                let learnedArr = (ui["learned"] as? [Int]) ?? []
                let key = self.compoundLessonKey(courseId: courseId, lessonId: lessonId)

                self.objectWillChange.send()
                self.snapshot.learnedSteps[key] = Set(learnedArr)
                if !learnedArr.isEmpty {
                    self.snapshot.startedCourses.insert(courseId)
                    self.snapshot.startedLessons[courseId, default: []].insert(lessonId)
                }
                self.snapshot.lastEventAt = Date()
                self.saveDebounced()
            }
        }
    }

    // MARK: - Explicit event API (можно вызывать из StepManager и других слоёв)

    /// Remove learned sets for a whole course or a single lesson. Matches multiple key formats.
    private func purgeLearned(courseId: String, lessonId: String? = nil) {
        let sepVariants = ["|", "/", ":", "#"]
        var lessonIdsToNotify: [String] = []

        if let lid = lessonId {
            // Remove exact keys for all known separators
            for sep in sepVariants {
                snapshot.learnedSteps.removeValue(forKey: "\(courseId)\(sep)\(lid)")
            }
            lessonIdsToNotify = [lid]
        } else {
            // Collect and remove any learned keys that look like this course
            let toRemove = snapshot.learnedSteps.keys.filter { key in
                sepVariants.contains { sep in key.hasPrefix("\(courseId)\(sep)") }
            }
            for key in toRemove { snapshot.learnedSteps.removeValue(forKey: key) }

            // Try to extract lessonIds from removed keys for granular notifications
            lessonIdsToNotify = toRemove.compactMap { key in
                for sep in sepVariants {
                    if let range = key.range(of: "\(courseId)\(sep)") {
                        let after = key[range.upperBound...]
                        return String(after)
                    }
                }
                return nil
            }
        }

        // Notify listeners that learned set is empty per lesson (some UIs ignore wildcards)
        for lid in lessonIdsToNotify {
            NotificationCenter.default.post(
                name: .usStepLearnedSetDidChange,
                object: nil,
                userInfo: ["courseId": courseId, "lessonId": lid, "learned": []]
            )
            NotificationCenter.default.post(
                name: Notification.Name("stepLearnedSetDidChange"),
                object: nil,
                userInfo: ["courseId": courseId, "lessonId": lid, "learned": []]
            )
        }
    }

    /// Отметить выученность шага (индекс в уроке)
    public func setStepLearned(courseId: String, lessonId: String, index: Int, isLearned: Bool) {
        objectWillChange.send()
        let key = compoundLessonKey(courseId: courseId, lessonId: lessonId)
        var set = snapshot.learnedSteps[key] ?? []
        if isLearned {
            set.insert(index)
            appendActivity(.stepLearned, courseId: courseId, lessonId: lessonId, stepIndex: index, refId: nil, ts: Date(), emitWillChange: false, save: false)
        } else {
            set.remove(index)
            appendActivity(.stepUnlearned, courseId: courseId, lessonId: lessonId, stepIndex: index, refId: nil, ts: Date(), emitWillChange: false, save: false)
            // if user removed the last learned step in the whole course,
            // drop today's day activity to avoid “phantom active” days.
            if set.isEmpty {
                snapshot.learnedSteps[key] = set // keep in sync for the helper below
                if !courseHasAnyLearnedSteps(courseId) {
                    let todayKey = bangkokDayKey(for: Self.bangkokCal.startOfDay(for: Date()))
                    if var daySet = snapshot.dayCourses[todayKey], daySet.contains(courseId) {
                        daySet.remove(courseId)
                        snapshot.dayCourses[todayKey] = daySet
                    }
                }
            }
        }
        snapshot.learnedSteps[key] = set
        snapshot.startedCourses.insert(courseId)
        snapshot.startedLessons[courseId, default: []].insert(lessonId)
        snapshot.lastEventAt = Date()
        saveDebounced()
        NotificationCenter.default.post(
            name: .usStepLearnedSetDidChange,
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId,
                "learned": Array(set)
            ]
        )
        NotificationCenter.default.post(
            name: Notification.Name("stepLearnedSetDidChange"),
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId,
                "learned": Array(set)
            ]
        )
    }

    /// Зафиксировать явный старт курса/урока
    public func markStarted(courseId: String, lessonId: String? = nil) {
        objectWillChange.send()
        snapshot.startedCourses.insert(courseId)
        if let lid = lessonId { snapshot.startedLessons[courseId, default: []].insert(lid) }
        touchAndSave()
    }

    /// Явно пометить активный курс
    public func markActive(courseId: String) {
        objectWillChange.send()
        snapshot.lastCourseId = courseId
        snapshot.startedCourses.insert(courseId)
        touchAndSave()
    }

    /// Явно пометить активный урок в курсе
    public func markActive(courseId: String, lessonId: String) {
        objectWillChange.send()
        snapshot.lastCourseId = courseId
        snapshot.lastLessonByCourse[courseId] = lessonId
        snapshot.startedCourses.insert(courseId)
        snapshot.startedLessons[courseId, default: []].insert(lessonId)
        touchAndSave()
    }

    /// Явно пометить активный шаг (индекс в уроке)
    public func markActive(courseId: String, lessonId: String, stepIndex: Int) {
        objectWillChange.send()
        snapshot.lastCourseId = courseId
        snapshot.lastLessonByCourse[courseId] = lessonId
        let key = compoundLessonKey(courseId: courseId, lessonId: lessonId)
        snapshot.lastStepByLesson[key] = max(snapshot.lastStepByLesson[key] ?? 0, stepIndex)
        snapshot.startedCourses.insert(courseId)
        snapshot.startedLessons[courseId, default: []].insert(lessonId)
        touchAndSave()
    }

    public func lastLessonId(for courseId: String) -> String? {
        snapshot.lastLessonByCourse[courseId]
    }

    public func lastStepIndex(courseId: String, lessonId: String) -> Int? {
        snapshot.lastStepByLesson[compoundLessonKey(courseId: courseId, lessonId: lessonId)]
    }

    /// Вернуть множество выученных индексов по уроку (для гидрации вью)
    public func learnedSet(courseId: String, lessonId: String) -> Set<Int> {
        let key = compoundLessonKey(courseId: courseId, lessonId: lessonId)
        return snapshot.learnedSteps[key] ?? []
    }

    /// Сброс всей сессии (для отладки/выхода из аккаунта)
    public func reset() {
        objectWillChange.send()
        snapshot = USSnapshot()
        snapshot.activityLog.removeAll()
        isProFromServer = snapshot.isProUser
        save()
    }

    /// Сбросить прогресс по конкретному курсу (без влияния на избранное)
    public func resetCourseProgress(courseId: String) {
        objectWillChange.send()
        // collect existing lesson IDs for notifications
        let prevLessonIds = snapshot.lessonProgress[courseId].map { Array($0.keys) } ?? []
        // 1) попросим менеджер уроков обнулить своё состояние
        LessonsManager.shared.resetCourseProgress(courseId: courseId)

        // 2) подчистим слепок UserSession
        snapshot.startedCourses.remove(courseId)
        snapshot.startedLessons[courseId] = Set<String>()
        snapshot.completedLessons[courseId] = Set<String>()
        snapshot.lessonProgress[courseId] = [:]

        // 3) удалим learned индексы по всем урокам этого курса (включая разные форматы ключей)
        purgeLearned(courseId: courseId, lessonId: nil)

        // Remove this course from every day entry
        if !snapshot.dayCourses.isEmpty {
            for (k, v) in snapshot.dayCourses {
                if v.contains(courseId) {
                    var nv = v
                    nv.remove(courseId)
                    snapshot.dayCourses[k] = nv
                }
            }
        }
        // Remove this course from every planned day entry
        if !snapshot.plannedDayCourses.isEmpty {
            for (k, v) in snapshot.plannedDayCourses {
                if v.contains(courseId) {
                    var nv = v
                    nv.remove(courseId)
                    snapshot.plannedDayCourses[k] = nv
                }
            }
        }

        snapshot.lastEventAt = Date()
        save()
        objectWillChange.send()
        // Fire both a stable legacy signal (if someone still listens) and the new namespaced one.
        NotificationCenter.default.post(name: .courseProgressDidReset, object: nil, userInfo: ["courseId": courseId])
        NotificationCenter.default.post(name: .usCourseProgressDidReset, object: nil, userInfo: ["courseId": courseId])

        // Ensure Step views clear any local caches even if there were no learned keys persisted
        for lid in prevLessonIds {
            NotificationCenter.default.post(
                name: .usStepLearnedSetDidChange,
                object: nil,
                userInfo: ["courseId": courseId, "lessonId": lid, "learned": []]
            )
            NotificationCenter.default.post(
                name: Notification.Name("stepLearnedSetDidChange"),
                object: nil,
                userInfo: ["courseId": courseId, "lessonId": lid, "learned": []]
            )
        }

        #if DEBUG
        print("[UserSession] resetCourseProgress -> \(courseId)")
        #endif
    }

    /// Сбросить прогресс по конкретному уроку внутри курса
    public func resetLessonProgress(courseId: String, lessonId: String) {
        objectWillChange.send()

        // 1) попросим менеджер уроков обнулить состояние урока
        LessonsManager.shared.resetLessonProgress(courseId: courseId, lessonId: lessonId)

        // remove lesson progress entry from snapshot map (will be rehydrated from managers)
        snapshot.lessonProgress[courseId]?.removeValue(forKey: lessonId)

        // 3) удалим learned индексы по этому уроку (включая разные форматы ключей)
        purgeLearned(courseId: courseId, lessonId: lessonId)

        snapshot.lastEventAt = Date()
        save()
        objectWillChange.send()
        NotificationCenter.default.post(name: .lessonProgressDidReset, object: nil, userInfo: ["courseId": courseId, "lessonId": lessonId])
        NotificationCenter.default.post(name: .usLessonProgressDidReset, object: nil, userInfo: ["courseId": courseId, "lessonId": lessonId])

        // Ensure Step view clears local caches for this lesson
        NotificationCenter.default.post(
            name: .usStepLearnedSetDidChange,
            object: nil,
            userInfo: ["courseId": courseId, "lessonId": lessonId, "learned": []]
        )
        NotificationCenter.default.post(
            name: Notification.Name("stepLearnedSetDidChange"),
            object: nil,
            userInfo: ["courseId": courseId, "lessonId": lessonId, "learned": []]
        )

        #if DEBUG
        print("[UserSession] resetLessonProgress -> \(courseId)|\(lessonId)")
        #endif
    }

    /// Полный сброс всего прогресса (все курсы). Избранное не трогаем.
    public func resetAllProgress() {
        objectWillChange.send()
        // collect existing map to broadcast full clear
        let prevMap = snapshot.lessonProgress
        LessonsManager.shared.resetAllProgress()

        snapshot.startedCourses.removeAll()
        snapshot.startedLessons.removeAll()
        snapshot.completedLessons.removeAll()
        snapshot.lessonProgress.removeAll()
        snapshot.learnedSteps.removeAll()
        snapshot.dayCourses.removeAll()
        snapshot.plannedDayCourses.removeAll()
        snapshot.activityLog.removeAll()
        objectWillChange.send()

        snapshot.lastEventAt = Date()
        save()
        NotificationCenter.default.post(name: .courseProgressDidReset, object: nil, userInfo: ["courseId": "*"])
        NotificationCenter.default.post(name: .usCourseProgressDidReset, object: nil, userInfo: ["courseId": "*"])

        // Broadcast clear for every known (courseId, lessonId)
        for (cid, map) in prevMap {
            for (lid, _) in map {
                NotificationCenter.default.post(
                    name: .usStepLearnedSetDidChange,
                    object: nil,
                    userInfo: ["courseId": cid, "lessonId": lid, "learned": []]
                )
                NotificationCenter.default.post(
                    name: Notification.Name("stepLearnedSetDidChange"),
                    object: nil,
                    userInfo: ["courseId": cid, "lessonId": lid, "learned": []]
                )
            }
        }

        #if DEBUG
        print("[UserSession] resetAllProgress")
        #endif
    }

    // MARK: - Subscription

    public var isProUser: Bool {
        snapshot.isProUser
    }

    public func setProUser(_ value: Bool) {
        objectWillChange.send()
        snapshot.isProUser = value
        isProFromServer = value
        touchAndSave()
    }

    // MARK: - Derived helpers

    public func courseStatus(_ courseId: String) -> LessonStatus {
        let lessons = snapshot.lessonProgress[courseId] ?? [:]
        guard !lessons.isEmpty else { return .locked }
        let all = lessons.values
        if all.allSatisfy({ $0.status == .completed }) { return .completed }
        if all.contains(where: { $0.learned > 0 }) { return .inProgress }
        return .locked
    }


    // MARK: - Favorites sync (from FavoriteManager)

    /// Полная замена избранного из FavoriteManager (идемпотентно)
    public func setFavorites(course: Set<String>, cards: Set<String>, hacks: Set<String>) {
        objectWillChange.send()
        snapshot.favorites[.course] = course
        snapshot.favorites[.card]   = cards
        snapshot.favorites[.hack]   = hacks
        touchAndSave()
    }

    /// Быстрая проверка: есть ли элемент в избранном по его id (по префиксу)
    public func isFavoriteId(_ id: String) -> Bool {
        if id.hasPrefix("course:") { return snapshot.favorites[.course]?.contains(id) ?? false }
        if id.hasPrefix("hack:")   { return snapshot.favorites[.hack]?.contains(id)   ?? false }
        // treat both `card:` and legacy `step:` as card bucket
        if id.hasPrefix("card:") || id.hasPrefix("step:") {
            return snapshot.favorites[.card]?.contains(id) ?? false
        }
        return false
    }

    // MARK: - Profile aggregation helpers

    /// Union of all known course ids across session state (started/progress/planned/activity).
    public func profileAllKnownCourseIds() -> [String] {
        var ids: Set<String> = []

        // started / progress
        ids.formUnion(snapshot.startedCourses)
        ids.formUnion(snapshot.lessonProgress.keys)

        // planned courses (all days)
        for (_, set) in snapshot.plannedDayCourses {
            ids.formUnion(set)
        }

        // daily activity courses (all days)
        for (_, set) in snapshot.dayCourses {
            ids.formUnion(set)
        }

        // activity log courses (all days)
        for (_, events) in snapshot.activityLog {
            for e in events {
                if let cid = e.courseId { ids.insert(cid) }
            }
        }

        return ids.sorted()
    }

    /// All known lesson ids for a course (from progress + startedLessons + lastLesson).
    public func profileAllKnownLessonIds(for courseId: String) -> [String] {
        var ids: Set<String> = []

        if let map = snapshot.lessonProgress[courseId] {
            ids.formUnion(map.keys)
        }
        if let set = snapshot.startedLessons[courseId] {
            ids.formUnion(set)
        }
        if let last = snapshot.lastLessonByCourse[courseId] {
            ids.insert(last)
        }

        return ids.sorted()
    }

    // MARK: - Persistence

    private func touchAndSave() {
        snapshot.lastEventAt = Date()
        saveDebounced()
    }

    private func saveDebounced() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: storeKey)
        } catch {
            print("[UserSession] save error: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return }
        do {
            let snap = try JSONDecoder().decode(USSnapshot.self, from: data)
            snapshot = snap
        } catch {
            print("[UserSession] load error: \(error)")
        }
    }

    // MARK: - Utils

    // (removed old dayKey(for:) - now handled by overloads above)

    private func courseHasAnyLearnedSteps(_ courseId: String) -> Bool {
        // any non-empty learned set for any lesson in this course
        let prefix = "\(courseId)|"
        for (k, set) in snapshot.learnedSteps {
            if k.hasPrefix(prefix), !set.isEmpty { return true }
        }
        return false
    }

    private func recordCourseActivity(courseId: String, on date: Date) {
        let key = bangkokDayKey(for: Self.bangkokCal.startOfDay(for: date))
        var set = snapshot.dayCourses[key] ?? []
        if set.contains(courseId) { return }
        set.insert(courseId)
        snapshot.dayCourses[key] = set
    }

    // MARK: - Activity log API (Profile: "моя активность")

    /// Public activity logger (single source of truth for Profile charts).
    /// Use this from managers instead of posting ad-hoc NotificationCenter requests.
    public func logActivity(
        _ kind: USActivityEventKind,
        courseId: String? = nil,
        lessonId: String? = nil,
        stepIndex: Int? = nil,
        refId: String? = nil,
        ts: Date = Date()
    ) {
        appendActivity(kind, courseId: courseId, lessonId: lessonId, stepIndex: stepIndex, refId: refId, ts: ts, emitWillChange: true, save: true)
    }

    private func appendActivity(
        _ kind: USActivityEventKind,
        courseId: String?,
        lessonId: String?,
        stepIndex: Int?,
        refId: String?,
        ts: Date = Date(),
        emitWillChange: Bool = true,
        save: Bool = true
    ) {
        if emitWillChange {
            objectWillChange.send()
        }
        snapshot.lastEventAt = ts

        // keep daily course activity in sync (so activity heatmap matches event log)
        // only for “positive” activity signals (avoid phantom active days on removals/unlearn).
        if let cid = courseId {
            switch kind {
            case .courseOpened, .lessonOpened, .stepLearned, .favoriteAdded:
                recordCourseActivity(courseId: cid, on: ts)
            default:
                break
            }
        }

        let day = Self.bangkokCal.startOfDay(for: ts)
        let key = bangkokDayKey(for: day)

        var list = snapshot.activityLog[key] ?? []
        list.append(
            USActivityEvent(
                kind: kind,
                ts: ts,
                courseId: courseId,
                lessonId: lessonId,
                stepIndex: stepIndex,
                refId: refId
            )
        )
        // keep chronological order (stable UX)
        list.sort { $0.ts < $1.ts }
        snapshot.activityLog[key] = list

        if save {
            saveDebounced()
        }

        NotificationCenter.default.post(name: .usActivityLogDidChange, object: nil, userInfo: ["day": day])
        NotificationCenter.default.post(name: .activityDidChange, object: nil, userInfo: ["day": day])
        NotificationCenter.default.post(name: Notification.Name("UserSessionActivityDidChange"), object: nil)
    }

    /// Returns last N day keys (Thailand calendar), ordered oldest -> newest.
    public func activityDayKeys(last days: Int, endingAt date: Date = Date()) -> [String] {
        guard days > 0 else { return [] }
        let end = Self.bangkokCal.startOfDay(for: date)
        return (0..<days).compactMap { offset in
            guard let d = Self.bangkokCal.date(byAdding: .day, value: -(days - 1 - offset), to: end) else { return nil }
            return bangkokDayKey(for: d)
        }
    }

    /// Events for a day key (yyyy-mm-dd) in chronological order.
    public func activityEvents(dayKey: String) -> [USActivityEvent] {
        snapshot.activityLog[dayKey] ?? []
    }

    /// Events for a day (Thailand calendar).
    public func activityEvents(on day: Date) -> [USActivityEvent] {
        let d = Self.bangkokCal.startOfDay(for: day)
        return activityEvents(dayKey: bangkokDayKey(for: d))
    }

    /// Raw intensity for a day key (0..N). UI maps this to dim/medium/max.
    public func activityIntensity(dayKey: String) -> Int {
        activityEvents(dayKey: dayKey).count
    }

    public func activityIntensity(on day: Date) -> Int {
        let d = Self.bangkokCal.startOfDay(for: day)
        return activityIntensity(dayKey: bangkokDayKey(for: d))
    }

    /// All course ids recorded for the given day (no limit; source of truth).
    public func courseIds(on date: Date) -> [String] {
        resolveDaySet(snapshot.dayCourses, day: date).sorted()
    }

    /// UI helper: same as `courseIds(on:)` but truncated for rendering.
    public func courseIds(on date: Date, limit: Int) -> [String] {
        let all = courseIds(on: date)
        guard limit > 0 else { return [] }
        if all.count <= limit { return all }
        return Array(all.prefix(limit))
    }

    public func hasCourses(on date: Date) -> Bool {
        !courseIds(on: date).isEmpty
    }

    // MARK: - Day Planning API (free/pro)

    /// Source of truth: planned course ids for a given day (unsorted set -> sorted array).
    public func plannedCourseIds(on day: Date) -> [String] {
        let keys = plannedKeyCandidates(for: day)
        return (snapshot.plannedDayCourses[keys.canonical] ?? []).sorted()
    }

    /// True if the course is planned on the given day.
    public func isCoursePlanned(courseId: String, on day: Date) -> Bool {
        let keys = plannedKeyCandidates(for: day)
        return (snapshot.plannedDayCourses[keys.canonical] ?? []).contains(courseId)
    }

    /// Replace the whole planned set for a day (free mode uses this with 0/1 course).
    public func setPlannedCourses(on day: Date, courseIds: Set<String>) {
        objectWillChange.send()
        migrateLegacyPlannedIfNeeded(for: day)
        let d = Self.bangkokCal.startOfDay(for: day)
        let key = plannedKeyCandidates(for: d).canonical
        snapshot.plannedDayCourses[key] = courseIds
        if courseIds.isEmpty {
            snapshot.plannedDayLastCourseId.removeValue(forKey: key)
        } else if courseIds.count == 1 {
            snapshot.plannedDayLastCourseId[key] = courseIds.first
        } else {
            // keep existing if still present; otherwise pick a deterministic one
            if let prev = snapshot.plannedDayLastCourseId[key], courseIds.contains(prev) {
                // keep
            } else {
                snapshot.plannedDayLastCourseId[key] = courseIds.sorted().first
            }
        }
        snapshot.startedCourses.formUnion(courseIds)
        snapshot.lastEventAt = Date()
        saveDebounced()
        NotificationCenter.default.post(
            name: Notification.Name("CoursePlanDidChange"),
            object: nil,
            userInfo: ["day": d]
        )
    }

    /// Toggle a single course on a day (pro mode uses this).
    public func togglePlannedCourse(courseId: String, on day: Date) {
        objectWillChange.send()
        migrateLegacyPlannedIfNeeded(for: day)
        let d = Self.bangkokCal.startOfDay(for: day)
        let key = plannedKeyCandidates(for: d).canonical
        var set: Set<String> = snapshot.plannedDayCourses[key] ?? []
        if set.contains(courseId) {
            set.remove(courseId)
            if snapshot.plannedDayLastCourseId[key] == courseId {
                snapshot.plannedDayLastCourseId.removeValue(forKey: key)
            }
        } else {
            set.insert(courseId)
            snapshot.startedCourses.insert(courseId)
            snapshot.plannedDayLastCourseId[key] = courseId
        }
        snapshot.plannedDayCourses[key] = set
        snapshot.lastEventAt = Date()
        saveDebounced()
        NotificationCenter.default.post(
            name: Notification.Name("CoursePlanDidChange"),
            object: nil,
            userInfo: ["day": d]
        )
    }

    /// Remove a course from a specific day (used by free replace UI).
    public func removePlannedCourse(courseId: String, on day: Date) {
        objectWillChange.send()
        migrateLegacyPlannedIfNeeded(for: day)
        let d = Self.bangkokCal.startOfDay(for: day)
        let key = plannedKeyCandidates(for: d).canonical
        var set: Set<String> = snapshot.plannedDayCourses[key] ?? []
        if set.isEmpty { return }
        if set.contains(courseId) {
            set.remove(courseId)
            if snapshot.plannedDayLastCourseId[key] == courseId {
                if let next = set.sorted().first {
                    snapshot.plannedDayLastCourseId[key] = next
                } else {
                    snapshot.plannedDayLastCourseId.removeValue(forKey: key)
                }
            }
            snapshot.plannedDayCourses[key] = set
            snapshot.lastEventAt = Date()
            saveDebounced()
            NotificationCenter.default.post(
                name: Notification.Name("CoursePlanDidChange"),
                object: nil,
                userInfo: ["day": d]
            )
        }
    }

    /// Record a course as planned/active for a specific day (used by Main calendar "add course" overlay).
    public func addCourseToDay(courseId: String, day: Date) {
        objectWillChange.send()
        migrateLegacyPlannedIfNeeded(for: day)
        let d = Self.bangkokCal.startOfDay(for: day)
        let key = plannedKeyCandidates(for: d).canonical
        var set: Set<String> = snapshot.plannedDayCourses[key] ?? []
        set.insert(courseId)
        snapshot.plannedDayCourses[key] = set
        snapshot.plannedDayLastCourseId[key] = courseId
        snapshot.startedCourses.insert(courseId)
        snapshot.lastEventAt = Date()
        saveDebounced()
        NotificationCenter.default.post(
            name: Notification.Name("CoursePlanDidChange"),
            object: nil,
            userInfo: ["day": d]
        )
    }

    /// Last planned course id for the given day (used to bubble to front in overlays).
    public func lastPlannedCourseId(on day: Date) -> String? {
        let keys = plannedKeyCandidates(for: day)
        return snapshot.plannedDayLastCourseId[keys.canonical]
    }

    private func compoundLessonKey(courseId: String, lessonId: String) -> String {
        "\(courseId)|\(lessonId)"
    }
}
