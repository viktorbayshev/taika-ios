//
//  SpeakerDS.swift
//  taika
//
//  first DS scaffold for tAIka (speaker) — visual only, no integrations
//  architecture: safeAreaInset header, tokens background, no local whites
//

import SwiftUI
import Foundation

// MARK: - tokens shortcuts
private typealias T = Theme

// MARK: - focus rect preference (for result spotlight)
private struct SpeakerActiveCardAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}


// MARK: - public entry
public struct SpeakerDSRoot: View {

    // when external != nil, this DS is driven by app logic (SpeakerManager)
    private struct External {
        let current: StepData.SpeakerResolved?
        let items: [StepData.SpeakerResolved]?
        let selectedId: UUID?
        let activeFilterId: UUID?
        let phase: SpeakerManager.Phase
        let heardThai: String?
        let heardRU: String?
        let heardTranslit: String?
        let heardConfidence: Int
        let taikaHints: [String]
        let recordingMeter: Double
        let recordingPartialThai: String?
        let recordingPartialTranslit: String?
        let lastAttempt: URL?
        let attemptCount: Int
        let lastPlayed: SpeakerManager.LastPlayed
        let onPlayReference: () -> Void
        let onPlayAttempt: () -> Void
        let onPlayReferenceForId: ((UUID) -> Void)?
        let onMicTap: () -> Void
        let onNext: () -> Void
        let onRepeat: () -> Void
        let onSubmitText: (String) -> Void
        let onSelectFilter: (UUID) -> Void
        let onSelectCard: (UUID) -> Void
        let resolveId: (StepData.SpeakerResolved) -> UUID
        let lessonTitleForLessonId: ((String) -> String?)?
    }

    private let external: External?

#if DEBUG
    struct PreviewExternal {
        let current: SpeakerItem?
        let items: [SpeakerItem]
        let activeFilterId: UUID?
        let phase: SpeakerPhase
        let heardThai: String?
        let heardRU: String?
        let heardTranslit: String?
        let heardConfidence: Int
        let taikaHints: [String]
        let recordingMeter: Double
        let recordingPartialThai: String?
        let recordingPartialTranslit: String?
        let lastAttempt: URL?
        let attemptCount: Int
        let lastPlayed: SpeakerManager.LastPlayed
    }
#endif

#if DEBUG
    private let previewExternal: PreviewExternal?
#else
    private let previewExternal: Any? = nil
#endif


    // reference audio bubble (messenger-style)
    @State private var refIsPlaying: Bool = false
    @State private var helperHasInteracted: Bool = false
    @State private var helperIsVisible: Bool = true
    @State private var helperTypedText: String = ""

    // local fallback selection for DS (used when external.selectedId is not wired yet)
    @State private var localSelectedId: UUID? = nil



    @State private var activeCardRect: CGRect = .zero
    @State private var hasActiveCardRect: Bool = false
    // reserve vertical space so the layout doesn't jump between phases
    // but don't keep a big “air gap” while recording/analyzing
    private let taikaBubbleHeightVisible: CGFloat = 96
    private let taikaBubbleHeightHidden: CGFloat = 0

    private var taikaBubbleReservedHeight: CGFloat {
        // bubble removed from result — no reserved space
        return taikaBubbleHeightHidden
    }


    public init() {
        self.external = nil
#if DEBUG
        self.previewExternal = nil
#endif
    }

    // MARK: - stable ids (critical for canvas + scroll)
    // SwiftUI canvas can hang when ForEach ids are unstable or duplicated.
    // We generate a deterministic UUID from the resolved step identity.
    fileprivate static func stableResolvedId(courseId: String, lessonId: String, index: Int, kindRaw: String) -> UUID {
        let seed = "speaker|\(courseId)|\(lessonId)|\(index)|\(kindRaw)"
        let bytes = [UInt8](seed.utf8)
        // FNV-1a 64-bit x2 -> 128-bit UUID
        var h1: UInt64 = 14695981039346656037
        var h2: UInt64 = 1099511628211
        for b in bytes {
            h1 ^= UInt64(b)
            h1 &*= 1099511628211
            h2 ^= UInt64(b)
            h2 &*= 14695981039346656037
        }
        let uuid = UUID(uuid: (
            UInt8((h1 >> 56) & 0xff), UInt8((h1 >> 48) & 0xff), UInt8((h1 >> 40) & 0xff), UInt8((h1 >> 32) & 0xff),
            UInt8((h1 >> 24) & 0xff), UInt8((h1 >> 16) & 0xff), UInt8((h1 >> 8) & 0xff),  UInt8(h1 & 0xff),
            UInt8((h2 >> 56) & 0xff), UInt8((h2 >> 48) & 0xff), UInt8((h2 >> 40) & 0xff), UInt8((h2 >> 32) & 0xff),
            UInt8((h2 >> 24) & 0xff), UInt8((h2 >> 16) & 0xff), UInt8((h2 >> 8) & 0xff),  UInt8(h2 & 0xff)
        ))
        return uuid
    }

