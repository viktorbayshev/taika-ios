//  StepAnimation.swift
//  taika
//
//  Coordinator layer that wires DS components together (no custom drawing here).
//  Responsibilities:
//  - Keep carousel and progress in sync (tap on card or progress segment).
//  - Haptics + gentle nudge if user jumps forward without pressing "Выучил".
//  - Lightweight “lesson complete” celebration.
//  This file intentionally depends only on StepDS contracts.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Coordinator View

public struct StepAnimationView: View {
    // Input data (Design‑System model)
    public var items: [SDStepItem]
    public var startIndex: Int? = nil
    private var activeIndex: Binding<Int>

    // Local UI state
    @State private var learned: Set<Int> = []
    @State private var favorites: Set<Int> = []
    @State private var animatedIndex: Double = 0

    // Progress highlight that "catches up" to the carousel
    @State private var displayedActiveIndex: Int = 0

    // Nudges
    @State private var shouldNudgeActive: Bool = false
    @State private var showCompletion: Bool = false
    @State private var isProgrammaticJump = false

    // One-time init guard to not reset active index on re-appear
    @State private var didInit = false

    @State private var progressAnimateSelection: Bool = true
    @State private var isJumpingViaProgress: Bool = false
    @State private var pendingTargetIndex: Int? = nil

    public init(items: [SDStepItem], startIndex: Int? = nil, bindActiveIndex: Binding<Int>) {
        self.items = items
        self.startIndex = startIndex
        self.activeIndex = bindActiveIndex
    }

    
    public var body: some View {
        ZStack {
            VStack(spacing: 18) {
                // TAIKA FM (simple demo hints; feed from outside in a real screen)
                SDStepHintsSection(
                    hints: [
                        "Повтори вслух — так лучше запомнится.",
                        "Ударение отмечено розовым в транскрипции.",
                        "Если трудно — вернись к предыдущей карточке."
                    ]
                )

                // Carousel wired to progress
                carousel

                // Progress synced with carousel
                SDStepProgress(
                    total: items.count,
                    activeIndex: displayedActiveIndex,
                    learned: learned,
                    favorites: favorites,
                    onTap: progressTapped
                )
                .transaction { t in
                    if !progressAnimateSelection { t.disablesAnimations = true }
                }
            }
            .padding(.bottom, 12)

            // Completion overlay
            if showCompletion {
                completionView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            guard didInit == false else { return }
            didInit = true
            let base = startIndex ?? activeIndex.wrappedValue
            let current = min(max(base, 0), max(items.count - 1, 0))
            activeIndex.wrappedValue = current
            displayedActiveIndex = current
            animatedIndex = Double(current)
            learned = []
            favorites = []
        }
        .onChange(of: items.count) { _ in
            // Clamp indices if data changed (e.g., hot reload), keep current selection if possible
            let clamped = min(max(activeIndex.wrappedValue, 0), max(items.count - 1, 0))
            if clamped != activeIndex.wrappedValue {
                activeIndex.wrappedValue = clamped
                displayedActiveIndex = clamped
            }
        }
        .onChange(of: learned) { newValue in
            // All cards learned – small celebration
            if items.isEmpty == false && newValue.count == items.count {
                celebrate()
            }
        }
        .onChange(of: activeIndex.wrappedValue) { newVal in
            let clamped = min(max(newVal, 0), max(items.count - 1, 0))
            if isJumpingViaProgress {
                // During a jump initiated by tapping progress we update only when deck reaches the target in onActiveIndexChange.
                return
            }
            displayedActiveIndex = clamped
            animatedIndex = Double(clamped)
        }
    }

    // MARK: - Subviews

    private var carousel: some View {
        SDStepCarousel(
            title: "УРОК",
            items: items,
            activeIndex: activeIndex,
            onTap: { item in if let i = index(of: item) { setActive(i) } },
            onPlay: { item in
                playHaptic(.light)
                advanceFromIntroIfNeeded(item)
            },
            onFav: { item in if let i = index(of: item) { toggleFavorite(i) } },
            onDone: { item in if let i = index(of: item) { markLearned(i) } },
            onActiveIndexChange: { newIndex in
                let clamped = min(max(newIndex, 0), max(items.count - 1, 0))

                if isJumpingViaProgress {
                    // Ignore all intermediate indices; only react when the deck reaches the final target.
                    if let target = pendingTargetIndex, clamped == target {
                        // Finalize and allow normal updates again
                        var noAnim = Transaction()
                        noAnim.disablesAnimations = true
                        withTransaction(noAnim) {
                            displayedActiveIndex = clamped
                            animatedIndex = Double(clamped)
                        }
                        isJumpingViaProgress = false
                        pendingTargetIndex = nil
                        playSelection()
                    }
                    return
                }

                // Normal adjacent scroll (user swiping the deck)
                let distance = abs(clamped - displayedActiveIndex)
                progressAnimateSelection = (distance <= 1)
                if distance > 1 {
                    var noAnim = Transaction()
                    noAnim.disablesAnimations = true
                    withTransaction(noAnim) {
                        displayedActiveIndex = clamped
                        animatedIndex = Double(clamped)
                    }
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        displayedActiveIndex = clamped
                        animatedIndex = Double(clamped)
                    }
                }
                playSelection()
            },
            onNext: { item in
                playSelection()
                advanceFromTipCTA(item)
            }
        )
    }

