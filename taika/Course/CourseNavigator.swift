import Foundation
import SwiftUI

public final class CourseNavigator {

    public static let shared = CourseNavigator()

    private init() {}

    public enum Advance {
        case nextLesson(courseId: String, lessonId: String)
        case nextCourse(courseId: String, lessonId: String)
        case end
    }

    // read from LessonsData
    private var lessonsData: LessonsData { .shared }
    private var courseData: CourseData { .shared }

    // ordered course ids
    public func orderedCourses() -> [String] {
        courseData.courses.map { $0.courseID }
    }

    // ordered lesson ids for given course
    public func orderedLessons(in courseId: String) -> [String] {
        var result: [String] = []
        // Probe sequential lesson ids following the app's established naming: courseId_l1, courseId_l2, ...
        // Stop at the first missing id AFTER we've found at least one.
        var foundAny = false
        for n in 1...99 {
            let lid = "\(courseId)_l\(n)"
            let items = StepData.shared.items(for: lid)
            if items.isEmpty {
                if foundAny { break } else { continue }
            }
            foundAny = true
            result.append(lid)
        }
        return result
    }

    // first lesson for course
    public func firstLesson(in courseId: String) -> String? {
        orderedLessons(in: courseId).first
    }

    // main advance logic
    public func advance(from courseId: String, lessonId: String) -> Advance {
        let lessons = orderedLessons(in: courseId)
        if let index = lessons.firstIndex(of: lessonId) {
            let next = index + 1
            if next < lessons.count {
                return .nextLesson(courseId: courseId, lessonId: lessons[next])
            } else {
                let courses = orderedCourses()
                if let ci = courses.firstIndex(of: courseId), ci + 1 < courses.count {
                    let nextCourse = courses[ci + 1]
                    if let first = firstLesson(in: nextCourse) {
                        return .nextCourse(courseId: nextCourse, lessonId: first)
                    }
                }
                return .end
            }
        }
        return .end
    }

    // resolve title safely
    public func lessonTitle(for lessonId: String) -> String {
        lessonsData.lessonTitle(for: lessonId) ?? "без названия"
    }

    // resolve course title safely from CourseData
    public func courseTitle(for courseId: String) -> String {
        if let course = courseData.courses.first(where: { $0.courseID == courseId }) {
            let t = (course.title as String).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return t.isEmpty ? courseId : t
        }
        // readable fallback: turn identifier into spaced words
        let pretty = courseId
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return pretty.isEmpty ? courseId : pretty
    }
}
