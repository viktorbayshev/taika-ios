//
//  HomeTaskManager.swift
//  taika
//
//  Created by product on 03.09.2025.
//
import Foundation
@MainActor
public final class HomeTaskManager: ObservableObject {
    @Published public private(set) var tasksByCourse: [String: [HTask]] = [:]
    // Learned triples captured for each task id
    private var triplesByTask: [String: [LearnedTriple]] = [:]

    /// Rule for when to spawn a hometask
    public enum Rule {
        case everyNLessons(Int)
        case finalAfter(Int)
    }

    // MARK: - UI adapters
    /// Estimated time (in minutes) based on the number of triples in the task.
    @MainActor
    public func estimatedMinutes(for taskId: String) -> Int? {
        guard let c = triplesByTask[taskId]?.count, c > 0 else { return nil }
        // Heuristic: ~0.7 min per card, at least 3 minutes per task
        return max(3, Int(round(Double(c) * 0.7)))
    }

    /// Generic adapter that maps internal HTask + triples into a UI model using a builder closure.
    /// This lets LessonsDS/HT build its own `HT.Item` without tight coupling here.
    @MainActor
    public func hometasksFor<T>(courseId: String,
                                make: (_ task: HTask, _ isLocked: Bool, _ estMinutes: Int?, _ triples: [LearnedTriple]) -> T) -> [T] {
        let tasks = tasks(for: courseId)
        return tasks.map { t in
            let pool = triplesByTask[t.id] ?? []
            let locked = pool.isEmpty
            let minutes = estimatedMinutes(for: t.id)
            return make(t, locked, minutes, pool)
        }
    }

    public struct LearnedTriple {
        public let ru: String
        public let th: String
        public let ph: String
        public init(ru: String, th: String, ph: String) {
            self.ru = ru; self.th = th; self.ph = ph
        }
    }

    // MARK: - Planning (UI-agnostic)
    public struct PlanDescriptor: Identifiable {
        public let id: String
        public let title: String
        public let index: Int
        public let triples: [LearnedTriple]
        public init(id: String, title: String, index: Int, triples: [LearnedTriple]) {
            self.id = id
            self.title = title
            self.index = index
            self.triples = triples
        }
    }

    // MARK: - Status & Kind (UI-agnostic)
    public enum HTAvailability: Equatable {
        case locked
        case available
        case done
    }

    /// Pick a game kind label by index (cyclic) or mark final as mixed.
    @inline(__always)
    public func gameKind(for index: Int, isFinal: Bool = false) -> String {
        if isFinal { return "смешанная" }
        let kinds = ["пары", "викторина", "аудио"]
        guard index >= 0 else { return kinds[0] }
        return kinds[index % kinds.count]
    }

    /// Determine availability for a planned descriptor using learned triples and any existing task state.
    @MainActor
    public func status(for descriptor: PlanDescriptor, courseId: String, minTriples: Int = 6) -> HTAvailability {
        // If we already have a concrete task with DONE status — surface that.
        if let existing = tasksByCourse[courseId]?.first(where: { $0.id == descriptor.id }) {
            if existing.status == .done { return .done }
            // If a real task exists but not done — consider it available.
            return .available
        }
        // Otherwise decide from the descriptor's pool size
        return descriptor.triples.count >= minTriples ? .available : .locked
    }

    /// Build a plan annotated with availability and game kind (no concrete HTask creation required).
    @MainActor
    public func availability(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(3),
        samplePerTask: Int = 6,
        minTriples: Int = 6
    ) -> [(descriptor: PlanDescriptor, status: HTAvailability, game: String)] {
        let plan = plan(for: courseId, lessonIds: lessonIds, rule: rule, samplePerTask: samplePerTask)
        return plan.enumerated().map { idx, d in
            let isFinal = d.id.hasSuffix("-ht-final")
            return (d, status(for: d, courseId: courseId, minTriples: minTriples), gameKind(for: idx, isFinal: isFinal))
        }
    }

