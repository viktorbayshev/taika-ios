//
//  MainData.swift
//  taika
//
//  Created by product on 24.08.2025.
//

import SwiftUI
import Foundation

/// View-model for the Main screen selections built from `CourseData`.
@MainActor class MainData: ObservableObject {
    @Published var featuredCourses: [Course] = []      // крупный баннер/карусель
    @Published var shortLessons: [Course] = []         // «короткие уроки»
    @Published var recommendedCourses: [Course] = []   // остальное (микс платн/беспл)

    /// Flattened accessor for convenience in views
    var courses: [Course] {
        featuredCourses + shortLessons + recommendedCourses
    }

    init() { reload() }

    /// Rebuilds all sections from the JSON source using `CourseData`.
    func reload() {
        switch CourseData().load() {
        case .success(let allCourses):
            buildSections(from: allCourses)
        case .failure:
            featuredCourses = []
            shortLessons = []
            recommendedCourses = []
        }
    }

    /// Pure function that fills published arrays. Keeps sections disjoint.
    private func buildSections(from allCourses: [Course]) {
        // Work on a mutable pool to avoid duplicates across sections
        var pool = allCourses

        // 1) Featured — первые 3 (или меньше, если курсов мало)
        let featuredCount = min(3, pool.count)
        featuredCourses = Array(pool.prefix(featuredCount))
        pool.removeFirst(featuredCount)

        // 2) Short lessons — быстрый вход. Фильтруем по количеству уроков (≤5) или
        // альтернативно по длительности (≤15 мин), если поле с уроками отсутствует.
        let shorts = pool.filter { course in
            if course.lessonCount <= 5 { return true }
            if course.durationMinutes <= 15 { return true }
            return false
        }
        shortLessons = shorts

        // 3) Recommended — всё остальное, без уже использованных id, слегка перемешать
        let usedIDs: Set<String> = Set(featuredCourses.map { $0.id })
            .union(Set(shortLessons.map { $0.id }))
        let remaining = pool.filter { course in
            !usedIDs.contains(course.id)
        }
        recommendedCourses = remaining.shuffled()
    }
}