    init(
        current: StepData.SpeakerResolved?,
        items: [StepData.SpeakerResolved]? = nil,
        selectedId: UUID? = nil,
        activeFilterId: UUID? = nil,
        phase: SpeakerManager.Phase,
        heardThai: String? = nil,
        heardRU: String? = nil,
        heardTranslit: String? = nil,
        heardConfidence: Int = 0,
        taikaHints: [String] = [],
        recordingMeter: Double = 0,
        recordingPartialThai: String? = nil,
        recordingPartialTranslit: String? = nil,
        lastAttempt: URL? = nil,
        attemptCount: Int = 0,
        lastPlayed: SpeakerManager.LastPlayed = .none,
        onPlayReference: @escaping () -> Void,
        onPlayAttempt: @escaping () -> Void,
        onPlayReferenceForId: ((UUID) -> Void)? = nil,
        onMicTap: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onRepeat: @escaping () -> Void,
        onSubmitText: @escaping (String) -> Void = { _ in },
        onSelectFilter: @escaping (UUID) -> Void = { _ in },
        onSelectCard: @escaping (UUID) -> Void = { _ in },
        resolveId: @escaping (StepData.SpeakerResolved) -> UUID = { r in
            SpeakerDSRoot.stableResolvedId(courseId: r.courseId, lessonId: r.lessonId, index: r.index, kindRaw: String(describing: r.kind))
        },
        lessonTitleForLessonId: ((String) -> String?)? = nil
    ) {
        self.external = External(
            current: current,
            items: items,
            selectedId: selectedId,
            activeFilterId: activeFilterId,
            phase: phase,
            heardThai: heardThai,
            heardRU: heardRU,
            heardTranslit: heardTranslit,
            heardConfidence: heardConfidence,
            taikaHints: taikaHints,
            recordingMeter: recordingMeter,
            recordingPartialThai: recordingPartialThai,
            recordingPartialTranslit: recordingPartialTranslit,
            lastAttempt: lastAttempt,
            attemptCount: attemptCount,
            lastPlayed: lastPlayed,
            onPlayReference: onPlayReference,
            onPlayAttempt: onPlayAttempt,
            onPlayReferenceForId: onPlayReferenceForId,
            onMicTap: onMicTap,
            onNext: onNext,
            onRepeat: onRepeat,
            onSubmitText: onSubmitText,
            onSelectFilter: onSelectFilter,
            onSelectCard: onSelectCard,
            resolveId: resolveId,
            lessonTitleForLessonId: lessonTitleForLessonId
        )
#if DEBUG
        self.previewExternal = nil
#endif
    }

#if DEBUG
    init(preview: PreviewExternal) {
        self.external = nil
        self.previewExternal = preview
    }
#endif

    private var isExternallyDriven: Bool {
        if external != nil { return true }
#if DEBUG
        if previewExternal != nil { return true }
#endif
        return false
    }

    private var extSelectedId: UUID? {
        external?.selectedId
    }

    private var externalResolveId: (StepData.SpeakerResolved) -> UUID {
        external?.resolveId ?? { _ in UUID() }
    }

    private var currentItem: SpeakerItem? {
#if DEBUG
        if let p = previewExternal {
            return p.current
        }
#endif

        guard let cur = external?.current else { return nil }
        return SpeakerItem(
            id: externalResolveId(cur),
            phrase: cur.face.subtitleTH,
            translit: cur.face.phonetic,
            hint: cur.face.titleRU,
            lessonTitle: external?.lessonTitleForLessonId?(cur.lessonId),
            kindTag: "фраза",
            isFavorite: false,
            isProLocked: false
        )
    }

    private var recordingPartialThai: String? {
#if DEBUG
        if let p = previewExternal {
            return p.recordingPartialThai
        }
#endif
        return external?.recordingPartialThai
    }

    private var recordingPartialTranslit: String? {
#if DEBUG
        if let p = previewExternal {
            return p.recordingPartialTranslit
        }
#endif
        return external?.recordingPartialTranslit
    }

    private var recordingMeter: Double {
#if DEBUG
        if let p = previewExternal {
            return p.recordingMeter
        }
#endif
        return external?.recordingMeter ?? 0
    }

    private var taikaHints: [String] {
#if DEBUG
        if let p = previewExternal {
            return p.taikaHints
        }
#endif
        return external?.taikaHints ?? []
    }

#if DEBUG
    // Computed property to check if running for Xcode previews
    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
#endif

    private var phase: SpeakerPhase {
#if DEBUG
        if let p = previewExternal {
            return p.phase
        }
#endif

        guard let p = external?.phase else { return .idle }
        switch p {
        case .idle: return .idle
        case .recording: return .recording(start: Date())
        case .analyzing: return .analyzing
        case .analyzingTranslation: return .analyzing
        case .hint: return .hint
        case .feedback(let score, let hint): return .feedback(score: score, hint: hint)
        }
    }