    private var completionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(PD.ColorToken.accent)
                .shadow(color: PD.ColorToken.accent.opacity(0.4), radius: 14, x: 0, y: 0)
            Text("Урок пройден!")
                .font(PD.FontToken.body(20, weight: .semibold))
                .foregroundColor(PD.ColorToken.text)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PD.ColorToken.accent, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
    }

    // MARK: - Actions

    private func index(of item: SDStepItem) -> Int? {
        items.firstIndex { $0.id == item.id }
    }

    private func setActive(_ index: Int) {
        let clamped = min(max(index, 0), max(items.count - 1, 0))
        activeIndex.wrappedValue = clamped
        displayedActiveIndex = clamped
        animatedIndex = Double(clamped)
        shouldNudgeActive = false
        playHaptic(.light)
    }

    private func markLearned(_ index: Int) {
        // Remember state before toggle
        let wasLearned = learned.contains(index)

        if wasLearned {
            // Turning OFF learned — update state, no auto-advance
            learned.remove(index)
            playHaptic(.soft)
            return
        } else {
            // Turning ON learned — update state and (if active) auto-advance
            learned.insert(index)
            playHaptic(.rigid)

            if index == activeIndex.wrappedValue, index + 1 < items.count {
                setActive(index + 1)
            }
        }
    }

    // Explicit Next CTA from tip card: just advance, no tag toggles
    private func advanceFromTipCTA(_ item: SDStepItem) {
        guard item.kind == .tip, let i = index(of: item) else { return }
        if i == activeIndex.wrappedValue, i + 1 < items.count {
            setActive(i + 1)
        }
    }

    // Auto-advance specifically for Intro card when user taps the right-arrow CTA
    private func advanceFromIntroIfNeeded(_ item: SDStepItem) {
        guard item.kind == .intro, let i = index(of: item) else { return }
        // advance only if intro is the current card
        if i == activeIndex.wrappedValue, i + 1 < items.count {
            setActive(i + 1)
        }
    }

    // Auto-advance for lifehacks (tips) when user taps the heart on the active card
    private func advanceFromTipIfNeeded(at index: Int) {
        guard items.indices.contains(index) else { return }
        // Only for lifehack cards
        if items[index].kind == .tip {
            // Advance only when user liked the card currently in focus
            if index == activeIndex.wrappedValue, index + 1 < items.count {
                setActive(index + 1)
            }
        }
    }

    private func toggleFavorite(_ index: Int) {
        // Remember state before toggle
        let wasFavorite = favorites.contains(index)

        if wasFavorite {
            // Turning OFF favorite — update state, no auto-advance
            favorites.remove(index)
            playHaptic(.soft)
            return
        } else {
            // Turning ON favorite — update state and (for tips) auto-advance
            favorites.insert(index)
            playHaptic(.soft)
            advanceFromTipIfNeeded(at: index)
        }
    }

    private func progressTapped(_ index: Int) {
        let clamped = min(max(index, 0), max(items.count - 1, 0))
        let current = displayedActiveIndex

        guard clamped != current else { return }

        let distance = abs(clamped - current)

        // Для коротких прыжков просто одна пружинящая анимация
        if distance <= 2 {
            isJumpingViaProgress = true
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                animatedIndex = Double(clamped)
                displayedActiveIndex = clamped
                activeIndex.wrappedValue = clamped
            }
            isJumpingViaProgress = false
            playSelection()
            return
        }

        // Для длинных прыжков — "картотека" по нескольким ключевым кадрам, а не по каждой карте,
        // чтобы движение было быстрым и не тормозным.
        let step = clamped > current ? 1 : -1
        let rawPath = Array(stride(from: current, through: clamped, by: step))

        // Сэмплим не больше 5–6 кадров по пути
        let maxFrames = 6
        let strideSize = max(1, rawPath.count / maxFrames)
        var sampled: [Int] = []
        for (idx, value) in rawPath.enumerated() where idx % strideSize == 0 {
            sampled.append(value)
        }
        if sampled.last != clamped {
            sampled.append(clamped)
        }

        isJumpingViaProgress = true

        Task {
            for (offset, i) in sampled.enumerated() {
                await MainActor.run {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.92)) {
                        animatedIndex = Double(i)
                        displayedActiveIndex = i
                        activeIndex.wrappedValue = i
                    }
                }

                // короткая пауза, чтобы чувствовалось движение, но без "тормозов"
                if offset < sampled.count - 1 {
                    try? await Task.sleep(nanoseconds: 26_000_000) // ~26ms
                }
            }

            await MainActor.run {
                isJumpingViaProgress = false
                playSelection()
            }
        }
    }

    private func nudgeForLearn() {
        shouldNudgeActive = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { shouldNudgeActive = false }
    }

    private func celebrate() {
        showCompletion = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.25)) { showCompletion = false }
        }
    }

    private func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
    private func playSelection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

