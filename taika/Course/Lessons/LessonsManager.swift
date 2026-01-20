//  LessonsManager.swift
//  taika
//
//  Created by product on 13.09.2025.
//

import Foundation
import Combine

/// Статус урока в рамках курса
public enum LessonStatus: String, Codable, Equatable {
    case locked
    case inProgress
    case completed
}

/// Прогресс по одному уроку
public struct LessonProgress: Codable, Equatable, Hashable {
    public var learned: Int
    public var total: Int
    public var status: LessonStatus

    /// Fractional percent progress [0.0 ... 1.0]
    public var percent: Double {
        guard total > 0 else { return 0.0 }
        let clamped = min(max(0, learned), total)
        return Double(clamped) / Double(total)
    }
}

extension LessonProgress {
    static var zero: LessonProgress { .init(learned: 0, total: 0, status: .locked) }
}

/// Агрегатор прогресса уроков по курсам — источник правды для хэдера Lessons/Course
@MainActor public final class LessonsManager: ObservableObject {
    public static let shared = LessonsManager()

    /// courseId -> (lessonId -> progress)
    @Published public private(set) var progress: [String: [String: LessonProgress]] = [:]
    @Published public private(set) var progressVersion: Int = 0

    // Tracks lessons that were explicitly started (entered) even with 0 learned
    @Published public private(set) var started: [String: Set<String>] = [:]