    /// Compute a plan of hometasks from learned data without constructing concrete HTask models.
    /// Use this when the caller wants to build view models or domain tasks on their side.
    @MainActor
    public func plan(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(2),
        samplePerTask: Int = 6
    ) -> [PlanDescriptor] {
        var output: [PlanDescriptor] = []

        func appendChunked(n: Int) {
            guard n > 0 else { return }
            var i = 0
            var taskIndex = 1
            while i < lessonIds.count {
                let chunk = Array(lessonIds[i..<min(i + n, lessonIds.count)])
                var pool: [LearnedTriple] = []
                for lid in chunk { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
                guard !pool.isEmpty else { i += n; continue }
                let picked = sample(pool, count: samplePerTask)
                let title = "Практика #\(taskIndex)"
                let id = "\(courseId)-ht-\(taskIndex)"
                output.append(.init(id: id, title: title, index: taskIndex, triples: picked))
                taskIndex += 1
                i += n
            }
        }

        func appendFinal(total: Int) {
            guard lessonIds.count >= total else { return }
            var pool: [LearnedTriple] = []
            for lid in lessonIds { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
            guard !pool.isEmpty else { return }
            let picked = sample(pool, count: max(samplePerTask, 12))
            let id = "\(courseId)-ht-final"
            output.append(.init(id: id, title: "Итоговая практика", index: max(output.count + 1, 1), triples: picked))
        }

        switch rule {
        case .everyNLessons(let n):
            appendChunked(n: n)
        case .finalAfter(let total):
            appendFinal(total: total)
        }
        return output
    }

    public init() {}

    public func setTasks(_ tasks: [HTask], for courseId: String) {
        tasksByCourse[courseId] = tasks
    }

    public func tasks(for courseId: String) -> [HTask] {
        tasksByCourse[courseId] ?? []
    }

    public func triples(for taskId: String) -> [LearnedTriple] {
        triplesByTask[taskId] ?? []
    }

    public func progress(for courseId: String) -> HTaskProgress {
        let ts = tasks(for: courseId)
        let total = ts.count
        let done = ts.filter { $0.status == .done }.count
        return .init(done: done, total: total)
    }

    public func markDone(_ taskId: String, in courseId: String) {
        guard var arr = tasksByCourse[courseId], let idx = arr.firstIndex(where: { $0.id == taskId }) else { return }
        arr[idx].status = .done
        tasksByCourse[courseId] = arr
    }

    // MARK: - Data collection from progress / steps
    @MainActor
    private func learnedTriples(courseId: String, lessonId: String) -> [LearnedTriple] {
        // Pull steps for the lesson and select only learned indices
        let steps = StepData.shared.items(for: lessonId)
        let learnedIdx = ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lessonId)
        var out: [LearnedTriple] = []
        for (i, it) in steps.enumerated() {
            guard learnedIdx.contains(i) else { continue }
            switch it.kind {
            case .word, .phrase, .casual:
                if let ru = it.ru {
                    let th = it.thai ?? ""
                    let ph = it.phonetic ?? ""
                    out.append(.init(ru: ru, th: th, ph: ph))
                }
            default: continue
            }
        }
        return out
    }

    /// Expose raw learned indices for a lesson (snapshot from ProgressManager)
    @MainActor
    public func learnedIndices(courseId: String, lessonId: String) -> Set<Int> {
        return ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lessonId)
    }

    private func sample<T>(_ array: [T], count: Int) -> [T] {
        guard count < array.count else { return array }
        return Array(array.shuffled().prefix(count))
    }