// MARK: - Preview

#if DEBUG
struct StepAnimation_Previews: PreviewProvider {
    static let demo: [SDStepItem] = [
        .init(kind: .word,   titleRU: "Кофе",           subtitleTH: "กาแฟ (kaa-fae)",                 phonetic: "ка-фа́э"),
        .init(kind: .word,   titleRU: "Вода",           subtitleTH: "น้ำ (náam)",                      phonetic: "на́м"),
        .init(kind: .phrase, titleRU: "Большое спасибо",subtitleTH: "ขอบคุณมาก (kh̄xbkhuṇ mâak)",      phonetic: "коп-ку́н ма́к"),
        .init(kind: .phrase, titleRU: "Доброе утро",    subtitleTH: "สวัสดีตอนเช้า (s̄wạs̄dī txn chêa)", phonetic: "са-ва́т-ди тон ча́о"),
        .init(kind: .tip,    titleRU: "Ассоциация",     subtitleTH: "Свяжи слово с ситуацией — запомнится быстрее.", phonetic: "")
    ]

    @State static var previewIndex = 0
    static var previews: some View {
        StatefulPreviewWrapper(0) { idx in
            ZStack { PD.ColorToken.background.ignoresSafeArea() }
                .overlay(
                    StepAnimationView(items: demo, startIndex: 0, bindActiveIndex: idx)
                        .preferredColorScheme(.dark)
                )
        }
    }
}

struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content
    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }
    var body: some View { content($value) }
}
#endif
