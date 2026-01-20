//  FavoriteData.swift
//  taika
//
//  Created by product on 29.08.2025.
//

import Foundation

/// Нормализатор lessonId для всех обращений к StepData/LessonsData
private func FDNormLessonId(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
     .lowercased()
     .replacingOccurrences(of: " ", with: "_")
}

/// Нормализатор courseId (в тех же правилах, что и lessonId)
private func FDNormCourseId(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
     .lowercased()
     .replacingOccurrences(of: " ", with: "_")
}

/// Парсим courseId/lessonId/stepId из каноничного ключа вида "course.lesson.step"
private func FDParseIds(from sourceId: String) -> (courseId: String?, lessonId: String?, stepId: String?) {
    let core = sourceId.split(separator: ":").last.map(String.init) ?? sourceId
    let parts = core.split(separator: ".").map(String.init)
    guard parts.count >= 3 else { return (nil, nil, nil) }
    return (parts[0], parts[1], parts.last)
}

/// Парсим из формата "course.lesson" (без шага) — легаси вариант
private func FDParseCourseLesson(from sourceId: String) -> (courseId: String?, lessonId: String?) {
    let core = sourceId.split(separator: ":").last.map(String.init) ?? sourceId
    let parts = core.split(separator: ".").map(String.init)
    guard parts.count >= 2 else { return (nil, nil) }
    return (parts[0], parts[1])
}

/// Парсим из формата "step:<courseId>:<lessonId>:idx<index>"
private func FDParseStepRoute(from sourceId: String) -> (courseId: String?, lessonId: String?, index: Int?) {
    guard sourceId.hasPrefix("step:") else { return (nil, nil, nil) }
    let parts = sourceId.split(separator: ":").map(String.init)
    guard parts.count >= 4 else { return (nil, nil, nil) }
    let courseId = parts[1]
    let lessonId = parts[2]
    let idxRaw   = parts[3]
    let idxStr   = idxRaw.hasPrefix("idx") ? String(idxRaw.dropFirst(3)) : idxRaw
    let idx      = Int(idxStr)
    return (courseId, lessonId, idx)
}

/// Каноничный вид для типа шага (для отображения)
public enum FDStepKindDisplay: String {
    case phrase   = "Фраза"
    case word     = "Слово"
    case casual   = "Неформально"
    case dialog   = "Диалог"
    case lifehack = "Лайфхак"
}

/// Карточка (фраза/слово) для избранного — DTO для ДС/Вью
public struct FDCardDTO: Identifiable, Equatable {
    public var id: String { sourceId }
    public let sourceId: String      // step id (из FavoriteItem.id)
    public let title: String         // ru
    public let subtitle: String      // th
    public let meta: String          // phonetic
    public let lessonTitle: String   // резолв из LessonsData, fallback "урок"
    public let tagText: String?      // "фраза" / "слово"
    public let addedAt: Date
}

/// Лайфхак для избранного — отдельный DTO
public struct FDHackDTO: Identifiable, Equatable {
    public var id: String { sourceId }
    public let sourceId: String
    public let title: String         // основной текст
    public let meta: String          // вспомогательный текст/транскрипция (если есть)
    public let lessonTitle: String
    public let addedAt: Date
}

/// Курс в избранном — DTO
public struct FDCourseDTO: Identifiable, Equatable {
    public var id: String { courseId }
    public let courseId: String
    public let title: String
    public let subtitle: String
    public let addedAt: Date
}

/// Data-слой для Избранного: резолвит сырые FavoriteItem в DTO для UI
public final class FavoriteData {
    public static let shared = FavoriteData()
    private init() {}

    // MARK: - Public API