    /// Rebuild hometasks for a course using a planning rule and a UI-agnostic builder.
    /// - Parameters:
    ///   - courseId: course to plan for
    ///   - lessonIds: ordered lesson ids for this course
    ///   - rule: grouping rule (default: one task per 2 lessons)
    ///   - samplePerTask: how many learned cards to include at most per task
    ///   - makeTask: builder that converts a title and card triples into an `HTask`
    @MainActor
    public func regenerateTasks(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(2),
        samplePerTask: Int = 6,
        makeTask: (_ title: String, _ triples: [LearnedTriple], _ index: Int) -> HTask
    ) {
        var produced: [HTask] = []

        // 1) Блоковые домашки (каждые N уроков)
        func appendChunked(n: Int) {
            guard n > 0 else { return }
            var i = 0
            var taskIndex = 1
            while i < lessonIds.count {
                let chunk = Array(lessonIds[i..<min(i + n, lessonIds.count)])
                var pool: [LearnedTriple] = []
                for lid in chunk { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
                guard !pool.isEmpty else { i += n; continue }
                let picked = sample(pool, count: samplePerTask)
                let title = "Практика #\(taskIndex)"
                let task = makeTask(title, picked, taskIndex)
                produced.append(task)
                triplesByTask[task.id] = picked
                taskIndex += 1
                i += n
            }
        }

        // 2) Финальная домашка (после total уроков)
        func appendFinal(total: Int) {
            guard lessonIds.count >= total else { return }
            var pool: [LearnedTriple] = []
            for lid in lessonIds { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
            guard !pool.isEmpty else { return }
            let picked = sample(pool, count: max(samplePerTask, 12))
            let title = "Итоговая практика"
            let task = makeTask(title, picked, (produced.count + 1))
            produced.append(task)
            triplesByTask[task.id] = picked
        }

        switch rule {
        case .everyNLessons(let n):
            appendChunked(n: n)
        case .finalAfter(let total):
            appendFinal(total: total)
        }

        setTasks(produced, for: courseId)
    }

    // MARK: - Sync with current learned flags
    /// Refresh internal pools (triplesByTask) for already created tasks using the latest learned flags
    /// from ProgressManager. This does NOT create or delete tasks; it only rebinds their card pools
    /// so UI shows up-to-date content and availability/locking is correct.
    /// Call this after toggling learned or on app foreground with the same grouping rule
    /// you used for task creation.
    @MainActor
    public func syncFromProgress(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(2),
        samplePerTask: Int = 6
    ) {
        // Build a fresh plan based on current learned flags
        let plan = plan(for: courseId, lessonIds: lessonIds, rule: rule, samplePerTask: samplePerTask)
        // Rebind pools for ids that we already have in tasksByCourse (leave unknown ids untouched)
        var map: [String: [LearnedTriple]] = [:]
        for d in plan {
            map[d.id] = d.triples
        }
        // Update existing tasks' pools
        if let tasks = tasksByCourse[courseId] {
            for task in tasks {
                if let triples = map[task.id] {
                    triplesByTask[task.id] = triples
                }
            }
        }
    }
    // MARK: - Normalization & Game Availability
    public enum HTGameMode: String, CaseIterable {
        case quiz, matching, audio, transcription
    }

    /// Clean user-facing triples: remove duplicates and fallback phonetic to RU if missing
    @MainActor
    public func userTriples(for courseId: String, lessonId: String) -> [LearnedTriple] {
        let raw = learnedTriples(courseId: courseId, lessonId: lessonId)
        var seen = Set<String>()
        var result: [LearnedTriple] = []
        for t in raw {
            let ru = t.ru.trimmingCharacters(in: .whitespacesAndNewlines)
            let th = t.th.trimmingCharacters(in: .whitespacesAndNewlines)
            let phRaw = t.ph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ru.isEmpty else { continue }
            let ph = phRaw.isEmpty ? ru : phRaw
            if seen.insert(ru.lowercased()).inserted {
                result.append(.init(ru: ru, th: th, ph: ph))
            }
        }
        return result
    }

    /// Determine which game modes are feasible based on data
    @MainActor
    public func availableModes(for courseId: String, lessonId: String) -> [HTGameMode] {
        let triples = userTriples(for: courseId, lessonId: lessonId)
        var modes: [HTGameMode] = []
        let uniqueRU = Set(triples.map { $0.ru }).count
        let nonEmptyPH = triples.filter { !$0.ph.isEmpty }.count

        if uniqueRU >= 4 { modes.append(.quiz) }
        if triples.count >= 3 { modes.append(.matching) }
        if nonEmptyPH >= 3 { modes.append(.transcription) }
        // audio temporarily disabled until audio sources ready
        // if audioAvailable(for: courseId, lessonId: lessonId) { modes.append(.audio) }

        return modes
    }

    private func audioAvailable(for courseId: String, lessonId: String) -> Bool {
        return false
    }
    // MARK: - Flow helper
    @MainActor
    public func firstAvailableTask(for courseId: String) -> HTask? {
        let ts = tasks(for: courseId)
        // вернуть первую задачу, которая ещё не помечена done
        if let notDone = ts.first(where: { $0.status != .done }) {
            return notDone
        }
        // иначе просто первую (если массив не пуст)
        return ts.first
    }
}
