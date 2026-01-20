import Foundation
import SwiftUI

// MARK: - Models

public struct LearningOutcome: Codable, Hashable, Identifiable {
    public var id: String { type }
    public let type: String
    public let count: Int
}

public struct Course: Codable, Identifiable, Hashable {
    // core json-aligned fields
    public let courseID: String
    public let title: String
    public let description: String
    public let category: String
    public let isPro: Bool
    public let lessonCount: Int
    public let durationMinutes: Int
    /// Иконки пока не используем: делаем их опциональными, чтобы JSON без поля не ломал парсинг
    public let iconName: String?
    public let isNew: Bool
    /// Может отсутствовать в кратких версиях JSON
    public let learningOutcomes: [LearningOutcome]

    // computed id for Identifiable convenience
    public var id: String { courseID }

    public var homeworkTotal: Int { 0 }
    public var homeworkDone: Int { 0 }

    enum CodingKeys: String, CodingKey {
        case courseID = "course_id"
        case title, description, category
        case isPro = "is_pro"
        case lessonCount = "lesson_count"
        case durationMinutes = "duration_minutes"
        case iconName = "icon_name"
        case isNew = "is_new"
        case learningOutcomes = "learning_outcomes"
        case id
        case courseTitle = "course_title"
    }

    /// Memberwise init for manual construction (e.g., previews/mocks)
    public init(
        courseID: String,
        title: String,
        description: String,
        category: String,
        isPro: Bool,
        lessonCount: Int,
        durationMinutes: Int,
        iconName: String? = nil,
        isNew: Bool = false,
        learningOutcomes: [LearningOutcome] = []
    ) {
        self.courseID = courseID
        self.title = title
        self.description = description
        self.category = category
        self.isPro = isPro
        self.lessonCount = lessonCount
        self.durationMinutes = durationMinutes
        self.iconName = iconName
        self.isNew = isNew
        self.learningOutcomes = learningOutcomes
    }

    // Кастомный decoder: гибко читаем Int/Bool и ставим дефолты для отсутствующих полей
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id fallback: accept either "course_id" or plain "id"
        if let cid = try? c.decode(String.self, forKey: .courseID) {
            self.courseID = cid
        } else if let cid = try? c.decode(String.self, forKey: .id) {
            self.courseID = cid
        } else {
            throw DecodingError.keyNotFound(CodingKeys.courseID, .init(codingPath: c.codingPath, debugDescription: "Neither course_id nor id present"))
        }

        // title fallback: accept either "title" or legacy "course_title"
        if let t = try? c.decode(String.self, forKey: .title) {
            self.title = t
        } else if let t = try? c.decode(String.self, forKey: .courseTitle) {
            self.title = t
        } else {
            throw DecodingError.keyNotFound(CodingKeys.title, .init(codingPath: c.codingPath, debugDescription: "Neither title nor course_title present"))
        }
        self.description = try c.decode(String.self, forKey: .description)
        self.category = try c.decode(String.self, forKey: .category)
        self.isPro = (try? c.decode(Bool.self, forKey: .isPro))
            ?? (try? c.decode(String.self, forKey: .isPro).lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "true")
            ?? false
        self.lessonCount = (try? c.decode(Int.self, forKey: .lessonCount))
            ?? (try? c.decode(String.self, forKey: .lessonCount)).flatMap { Int($0) } ?? 0
        self.durationMinutes = (try? c.decode(Int.self, forKey: .durationMinutes))
            ?? (try? c.decode(String.self, forKey: .durationMinutes)).flatMap { Int($0) } ?? 0
        self.iconName = try? c.decode(String.self, forKey: .iconName)
        self.isNew = (try? c.decode(Bool.self, forKey: .isNew))
            ?? (try? c.decode(String.self, forKey: .isNew).lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "true")
            ?? false
        self.learningOutcomes = (try? c.decode([LearningOutcome].self, forKey: .learningOutcomes)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(courseID, forKey: .courseID)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(category, forKey: .category)
        try c.encode(isPro, forKey: .isPro)
        try c.encode(lessonCount, forKey: .lessonCount)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encodeIfPresent(iconName, forKey: .iconName)
        try c.encode(isNew, forKey: .isNew)
        try c.encode(learningOutcomes, forKey: .learningOutcomes)
    }
}

// MARK: - Data Source

public final class CourseData: ObservableObject {
    /// Global singleton for quick access from views (e.g., previews / legacy call sites).
    /// It auto-loads `taika_basa_course.json` once at startup.
    public static let shared: CourseData = {
        let instance = CourseData()
        _ = instance.load() // safe: prints error if file missing
        return instance
    }()

