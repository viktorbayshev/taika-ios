//
//  CourseSearch.swift
//  taika
//
//  Created by product on 02.09.2025.
//



import Foundation

/// Simple model for course search indexing
struct SearchableCourse: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
}

/// Simple model for lesson search indexing
struct SearchableLesson: Identifiable, Equatable {
    let id: String
    let courseId: String
    let title: String
    let subtitle: String
    let description: String
}

/// Handles indexing and searching over courses + lessons
struct CourseSearch {
    private let courses: [SearchableCourse]
    private let lessons: [SearchableLesson]

    /// Builds the search index from the provided courses + lessons
    init(courses: [SearchableCourse], lessons: [SearchableLesson]) {
        self.courses = courses
        self.lessons = lessons
    }

    /// Normalizes a string for search (case/diacritic-insensitive, trimmed)
    private func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scoreMatch(title: String, subtitle: String, description: String, q: String) -> Int {
        // simple UX scoring: title > subtitle > description
        var score = 0
        if title.contains(q) { score += 3 }
        if subtitle.contains(q) { score += 2 }
        if description.contains(q) { score += 1 }
        return score
    }

    /// Searches courses and lessons matching the query.
    /// Returns at most `courseLimit` courses and `lessonLimit` lessons.
    func search(_ query: String, courseLimit: Int = 20, lessonLimit: Int = 30) -> (courses: [SearchableCourse], lessons: [SearchableLesson]) {
        let q = normalize(query)
        guard !q.isEmpty else { return ([], []) }

        // courses
        var courseHits: [(score: Int, item: SearchableCourse, key: String)] = []
        var seenCourseKeys = Set<String>()

        for course in courses {
            let t = normalize(course.title)
            let st = normalize(course.subtitle)
            let d = normalize(course.description)
            let score = scoreMatch(title: t, subtitle: st, description: d, q: q)
            guard score > 0 else { continue }

            // de-dupe by stable key; many sources duplicate the same course across sections
            let key = t + "|" + st
            if !seenCourseKeys.contains(key) {
                courseHits.append((score, course, key))
                seenCourseKeys.insert(key)
            }
        }

        courseHits.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.key < rhs.key
        }

        let courseResults = courseHits.prefix(courseLimit).map { $0.item }

        // lessons
        var lessonHits: [(score: Int, item: SearchableLesson, key: String)] = []
        var seenLessonKeys = Set<String>()

        for lesson in lessons {
            let t = normalize(lesson.title)
            let st = normalize(lesson.subtitle)
            let d = normalize(lesson.description)
            let score = scoreMatch(title: t, subtitle: st, description: d, q: q)
            guard score > 0 else { continue }

            let key = lesson.courseId + "|" + t + "|" + st
            if !seenLessonKeys.contains(key) {
                lessonHits.append((score, lesson, key))
                seenLessonKeys.insert(key)
            }
        }

        lessonHits.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.key < rhs.key
        }

        let lessonResults = lessonHits.prefix(lessonLimit).map { $0.item }

        return (courseResults, lessonResults)
    }
}