    private let storeKey = "LessonsManager.progress.v1"
    private let storeKeyStarted = "LessonsManager.started.v1"
    private var saveWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    // Coalesced UI notifier to prevent excessive objectWillChange/tick spam
    private var pendingEmit = false
    private func scheduleEmit() {
        guard !pendingEmit else { return }
        pendingEmit = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingEmit = false
            self.objectWillChange.send()
            self.tick()
        }
    }

    // Navigation helper (single source of truth for course/lesson order)
    public let navigator = CourseNavigator.shared

    // single source of truth for lesson content (parsed from lessons.json)
    private let lessonsData = LessonsData.shared

    private init() {
        load()
        NotificationCenter.default.addObserver(forName: .stepProgressDidChange, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                guard let u = note.userInfo as? [String: Any],
                      let courseId = u["courseId"] as? String,
                      let lessonId = u["lessonId"] as? String else {
                    self.publishProgress()
                    return
                }

                var updated = false

                if let learnedArr = u["learnedContent"] as? [Int],
                   let allArr = u["allCards"] as? [Int] {
                    let hacksArr = (u["lifehacks"] as? [Int]) ?? []
                    self.updateLessonProgress(
                        courseId: courseId,
                        lessonId: lessonId,
                        learnedContent: Set(learnedArr),
                        allCards: Set(allArr),
                        lifehacks: Set(hacksArr)
                    )
                    updated = true
                } else if let learned = u["learnedCount"] as? Int,
                          let total = u["totalCount"] as? Int {
                    let hacks = (u["lifehackCount"] as? Int) ?? 0
                    self.updateLessonProgress(courseId: courseId,
                                              lessonId: lessonId,
                                              learnedCount: learned,
                                              total: total,
                                              lifehackCount: hacks)
                    updated = true
                }

                if updated == false {
                    #if DEBUG
                    print("[LessonsManager] stepProgressDidChange: payload parsed but no fields matched, forcing refresh")
                    #endif
                }
                self.forceRefresh()
            }
        }
        NotificationCenter.default.addObserver(forName: .stepProgressDidReset, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.forceRefresh()
            }
        }
        // Mark a lesson as started (user entered the lesson) even if learned == 0
        NotificationCenter.default.addObserver(forName: .lessonDidStart, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                guard let u = note.userInfo as? [String: Any],
                      let courseId = u["courseId"] as? String,
                      let lessonId = u["lessonId"] as? String else {
                    return
                }
                let providedTotal = (u["totalCount"] as? Int) ?? 0
                self.markLessonStarted(courseId: courseId, lessonId: lessonId, hintTotal: providedTotal)
            }
        }
        // Refresh lesson counters when favorites change
        FavoriteManager.shared.$items
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.forceRefresh()
            }
            .store(in: &cancellables)
    }

    private func tick() {
        // Wrap to avoid overflow in extreme cases
        if progressVersion == Int.max { progressVersion = 0 }
        progressVersion += 1
    }

    /// Явно опубликовать текущее состояние (на случай, когда данные логически поменялись,
    /// но словарь `progress` остался прежним и SwiftUI не триггернул перерисовку)
    public func publishProgress() {
        scheduleEmit()
    }

    /// Силовой рефреш подписчиков (дергает objectWillChange и версию)
    public func forceRefresh() {
        scheduleEmit()
    }

    /// Применить снапшот прогресса по конкретному уроку (используется из Step/ProgressManager)
    public func applySnapshot(courseId: String,
                              lessonId: String,
                              learnedContent: Set<Int>,
                              allCards: Set<Int>,
                              lifehacks: Set<Int> = []) {
        updateLessonProgress(courseId: courseId,
                             lessonId: lessonId,
                             learnedContent: learnedContent,
                             allCards: allCards,
                             lifehacks: lifehacks)
        // Print percent for debug
        if let prog = lessonProgress(courseId: courseId, lessonId: lessonId) {
            #if DEBUG
            print("[LessonsManager] applySnapshot course=\(courseId) lesson=\(lessonId) percent=\(prog.percent)")
            #endif
        }
        // UI обновится через собственный эмит в updateLessonProgress либо через внешние нотификации
    }

    /// Обновить агрегат прогресса по уроку (вызов из StepManager)
    /// - Parameters:
    ///   - learnedCount: количество выученных "контентных" карточек (без лайфхаков)
    ///   - total: общее количество карточек урока (с лайфхаками)
    ///   - lifehackCount: сколько из total являются лайфхаками (НЕ участвуют в прогрессе урока)
    public func updateLessonProgress(courseId: String,
                                     lessonId: String,
                                     learnedCount: Int,
                                     total: Int,
                                     lifehackCount: Int = 0) {
        // Выкидываем лайфхаки из общего количества для расчёта статуса/процента
        let hacks = max(0, lifehackCount)
        let rawTotal = max(0, total)
        let effectiveTotal = max(0, rawTotal - hacks)

        let learned = max(0, learnedCount)

        let status: LessonStatus
        if effectiveTotal == 0 {
            // Нет контентных карточек → урок нельзя завершить, остаётся locked, пока нет выученных
            status = learned > 0 ? .inProgress : .locked
        } else if learned >= effectiveTotal {
            status = .completed
        } else if learned > 0 {
            status = .inProgress
        } else {
            status = .locked
        }

        var byLesson = progress[courseId] ?? [:]
        let next = LessonProgress(learned: learned, total: effectiveTotal, status: status)

        if byLesson[lessonId] != next {
            byLesson[lessonId] = next
            progress[courseId] = byLesson
            saveDebounced()
            objectWillChange.send()
            tick()
        }

        // Print percent for debug
        #if DEBUG
        print("[LessonsManager] update course=\(courseId) lesson=\(lessonId) → learned=\(learned) / total=\(rawTotal) (hacks=\(hacks) → effective=\(effectiveTotal)) status=\(status) percent=\(next.percent)")
        #endif
    }

    /// Удобный апдейтер, если уже посчитаны наборы индексов
    /// - Parameters:
    ///   - learnedContent: множество индексов контентных карточек (без лайфхаков)
    ///   - allCards: общее множество всех карточек урока (включая лайфхаки)
    ///   - lifehacks: множество индексов лайфхаков (исключаются из прогресса)
    public func updateLessonProgress(
        courseId: String,
        lessonId: String,
        learnedContent: Set<Int>,
        allCards: Set<Int>,
        lifehacks: Set<Int> = []
    ) {
        // Контентные = все минус лайфхаки
        let effectiveSet = allCards.subtracting(lifehacks)
        let learned = learnedContent.intersection(effectiveSet).count
        _ = max(0, effectiveSet.count)
        self.updateLessonProgress(courseId: courseId,
                                  lessonId: lessonId,
                                  learnedCount: learned,
                                  total: allCards.count,
                                  lifehackCount: lifehacks.count)
        // Print percent for debug
        if let prog = lessonProgress(courseId: courseId, lessonId: lessonId) {
            #if DEBUG
            print("[LessonsManager] updateLessonProgress (set-based) course=\(courseId) lesson=\(lessonId) percent=\(prog.percent)")
            #endif
        }
    }

    /// Помечает урок как «начатый» (вошли в lesson), даже если learned==0.
    /// Если передан hintTotal > 0 и у нас не было записи по уроку — создаём запись с total=hintTotal.
    public func markLessonStarted(courseId: String, lessonId: String, hintTotal: Int = 0) {
        var s = started[courseId] ?? []
        let inserted = s.insert(lessonId).inserted
        if inserted {
            started[courseId] = s
            // Если нет прогресса по уроку — можем создать "нулевую" запись,
            // чтобы статус курса пересчитался в .inProgress сразу после входа.
            if progress[courseId]?[lessonId] == nil {
                let total = max(0, hintTotal)
                let lp = LessonProgress(learned: 0, total: total, status: .inProgress)
                var byLesson = progress[courseId] ?? [:]
                byLesson[lessonId] = lp
                progress[courseId] = byLesson
            }
            save()
            saveStarted()
            objectWillChange.send()
            tick()
        }
    }

    /// Текущий прогресс по конкретному уроку
    public func lessonProgress(courseId: String, lessonId: String) -> LessonProgress? {
        progress[courseId]?[lessonId]
    }

    // MARK: - Main integration helpers

    /// Удобный доступ к проценту прогресса по уроку (0.0 ... 1.0)
    @inlinable
    public func lessonPercent(courseId: String, lessonId: String) -> Double {
        lessonProgress(courseId: courseId, lessonId: lessonId)?.percent ?? 0.0
    }

    /// Возвращает статус и прогресс по уроку (0.0...1.0)
    public func lessonStatusWithProgress(courseId: String, lessonId: String) -> (LessonStatus, Double) {
        guard let lp = lessonProgress(courseId: courseId, lessonId: lessonId), lp.total > 0 else {
            return (.locked, 0.0)
        }
        return (lp.status, lp.percent)
    }

    /// Returns all lessonIds currently tracked for a course, sorted for stability.
    public func lessonIds(for courseId: String) -> [String] {
        let byLesson = progress[courseId] ?? [:]
        return byLesson.keys.sorted()
    }

    /// Returns the overall status for a course:
    /// - .completed if all lessons are completed and at least one exists,
    /// - .inProgress if any lesson is in progress or any lesson is started,
    /// - .locked otherwise (no progress or all locked).
    public func courseStatus(for courseId: String) -> LessonStatus {
        let byLesson = progress[courseId] ?? [:]
        let statuses = byLesson.values.map { $0.status }

        // Если хотя бы один урок отмечен как «начатый», курс считается в процессе
        let startedLessons = started[courseId] ?? []

        if statuses.isEmpty && startedLessons.isEmpty {
            return .locked
        }
        if statuses.allSatisfy({ $0 == .completed }) && !statuses.isEmpty {
            return .completed
        }
        if statuses.contains(.inProgress) || !startedLessons.isEmpty {
            return .inProgress
        }
        return .locked
    }

    /// Общий процент прогресса по курсу (0.0 ... 1.0) на основе прогресса всех уроков
    public func coursePercent(for courseId: String) -> Double {
        let byLesson = progress[courseId] ?? [:]
        guard !byLesson.isEmpty else { return 0.0 }

        // Weighted by effective totals (lp.total already excludes lifehacks in updateLessonProgress)
        let valid = byLesson.values.filter { $0.total > 0 }
        guard !valid.isEmpty else { return 0.0 }

        let learnedTotal = valid.reduce(0) { $0 + max(0, $1.learned) }
        let total = valid.reduce(0) { $0 + max(0, $1.total) }
        guard total > 0 else { return 0.0 }

        let value = Double(min(learnedTotal, total)) / Double(total)
        return min(max(value, 0.0), 1.0)
    }
    /// Кол-во завершённых уроков для хэдера курса
    public func headerCounts(for courseId: String, lessonsTotal: Int) -> (completed: Int, total: Int) {
        let course = progress[courseId] ?? [:]
        let completed = course.values.filter { $0.status == .completed }.count
        return (completed, lessonsTotal)
    }

    /// Полный сброс прогресса по курсу
    public func resetCourseProgress(courseId: String) {
        // 1) Обнуляем агрегаты по урокам этого курса
        progress[courseId] = [:]
        // также чистим персист в ProgressManager по всем урокам курса
        ProgressManager.shared.resetCourse(courseId: courseId)

        NotificationCenter.default.post(
            name: .stepProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": "__all__"
            ]
        )

        // 2) Сбрасываем связанные состояния в соседних менеджерах (если реализованы)
        // NOTE: Реализуй методы в соответствующих менеджерах, если их ещё нет.
        #if canImport(Foundation)
        FavoriteManager.shared.clearForCourse(courseId)
        #endif

        // 3) Сохранить и оповестить подписчиков
        save()
        scheduleEmit()

        // 4) Широкое оповещение через NotificationCenter (на него можно подписать StepView и др.)
        NotificationCenter.default.post(name: .lessonsCourseProgressDidReset, object: nil, userInfo: ["courseId": courseId])
        NotificationCenter.default.post(name: .courseProgressDidReset, object: nil, userInfo: ["courseId": courseId])
        NotificationCenter.default.post(name: .stepStateShouldReset, object: nil, userInfo: ["courseId": courseId])

        #if DEBUG
        print("[LessonsManager] reset progress for course=\(courseId)")
        #endif
    }

    /// Сброс прогресса по конкретному уроку
    public func resetLessonProgress(courseId: String, lessonId: String) {
        // 1) Удалить агрегат по этому уроку в рамках курса
        var byLesson = progress[courseId] ?? [:]
        let hadValue = byLesson.removeValue(forKey: lessonId) != nil
        progress[courseId] = byLesson
        // чистим персист в ProgressManager для конкретного урока
        ProgressManager.shared.resetLesson(courseId: courseId, lessonId: lessonId)

        NotificationCenter.default.post(
            name: .stepProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId
            ]
        )

        // 2) Сохранить и оповестить UI (даже если не было записи — важно дернуть перерисовку)
        save()
        scheduleEmit()

        // 3) Нотификации для подписчиков (StepView/StepManager и т.д.)
        NotificationCenter.default.post(
            name: .lessonsLessonProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId,
                "changed": hadValue
            ]
        )
        NotificationCenter.default.post(
            name: .lessonProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId,
                "changed": hadValue
            ]
        )
        NotificationCenter.default.post(
            name: .stepStateShouldReset,
            object: nil,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId
            ]
        )

        #if DEBUG
        print("[LessonsManager] reset progress course=\(courseId) lesson=\(lessonId)")
        #endif
    }

    /// Полный сброс прогресса по всем курсам
    public func resetAllProgress() {
        // 1) Обнуляем весь агрегированный прогресс
        progress.removeAll()

        // 2) Сбрасываем связанные состояния в соседних менеджерах (если реализованы)
        #if canImport(Foundation)
        FavoriteManager.shared.clearAll()
        #endif

        // 3) Сохранить и оповестить UI
        save()
        scheduleEmit()

        // 4) Широкое оповещение
        NotificationCenter.default.post(name: .allProgressDidReset, object: nil)
        NotificationCenter.default.post(name: .stepStateShouldReset, object: nil, userInfo: ["courseId": "__all__"])

        #if DEBUG
        print("[LessonsManager] reset progress for ALL courses")
        #endif
    }


    /// Количество лайков (из FavoriteManager) по конкретному уроку
    public func lessonFavoriteCount(courseId: String, lessonId: String) -> Int {
        #if canImport(Foundation)
        let favs = FavoriteManager.shared.favoritesForLesson(courseId: courseId, lessonId: lessonId)
        return favs.count
        #else
        return 0
        #endif
    }

    /// Удобный хелпер для Step/StepManager: агрегирует прогресс урока из наборов индексов
    public func aggregateFromStep(courseId: String,
                                  lessonId: String,
                                  learnedContent: Set<Int>,
                                  allCards: Set<Int>,
                                  lifehacks: Set<Int> = []) {
        applySnapshot(courseId: courseId,
                      lessonId: lessonId,
                      learnedContent: learnedContent,
                      allCards: allCards,
                      lifehacks: lifehacks)
    }

    /// Перценты прогресса по каждому уроку (для хэдера/слотов)
    /// - Parameters:
    ///   - courseId: идентификатор курса
    ///   - lessonIds: массив lessonId в нужном порядке (1:1 с отображением во View)
    /// - Returns: массив значений [0.0 ... 1.0], по одному на каждый lessonId
    @inlinable
    public func percentsForLessons(courseId: String, lessonIds: [String]) -> [Double] {
        let byLesson = progress[courseId] ?? [:]
        return lessonIds.map { lid in
            guard let lp = byLesson[lid], lp.total > 0 else { return 0.0 }
            let clamped = min(max(0, lp.learned), lp.total)
            return Double(clamped) / Double(lp.total)
        }
    }

    /// Точные доли прогресса по урокам для мини-слотов хэдера (0.0...1.0 в заданном порядке)
    @inlinable
    public func progressSlots(courseId: String, lessonIds: [String]) -> [Double] {
        let byLesson = progress[courseId] ?? [:]
        return lessonIds.map { lid in
            guard let lp = byLesson[lid] else { return 0.0 }
            // percent уже считается на основе effective total (без лайфхаков)
            let value = lp.percent
            return min(max(value, 0.0), 1.0)
        }
    }

    // MARK: - Persistence

    private func saveDebounced() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(data, forKey: storeKey)
            UserDefaults.standard.set(progressVersion, forKey: storeKey+".version")
        } catch {
            print("[LessonsManager] save error: \(error)")
        }
        if let dataStarted = try? JSONEncoder().encode(started.mapValues { Array($0) }) {
            UserDefaults.standard.set(dataStarted, forKey: storeKeyStarted)
        }
    }

    private func saveStarted() {
        if let data = try? JSONEncoder().encode(started.mapValues { Array($0) }) {
            UserDefaults.standard.set(data, forKey: storeKeyStarted)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: [String: LessonProgress]].self, from: data)
            progress = decoded
            let ver = UserDefaults.standard.integer(forKey: storeKey+".version")
            self.progressVersion = max(0, ver)
        } catch {
            print("[LessonsManager] load error: \(error)")
        }
        if let dataStarted = UserDefaults.standard.data(forKey: storeKeyStarted),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: dataStarted) {
            // восстановим множества
            self.started = decoded.mapValues { Set($0) }
        }
    }
    // MARK: - Navigation (forwarded to CourseNavigator)
    /// Compute next destination from a given course/lesson.
    @inlinable
    public func advance(from courseId: String, lessonId: String) -> CourseNavigator.Advance {
        navigator.advance(from: courseId, lessonId: lessonId)
    }

    /// First lesson in a course (if any)
    @inlinable
    public func firstLesson(in courseId: String) -> String? {
        navigator.firstLesson(in: courseId)
    }

    /// Safe lesson title resolution
    @inlinable
    public func lessonTitle(for lessonId: String) -> String {
        navigator.lessonTitle(for: lessonId)
    }

    /// Canonical lesson title lookup used across the app (favorites, etc.)
    /// `courseId` kept for forward-compat (not used by current navigator)
    @inlinable
    public func titleForLesson(courseId: String, lessonId: String) -> String {
        let t = navigator.lessonTitle(for: lessonId)
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? lessonId.replacingOccurrences(of: "_", with: " ") : t
    }

    /// Safe course title resolution
    @inlinable
    public func courseTitle(for courseId: String) -> String {
        // delegate to single source of truth
        let resolved = navigator.courseTitle(for: courseId)
        let trimmed = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        // fallback: humanize id if navigator has no title yet
        return courseId
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

public extension Notification.Name {
    static let lessonsCourseProgressDidReset = Notification.Name("LessonsManager.courseProgressDidReset")
    static let lessonsLessonProgressDidReset = Notification.Name("LessonsManager.lessonProgressDidReset")
    static let allProgressDidReset = Notification.Name("LessonsManager.allProgressDidReset")
    static let stepStateShouldReset = Notification.Name("LessonsManager.stepStateShouldReset")

    static let stepProgressDidChange = Notification.Name("Step.progressDidChange")
    static let stepProgressDidReset  = Notification.Name("Step.progressDidReset")
    static let lessonDidStart = Notification.Name("Lesson.sessionDidStart")
}




// MARK: - Paywall preview
extension LessonsManager {

    /// paywall preview lessons for a pro-course overlay (read-only)
    func paywallPreviewLessons(for courseId: String) -> [LessonBundle] {
        lessonsData.lessons(for: courseId)
    }
}
