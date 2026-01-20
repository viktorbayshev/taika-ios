//
//  SpeakerView.swift
//  taika
//
//  Created by product on 26.12.2025.
//

import SwiftUI

/// host screen (assembly + navigation only). visuals live in speaker ds.
struct SpeakerView: View {
    @StateObject private var speaker = SpeakerManager()

    private func displayLessonTitle(for lessonId: String) -> String {
        // best-effort: keep it human, never show raw ids
        // expected ids look like: course_b_1_l1, course_a_2_l12, etc.
        let lower = lessonId.lowercased()

        // try: _l<digits>
        if let r = lower.range(of: "_l", options: .backwards) {
            let tail = String(lower[r.upperBound...])
            let digits = tail.prefix { $0.isNumber }
            if let n = Int(digits), n > 0 {
                return "урок \(n)"
            }
        }

        // try: trailing digits anywhere
        let digits = lower.reversed().prefix { $0.isNumber }.reversed()
        if let n = Int(String(digits)), n > 0 {
            return "урок \(n)"
        }

        return ""
    }

    private func ensureActiveSelection() {
        // if nothing is selected yet, bind selection to current (or first visible item)
        if speaker.selectedId == nil {
            if let cur = speaker.current {
                speaker.selectCard(by: speaker.resolveId(cur))
            } else if let first = speaker.carouselItems.first {
                speaker.selectCard(by: speaker.resolveId(first))
            }
        }
    }

    private func onPlayReference() {
        ensureActiveSelection()
        if let sel = speaker.selectedId {
            speaker.playReference(for: sel)
        } else {
            speaker.playReference()
        }
    }

    private func onPlayAttempt() {
        speaker.playAttempt()
    }

    private func onMicTap() {
        ensureActiveSelection()
        guard speaker.selectedId != nil || speaker.current != nil else { return }

        switch speaker.phase {
        case .idle, .hint, .feedback:
            speaker.startAttempt()
        case .recording:
            speaker.stopAttemptAndAnalyze()
        case .analyzing, .analyzingTranslation:
            return
        }
    }

    private func lessonTitle(for lessonId: String) -> String? {
        let t = displayLessonTitle(for: lessonId)
        return t.isEmpty ? nil : t
    }

    var body: some View {
        SpeakerDSRoot(
            current: speaker.current,
            items: speaker.carouselItems,
            selectedId: speaker.selectedId,
            activeFilterId: speaker.activeFilterId,
            phase: speaker.phase,
            heardThai: speaker.heardThai,
            heardRU: speaker.heardRU,
            heardTranslit: speaker.heardTranslit,
            heardConfidence: speaker.heardConfidence,
            taikaHints: speaker.taikaHints,
            recordingMeter: speaker.recordingMeter,
            recordingPartialThai: speaker.recordingPartialThai,
            recordingPartialTranslit: speaker.recordingPartialTranslit,
            lastAttempt: speaker.lastAttempt,
            attemptCount: speaker.attemptCount,
            lastPlayed: speaker.lastPlayed,
            onPlayReference: onPlayReference,
            onPlayAttempt: onPlayAttempt,
            onPlayReferenceForId: { id in
                speaker.playReference(for: id)
            },
            onMicTap: onMicTap,
            onNext: { speaker.next() },
            onRepeat: { speaker.repeatCurrent() },
            onSubmitText: { text in
                speaker.submitText(text)
            },
            onSelectFilter: { id in
                speaker.applyFilter(id)
            },
            onSelectCard: { id in
                speaker.selectCard(by: id)
                // when user switches cards, keep UI in a stable state
                if speaker.phase == .recording {
                    speaker.stopAttemptAndAnalyze()
                } else if speaker.phase == .analyzing || speaker.phase == .analyzingTranslation {
                    // do nothing; analysis will finish for the previous attempt
                } else {
                    // snap back to idle/hint (manager will provide hints)
                    speaker.repeatCurrent()
                }
            },
            resolveId: { r in
                speaker.resolveId(r)
            },
            lessonTitleForLessonId: lessonTitle
        )
        .onAppear {
            speaker.loadIfNeeded()
            speaker.applyFilter(SpeakerMode.current.id)

            // log only once per screen presentation
            UserSession.shared.logActivity(
                .speakerOpened,
                courseId: speaker.current?.courseId,
                lessonId: speaker.current?.lessonId,
                stepIndex: speaker.current?.index,
                refId: "speaker:mvp"
            )
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SpeakerPreviewWrapper()
}

private struct SpeakerPreviewWrapper: View {
    @StateObject private var favorites = FavoriteManager.shared
    @StateObject private var overlay = OverlayPresenter.shared
    @StateObject private var nav = NavigationIntent()
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var pro = ProManager.shared

    var body: some View {
        NavigationStack {
            SpeakerView()
        }
        .preferredColorScheme(theme.preferredScheme)
        .environmentObject(theme)
        .environmentObject(favorites)
        .environmentObject(overlay)
        .environmentObject(nav)
        .environmentObject(pro)
    }
}