    public var body: some View {
        ZStack {
            T.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                filtersStrip
                    .padding(.top, 6)
                    .padding(.bottom, 18)

                // taika fm bubble lives under filters (not above the CTA)
                Group {
                    topTaikaBubble
                }
                .frame(maxWidth: .infinity)
                .frame(height: taikaBubbleReservedHeight, alignment: .top)
                .padding(.horizontal, 18)
                .padding(.bottom, phase.isFeedback ? 6 : 0)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    topCarousel
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)

                    speakerPlayerPanel
                        .padding(.top, 2)
                        .padding(.horizontal, 22)

                    idleHelperHint
                        .padding(.top, 8)
                        .padding(.horizontal, 22)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.18), value: phase.isFeedback)
        .onChange(of: extSelectedId) { newValue in
            if let v = newValue { localSelectedId = v }
        }
        .onChange(of: activeFilterId) { _ in
            // reset fallback selection when switching modes
            localSelectedId = nil
        }
        .task(id: helperHasInteracted) {
            // preview защитный рантайм: canvas часто пересоздаёт view и может зависнуть на long-running task.
            // в превью — просто показываем строку и выходим.
#if DEBUG
            if external == nil {
                await MainActor.run {
                    helperIsVisible = true
                    helperTypedText = "выбери фразу и нажми микрофон"
                }
                return
            }
#endif

            guard !helperHasInteracted else { return }

            let full = "выбери фразу и нажми микрофон"

            // ждём idle ограниченно по времени, чтобы не подвешивать UI
            let deadline = Date().addingTimeInterval(2.0)
            while phase != .idle, !Task.isCancelled, !helperHasInteracted, Date() < deadline {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            await MainActor.run {
                helperIsVisible = true
                helperTypedText = ""
            }

            for ch in full {
                if Task.isCancelled || helperHasInteracted || phase != .idle { break }
                await MainActor.run { helperTypedText.append(ch) }
                try? await Task.sleep(nanoseconds: 95_000_000)
            }
        }
        .safeAreaInset(edge: .top) { header }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                bottomPrimaryAction
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var topTaikaBubble: some View {
        Color.clear
    }

    @ViewBuilder private var idleHelperHint: some View {
        // keep constant vertical space so the carousel doesn't jump between phases
        ZStack {
            if phase == .idle, !helperHasInteracted {
                Text(helperTypedText.isEmpty ? " " : helperTypedText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .opacity(helperIsVisible ? 0.86 : 0.0)
                    .animation(.easeInOut(duration: 0.22), value: helperIsVisible)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(!helperIsVisible)
            } else {
                // spacer placeholder (same typography metrics)
                Text(" ")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.clear)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 22, alignment: .center)
    }
    // MARK: header (safeAreaInset)
    private var header: some View {
        AppHeader(
            showSearch: false,
            showHeart: false,
            showProfile: false,
            onTapSearch: {},
            onTapHeart: {},
            onTapProfile: {}
        )
        .frame(height: 56)
        .background(T.Colors.backgroundPrimary)
    }



    // MARK: taika bubble (center)
    @ViewBuilder private func taikaCenterBubble(_ lines: [String]) -> some View {
        let cleaned: [String] = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cleaned.isEmpty {
            EmptyView()
        } else {
            let accentFill = ThemeManager.shared.currentAccentFill
            let accentStyle: AnyShapeStyle = AnyShapeStyle(accentFill)
            TaikaFMBubble(label: "taika fm", reactions: [], onReactionTap: nil) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentStyle)
                        .opacity(0.75)
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("тайка")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .opacity(0.85)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(cleaned.indices, id: \.self) { idx in
                                Text(cleaned[idx])
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(PD.ColorToken.text)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                                    .opacity(0.94)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder private func taikaCenterBubble(_ text: String) -> some View {
        taikaCenterBubble([text])
    }

    // MARK: pro wireframe

    private var allSpeakerItems: [SpeakerItem] {
#if DEBUG
        if let p = previewExternal {
            return p.items
        }
#endif

        if let extItems = external?.items {
            var out: [SpeakerItem] = []
            out.reserveCapacity(extItems.count)
            var seen: Set<UUID> = []

            for cur in extItems {
                let id = externalResolveId(cur)
                if seen.contains(id) { continue }
                seen.insert(id)

                out.append(
                    SpeakerItem(
                        id: id,
                        phrase: cur.face.subtitleTH,
                        translit: cur.face.phonetic,
                        hint: cur.face.titleRU,
                        lessonTitle: external?.lessonTitleForLessonId?(cur.lessonId),
                        kindTag: "фраза",
                        isFavorite: false,
                        isProLocked: false
                    )
                )
            }

            return out
        }

        if let cur = currentItem {
            return [cur]
        }

        return []
    }

    // MARK: - expose current result values for top card
    private var heardRUText: String {
#if DEBUG
        if let p = previewExternal {
            return (p.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
#endif
        return (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var heardTranslitText: String {
#if DEBUG
        if let p = previewExternal {
            return (p.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
#endif
        return (external?.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var heardConfidenceValue: Int {
#if DEBUG
        if let p = previewExternal {
            return p.heardConfidence
        }
#endif
        return external?.heardConfidence ?? 0
    }


    private var activeMode: SpeakerMode {
        if let id = activeFilterId, let m = SpeakerMode(id: id) { return m }
        return .current
    }

    private var emptyStateTitle: String {
        switch activeMode {
        case .current: return "в текущем уроке пока нет фраз"
        case .favorites: return "в избранном пока пусто"
        case .learned: return "выученных фраз пока нет"
        case .random: return "пока нечего показать"
        }
    }

    private var emptyStateSubtitle: String {
        switch activeMode {
        case .current:
            return "открой урок со степами и вернись сюда"
        case .favorites:
            return "лайкни пару фраз в уроках — они появятся здесь"
        case .learned:
            return "отмечай степы как выученные — и они соберутся тут"
        case .random:
            return "попробуй другой режим или вернись позже"
        }
    }

    @ViewBuilder private var emptyCarouselState: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let cardW: CGFloat = 268
        let cardH: CGFloat = 196

        VStack {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))

                    Image(systemName: activeMode == .favorites ? "heart.slash" : (activeMode == .learned ? "checkmark.circle" : "sparkles"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .opacity(0.9)
                }

                VStack(spacing: 6) {
                    Text(emptyStateTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(emptyStateSubtitle)
                        .font(.footnote)
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .opacity(0.92)
                }
                .padding(.horizontal, 18)

                if activeMode == .favorites || activeMode == .learned {
                    Button {
                        external?.onSelectFilter(SpeakerMode.current.id)
                    } label: {
                        Text("перейти в текущий урок")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: cardW, height: cardH)
            .background(
                Theme.Surfaces.card(round)
            )
            .overlay(
                round
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - speaker player panel (t1)
    // minimal single-transport player (no modes)
    // behavior:
    // - if attempt exists: main play plays attempt
    // - speaker button (appears only when attempt exists) plays reference
    // - mic toggles record/stop
    // - next moves to next phrase
    @ViewBuilder private var speakerPlayerPanel: some View {
        let maxW: CGFloat = 360

        let isRecording: Bool = {
            if case .recording = phase { return true }
            return false
        }()

        let isAnalyzing: Bool = (phase == .analyzing)
        let disabledGlobal = isRecording || isAnalyzing

        let items = allSpeakerItems
        let currentId = external?.selectedId ?? localSelectedId ?? currentItem?.id ?? items.first?.id
        let hasAttempt = (external?.lastAttempt != nil)

        let lastPlayed = external?.lastPlayed ?? .none
        let waveActive: Bool = (lastPlayed == .reference) || (lastPlayed == .attempt)

        // main play: attempt if exists, otherwise reference
        let canPlayMain: Bool = !disabledGlobal && (hasAttempt || true)

        HStack(spacing: 14) {
            // speaker (reference) — only when attempt exists, otherwise redundant
            if hasAttempt {
                Button {
                    guard !disabledGlobal else { return }
                    if let id = currentId, let cb = external?.onPlayReferenceForId {
                        cb(id)
                    } else {
                        external?.onPlayReference()
                    }
                } label: {
                    speakerTransportIcon(
                        system: "speaker.wave.2.fill",
                        isActive: lastPlayed == .reference,
                        isDisabled: disabledGlobal
                    )
                }
                .buttonStyle(.plain)
                .disabled(disabledGlobal)
            }

            // play/pause (single)
            Button {
                guard !disabledGlobal else { return }
                if hasAttempt {
                    external?.onPlayAttempt()
                } else {
                    if let id = currentId, let cb = external?.onPlayReferenceForId {
                        cb(id)
                    } else {
                        external?.onPlayReference()
                    }
                }
            } label: {
                speakerTransportIcon(
                    system: waveActive ? "pause.fill" : "play.fill",
                    isActive: waveActive,
                    isDisabled: disabledGlobal
                )
            }
            .buttonStyle(.plain)
            .disabled(!canPlayMain)

            // waveform (single)
            SpeakerPlayerWave(active: waveActive)
                .frame(height: 16)
                .frame(maxWidth: .infinity)
                .opacity(disabledGlobal ? 0.45 : 0.90)

            // mic
            Button {
                guard !isAnalyzing else { return }
                external?.onMicTap()
            } label: {
                speakerTransportIcon(
                    system: isRecording ? "stop.fill" : "mic.fill",
                    isActive: isRecording,
                    isDisabled: isAnalyzing
                )
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzing)

            // next
            Button {
                guard !disabledGlobal else { return }
                external?.onNext()
            } label: {
                speakerTransportIcon(
                    system: "forward.end.fill",
                    isActive: false,
                    isDisabled: disabledGlobal
                )
            }
            .buttonStyle(.plain)
            .disabled(disabledGlobal)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: maxW)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(speakerPlayerSurface)
    }


    private var speakerPlayerSurface: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.035))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.10))
                    .blur(radius: 18)
            )
    }


    private func speakerTransportIcon(system: String, isActive: Bool, isDisabled: Bool) -> some View {
        let accent = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        let fg: AnyShapeStyle = isActive ? accent : AnyShapeStyle(Color.white.opacity(0.88))

        return Image(systemName: system)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isDisabled ? AnyShapeStyle(Color.white.opacity(0.26)) : fg)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
    }

    @ViewBuilder private var topCarousel: some View {
        let items = allSpeakerItems
        if items.isEmpty {
            let itemH: CGFloat = 196
            emptyCarouselState
                .frame(height: itemH)
        } else {
            let currentId = external?.selectedId ?? localSelectedId ?? currentItem?.id ?? items.first?.id
            let itemW: CGFloat = 268
            let itemH: CGFloat = 196
            let itemSpacing: CGFloat = 26

            Group {
                let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

                if phase.isFeedback {
                    // freeze: show only the active card centered (no transforms / no scroll)
                    let activeId = currentId
                    let activeItem = items.first(where: { $0.id == activeId }) ?? items.first!

                    SpeakerTopCard(
                        item: activeItem,
                        isActive: true,
                        phase: phase,
                        recordingPartialTranslit: recordingPartialTranslit,
                        recordingMeter: recordingMeter,
                        heardRU: external?.heardRU,
                        heardTranslit: external?.heardTranslit,
                        heardConfidence: heardConfidenceValue,
                        canPlayAttempt: (external?.lastAttempt != nil),
                        attemptCount: (external?.attemptCount ?? 0),
                        lastPlayed: (external?.lastPlayed ?? .none),
                        onPlayReference: {
                            if let cb = external?.onPlayReferenceForId {
                                cb(activeItem.id)
                            } else {
                                external?.onPlayReference()
                            }
                        },
                        onPlayAttempt: {
                            external?.onPlayAttempt()
                        }
                    )
                    .scaleEffect(1.04)
                    .frame(width: itemW, height: itemH)
                    .frame(maxWidth: .infinity, alignment: .center)

                } else if isPreview {
                    // previews: avoid ScrollViewReader/GeometryReader/scrollTo loops that can stall canvas.
                    // show a stable, static mini-strip with tap selecting but no auto-scroll.
                    let activeId = currentId
                    let visible = Array(items.prefix(5))

                    HStack(spacing: itemSpacing) {
                        ForEach(visible) { it in
                            let isActive = (activeId == it.id)

                            SpeakerTopCard(
                                item: it,
                                isActive: isActive,
                                phase: phase,
                                recordingPartialTranslit: recordingPartialTranslit,
                                recordingMeter: recordingMeter,
                                heardRU: external?.heardRU,
                                heardTranslit: external?.heardTranslit,
                                heardConfidence: heardConfidenceValue,
                                canPlayAttempt: (external?.lastAttempt != nil),
                                attemptCount: (external?.attemptCount ?? 0),
                                lastPlayed: (external?.lastPlayed ?? .none),
                                onPlayReference: {
                                    if let cb = external?.onPlayReferenceForId {
                                        cb(it.id)
                                    } else {
                                        external?.onPlayReference()
                                    }
                                },
                                onPlayAttempt: {
                                    external?.onPlayAttempt()
                                }
                            )
                            .scaleEffect(isActive ? 1.02 : 0.92)
                            .opacity(isActive ? 1.0 : 0.55)
                            .frame(width: itemW, height: itemH)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                localSelectedId = it.id
                                external?.onSelectCard(it.id)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                } else {
                    GeometryReader { outer in
                        let centerX = outer.size.width * 0.5
                        let sidePadding: CGFloat = max(0, (outer.size.width - itemW) * 0.5)

                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: itemSpacing) {
                                    ForEach(items) { it in
                                        GeometryReader { geo in
                                            let midX = geo.frame(in: .named("topCarousel")).midX
                                            let distance = abs(midX - centerX)
                                            let maxDistance = itemW + itemSpacing
                                            let t = min(distance / maxDistance, 1)

                                            // match FavoriteDS reel feel: slightly more separation and deeper falloff
                                            let scale: CGFloat = 0.88 + (1 - t) * 0.16
                                            let alpha: Double = 0.35 + (1 - t) * 0.65
                                            let y: CGFloat = t * 22

                                            let isActive = (currentId == it.id)

                                            SpeakerTopCard(
                                                item: it,
                                                isActive: isActive,
                                                phase: phase,
                                                recordingPartialTranslit: recordingPartialTranslit,
                                                recordingMeter: recordingMeter,
                                                heardRU: external?.heardRU,
                                                heardTranslit: external?.heardTranslit,
                                                heardConfidence: heardConfidenceValue,
                                                canPlayAttempt: (external?.lastAttempt != nil),
                                                attemptCount: (external?.attemptCount ?? 0),
                                                lastPlayed: (external?.lastPlayed ?? .none),
                                                onPlayReference: {
                                                    if let cb = external?.onPlayReferenceForId {
                                                        cb(it.id)
                                                    } else {
                                                        external?.onPlayReference()
                                                    }
                                                },
                                                onPlayAttempt: {
                                                    external?.onPlayAttempt()
                                                }
                                            )
                                            .scaleEffect(scale)
                                            .opacity(alpha)
                                            .offset(y: y)
                                            .zIndex(1.0 - t)
                                        }
                                        .frame(width: itemW, height: itemH)
                                        .id(it.id)
                                        .contentShape(Rectangle())
                                        .highPriorityGesture(
                                            TapGesture(count: 2).onEnded {
                                                if let cb = external?.onPlayReferenceForId {
                                                    cb(it.id)
                                                } else {
                                                    external?.onPlayReference()
                                                }
                                            }
                                        )
                                        .onTapGesture {
                                            localSelectedId = it.id
                                            external?.onSelectCard(it.id)
                                            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                                                proxy.scrollTo(it.id, anchor: .center)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, sidePadding)
                                .padding(.vertical, 6)
                            }
                            .coordinateSpace(name: "topCarousel")
                            .onAppear {
                                guard let id = currentId else { return }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: itemH)
        }
    }




    @ViewBuilder private var centerResult: some View {
        // all states are rendered inside the active top carousel card (single-carousel concept)
        EmptyView()
    }

    private var proResultHero: some View {
        guard case .feedback = phase else { return AnyView(EmptyView()) }

        let heardPhonetic: String = {
#if DEBUG
            if let p = previewExternal {
                return (p.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
#endif
            return (external?.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        let heardRU: String = {
#if DEBUG
            if let p = previewExternal {
                return (p.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
#endif
            return (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        return AnyView(
            VStack(alignment: .center, spacing: 0) {
                VStack(alignment: .center, spacing: 10) {
                    // recognized (main) — ru translation
                    Text("перевод")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .opacity(0.85)
                        .padding(.bottom, 2)

                    if !heardRU.isEmpty {
                        Text(heardRU)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(T.Colors.textPrimary)
                            .kerning(0.35)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, 10)
                    } else {
                        Text("—")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }

                    // phonetic (what user said) — russian letters
                    if !heardPhonetic.isEmpty {
                        Text(heardPhonetic)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .opacity(0.82)
                            .padding(.top, 2)
                    }

                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 22)
        )
    }

    private var bottomPrimaryAction: some View {
        let title: String
        let icon: String
        let action: () -> Void

        switch phase {
        case .recording:
            title = "stop"
            icon = "stop.circle.fill"
            action = { external?.onMicTap() }
        case .feedback:
            title = "ещё раз"
            icon = "arrow.clockwise"
            action = { external?.onRepeat() }
        case .hint:
            title = "ещё раз"
            icon = "arrow.clockwise"
            action = { external?.onRepeat() }
        default:
            title = "говорить"
            icon = "mic.fill"
            action = { external?.onMicTap() }
        }

        return Button(action: action) {
            HStack {
                Spacer(minLength: 0)

                Text(title)
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.black.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, alignment: .center)
    }


    private var activeFilterId: UUID? {
#if DEBUG
        if let p = previewExternal {
            return p.activeFilterId
        }
#endif
        return external?.activeFilterId
    }

    private var modeFilters: [AppFilterItem] {
        let active = activeFilterId
        return [
            AppFilterItem(id: SpeakerMode.current.id, title: "текущий урок", isActive: active == SpeakerMode.current.id),
            AppFilterItem(id: SpeakerMode.favorites.id, title: "избранное", isActive: active == SpeakerMode.favorites.id),
            AppFilterItem(id: SpeakerMode.learned.id, title: "выученные", isActive: active == SpeakerMode.learned.id),
            AppFilterItem(id: SpeakerMode.random.id, title: "случайные", isActive: active == SpeakerMode.random.id)
        ]
    }

    private var filtersStrip: some View {
        // carousel-like: outline pills + depth hint
        let items = modeFilters
        let activeIdx = items.firstIndex(where: { $0.isActive }) ?? 0

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, it in
                    let isActive = it.isActive
                    Button {
                        external?.onSelectFilter(it.id)
                    } label: {
                        Text(it.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                isActive
                                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                : AnyShapeStyle(PD.ColorToken.textSecondary)
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}


// MARK: - carousel/coverflow effect for top card

private struct SpeakerTopCard: View {
    let item: SpeakerItem
    let isActive: Bool
    let phase: SpeakerPhase
    let recordingPartialTranslit: String?
    let recordingMeter: Double
    let heardRU: String?
    let heardTranslit: String?
    let heardConfidence: Int
    let canPlayAttempt: Bool
    let attemptCount: Int
    let lastPlayed: SpeakerManager.LastPlayed
    let onPlayReference: () -> Void
    let onPlayAttempt: () -> Void

    @State private var recordPulse: CGFloat = 0
    @State private var analyzePulse: CGFloat = 0

    private var isRecordingActive: Bool {
        guard isActive else { return false }
        if case .recording = phase { return true }
        return false
    }

    private var isAnalyzingActive: Bool {
        guard isActive else { return false }
        return phase == .analyzing
    }

    private var isResultActive: Bool {
        guard isActive else { return false }
        return phase.isFeedback
    }

    @ViewBuilder private var attemptChip: some View {
        if !(isActive && attemptCount > 0 && !isRecordingActive && !isAnalyzingActive) {
            EmptyView()
        } else {
            Text("try \(attemptCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnyShapeStyle(PD.ColorToken.textSecondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(height: 22, alignment: .center)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .accessibilityLabel("попыток: \(attemptCount)")
        }
    }

    private func clean(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ruTitle: String {
        // main title in the card: russian meaning (what we show as the card title)
        // in speaker items, `hint` is ru meaning.
        clean(item.hint)
    }

    private var translitAccent: String {
        // pink line: reference phonetic/translit
        clean(item.translit)
    }

    private var thaiSecondary: String {
        // secondary grey line: thai script
        clean(item.phrase)
    }

    private var heardRUText: String { clean(heardRU) }
    private var heardTranslitText: String { clean(heardTranslit) }

    private var feedbackScore: Int? {
        guard isResultActive else { return nil }
        if case .feedback(let score, _) = phase { return score }
        return nil
    }

    private var verdictIsMatch: Bool {
        // v0: verdict is driven only by numeric score from SpeakerManager
        // (no string containment hacks; no RU fallback)
        guard let s = feedbackScore else { return false }
        return s >= 70
    }

    // verdictPill removed as per instructions

    @ViewBuilder private var leftAudioButton: some View {
        let isDisabledCommon = (!isActive) || isRecordingActive || isAnalyzingActive
        let canAttempt = canPlayAttempt && !isDisabledCommon
        let canReference = !isDisabledCommon

        HStack(spacing: 6) {
            Button(action: {
                guard canReference else { return }
                onPlayReference()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isRecordingActive ? "record.circle.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("эталон")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity((lastPlayed == .reference && isActive && !isRecordingActive) ? 0.10 : 0.06))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity((lastPlayed == .reference && isActive && !isRecordingActive) ? 0.16 : 0.10), lineWidth: 1)
                        )
                )
                .opacity(canReference ? 1.0 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!canReference)
            .accessibilityLabel(isRecordingActive ? "идёт запись" : "эталон")

            Button(action: {
                guard canAttempt else { return }
                onPlayAttempt()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .semibold))
                    Text("я")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity((lastPlayed == .attempt && isActive && canPlayAttempt && !isRecordingActive) ? 0.10 : 0.06))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity((lastPlayed == .attempt && isActive && canPlayAttempt && !isRecordingActive) ? 0.16 : 0.10), lineWidth: 1)
                        )
                )
                .opacity(canAttempt ? 1.0 : 0.35)
            }
            .buttonStyle(.plain)
            .disabled(!canAttempt)
            .accessibilityLabel("моя запись")
        }
        .opacity(isActive ? 1.0 : 0.0)
    }



    private enum VerdictKind {
        case match, mismatch

        var title: String {
            switch self {
            case .match: return "совпало"
            case .mismatch: return "не совпало"
            }
        }

        var tint: AnyShapeStyle {
            switch self {
            case .match:
                return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
            case .mismatch:
                return AnyShapeStyle(Color.white)
            }
        }

        var shadowColor: Color {
            switch self {
            case .match:
                // approximate accent for shadows
                return Color.accentColor
            case .mismatch:
                return Color.white
            }
        }

        var dotOpacity: Double {
            switch self {
            case .match: return 0.38
            case .mismatch: return 0.22
            }
        }

        var strokeOpacity: Double {
            switch self {
            case .match: return 0.30
            case .mismatch: return 0.16
            }
        }

        var glowOpacity: Double {
            switch self {
            case .match: return 0.20
            case .mismatch: return 0.10
            }
        }
    }

    private var verdictKind: VerdictKind {
        verdictIsMatch ? .match : .mismatch
    }

    @ViewBuilder private var phaseBadge: some View {
        if isResultActive {
            resultBadge
        } else if isRecordingActive {
            recordingBadge
        } else {
            EmptyView()
        }
    }

    @ViewBuilder private var resultBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(verdictKind.tint.opacity(verdictKind.dotOpacity))
                .frame(width: 8, height: 8)

            Text(verdictKind.title + (feedbackScore != nil ? " · \(feedbackScore!)" : ""))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .blur(radius: 10)
                )
        )
    }

    @ViewBuilder private var recordingBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .frame(width: 8, height: 8)
                .opacity(0.85)

            Text("запись")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .opacity(isActive ? 1.0 : 0.0)
    }

    @ViewBuilder private var analyzingBadge: some View {
        HStack(spacing: 8) {
            TypingDots(scale: 0.85)
                .opacity(0.85)

            Text("анализ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .opacity(isActive ? 1.0 : 0.0)
    }


    @ViewBuilder private func aiBackGlow(intensity: CGFloat, isCold: Bool) -> some View {
        // single centered “ai core sphere” BEHIND the card.
        // IMPORTANT: we keep it centered and avoid any lateral offsets so it reads as coming out from the card center.
        let a = Color.accentColor
        let w = Color.white

        ZStack {
            // core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            a.opacity((isCold ? 0.10 : 0.18) * intensity),
                            a.opacity((isCold ? 0.05 : 0.09) * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 210
                    )
                )
                .frame(width: 360, height: 360)

            // soft white bloom (depth)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            w.opacity((isCold ? 0.04 : 0.07) * intensity),
                            w.opacity((isCold ? 0.02 : 0.03) * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 260
                    )
                )
                .frame(width: 460, height: 460)

            // outer faint accent haze
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            a.opacity((isCold ? 0.035 : 0.055) * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 320
                    )
                )
                .frame(width: 560, height: 560)
        }
        .blur(radius: 40)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // Mask that removes the card interior from the glow so it never looks like it sits ON TOP of the card.
    // This keeps the “sphere” clearly BEHIND and only visible around the card edges.
    private var glowOutsideCardMask: some View {
        let card = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        return Rectangle()
            .fill(Color.black)
            .overlay(
                card
                    .fill(Color.black)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }

    @ViewBuilder private var hiTechRecordingFrame: some View {
        if !isRecordingActive {
            EmptyView()
        } else {
            let intensity = 0.55 + 0.45 * recordPulse

            aiBackGlow(intensity: intensity, isCold: false)
                // larger than the card so it “leaks” outside
                .frame(width: 700, height: 520)
                // ensure glow does NOT tint the semi-transparent card surface
                .mask(glowOutsideCardMask)
                .opacity(0.78)
                .transition(.opacity)
                .onAppear {
                    recordPulse = 0
                    withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                        recordPulse = 1
                    }
                }
        }
    }

    @ViewBuilder private var hiTechAnalyzingFrame: some View {
        if !isAnalyzingActive {
            EmptyView()
        } else {
            let intensity = 0.45 + 0.35 * analyzePulse

            aiBackGlow(intensity: intensity, isCold: true)
                .frame(width: 700, height: 520)
                .mask(glowOutsideCardMask)
                .opacity(0.64)
                .transition(.opacity)
                .onAppear {
                    analyzePulse = 0
                    withAnimation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true)) {
                        analyzePulse = 1
                    }
                }
        }
    }

    @ViewBuilder private var hiTechResultFrame: some View {
        if !isResultActive {
            EmptyView()
        } else {
            let tint = verdictKind.tint
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .stroke(
                    tint,
                    lineWidth: 1.2
                )
                .shadow(color: verdictKind.shadowColor.opacity(verdictKind.glowOpacity), radius: 18)
                .shadow(color: verdictKind.shadowColor.opacity(verdictKind.glowOpacity * 0.7), radius: 36)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.00),
                            verdictKind.shadowColor.opacity(0.08),
                            Color.white.opacity(0.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.screen)
                    .opacity(0.65)
                    .mask(
                        RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                            .stroke(Color.white, lineWidth: 8)
                    )
                )
                .transition(.opacity)
        }
    }


    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)

        VStack(alignment: .leading, spacing: 10) {
            // top row (FavoriteDS-like scaffold)
            HStack(spacing: 8) {
                Text("taikA")
                    .font(.custom("ONMARK Trial", size: 14))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.text)

                Spacer(minLength: 0)

                attemptChip
                    .layoutPriority(0)
            }

            Spacer(minLength: 0)

            // center block (FavoriteDS-like typography rhythm)
            Group {
                if isAnalyzingActive {
                    VStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .scaleEffect(1.05)

                        Text("анализирую…")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AnyShapeStyle(PD.ColorToken.textSecondary))
                            .opacity(0.88)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        // line 1 (accent): translit (target)
                        Text(translitAccent.isEmpty ? "—" : translitAccent)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .lineLimit(2)
                            .minimumScaleFactor(0.80)
                            .opacity(translitAccent.isEmpty ? 0.45 : 1.0)

                        if isRecordingActive {
                            // while recording we DON'T show RU meaning (it will appear in result)
                            MiniWaveform(meter: recordingMeter)
                                .padding(.top, 2)

                            Text(thaiSecondary)
                                .font(.footnote)
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .opacity(0.86)
                                .lineLimit(1)
                                .minimumScaleFactor(0.90)
                                .opacity(thaiSecondary.isEmpty ? 0.0 : 1.0)
                        } else {
                            // line 2 (title): RU meaning (shown only when not recording)
                            Text(ruTitle.isEmpty ? "—" : ruTitle)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(T.Colors.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.80)
                                .opacity(ruTitle.isEmpty ? 0.45 : 1.0)

                            // line 3 (secondary): thai script
                            Text(thaiSecondary)
                                .font(.footnote)
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .opacity(0.86)
                                .lineLimit(1)
                                .minimumScaleFactor(0.90)
                                .opacity(thaiSecondary.isEmpty ? 0.0 : 1.0)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

        }
        .padding(16)
        .frame(width: 268, height: 196, alignment: .topLeading)
        .background(
            Theme.Surfaces.card(round)
        )
        .background {
            // aura outside the card while recording/analyzing
            ZStack {
                hiTechRecordingFrame
                hiTechAnalyzingFrame
            }
        }
        .overlay {
            hiTechResultFrame
        }
        .animation(.easeInOut(duration: 0.18), value: isRecordingActive)
        .animation(.easeInOut(duration: 0.18), value: isAnalyzingActive)
        .overlay(alignment: .bottomTrailing) {
            phaseBadge
                .padding(.trailing, 14)
                .padding(.bottom, 14)
                .allowsHitTesting(false)
        }
        .contentShape(round)
    }
}

// MARK: - domain
enum SpeakerMode: Hashable {
    case current, favorites, learned, random

    // stable ids for AppFiltersBar (UUID-based)
    private static let currentId = UUID(uuidString: "9C9B0F3C-8B3B-4C7C-9D26-8B0F4C9A1A01")!
    private static let favoritesId = UUID(uuidString: "2A6E4A7B-0B7B-4E7B-8C5A-7B9D1F8E2B02")!
    private static let learnedId = UUID(uuidString: "3B7C5D8A-1C4D-4D2B-9A6C-2D1C7E4B5A04")!
    private static let randomId = UUID(uuidString: "7E1D5B8E-2C5A-4C1C-8B6E-5A2C1D7E3C03")!

    var id: UUID {
        switch self {
        case .current: return Self.currentId
        case .favorites: return Self.favoritesId
        case .learned: return Self.learnedId
        case .random: return Self.randomId
        }
    }

    init?(id: UUID) {
        switch id {
        case Self.currentId: self = .current
        case Self.favoritesId: self = .favorites
        case Self.learnedId: self = .learned
        case Self.randomId: self = .random
        default: return nil
        }
    }
}

enum SpeakerPhase: Equatable {
    case idle
    case recording(start: Date)
    case analyzing
    case hint
    case feedback(score: Int, hint: String?)

    var isFeedback: Bool { if case .feedback = self { return true } else { return false } }
    var label: String {
        switch self {
        case .idle: return "нажми и говори"
        case .recording: return "запись…"
        case .analyzing: return "анализ…"
        case .hint: return "совет"
        case .feedback: return "результат"
        }
    }
}

struct SpeakerItem: Identifiable, Hashable {
    let id: UUID
    var phrase: String
    var translit: String
    var hint: String
    var lessonTitle: String? = nil
    var kindTag: String = "фраза"
    var isFavorite: Bool = false
    var isLearned: Bool = false
    var isProLocked: Bool = false
}



// MARK: - components

private struct TypingDots: View {
    var scale: CGFloat = 1.0
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            dot(0)
            dot(1)
            dot(2)
        }
        .scaleEffect(scale)
        .onAppear {
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            phase = 1
            guard !isPreview else { return }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func dot(_ i: Int) -> some View {
        let delay = Double(i) * 0.18
        return Circle()
            .fill(Color.white.opacity(0.55))
            .frame(width: 5, height: 5)
            .opacity(opacity(delay: delay))
    }

    private func opacity(delay: Double) -> Double {
        // simple looping wave
        let t = (Double(phase) * 1.0 + delay).truncatingRemainder(dividingBy: 1.0)
        // peak in the middle
        let v = 1.0 - abs(t - 0.5) * 2.0
        return 0.25 + 0.55 * max(0.0, v)
    }
}



private struct MiniWaveform: View {
    let meter: Double
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            bar(0)
            bar(1)
            bar(2)
            bar(3)
            bar(4)
            bar(5)
        }
        .frame(height: 14)
        .onAppear {
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            phase = 1
            guard !isPreview else { return }
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(_ i: Int) -> some View {
        let base: CGFloat = 3
        let amp = CGFloat(max(0.0, min(1.0, meter)))
        let wobble = 0.25 + 0.75 * wave(i)
        let h = base + (12 * amp * wobble)

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
            .frame(width: 3, height: h)
            .opacity(0.85)
    }

    private func wave(_ i: Int) -> CGFloat {
        let t = (Double(phase) + Double(i) * 0.12).truncatingRemainder(dividingBy: 1.0)
        // triangle-ish wave
        let v = 1.0 - abs(t - 0.5) * 2.0
        return CGFloat(max(0.0, v))
    }
}


private struct SpeakerPlayerWave: View {
    let active: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            HStack(alignment: .center, spacing: 4) {
                waveBar(h: h, i: 0)
                waveBar(h: h, i: 1)
                waveBar(h: h, i: 2)
                waveBar(h: h, i: 3)
                waveBar(h: h, i: 4)
                waveBar(h: h, i: 5)
                waveBar(h: h, i: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            phase = 1
            guard !isPreview else { return }
            withAnimation(.linear(duration: active ? 0.95 : 1.35).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .onChange(of: active) { _ in
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            phase = 1
            guard !isPreview else { return }
            phase = 0
            withAnimation(.linear(duration: active ? 0.95 : 1.35).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func waveBar(h: CGFloat, i: Int) -> some View {
        let t = (Double(phase) + Double(i) * 0.13).truncatingRemainder(dividingBy: 1.0)
        let v = 1.0 - abs(t - 0.5) * 2.0
        let amp = CGFloat(max(0.0, v))
        let base: CGFloat = max(2.0, h * 0.18)
        let maxExtra: CGFloat = max(6.0, h * 0.70)
        let barH = base + maxExtra * (active ? amp : amp * 0.35)

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white.opacity(active ? 0.70 : 0.35))
            .frame(width: 3, height: barH)
    }
}


// MARK: - previews

// MARK: - previews

#if DEBUG
private struct SpeakerDSStoryPreview: View {
    enum StoryPhase: String, CaseIterable, Identifiable {
        case idle = "idle"
        case recording = "record"
        case analyzing = "analyze"
        case feedback = "result"

        var id: String { rawValue }
    }

    @State private var storyPhase: StoryPhase = .idle

    private let demoCurrent = SpeakerItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        phrase: "ใช้ได้",
        translit: "чай дай↘︎",
        hint: "норм, пойдёт",
        lessonTitle: "урок 2",
        kindTag: "фраза",
        isFavorite: true,
        isLearned: false,
        isProLocked: false
    )

    private let demoItems: [SpeakerItem] = [
        SpeakerItem(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            phrase: "ใช้ได้",
            translit: "чай дай↘︎",
            hint: "норм, пойдёт",
            lessonTitle: "урок 2",
            kindTag: "фраза",
            isFavorite: true,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            phrase: "สวัสดีครับ",
            translit: "са-ва-ди-крап",
            hint: "привет",
            lessonTitle: "урок 5",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: true,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            phrase: "ขอบคุณครับ",
            translit: "кхоп-кхун-крап",
            hint: "спасибо",
            lessonTitle: "урок 5",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            phrase: "ไม่เป็นไร",
            translit: "май-пен-рай",
            hint: "ничего страшного",
            lessonTitle: "урок 3",
            kindTag: "фраза",
            isFavorite: true,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            phrase: "ขอโทษครับ",
            translit: "кхо-тхот-крап",
            hint: "извини",
            lessonTitle: "урок 4",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            phrase: "ไปไหน",
            translit: "пай-най?",
            hint: "куда идёшь?",
            lessonTitle: "урок 6",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: true,
            isProLocked: false
        )
    ]

    private var phase: SpeakerPhase {
        switch storyPhase {
        case .idle:
            return .idle
        case .recording:
            return .recording(start: Date())
        case .analyzing:
            return .analyzing
        case .feedback:
            return .feedback(score: 0, hint: nil)
        }
    }

    private var heardThai: String? {
        switch storyPhase {
        case .feedback:
            return "ฟинดีนะ"
        default:
            return nil
        }
    }

    private var heardPhonetic: String? {
        switch storyPhase {
        case .feedback:
            return "фин-ди-на"
        default:
            return nil
        }
    }

    private var recordingPartialThai: String? {
        switch storyPhase {
        case .recording:
            return ""
        default:
            return nil
        }
    }

    private var recordingPartialTranslit: String? {
        switch storyPhase {
        case .recording:
            // demo: partial should match the currently selected target (not a constant)
            return "чай дай"
        default:
            return nil
        }
    }

    private var meter: Double {
        switch storyPhase {
        case .recording:
            return 0.42
        default:
            return 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // phase switcher (preview-only)
            Picker("phase", selection: $storyPhase) {
                ForEach(StoryPhase.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(T.Colors.backgroundPrimary)

            SpeakerDSRoot(
                preview: .init(
                    current: demoCurrent,
                    items: demoItems,
                    activeFilterId: SpeakerMode.current.id,
                    phase: phase,
                    heardThai: heardThai,
                    heardRU: storyPhase == .feedback ? "мне хорошо" : nil,
                    heardTranslit: heardPhonetic,
                    heardConfidence: 0,
                    taikaHints: storyPhase == .feedback ? [
                        "норм",
                        "давай медленнее и чётче — будет лучше"
                    ] : [],
                    recordingMeter: meter,
                    recordingPartialThai: recordingPartialThai,
                    recordingPartialTranslit: recordingPartialTranslit,
                    lastAttempt: storyPhase == .feedback ? URL(fileURLWithPath: "/tmp/speaker_preview_attempt.m4a") : nil,
                    attemptCount: storyPhase == .feedback ? 4 : (storyPhase == .recording ? 1 : 0),
                    lastPlayed: storyPhase == .feedback ? .attempt : .none
                )
            )
        }
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
    }
}

#Preview("speaker ds — story") {
    SpeakerDSStoryPreview()
}
#endif
