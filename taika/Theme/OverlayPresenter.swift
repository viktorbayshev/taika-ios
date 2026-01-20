//
//  OverlayPresenter.swift
//  taika
//
//  Created by product on 13.12.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class OverlayPresenter: ObservableObject {

    static let shared = OverlayPresenter()

    enum Overlay: Equatable {
        // search (ui + data)
        case search

        // calendar (data only)
        case calendarAdd(Date)
        case calendarSummary(Date)

        // quickstart loading (ui only)
        case randomCourseLoading

        // pro gating (data only)
        case proCoursePaywall(courseId: String)

        // theme / accent (ui only)
        case accentPicker
    }

    @Published private(set) var overlay: Overlay? = nil

    // MARK: - search state

    @Published var searchQuery: String = ""

    @Published private(set) var searchCourseIds: [String] = []
    @Published private(set) var searchLessonIds: [String] = []

    @Published private(set) var isSearching: Bool = false

    private var searchIndex: SearchIndex? = nil
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        // debounce search so typing does not thrash the main view tree
        $searchQuery
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] q in
                self?.performSearch(query: q)
            }
            .store(in: &cancellables)
    }

    /// Configure search index once (e.g. after Course/Lessons JSON are loaded).
    func configureSearchIndex(courses: [SearchIndex.Entry], lessons: [SearchIndex.Entry]) {
        self.searchIndex = SearchIndex(courses: courses, lessons: lessons)
        // re-run current query against the new index
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        performSearch(query: q)
    }

    func resetSearchState() {
        searchQuery = ""
        searchCourseIds = []
        searchLessonIds = []
        isSearching = false
    }

    var isPresented: Bool { overlay != nil }

    var isSearchPresented: Bool {
        if case .search = overlay { return true }
        return false
    }

    func presentSearch() {
        resetSearchState()
        overlay = .search
    }

    func presentAccentPicker() {
        overlay = .accentPicker
    }

    func present(_ overlay: Overlay) {
        self.overlay = overlay
    }

    func dismiss() {
        if isSearchPresented {
            resetSearchState()
        }
        overlay = nil
    }

    // MARK: - search implementation

    struct SearchIndex: Sendable {
        struct Entry: Sendable {
            let id: String
            let haystack: String

            init(id: String, haystack: String) {
                self.id = id
                self.haystack = SearchIndex.normalize(haystack)
            }
        }

        let courses: [Entry]
        let lessons: [Entry]

        init(courses: [Entry], lessons: [Entry]) {
            self.courses = courses
            self.lessons = lessons
        }

        static func normalize(_ s: String) -> String {
            // keep it fast and locale-agnostic
            s.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
        }
    }

    private func performSearch(query raw: String) {
        guard isSearchPresented else { return }

        let q = SearchIndex.normalize(raw)
        guard let idx = searchIndex else {
            // no index yet – keep empty results, but do not thrash
            searchCourseIds = []
            searchLessonIds = []
            isSearching = false
            return
        }

        guard q.count >= 2 else {
            // treat short queries as "empty" to avoid noisy matches
            searchCourseIds = []
            searchLessonIds = []
            isSearching = false
            return
        }

        let courses = idx.courses
        let lessons = idx.lessons

        isSearching = true

        Task.detached(priority: .userInitiated) {
            let courseMatches = courses
                .filter { $0.haystack.contains(q) }
                .prefix(24)
                .map { $0.id }

            let lessonMatches = lessons
                .filter { $0.haystack.contains(q) }
                .prefix(24)
                .map { $0.id }

            let courseIds = Array(courseMatches)
            let lessonIds = Array(lessonMatches)

            await MainActor.run {
                // only apply if we are still in search overlay and query hasn't changed
                guard self.isSearchPresented else { return }
                guard SearchIndex.normalize(self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)) == q else { return }

                self.searchCourseIds = courseIds
                self.searchLessonIds = lessonIds
                self.isSearching = false
            }
        }
    }
}
