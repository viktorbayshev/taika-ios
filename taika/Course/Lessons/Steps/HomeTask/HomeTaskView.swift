//
//  HomeTaskView.swift
//  taika
//
//  Minimal game screen: "Подобрать пару" — phonetic (left) ↔ ru (right)
//  Uses MPMatchPairsGrid from HomeTaskDS.swift and HomeTaskManager as data source.
//

import SwiftUI

@MainActor
public struct HomeTaskView: View {
    public let courseId: String
    public let lessonId: String
    public let embedBackground: Bool
    public let onClose: (() -> Void)?
    public let onNextGame: (() -> Void)?
    public let isProUser: Bool
    public let displayTitle: String?
    @StateObject private var store: HomeTaskManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager

    // Matching state
    @State private var leftItems: [MPItem] = []
    @State private var rightItems: [MPItem] = []
    @State private var selectedLeft: Int? = nil
    @State private var selectedRight: Int? = nil
    @State private var matchedPairIds: Set<String> = []
    @State private var tries: Int = 0
    // Summary overlay visibility (separate from computed isFinished)
    @State private var showSummary: Bool = false

    // Intro animation state
    @State private var didRunIntro: Bool = false
    @State private var gridFlipDeg: Double = 0
    @State private var gridOpacity: Double = 0
    @State private var flipTimer: Timer? = nil
    @State private var flipCycle: Int = 0
    @State private var flipStates: [String: Bool] = [:]

    // Staged pool logic
    @State private var allTriples: [HomeTaskManager.LearnedTriple] = []
    @State private var remainingTriples: [HomeTaskManager.LearnedTriple] = []
    @State private var totalPairsCount: Int = 0
    private let visiblePairsTarget: Int = 5