    @Published public private(set) var courses: [Course] = []
    private var didLoad = false
    
    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
         .replacingOccurrences(of: "\u{00A0}", with: " ") // NBSP → space
         .lowercased()
    }

    public init() {}

    /// Load courses from a JSON file in the main bundle. The extension must be `.json`.
    @discardableResult
    public func load(from filename: String = "taika_basa_course") -> Result<[Course], Error> {
        if didLoad, !courses.isEmpty {
            return .success(courses)
        }
        do {
            let courses = try CourseData.decode([Course].self, fromJSON: filename)
            if Thread.isMainThread {
                self.courses = courses
                self.didLoad = true
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.courses = courses
                    self?.didLoad = true
                }
            }
            print("[CourseData] loaded: \(courses.count) courses → ids: \(courses.prefix(3).map{ $0.courseID })")
            return .success(courses)
        } catch {
            print("[CourseData] Failed to load \(filename).json: \(error)")
            return .failure(error)
        }
    }

    /// Convenience to load from raw `Data` (useful for tests / previews).
    @discardableResult
    public func load(from data: Data) -> Result<[Course], Error> {
        if didLoad, !courses.isEmpty {
            return .success(courses)
        }
        do {
            let decoded = try JSONDecoder.taika.decode([Course].self, from: data)
            if Thread.isMainThread {
                self.courses = decoded
                self.didLoad = true
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.courses = decoded
                    self?.didLoad = true
                }
            }
            return .success(decoded)
        } catch {
            print("[CourseData] Failed to decode raw data: \(error)")
            return .failure(error)
        }
    }

    public func course(with id: String) -> Course? {
        let nid = norm(id)
        // 1) exact (fast)
        if let exact = courses.first(where: { $0.courseID == id }) { return exact }
        // 2) case/whitespace-insensitive
        if let ci = courses.first(where: { norm($0.courseID) == nid }) { return ci }
        // 3) relaxed contains (guards against prefixes/suffixes or legacy ids)
        if let rel = courses.first(where: { nid.contains(norm($0.courseID)) || norm($0.courseID).contains(nid) }) {
            return rel
        }
        return nil
    }

    // Simple aggregates if понадобятся в UI
    public var totalLessons: Int { courses.reduce(0) { $0 + $1.lessonCount } }
    public var totalDurationMinutes: Int { courses.reduce(0) { $0 + $1.durationMinutes } }

    /// Курсы для карусели-подборки (можно позже сузить фильтрами)
    public var featuredCourses: [Course] {
        courses
    }

    /// Title for a given course id (1:1 with CourseView, uses Course.title)
    public func title(for id: String) -> String? {
        course(with: id)?.title
    }

    /// Subtitle/description for a given course id (1:1 with CourseView, uses Course.description)
    public func subtitle(for id: String) -> String? {
        course(with: id)?.description
    }

    /// Returns the description string for a given course id, if available.
    public func description(for id: String) -> String? {
        course(with: id)?.description
    }

    /// Placeholder: total homework tasks for a course
    public func homeworkTotal(for courseId: String) -> Int {
        courses.first(where: { $0.courseID == courseId })?.homeworkTotal ?? 0
    }

    /// Placeholder: completed homework tasks for a course
    public func homeworkDone(for courseId: String) -> Int {
        courses.first(where: { $0.courseID == courseId })?.homeworkDone ?? 0
    }
    
    public func category(for id: String) -> String? {
        let cat = course(with: id)?.category
        if cat == nil { print("[CourseData] category not found for id=\(id). Known: \(courses.map{ $0.courseID }.prefix(5)) …") }
        return cat
    }
}

// MARK: - JSON Helpers

private extension CourseData {
    static func decode<T: Decodable>(_ type: T.Type, fromJSON name: String) throws -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "CourseData", code: 1, userInfo: [NSLocalizedDescriptionKey: "File \(name).json not found in bundle"]) }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.taika.decode(T.self, from: data)
    }
}

private extension JSONDecoder {
    static var taika: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys // мы сами описали CodingKeys, т.к. в JSON есть snake_case
        return d
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: K) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let s = try? decode(String.self, forKey: key), let i = Int(s) { return i }
        return nil
    }
    func decodeFlexibleBool(forKey key: K) -> Bool? {
        if let b = try? decode(Bool.self, forKey: key) { return b }
        if let s = try? decode(String.self, forKey: key) {
            return ["1","true","yes"].contains(s.lowercased())
        }
        return nil
    }
}

// MARK: - Debug Samples

#if DEBUG
public enum CourseSamples {
    /// Быстрая проверка, что парсинг проходит (читает тот же файл из бандла).
    public static var fromBundle: [Course] {
        (try? CourseData.decode([Course].self, fromJSON: "taika_basa_course")) ?? []
    }

    /// Минимальный мок на случай отсутствия файла.
    public static var minimal: [Course] {[
        Course(
            courseID: "sample_1",
            title: "Разговорный старт",
            description: "Быстрый разгон разговорных фраз.",
            category: "База от Тайки",
            isPro: false,
            lessonCount: 8,
            durationMinutes: 15,
            iconName: "start_point",
            isNew: true,
            learningOutcomes: [
                LearningOutcome(type: "Приветствия", count: 5),
                LearningOutcome(type: "Фразы", count: 10)
            ]
        )
    ]}
}
#endif