    /// Основной метод: из массива FavoriteItem получаем три набора DTO
    func resolve(_ items: [FavoriteItem]) -> (courses: [FDCourseDTO], cards: [FDCardDTO], hacks: [FDHackDTO]) {
        // Синхронная обёртка для старых вызовов: если мы на главном потоке —
        // считаем в фоне и ждём результат без блокировки рендера (не используем .wait() на main).
        if Thread.isMainThread {
            let group = DispatchGroup()
            var out: (courses: [FDCourseDTO], cards: [FDCardDTO], hacks: [FDHackDTO]) = ([], [], [])
            group.enter()
            Task {
                let r = await resolveAsync(items)
                out = r
                group.leave()
            }
            // Разрешаем главному циклу крутиться, пока ждём фоновый результат
            while group.wait(timeout: .now()) == .timedOut {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.005))
            }
            return out
        } else {
            // Не на main — можно подождать обычным семафором
            let semaphore = DispatchSemaphore(value: 0)
            var result: (courses: [FDCourseDTO], cards: [FDCardDTO], hacks: [FDHackDTO]) = ([], [], [])
            Task.detached(priority: .userInitiated) { [self] in
                let r = await self.resolveAsync(items)
                result = r
                semaphore.signal()
            }
            semaphore.wait()
            return result
        }
    }

    // MARK: - Async API

    /// Чистый расчёт без побочных эффектов/UI — можно вызывать в фоне
    private func computeResolved(items: [FavoriteItem]) -> (courses: [FDCourseDTO], cards: [FDCardDTO], hacks: [FDHackDTO]) {
        var courses: [FDCourseDTO] = []
        var cards:   [FDCardDTO]   = []
        var hacks:   [FDHackDTO]   = []

        let canonicalItems = self.canonicalize(items)
        for it in canonicalItems {
            // КУРСЫ
            if it.id.hasPrefix("course:") || (it.lessonId.isEmpty && !it.id.contains(".")) {
                let cid: String = {
                    if it.id.hasPrefix("course:") { return String(it.id.dropFirst("course:".count)) }
                    return it.courseId.isEmpty ? it.id : it.courseId
                }()
                var courseTitle = CourseData.shared.title(for: cid) ?? ""
                var courseSubtitle = CourseData.shared.subtitle(for: cid) ?? ""
                if courseTitle.isEmpty {
                    let list = LessonsData.shared.lessons(for: cid)
                    if let t = list.first?.title, !t.isEmpty { courseTitle = t }
                    if courseSubtitle.isEmpty { courseSubtitle = list.first?.subtitle ?? "" }
                }
                if courseTitle.isEmpty { courseTitle = "курс" }
                courses.append(FDCourseDTO(courseId: cid, title: courseTitle, subtitle: "", addedAt: it.createdAt))
                continue
            }

            // ШАГИ
            var courseId = it.courseId
            var lessonId = it.lessonId
            if courseId.isEmpty || lessonId.isEmpty {
                let parsed = FDParseIds(from: it.id)
                if courseId.isEmpty, let c = parsed.courseId { courseId = c }
                if lessonId.isEmpty, let l = parsed.lessonId { lessonId = l }
                if courseId.isEmpty || lessonId.isEmpty {
                    let two = FDParseCourseLesson(from: it.id)
                    if courseId.isEmpty, let c = two.courseId { courseId = c }
                    if lessonId.isEmpty, let l = two.lessonId { lessonId = l }
                }
                if courseId.isEmpty || lessonId.isEmpty {
                    let stepParsed = FDParseStepRoute(from: it.id)
                    if courseId.isEmpty, let c = stepParsed.courseId { courseId = c }
                    if lessonId.isEmpty, let l = stepParsed.lessonId { lessonId = l }
                }
            }
            if lessonId.isEmpty, let found = self.locateLessonId(for: it.id, hintCourseId: courseId.isEmpty ? nil : courseId) {
                courseId = found.courseId
                lessonId = found.lessonId
            }
            courseId = FDNormCourseId(courseId)
            lessonId = FDNormLessonId(lessonId)
            let storedTitle = (it.lessonTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            let lessonName = self.lessonTitle(courseId: courseId, lessonId: lessonId) ?? (storedTitle.isEmpty ? "урок" : storedTitle)

            let isHackExplicit = it.phonetic.hasPrefix("hack:") || it.id.hasPrefix("hack:") || it.ru == "Лайфхак"
            if isHackExplicit {
                let sid = self.canonicalStepId(from: it.id, courseId: courseId, lessonId: lessonId, ru: it.ru, th: it.th)
                let finalBody = self.preferredHackText(item: it, lessonId: lessonId, stepId: sid)
                let body = finalBody.isEmpty ? "Лайфхак" : finalBody
                hacks.append(FDHackDTO(sourceId: "hack:" + sid, title: body, meta: "", lessonTitle: lessonName.isEmpty ? "Лайфхак" : lessonName, addedAt: it.createdAt))
                continue
            }

            let detectedKind = self.stepKind(lessonId: lessonId, stepId: it.id)
            switch detectedKind {
            case .some(.lifehack):
                let sid = self.canonicalStepId(from: it.id, courseId: courseId, lessonId: lessonId, ru: it.ru, th: it.th)
                let body0 = self.preferredHackText(item: it, lessonId: lessonId, stepId: sid)
                let body = body0.isEmpty ? "Лайфхак" : body0
                hacks.append(FDHackDTO(sourceId: "hack:" + sid, title: body, meta: "", lessonTitle: lessonName.isEmpty ? "Лайфхак" : lessonName, addedAt: it.createdAt))
            case .some(.phrase):
                let sid = self.canonicalStepId(from: it.id, courseId: courseId, lessonId: lessonId, ru: it.ru, th: it.th)
                cards.append(FDCardDTO(sourceId: sid, title: it.ru, subtitle: it.th, meta: it.phonetic.isEmpty ? (self.stepPhonetic(lessonId: lessonId, stepId: it.id, ru: it.ru, th: it.th) ?? "") : it.phonetic, lessonTitle: lessonName, tagText: "фраза", addedAt: it.createdAt))
            case .some(.word):
                let sid = self.canonicalStepId(from: it.id, courseId: courseId, lessonId: lessonId, ru: it.ru, th: it.th)
                cards.append(FDCardDTO(sourceId: sid, title: it.ru, subtitle: it.th, meta: it.phonetic.isEmpty ? (self.stepPhonetic(lessonId: lessonId, stepId: it.id, ru: it.ru, th: it.th) ?? "") : it.phonetic, lessonTitle: lessonName, tagText: "слово", addedAt: it.createdAt))
            case .some(.casual):
                let sid = self.canonicalStepId(from: it.id, courseId: courseId, lessonId: lessonId, ru: it.ru, th: it.th)
                cards.append(FDCardDTO(sourceId: sid, title: it.ru, subtitle: it.th, meta: it.phonetic.isEmpty ? (self.stepPhonetic(lessonId: lessonId, stepId: it.id, ru: it.ru, th: it.th) ?? "") : it.phonetic, lessonTitle: lessonName, tagText: "неформально", addedAt: it.createdAt))
            case .some(.dialog):
                let sid = self.canonicalStepId(from: it.id, courseId: courseId, lessonId: lessonId, ru: it.ru, th: it.th)
                cards.append(FDCardDTO(sourceId: sid, title: it.ru, subtitle: it.th, meta: it.phonetic.isEmpty ? (self.stepPhonetic(lessonId: lessonId, stepId: it.id, ru: it.ru, th: it.th) ?? "") : it.phonetic, lessonTitle: lessonName, tagText: "диалог", addedAt: it.createdAt))
            default:
                let sid = self.canonicalStepId(from: it.id, courseId: courseId, lessonId: lessonId, ru: it.ru, th: it.th)
                cards.append(FDCardDTO(sourceId: sid, title: it.ru, subtitle: it.th, meta: it.phonetic.isEmpty ? (self.stepPhonetic(lessonId: lessonId, stepId: it.id, ru: it.ru, th: it.th) ?? "") : it.phonetic, lessonTitle: lessonName, tagText: nil, addedAt: it.createdAt))
            }

            if let last = cards.last, last.title == "Лайфхак", !last.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = cards.popLast()
                hacks.append(FDHackDTO(sourceId: "hack:" + last.sourceId, title: last.subtitle, meta: last.title, lessonTitle: last.lessonTitle, addedAt: last.addedAt))
            }
        }
        // De-duplicate by sourceId, keep newest
        var latestCards: [String: FDCardDTO] = [:]
        for c in cards {
            if let cur = latestCards[c.sourceId] {
                if c.addedAt > cur.addedAt { latestCards[c.sourceId] = c }
            } else {
                latestCards[c.sourceId] = c
            }
        }
        cards = Array(latestCards.values)

        var latestHacks: [String: FDHackDTO] = [:]
        for h in hacks {
            if let cur = latestHacks[h.sourceId] {
                if h.addedAt > cur.addedAt { latestHacks[h.sourceId] = h }
            } else {
                latestHacks[h.sourceId] = h
            }
        }
        hacks = Array(latestHacks.values)

        courses.sort { $0.addedAt > $1.addedAt }
        cards.sort   { $0.addedAt > $1.addedAt }
        hacks.sort   { $0.addedAt > $1.addedAt }
        return (courses, cards, hacks)
    }

    /// Async-версия без блокировки главного потока
    func resolveAsync(_ items: [FavoriteItem]) async -> (courses: [FDCourseDTO], cards: [FDCardDTO], hacks: [FDHackDTO]) {
        return await Task.detached(priority: .userInitiated) { [self] in
            computeResolved(items: items)
        }.value
    }

    // MARK: - Canonicalize Favorites

    /// Переканонизировать сырые избранные: перепишем id шагов в формат
    /// `step:courseId:lessonId:idxN`, нормализуем lessonId и проставим lessonTitle.
    /// Менеджер может вызвать это один раз после загрузки, затем сохранить.
    func canonicalize(_ items: [FavoriteItem]) -> [FavoriteItem] {
        var result: [FavoriteItem] = []
        result.reserveCapacity(items.count)
        for it in items {
            // курсы — без изменений
            if it.id.hasPrefix("course:") || (it.lessonId.isEmpty && !it.id.contains(".")) {
                result.append(it)
                continue
            }
            var courseId = it.courseId
            var lessonId = it.lessonId
            if courseId.isEmpty || lessonId.isEmpty {
                let parsed = FDParseIds(from: it.id)
                if courseId.isEmpty, let c = parsed.courseId { courseId = c }
                if lessonId.isEmpty, let l = parsed.lessonId { lessonId = l }
                if courseId.isEmpty || lessonId.isEmpty {
                    let stepParsed = FDParseStepRoute(from: it.id)
                    if courseId.isEmpty, let c = stepParsed.courseId { courseId = c }
                    if lessonId.isEmpty, let l = stepParsed.lessonId { lessonId = l }
                }
            }
            // добиваем через скан каталога, если надо
            if lessonId.isEmpty {
                if let found = locateLessonId(for: it.id, hintCourseId: courseId.isEmpty ? nil : courseId) {
                    courseId = found.courseId
                    lessonId = found.lessonId
                }
            }
            let normCourse = FDNormCourseId(courseId)
            let normLesson = FDNormLessonId(lessonId)
            let sid = canonicalStepId(from: it.id, courseId: normCourse, lessonId: normLesson, ru: it.ru, th: it.th)
            let title = lessonTitle(courseId: normCourse, lessonId: normLesson) ?? it.lessonTitle
            let rebuilt = FavoriteItem(
                id: sid,
                ru: it.ru,
                th: it.th,
                phonetic: it.phonetic,
                courseId: normCourse,
                lessonId: normLesson,
                lessonTitle: title,
                createdAt: it.createdAt
            )
            result.append(rebuilt)
        }
        return result
    }

    // MARK: - Canonical Step Id

    /// Возвращает канонический step id для шага: step:courseId:lessonId:idxN, если возможно, иначе исходный id
    private static var stepIdCache: [String: String] = [:] // key: lessonId|id
    private static let stepIdCacheLock = NSLock()
    private func canonicalStepId(from id: String, courseId: String, lessonId: String, ru: String, th: String) -> String {
        let normLesson = FDNormLessonId(lessonId)
        let cacheKey = normLesson + "|" + id
        // Memoization
        Self.stepIdCacheLock.lock()
        if let cached = Self.stepIdCache[cacheKey] {
            Self.stepIdCacheLock.unlock()
            return cached
        }
        Self.stepIdCacheLock.unlock()
        // Если уже в формате step:courseId:lessonId:idxN — нормализуем lessonId и возвращаем
        if id.hasPrefix("step:") {
            let comps = id.split(separator: ":").map(String.init)
            if comps.count == 4 {
                let cid = comps[1]
                let lid = FDNormLessonId(comps[2])
                let idx = comps[3]
                let result = "step:\(cid):\(lid):\(idx)"
                Self.stepIdCacheLock.lock()
                Self.stepIdCache[cacheKey] = result
                Self.stepIdCacheLock.unlock()
                return result
            }
        }
        guard !lessonId.isEmpty else { return id }
        let dsItems = StepData.shared.items(for: normLesson)

        func indexInDS() -> Int? {
            for (idx, any) in dsItems.enumerated() {
                let m = Mirror(reflecting: any)
                var idMatch = false
                var contentMatch = false
                var ruField = ""
                var thField = ""
                // 1) match by any id-like field
                for child in m.children {
                    guard let label = child.label else { continue }
                    if ["id","stepId","stepID","uid","code"].contains(label) {
                        let v = String(describing: child.value)
                        if normalizeId(v) == normalizeId(id) || v == id { idMatch = true }
                    }
                    if ["ru","titleRU","titleRu","title"].contains(label) {
                        ruField = String(describing: child.value)
                    }
                    if ["th","thai","subtitle","subtitleTH"].contains(label) {
                        thField = String(describing: child.value)
                    }
                }
                // 2) match by content if id failed
                if !idMatch, (!ru.isEmpty || !th.isEmpty) {
                    if (!ru.isEmpty && !ruField.isEmpty && ruField == ru) || (!th.isEmpty && !thField.isEmpty && thField == th) {
                        contentMatch = true
                    }
                }
                if idMatch || contentMatch { return idx }
            }
            return nil
        }

        if let idx = indexInDS() {
            var cId = courseId
            if cId.isEmpty, let located = locateLessonId(for: id, hintCourseId: nil) { cId = located.courseId }
            if cId.isEmpty { cId = "unknown" }
            let result = "step:\(cId):\(normLesson):idx\(idx)"
            Self.stepIdCacheLock.lock()
            Self.stepIdCache[cacheKey] = result
            Self.stepIdCacheLock.unlock()
            return result
        }

        // Fallback: raw StepData scan (как было)
        let steps = StepData.shared.items(for: normLesson)
        let stepNeedle = normalizeId(id)
        for (idx, any) in steps.enumerated() {
            let m = Mirror(reflecting: any)
            var found = false

            // 1) match by any id-like field (normalized, rightmost token)
            for child in m.children {
                guard let label = child.label else { continue }
                if ["id","stepId","stepID","uid","code"].contains(label) {
                    let v = String(describing: child.value)
                    if normalizeId(v) == stepNeedle || v == id { found = true; break }
                }
            }

            // 2) if not matched — try by ru/th content
            if !found {
                var ruMatch = false
                var thMatch = false
                for child in m.children {
                    guard let label = child.label else { continue }
                    if ["ru","titleRU","titleRu","title"].contains(label) {
                        let v = String(describing: child.value)
                        if !ru.isEmpty, !v.isEmpty, v == ru { ruMatch = true }
                    }
                    if ["th","thai","subtitle","subtitleTH"].contains(label) {
                        let v = String(describing: child.value)
                        if !th.isEmpty, !v.isEmpty, v == th { thMatch = true }
                    }
                }
                if ruMatch || thMatch { found = true }
            }

            if found {
                var cId = courseId
                if cId.isEmpty {
                    if let located = locateLessonId(for: id, hintCourseId: nil) { cId = located.courseId }
                    if cId.isEmpty { cId = "unknown" }
                }
                let result = "step:\(cId):\(normLesson):idx\(idx)"
                Self.stepIdCacheLock.lock()
                Self.stepIdCache[cacheKey] = result
                Self.stepIdCacheLock.unlock()
                return result
            }
        }
        // one more attempt: if id is like course.lesson.slug — try match by slug
        let parsed = FDParseIds(from: id)
        if let slug = parsed.stepId {
            for (idx, any) in steps.enumerated() {
                let m = Mirror(reflecting: any)
                for child in m.children {
                    guard let label = child.label else { continue }
                    if ["id","stepId","stepID","uid","code"].contains(label) {
                        let v = String(describing: child.value)
                        if normalizeId(v) == normalizeId(slug) {
                            var cId = courseId
                            if cId.isEmpty, let located = locateLessonId(for: id, hintCourseId: nil) { cId = located.courseId }
                            if cId.isEmpty { cId = "unknown" }
                            let result = "step:\(cId):\(normLesson):idx\(idx)"
                            Self.stepIdCacheLock.lock()
                            Self.stepIdCache[cacheKey] = result
                            Self.stepIdCacheLock.unlock()
                            return result
                        }
                    }
                }
            }
        }
        // fallback: preserve original id to keep uniqueness; do not force idx0
        Self.stepIdCacheLock.lock()
        Self.stepIdCache[cacheKey] = id
        Self.stepIdCacheLock.unlock()
        return id
    }

    // MARK: - Caches

    private var lessonTitleCache: [String: String] = [:]   // key: courseId|lessonId
    private static var stepKindCache:   [String: FDStepKindDisplay] = [:] // key: lessonId|stepId
    private static let stepKindCacheLock = NSLock()

    /// Cache: per-lesson index of stepId -> raw index (StepData order)
    private var stepIndexCache: [String: [String: Int]] = [:]   // key: normLessonId -> [normStepId: idx]
    /// Cache: per-lesson meta fields for fast lookups (built once per lesson)
    private var stepMetaCache: [String: [String: (ru: String, th: String, phon: String?, tip: String?, title: String?)]] = [:] // key: normLessonId -> [normStepId: meta]

    /// Build indices/meta for a lesson once (single Mirror pass)
    private func ensureLessonIndex(_ lessonId: String) {
        let lid = FDNormLessonId(lessonId)
        if stepIndexCache[lid] != nil { return }
        var id2idx: [String: Int] = [:]
        var id2meta: [String: (String, String, String?, String?, String?)] = [:]
        let steps = StepData.shared.items(for: lid)
        for (idx, any) in steps.enumerated() {
            let m = Mirror(reflecting: any)
            var sid: String = "\(idx)" // fallback to index if no explicit id
            var ru: String = ""
            var th: String = ""
            var phon: String?
            var tip: String?
            var title: String?
            for child in m.children {
                guard let label = child.label else { continue }
                switch label {
                case "id","stepId","stepID","uid","code":
                    sid = normalizeId(String(describing: child.value))
                case "ru","titleRU","titleRu","title":
                    ru = String(describing: child.value)
                case "th","thai","subtitle","subtitleTH":
                    th = String(describing: child.value)
                case "phonetic","translit","ipa","pinyin","roma","romaji":
                    let v = String(describing: child.value); if !v.isEmpty { phon = v }
                case "tip","text","body","content","value":
                    let v = String(describing: child.value); if !v.isEmpty { tip = v }
                case "name","header":
                    let v = String(describing: child.value); if !v.isEmpty { title = v }
                default:
                    break
                }
            }
            id2idx[sid] = idx
            id2meta[sid] = (ru, th, phon, tip, title)
        }
        stepIndexCache[lid] = id2idx
        stepMetaCache[lid]  = id2meta
    }

    // MARK: - Fallback locators
    /// Если у избранного нет lessonId, ищем урок, в котором есть шаг с данным stepId (нормализованным)
    private func locateLessonId(for stepId: String, hintCourseId: String?) -> (courseId: String, lessonId: String)? {
        let needle = normalizeId(stepId)
        // Приоритет: подсказка курса → попытка вытащить courseId из самого stepId
        var courseIds: [String] = []
        if let c = (hintCourseId?.isEmpty == false ? hintCourseId : nil) {
            courseIds = [c]
        } else {
            let parsed = FDParseIds(from: stepId)
            if let c = parsed.courseId, !c.isEmpty { courseIds = [c] }
            // если курс определить не удалось — прекращаем поиск
        }
        if courseIds.isEmpty { return nil }
        for cid in courseIds {
            let lessons = LessonsData.shared.lessons(for: cid)
            for l in lessons {
                let steps = StepData.shared.items(for: FDNormLessonId(l.id))
                for any in steps {
                    let m = Mirror(reflecting: any)
                    for child in m.children {
                        guard let label = child.label else { continue }
                        if ["id","stepId","stepID","uid","code"].contains(label) {
                            if normalizeId(String(describing: child.value)) == needle {
                                return (cid, l.id)
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Resolvers

    private func lessonTitle(courseId: String, lessonId: String) -> String? {
        guard !courseId.isEmpty, !lessonId.isEmpty else { return nil }
        let k = courseId + "|" + lessonId
        if let cached = lessonTitleCache[k] { return cached }

        // Non-isolated lookup: use LessonsData directly (thread-safe data source)
        let normCourse = FDNormCourseId(courseId)
        let normLesson = FDNormLessonId(lessonId)
        let lessons = LessonsData.shared.lessons(for: normCourse)
        if let hit = lessons.first(where: { FDNormLessonId($0.id) == normLesson }) {
            let t = hit.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                lessonTitleCache[k] = t
                return t
            }
        }
        // Fallback: try exact (non-normalized) match just in case
        if let hit2 = lessons.first(where: { $0.id == lessonId }) {
            let t = hit2.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                lessonTitleCache[k] = t
                return t
            }
        }
        return nil
    }

    /// Попытка определить тип шага (phrase/word/lifehack) из StepData, терпима к различиям API
    private func stepKind(lessonId: String, stepId: String) -> FDStepKindDisplay? {
        // If lessonId is unknown, still try to classify by the raw stepId
        if lessonId.isEmpty {
            let low = stepId.lowercased()
            if low.contains("tip") || low.contains("lifehack") || low.contains("hack") || low.contains("лайф") {
                return .lifehack
            }
            return nil
        }
        let normL = FDNormLessonId(lessonId)
        let k = lessonId + "|" + normalizeId(stepId)
        ensureLessonIndex(normL)
        let sidNorm = normalizeId(stepId)
        Self.stepKindCacheLock.lock()
        if let cached = Self.stepKindCache[k] {
            Self.stepKindCacheLock.unlock()
            return cached
        }
        Self.stepKindCacheLock.unlock()
        if let meta = stepMetaCache[normL]?[sidNorm] {
            // если есть tip и нет явных полей фразы — считаем лайфхаком без лишних рефлексий
            if (meta.tip?.isEmpty == false) && meta.ru.isEmpty && meta.th.isEmpty {
                Self.stepKindCacheLock.lock(); Self.stepKindCache[k] = .lifehack; Self.stepKindCacheLock.unlock()
                return .lifehack
            }
        }
        let steps = StepData.shared.items(for: normL)
        var matched: Any? = nil
        let needle = normalizeId(stepId)

        outer: for any in steps {
            let m = Mirror(reflecting: any)
            // ищем поле id/stepId/uid/code — берём совпадающее
            for child in m.children {
                guard let label = child.label else { continue }
                if ["id","stepId","stepID","uid","code"].contains(label) {
                    if let v = child.value as? String, normalizeId(v) == needle {
                        matched = any
                        break outer
                    }
                }
            }
        }

        if matched == nil, steps.count == 1 { matched = steps.first }
        guard let found = matched else { return nil }

        let m2 = Mirror(reflecting: found)
        var explicitDetected: FDStepKindDisplay? = nil
        let kindKeys = [
            "kind", "type", "category",
            "stepKind", "stepkind", "stepType", "steptype", "step_type",
            "k", "t", "cat", "tag"
        ]
        for child in m2.children {
            guard let label = child.label else { continue }
            if kindKeys.contains(label) {
                let raw = String(describing: child.value).lowercased()
                if raw.contains("phrase") || raw.contains("фраз") { explicitDetected = .phrase }
                else if raw.contains("word")   || raw.contains("слов") { explicitDetected = .word }
                else if raw.contains("lifehack") || raw.contains("лайф") || raw.contains("hack") || raw.contains("tip") || raw.contains("совет") || raw.contains("подсказ") { explicitDetected = .lifehack }
                else if raw.contains("casual") || raw.contains("неформ") { explicitDetected = .casual }
                else if raw.contains("dialog") || raw.contains("диалог") { explicitDetected = .dialog }
                break
            }
        }
        if let d = explicitDetected {
            Self.stepKindCacheLock.lock(); Self.stepKindCache[k] = d; Self.stepKindCacheLock.unlock()
            return d
        }

        // Heuristic: treat steps that have a standalone body/tip without phrase fields as lifehack
        do {
            let steps = StepData.shared.items(for: normL)
            let needle = normalizeId(stepId)
            for any in steps {
                let m = Mirror(reflecting: any)
                var idMatch = false
                var bodyCandidate: String?
                var hasPhraseFields = false
                for child in m.children {
                    guard let label = child.label else { continue }
                    if ["id","stepId","stepID","uid","code"].contains(label) {
                        if normalizeId(String(describing: child.value)) == needle { idMatch = true }
                    }
                    if ["ru","titleRU","titleRu","title"].contains(label) { hasPhraseFields = hasPhraseFields || !String(describing: child.value).isEmpty }
                    if ["th","thai","subtitle","subtitleTH","phonetic","translit"].contains(label) { hasPhraseFields = hasPhraseFields || !String(describing: child.value).isEmpty }
                    if ["tip","text","body","content","value"].contains(label) {
                        let v = String(describing: child.value)
                        if !v.isEmpty { bodyCandidate = v }
                    }
                }
                if idMatch, let _ = bodyCandidate, hasPhraseFields == false {
                    Self.stepKindCacheLock.lock(); Self.stepKindCache[k] = .lifehack; Self.stepKindCacheLock.unlock()
                    return .lifehack
                }
            }
        }

        // Last-resort: если не нашли объект шага, попробуем по самому stepId угадать tip/hack
        let low = stepId.lowercased()
        if low.contains("tip") || low.contains("lifehack") || low.contains("hack") || low.contains("лайф") {
            Self.stepKindCacheLock.lock(); Self.stepKindCache[k] = .lifehack; Self.stepKindCacheLock.unlock()
            return .lifehack
        }
        return nil
    }
    /// Prebuilds indices for all lessons in user favorites; call this in background before heavy resolve
    static func prepareCache(for favorites: [FavoriteItem]) {
        // Build unique lessonIds from all items
        let lessonIds: Set<String> = Set(favorites.compactMap { item in
            var lessonId = item.lessonId
            if lessonId.isEmpty {
                let parsed = FDParseIds(from: item.id)
                if let l = parsed.lessonId { lessonId = l }
            }
            return lessonId.isEmpty ? nil : FDNormLessonId(lessonId)
        })
        let instance = FavoriteData.shared
        for lid in lessonIds {
            instance.ensureLessonIndex(lid)
        }
    }

    // MARK: - Step mirrors (fallbacks for legacy favorites)

    private func lifehackBody(lessonId: String, stepId: String) -> String? {
        guard !lessonId.isEmpty else { return nil }
        let lid = FDNormLessonId(lessonId)
        ensureLessonIndex(lid)
        let sid = normalizeId(stepId)
        if let meta = stepMetaCache[lid]?[sid], let body = meta.tip, !body.isEmpty {
            return body
        }
        return nil
    }

    private func lifehackTitle(lessonId: String, stepId: String) -> String? {
        guard !lessonId.isEmpty else { return nil }
        let lid = FDNormLessonId(lessonId)
        ensureLessonIndex(lid)
        let sid = normalizeId(stepId)
        if let meta = stepMetaCache[lid]?[sid], let t = meta.title, !t.isEmpty {
            return t
        }
        return nil
    }

    /// Фоллбек-резолвер транслита/фонетики для шага по lessonId/stepId/ru/th (через кэш)
    private func stepPhonetic(lessonId: String, stepId: String, ru: String, th: String) -> String? {
        guard !lessonId.isEmpty else { return nil }
        let lid = FDNormLessonId(lessonId)
        ensureLessonIndex(lid)
        let sid = normalizeId(stepId)
        if let meta = stepMetaCache[lid]?[sid] {
            if let p = meta.phon, !p.isEmpty { return p }
            // fallback: если id не совпал, попробуем по содержимому
            if (!ru.isEmpty && !meta.ru.isEmpty && meta.ru == ru) || (!th.isEmpty && !meta.th.isEmpty && meta.th == th) {
                return meta.phon
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func normalizeId(_ raw: String) -> String {
        // сначала берём правую часть после ':', затем правую часть после '.' —
        // это даст нам собственно идентификатор шага (uuid/код)
        let afterColon = raw.split(separator: ":").last.map(String.init) ?? raw
        let afterDot   = afterColon.split(separator: ".").last.map(String.init) ?? afterColon
        return afterDot
    }
}


extension FavoriteData {
    /// Минимальный маршрут для неканоничных sourceId: попытаться получить (courseId, lessonId)
    /// Используется FavoriteView для открытия MiniStepHost, когда resolveRoute не сработал.
    func fallbackRoute(from sourceId: String, hintCourseId: String? = nil) -> (courseId: String, lessonId: String)? {
        // 1) прямой локатор по каталогу
        if let r = locateLessonId(for: sourceId, hintCourseId: hintCourseId) {
            return (r.courseId, FDNormLessonId(r.lessonId))
        }
        // 2) попытка распарсить dot-форму course.lesson[.slug]
        let p = FDParseIds(from: sourceId)
        if let c = p.courseId, let l = p.lessonId { return (c, FDNormLessonId(l)) }
        // 3) попытка распарсить course.lesson (без шага)
        let two = FDParseCourseLesson(from: sourceId)
        if let c = two.courseId, let l = two.lessonId { return (c, FDNormLessonId(l)) }
        return nil
    }
}


extension FavoriteData {
    /// Унифицированный выбор текста лайфхака из FavoriteItem/DS
    fileprivate func preferredHackText(item it: FavoriteItem, lessonId: String, stepId sid: String) -> String {
        // 1) Primary: explicit lifehack text stored in FavoriteItem.th
        let t1 = it.th.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t1.isEmpty { return t1 }

        // 2) Secondary: phonetic with a lifehack marker → strip the marker and trim
        let metaRaw = it.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !metaRaw.isEmpty {
            let lower = metaRaw.lowercased()
            let prefixes = ["hack:", "tip:"]
            for p in prefixes {
                if lower.hasPrefix(p) {
                    let dropped = metaRaw.dropFirst(p.count)
                    let stripped = dropped.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !stripped.isEmpty { return stripped }
                    break
                }
            }
        }

        // 3) Fallbacks from StepData: body/tip first, then title
        if let body = lifehackBody(lessonId: lessonId, stepId: sid)?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            return body
        }
        if let title = lifehackTitle(lessonId: lessonId, stepId: sid)?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }

        // 4) One more attempt with the original (possibly non-canonical) id
        if let body2 = lifehackBody(lessonId: lessonId, stepId: it.id)?.trimmingCharacters(in: .whitespacesAndNewlines), !body2.isEmpty {
            return body2
        }
        if let title2 = lifehackTitle(lessonId: lessonId, stepId: it.id)?.trimmingCharacters(in: .whitespacesAndNewlines), !title2.isEmpty {
            return title2
        }

        return ""
    }
}