    public init(courseId: String,
                lessonId: String,
                embedBackground: Bool = false,
                store: HomeTaskManager? = nil,
                onClose: (() -> Void)? = nil,
                onNextGame: (() -> Void)? = nil,
                isProUser: Bool = true,
                displayTitle: String? = nil) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.embedBackground = embedBackground
        self.onClose = onClose
        self.onNextGame = onNextGame
        self.isProUser = isProUser
        self.displayTitle = displayTitle
        _store = StateObject(wrappedValue: store ?? HomeTaskManager())
    }

    public var body: some View {
        VStack(spacing: 0) {
            if leftItems.isEmpty || rightItems.isEmpty {
                emptyState
                    .onAppear {
                        buildRound()
                        if !didRunIntro {
                            didRunIntro = true
                            startTabloidIntro()
                        }
                    }
                    .padding(.top, 12)
            } else {
                dsHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                MPMatchPairsGrid(
                    left: leftItems,
                    right: rightItems,
                    selectedLeft: selectedLeft,
                    selectedRight: selectedRight,
                    leftTitle: "транслит",
                    rightTitle: "перевод",
                    onTapLeft: { tapLeft($0) },
                    onTapRight: { tapRight($0) },
                    revealedIds: Set(flipStates.compactMap { $0.value ? $0.key : nil })
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .allowsHitTesting(!isFinished)
                .animation(.default, value: matchedPairIds)
                .rotation3DEffect(.degrees(gridFlipDeg), axis: (x: 0, y: 1, z: 0))
                .opacity(gridOpacity)
            }
            Spacer(minLength: 0)
        }
        .overlay {
            if isFinished && showSummary {
                ZStack {
                    // Dimmed glass backdrop (non-interactive)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .saturation(1.0)
                        .contrast(1.12)
                        .overlay(Color.black.opacity(0.22))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    // Summary card
                    HomeTaskSummaryOverlay(
                        title: "Итоги закрепления",
                        subtitle: "пары: \(matchedPairIds.count) из \(totalPairsCount) • попытки: \(tries)",
                        primaryTitle: "ещё раз",
                        secondaryTitle: "следующая игра",
                        onPrimary: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSummary = false
                            buildRound(force: true)
                        },
                        onSecondary: {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            showSummary = false
                            onNextGame?()
                        },
                        onClose: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSummary = false
                            buildRound(force: true)
                        },
                        ctaStyle: .brandChips,
                        isProUser: isProUser
                    )
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.spring(response: 0.35, dampingFraction: 0.95), value: showSummary)
            }
        }
        .overlay(alignment: .topTrailing) {
            // floating close (View-level only)
            Button(action: {
                if let onClose = onClose { onClose() } else { dismiss() }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .padding(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 16)
            .opacity(isFinished ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isFinished)
        }
        .background(
            Group {
                if embedBackground {
                    CD.ColorToken.background.ignoresSafeArea()
                } else {
                    Color.clear
                }
            }
        )
        .onAppear {
            buildRound()
            if !didRunIntro {
                didRunIntro = true
                startTabloidIntro()
            }
        }
        .onDisappear {
            flipTimer?.invalidate()
        }
    }


    // DS header: title + tiny hint (matches HomeTaskDS look)
    private var dsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("подобрать пару")
                .font(CD.FontToken.title(26, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
            HStack(spacing: 8) {
                Circle()
                    .foregroundStyle(theme.currentAccentFill)
                    .frame(width: 6, height: 6)
                Text("найди совпадения слева и справа")
                    .font(CD.FontToken.body(13, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("нет пар для матча")
                .font(CD.FontToken.body(16, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("обновить") { buildRound(force: true) }
                .font(CD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().stroke(theme.currentAccentFill, lineWidth: 1))
        }
        .padding(20)
    }

    // MARK: - Logic
    private var isFinished: Bool { totalPairsCount > 0 && matchedPairIds.count >= totalPairsCount }

    private func titleForLesson() -> String {
        if let t = displayTitle, !t.isEmpty { return t }
        let title = resolvedLessonTitle()
        return "\(title) — подобрать пару"
    }

    private func resolvedLessonTitle() -> String {
        // Try LessonsData with dashed IDs first
        let (_, clid) = canonicalIds()
        if let t = LessonsData.shared.lessonTitle(for: clid), !t.isEmpty { return t }
        // Fallback to original lessonId
        if let t = LessonsData.shared.lessonTitle(for: lessonId), !t.isEmpty { return t }
        // Graceful fallback: derive "Урок N" from id like "lesson_1" or "..._l8"
        if let n = lessonNumber(from: lessonId) { return "Урок \(n)" }
        return "Урок"
    }

    private func lessonNumber(from raw: String) -> Int? {
        // Extract trailing digits after "lesson_" or "_l"
        let patterns = ["lesson_([0-9]+)$", "_l([0-9]+)$"]
        for p in patterns {
            if let r = raw.range(of: p, options: .regularExpression) {
                let sub = String(raw[r])
                let digits = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let num = Int(digits) {
                    return num
                }
            }
        }
        return nil
    }

    private func canonicalIds() -> (String, String) {
        // Progress stores ids with dashes; lessons may come with underscores
        let cid = courseId.replacingOccurrences(of: "_", with: "-")
        let lid = lessonId.replacingOccurrences(of: "_", with: "-")
        return (cid, lid)
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func demoTriples() -> [HomeTaskManager.LearnedTriple] {
        return [
            .init(ru: "привет", th: "", ph: "са-ват-ди"),
            .init(ru: "здравствуйте", th: "", ph: "са-ват-ди кхрап"),
            .init(ru: "приветик (мягко)", th: "", ph: "са-ват-ди ик-кхранг"),
            .init(ru: "всем привет!", th: "", ph: "ват-ди на"),
            .init(ru: "добро пожаловать!", th: "", ph: "йин-ди тон-рап"),
            .init(ru: "привет ещё раз", th: "", ph: "са-ват-ди тук-кхон")
        ]
    }

    private func buildRound(force: Bool = false) {
        // pull learned pairs directly from progress (try canonical dashed ids first)
        let (ccid, clid) = canonicalIds()
        var triples = store.userTriples(for: ccid, lessonId: clid)
        if triples.isEmpty {
            triples = store.userTriples(for: courseId, lessonId: lessonId)
        }
        if triples.isEmpty && isPreview { triples = demoTriples() }
        triples = triples.filter { !$0.ru.isEmpty && !$0.ph.isEmpty }
        guard !triples.isEmpty else { leftItems = []; rightItems = []; totalPairsCount = 0; return }

        // Reset all state
        allTriples = triples.shuffled()
        totalPairsCount = allTriples.count
        matchedPairIds = []
        tries = 0
        selectedLeft = nil; selectedRight = nil

        // Seed visible with up to 5 pairs
        let seedCount = min(visiblePairsTarget, allTriples.count)
        let seed = Array(allTriples.prefix(seedCount))
        remainingTriples = Array(allTriples.dropFirst(seedCount))

        var L: [MPItem] = []
        var R: [MPItem] = []
        for t in seed {
            let pid = "\(t.ru)|\(t.ph)"
            L.append(.init(pairId: pid, text: t.ph, side: .left, hasAudio: true))
            R.append(.init(pairId: pid, text: t.ru, side: .right))
        }
        leftItems = L.shuffled()
        rightItems = R.shuffled()
        // reset states
        for i in leftItems.indices { leftItems[i].state = .idle }
        for j in rightItems.indices { rightItems[j].state = .idle }

        // Prepare reveal states: if intro already ran, default all to revealed
        let ids = Set(leftItems.map { $0.pairId } + rightItems.map { $0.pairId })
        if didRunIntro {
            var dict: [String: Bool] = [:]
            ids.forEach { dict[$0] = true }
            flipStates = dict
            gridOpacity = 1
        } else {
            // intro will manage flipStates itself
            flipStates = [:]
            gridOpacity = 0
        }
    }

    private func introduceNextPairIfNeeded() {
        // Keep up to visiblePairsTarget pairs visible until we exhaust remainingTriples
        guard !remainingTriples.isEmpty else { return }
        let need = max(0, visiblePairsTarget - currentVisiblePairsCount())
        guard need > 0 else { return }
        let take = min(need, remainingTriples.count)
        let newcomers = Array(remainingTriples.prefix(take))
        remainingTriples.removeFirst(take)
        for t in newcomers {
            let pid = "\(t.ru)|\(t.ph)"
            leftItems.append(.init(pairId: pid, text: t.ph, side: .left, hasAudio: true))
            rightItems.append(.init(pairId: pid, text: t.ru, side: .right))
        }
        // Shuffle all cards after adding newcomers
        leftItems.shuffle()
        rightItems.shuffle()
        // seed backs for newcomers, then flip to face shortly
        for t in newcomers {
            let pid = "\(t.ru)|\(t.ph)"
            flipStates[pid] = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                for t in newcomers {
                    let pid = "\(t.ru)|\(t.ph)"
                    flipStates[pid] = true
                }
                // Shuffle again after reveal animation to randomize grid
                leftItems.shuffle()
                rightItems.shuffle()
            }
        }
    }

    private func currentVisiblePairsCount() -> Int {
        // left/right arrays include matched items; count unique pairIds minus those already matched
        let ids = Set(leftItems.map { $0.pairId })
        return ids.subtracting(matchedPairIds).count
    }

    private func tapLeft(_ idx: Int) {
        guard leftItems.indices.contains(idx) else { return }
        if leftItems[idx].state == .matched { return }
        // clear previous selection state
        if let p = selectedLeft, leftItems.indices.contains(p) {
            leftItems[p].state = .idle
        }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            selectedLeft = (selectedLeft == idx) ? nil : idx
        }
        // apply selected state
        if let s = selectedLeft {
            leftItems[s].state = .selected
        }
        tryResolve()
    }

    private func tapRight(_ idx: Int) {
        guard rightItems.indices.contains(idx) else { return }
        if rightItems[idx].state == .matched { return }
        if let p = selectedRight, rightItems.indices.contains(p) {
            rightItems[p].state = .idle
        }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            selectedRight = (selectedRight == idx) ? nil : idx
        }
        if let s = selectedRight {
            rightItems[s].state = .selected
        }
        tryResolve()
    }

    private func tryResolve() {
        guard let li = selectedLeft, let ri = selectedRight,
              leftItems.indices.contains(li), rightItems.indices.contains(ri) else { return }
        tries += 1
        let L = leftItems[li]; let R = rightItems[ri]
        if L.pairId == R.pairId {
            matchedPairIds.insert(L.pairId)
            // mark matched visually
            leftItems[li].state = .matched
            rightItems[ri].state = .matched
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // If we still have newcomers in the pool, remove matched and introduce next pair
            let canIntroduceMore = !remainingTriples.isEmpty
            if canIntroduceMore {
                // remove matched items from the visible lists
                leftItems.removeAll { $0.pairId == L.pairId }
                rightItems.removeAll { $0.pairId == R.pairId }
                flipStates[L.pairId] = nil
                introduceNextPairIfNeeded()
            } else {
                // pool exhausted — keep matched cards on screen to preserve 5 visible
            }
            selectedLeft = nil; selectedRight = nil
            // Последняя пара → сыграть «табло»-аутро (всё на рубашку), затем показать summary
            if matchedPairIds.count >= totalPairsCount {
                startTabloidOutroAndShowSummary()
            }
        } else {
            // brief wrong pulse on both sides
            leftItems[li].state = .wrong
            rightItems[ri].state = .wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                if leftItems.indices.contains(li) { leftItems[li].state = .idle }
                if rightItems.indices.contains(ri) { rightItems[ri].state = .idle }
                selectedLeft = nil; selectedRight = nil
            }
        }
    }

    // Tabloid-style intro flipping animation
    private func startTabloidIntro() {
        flipCycle = 0
        let ids = Set(leftItems.map { $0.pairId } + rightItems.map { $0.pairId })
        flipStates = Dictionary(uniqueKeysWithValues: ids.map { ($0, false) })
        gridOpacity = 1
        flipTimer?.invalidate()
        flipTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { timer in
            Task { @MainActor in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    for key in flipStates.keys {
                        if Bool.random() { flipStates[key]?.toggle() }
                    }
                }
                flipCycle += 1
                if flipCycle > 8 {
                    timer.invalidate()
                    flipTimer = nil
                    withAnimation(.easeOut(duration: 0.4)) {
                        for key in flipStates.keys { flipStates[key] = true }
                    }
                }
            }
        }
    }

    // Tabloid-style outro: random flips ending with all backs, then show summary
    private func startTabloidOutroAndShowSummary() {
        flipTimer?.invalidate()
        let ids = Set(leftItems.map { $0.pairId } + rightItems.map { $0.pairId })
        var cycles = 0
        flipTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { timer in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.16)) {
                    for id in ids where Bool.random() { flipStates[id]?.toggle() }
                }
                cycles += 1
                if cycles > 6 {
                    timer.invalidate()
                    flipTimer = nil
                    withAnimation(.easeOut(duration: 0.28)) {
                        for id in ids { flipStates[id] = false }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        Task { @MainActor in showSummary = true }
                    }
                }
            }
        }
    }
}

#if DEBUG
struct HomeTaskView_Previews: PreviewProvider {
    static var previews: some View {
        let s = HomeTaskManager()
        s.setTasks([
            HTask(courseId: "course_demo", lessonIndex: 0, title: "урок #1", details: "", status: .available)
        ], for: "course_demo")
        return HomeTaskView(courseId: "course_demo", lessonId: "lesson_1", embedBackground: true, store: s, displayTitle: "Урок 1 — подобрать пару")
            .preferredColorScheme(.dark)
            .environmentObject(ThemeManager.shared)
    }
}
#endif
