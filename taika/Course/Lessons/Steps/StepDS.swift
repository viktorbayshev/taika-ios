// MARK: - Step Progress Segment (single capsule)
public struct SDStepProgressSegment: View {
    public var width: CGFloat
    public var isActive: Bool
    public var isLearned: Bool
    public var isFavorite: Bool
    public var index: Int?
    public var onTap: ((Int) -> Void)?

    public init(width: CGFloat,
                isActive: Bool,
                isLearned: Bool,
                isFavorite: Bool,
                index: Int? = nil,
                onTap: ((Int) -> Void)? = nil) {
        self.width = width
        self.isActive = isActive
        self.isLearned = isLearned
        self.isFavorite = isFavorite
        self.index = index
        self.onTap = onTap
    }

    public var body: some View {
        let base = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return ZStack {
            base
                .fill(
                    isLearned
                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    : AnyShapeStyle(.ultraThinMaterial.opacity(0.10))
                )
                .frame(width: width, height: 36)
                .overlay(base.stroke(PD.ColorToken.stroke, lineWidth: 1))
                .overlay(
                    Group {
                        if isActive {
                            base.stroke(PD.ColorToken.textSecondary, lineWidth: 2)
                        }
                    }
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isActive)
                .animation(.easeOut(duration: 0.18), value: isLearned)
                .animation(.easeOut(duration: 0.18), value: isFavorite)

            if isFavorite {
                Group {
                    if isLearned {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(PD.ColorToken.card)
                    } else {
                        GradientIcon(systemName: "heart.fill", size: 12)
                    }
                }
                .opacity(0.95)
                .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: 36)
        .contentShape(Rectangle())
        .onTapGesture {
            if let idx = index {
                onTap?(idx)
            }
        }
    }
}
//
//  StepDS.swift
//  taika
//
//  Design System for STEP (lesson content) cards & carousels
//  Visual-only layer: no networking/state here – just views & light models.

import SwiftUI
import UIKit

// MARK: - Model
public struct SDStepItem: Identifiable, Hashable {
    public enum Kind: String, CaseIterable, Hashable {
        case intro, word, phrase, tip, casual, summary
    }
    public let id: UUID
    public var kind: Kind
    public var titleRU: String            // «слово / фраза» на русском
    public var subtitleTH: String         // тайский / латиницей
    public var phonetic: String           // руссифицированная транскрипция по слогам
    public var metaLearned: Int?
    public var metaFavorites: Int?
    public var isFavorite: Bool
    public var isLearned: Bool
    public var isPro: Bool

    public init(
        id: UUID = .init(),
        kind: Kind,
        titleRU: String,
        subtitleTH: String,
        phonetic: String,
        metaLearned: Int? = nil,
        metaFavorites: Int? = nil,
        isFavorite: Bool = false,
        isLearned: Bool = false,
        isPro: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.titleRU = titleRU
        self.subtitleTH = subtitleTH
        self.phonetic = phonetic
        self.metaLearned = metaLearned
        self.metaFavorites = metaFavorites
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.isPro = isPro
    }
}

extension SDStepItem {
    var visualKind: Kind {
        // визуальный тип теперь напрямую следует за kind из json:
        // word / phrase / casual / tip / intro / summary
        // без эвристик по количеству слов в titleRU
        return kind
    }
}


// MARK: - Tag chip (тип карточки)

// Shared accent gradient (matches Lessons / Favorites)
fileprivate var AccentGradient: LinearGradient {
    LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.52, blue: 0.80),
            Color(red: 0.91, green: 0.62, blue: 0.98)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// Gradient helpers for icons/text

// Shared helper to compute *final* visual card size by step kind
fileprivate func stepCardSize(for kind: SDStepItem.Kind) -> CGSize {
    switch kind {
    case .tip:
        // лайфхаки — вертикальные, с отдельной увеличенной высотой
        return CGSize(
            width:  CardDS.Metrics.stepCardWidth,
            height: CardDS.Metrics.stepLifehackCardHeight
        )

    case .word, .phrase, .casual, .intro, .summary:
        // учебные / интро / саммари — квадратные (базовая высота word‑карты)
        return CGSize(
            width:  CardDS.Metrics.stepCardWidth,
            height: CardDS.Metrics.stepWordCardHeight
        )
    }
}
fileprivate struct GradientIcon: View {
    var systemName: String
    var size: CGFloat = 18
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
    }
}
fileprivate struct GradientStrokeCapsule: View {
    var body: some View {
        Capsule(style: .continuous)
            .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1)
    }
}

// MARK: - like micro-animations
// gradient sweep that fills heart from left → right (brief)
fileprivate struct SDFavSweepFill: View {
    var trigger: Bool
    @State private var progress: CGFloat = 0
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: 34 * max(progress, 0.001), height: 32)
            .clipped()
            .mask(Image(systemName: "heart.fill").font(.system(size: 18, weight: .semibold)))
            .opacity(progress > 0 ? 1 : 0)
        }
        .frame(width: 34, height: 32)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, on in
            guard on else { return }
            progress = 0
            withAnimation(.easeOut(duration: 0.18)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { progress = 0 }
        }
    }
}

// thin halo ring (no glow) expands and fades
fileprivate struct SDFavHaloRing: View {
    var trigger: Bool
    @State private var scale: CGFloat = 0.3
    @State private var alpha: CGFloat = 0.0
    var body: some View {
        Circle()
            .stroke(LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
            .frame(width: 36, height: 36)
            .scaleEffect(scale)
            .opacity(alpha)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, on in
                guard on else { return }
                scale = 0.3; alpha = 0.35
                withAnimation(.easeOut(duration: 0.20)) { scale = 1.30; alpha = 0.0 }
            }
    }
}

// slow minimal pulse wave (single ring)
fileprivate struct SDFavPulseWave: View {
    var trigger: Bool
    @State private var scale: CGFloat = 0.9
    @State private var alpha: CGFloat = 0.0
    var body: some View {
        Circle()
            .stroke(LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
            .frame(width: 42, height: 42)
            .scaleEffect(scale)
            .opacity(alpha)
            .blur(radius: 0.5)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, on in
                guard on else { return }
                scale = 0.92; alpha = 0.20
                withAnimation(.easeOut(duration: 0.50)) {
                    scale = 1.50; alpha = 0.0
                }
            }
    }
}

// tiny check flash — appears briefly when item is liked (yandex‑style feedback)
fileprivate struct SDTickFlash: View {
    var trigger: Bool
    @State private var show: Bool = false
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing))
            .scaleEffect(show ? 1.0 : 0.86)
            .opacity(show ? 0.95 : 0.0)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, on in
                guard on else { return }
                show = false
                withAnimation(.easeOut(duration: 0.10)) { show = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeOut(duration: 0.10)) { show = false }
                }
            }
    }
}

// big like flash — moderate, calm Yandex‑style heart (centered, subtle)
fileprivate struct SDBigLikeFlash: View {
    var trigger: Bool
    @State private var scale: CGFloat = 0.92
    @State private var alpha: CGFloat = 0.0
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .mask(
                Image(systemName: "heart.fill")
                    .font(.system(size: 180, weight: .semibold))
            )
            .opacity(alpha)
            .scaleEffect(scale)
            .blur(radius: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, on in
            guard on else { return }
            // gentle breathe: 0.92 → 1.08 → 1.00 and fade
            scale = 0.92; alpha = 0.0
            withAnimation(.easeOut(duration: 0.22)) { scale = 1.08; alpha = 0.22 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeOut(duration: 0.18)) { scale = 1.00; alpha = 0.18 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                withAnimation(.easeOut(duration: 0.16)) { alpha = 0.0 }
            }
        }
    }
}

// Helper: build styled Text with stressed syllable (accent) highlighted
// Helper: build styled Text with stressed syllable (accent) highlighted
fileprivate func phoneticStyledText(_ s: String) -> Text {
    // всё, что без ударения — базовый светлый текст;
    // слог (кусок между пробелами/дефисами), внутри которого есть диакритика,
    // подсвечиваем целиком акцентным градиентом.
    let accentScalars: Set<UnicodeScalar> = [
        // acute
        UnicodeScalar(0x0301)!, // COMBINING ACUTE ACCENT
        UnicodeScalar(0x00B4)!, // ACUTE ACCENT (spacing)
        UnicodeScalar(0x02CA)!, // MODIFIER LETTER ACUTE ACCENT
        // grave
        UnicodeScalar(0x0300)!, // COMBINING GRAVE ACCENT
        UnicodeScalar(0x02CB)!, // MODIFIER LETTER GRAVE ACCENT
        // circumflex
        UnicodeScalar(0x0302)!, // COMBINING CIRCUMFLEX ACCENT
        UnicodeScalar(0x02C6)!, // MODIFIER LETTER CIRCUMFLEX ACCENT
        // breve
        UnicodeScalar(0x0306)!, // COMBINING BREVE
        UnicodeScalar(0x02D8)!, // BREVE (spacing)
        // caron
        UnicodeScalar(0x030C)!, // COMBINING CARON
        UnicodeScalar(0x02C7)!  // CARON (modifier)
    ]

    func chunkHasAccent(_ chunk: String) -> Bool {
        chunk.unicodeScalars.contains { accentScalars.contains($0) }
    }

    // быстрый путь: если нет ни одного ударения — просто базовый светлый текст
    guard s.unicodeScalars.contains(where: { accentScalars.contains($0) }) else {
        return Text(s).foregroundStyle(PD.ColorToken.text)
    }

    // слогами считаем куски между пробелами и дефисами
    let separators: Set<Character> = [" ", "-", "·"]

    var result = Text("")
    var currentChunk = ""
    var currentSeparator: Character? = nil

    func flushChunk() {
        guard !currentChunk.isEmpty else { return }
        let isAccentChunk = chunkHasAccent(currentChunk)
        let base = Text(currentChunk)
        if isAccentChunk {
            result = result + base.foregroundStyle(ThemeManager.shared.currentAccentFill)
        } else {
            result = result + base.foregroundStyle(PD.ColorToken.text)
        }
        currentChunk = ""
    }

    for ch in s {
        if separators.contains(ch) {
            // сначала выкидываем накопленный слог
            flushChunk()
            // сам разделитель добавляем базовым светлым цветом
            let sepText = Text(String(ch))
                .foregroundStyle(PD.ColorToken.text)
            result = result + sepText
            currentSeparator = ch
        } else {
            currentSeparator = nil
            currentChunk.append(ch)
        }
    }
    // последний слог
    flushChunk()

    return result
}


// MARK: - Step card
// (StepWordCardVisual removed)

/// Step Card for displaying a learning item. Supports active glow state.
public struct SDStepCard: View {
    /// Whether this card is currently active/selected (shows glow, no white stroke)
    public var isActive: Bool = false
    public var isReadOnly: Bool = false
    public var isOverlay: Bool = false
    // Unified typography for learning cards (word/phrase/casual)
    private let TITLE_FONT: Font      = .taikaTitle(28)                      // main RU word/phrase
    private let PHON_FONT: Font       = .system(size: 18, weight: .semibold) // phonetic line (accented)
    private let THAI_FONT: Font       = .system(size: 20, weight: .regular)  // thai line
    // Typography for tips (лайфхаки)
    private let TIP_TITLE_FONT  = PD.FontToken.body(18, weight: .semibold)
    private let TIP_BODY_FONT   = PD.FontToken.body(15, weight: .regular)
    private let LINES_SPACING: CGFloat = 3
    public var item: SDStepItem
    public var onTap: ()->Void
    public var onPlay: ()->Void
    public var onToggleFavorite: ()->Void
    public var onMarkLearned: ()->Void
    public var onNext: ()->Void

    // Injectables to allow custom visuals from StepIntroSum
    private var introContentBuilder: () -> AnyView
    private var summaryContentBuilder: () -> AnyView
    private var introBarBuilder: () -> AnyView
    private var summaryBarBuilder: () -> AnyView

    @State private var favPulse: Bool = false
    @State private var playPulse: Bool = false
    @State private var nextPulse: Bool = false
    @State private var donePulse: Bool = false
    @State private var isFav: Bool = false
    @State private var denyPulse: Bool = false
    @State private var likeAnim: Bool = false
    @State private var unlikeAnim: Bool = false
    @State private var bigLike: Bool = false
    private var isLearned: Bool

    private func splitSubtitle(_ raw: String) -> (thai: String, latin: String) {
        // Expected formats: "ขอบคุณ (kh̄xbkhuṇ)" or just "ขอบคุณ"
        if let open = raw.firstIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            let thai = raw[..<open].trimmingCharacters(in: .whitespaces)
            let latin = raw[raw.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            return (String(thai), String(latin))
        } else {
            return (raw, raw)
        }
    }

    public init(
        item: SDStepItem,
        onTap: @escaping ()->Void = {},
        onPlay: @escaping ()->Void = {},
        onToggleFavorite: @escaping ()->Void = {},
        onMarkLearned: @escaping ()->Void = {},
        onNext: @escaping ()->Void = {},
        initialLearned: Bool = false,
        introContent: (() -> AnyView)? = nil,
        summaryContent: (() -> AnyView)? = nil,
        introCTA:   (() -> AnyView)? = nil,
        summaryCTA: (() -> AnyView)? = nil,
        isReadOnly: Bool = false,
        isOverlay: Bool = false,
        isActive: Bool = false
    ) {
        self.item = item
        self.onTap = onTap
        self.onPlay = onPlay
        self.onToggleFavorite = onToggleFavorite
        self.onMarkLearned = onMarkLearned
        self.onNext = onNext
        // Fallbacks are defined here, so we can safely use private/internal helpers
        self.introContentBuilder   = introContent   ?? { AnyView(_IntroPlaceholder()) }
        self.summaryContentBuilder = summaryContent ?? { AnyView(_SummaryPlaceholder()) }
        self.introBarBuilder       = introCTA       ?? { AnyView(SDStepCard.defaultIntroActionBar()) }
        self.summaryBarBuilder     = summaryCTA     ?? { AnyView(SDStepCard.defaultSummaryActionBar()) }
        self._isFav = State(initialValue: item.isFavorite)
        self.isLearned = initialLearned
        self.isActive = isActive
        self.isOverlay = isOverlay
        self.isReadOnly = isReadOnly
    }

    public var body: some View {
        let vkOuter = item.visualKind
        let cardSize = stepCardSize(for: vkOuter)

        // строим готовую карточку из CardDS и сразу прокидываем всю логику CTA внутрь
        let cardView: AnyView = {
            switch vkOuter {
            case .tip:
                return AnyView(
                    StepLifehackCardLegacy(
                        body: item.subtitleTH.isEmpty ? item.titleRU : item.subtitleTH,
                        label: labelFor(item: item),
                        size: cardSize,
                        sectionChrome: .seps,
                        chromeStyle: .cards,
                        isFavorite: isFav,
                        onFavorite: {
                            onToggleFavorite()
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            favPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { favPulse = false }
                        },
                        onNext: {
                            onNext()
                            nextPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { nextPulse = false }
                        }
                    )
                )

            default:
                if item.isPro {
                    return AnyView(
                        StepProGateCard(
                            title: item.titleRU,
                            subtitle: item.subtitleTH,
                            footnote: item.phonetic.isEmpty ? "нужно pro" : item.phonetic,
                            label: "pro",
                            primaryTitle: "открыть pro",
                            size: cardSize,
                            sectionChrome: .seps,
                            chromeStyle: .cards,
                            onPrimaryTap: {
                                onTap()
                            }
                        )
                    )
                }

                return AnyView(
                    StepWordCard(
                        title: item.titleRU,
                        translit: item.phonetic,
                        thai: splitSubtitle(item.subtitleTH).thai,
                        label: labelFor(item: item),
                        size: cardSize,
                        sectionChrome: .seps,
                        chromeStyle: .cards,
                        isFavorite: isFav,
                        isLearned: isLearned,
                        allowLearn: !isReadOnly,
                        onPlay: {
                            playPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { playPulse = false }
                            onPlay()
                        },
                        onFavorite: {
                            onToggleFavorite()
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            favPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { favPulse = false }
                        },
                        onLearn: {
                            if isReadOnly {
                                denyFeedback()
                            } else {
                                onMarkLearned()
                                donePulse = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { donePulse = false }
                            }
                        }
                    )
                )
            }
        }()

        return cardView
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .frame(width: cardSize.width)
            .frame(minHeight: cardSize.height)
            .animation(.none, value: isLearned)
            .animation(.none, value: isFav)
            .transaction { $0.animation = nil }
            .onAppear { isFav = item.isFavorite }
            .onChange(of: item.id) { _, _ in isFav = item.isFavorite }
            .onChange(of: item.isFavorite) { _, newValue in isFav = newValue }
    }



    private func labelFor(item: SDStepItem) -> String {
        if item.isPro { return "pro" }
        switch item.visualKind {
        case .intro: return "Старт"
        case .word: return "Слово"
        case .phrase: return "Фраза"
        case .tip: return "Лайфхак"
        case .casual: return "Сленг"
        case .summary: return "Итоги"
        }
    }


    private func styledPhonetic(_ s: String) -> some View {
        phoneticStyledText(s)
            .font(PHON_FONT)
            .multilineTextAlignment(.center)
    }


    private func denyFeedback() {
        // Rigid haptic + tiny bounce to indicate non-interactive in overlay
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            denyPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                denyPulse = false
            }
        }
    }

    // MARK: - New Action Bars for Intro and Summary
    static func defaultIntroActionBar() -> some View {
        ZStack(alignment: .trailing) {
            Capsule(style: .continuous)
                .fill(Color.clear)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1)
                )

            Button(action: { }) {
                GradientIcon(systemName: "chevron.right", size: 18)
                    .frame(width: 34, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .contentShape(Rectangle())
    }

    static func defaultSummaryActionBar() -> some View {
        HStack(spacing: 0) {
            Button(action: { }) {
                GradientIcon(systemName: "doc.text", size: 18)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: { }) {
                GradientIcon(systemName: "chevron.right", size: 18)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.clear)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .contentShape(Rectangle())
    }

    private func builtIntroActionBar() -> AnyView { introBarBuilder() }
    private func builtSummaryActionBar() -> AnyView { summaryBarBuilder() }
}

// Local placeholders to keep DS self-contained when StepIntroSum is not linked.
private struct _IntroPlaceholder: View {
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image("mascot.step")
                .resizable()
                .scaledToFit()
                .frame(height: 88)
                .opacity(0.75)
            Text("Вступление")
                .font(PD.FontToken.body(18, weight: .semibold))
                .foregroundColor(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct _SummaryPlaceholder: View {
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image("mascot.step")
                .resizable()
                .scaledToFit()
                .frame(height: 88)
                .opacity(0.75)
            Text("Итоги урока")
                .font(PD.FontToken.body(18, weight: .semibold))
                .foregroundColor(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// Helper for detecting which step card is closest to center in the carousel
fileprivate struct SDStepCarouselCenterCandidate: Equatable {
    let index: Int
    let norm: CGFloat
    let carouselID: UUID
}

fileprivate struct SDStepCarouselCenterPreferenceKey: PreferenceKey {
    static var defaultValue: [SDStepCarouselCenterCandidate] = []
    static func reduce(value: inout [SDStepCarouselCenterCandidate],
                       nextValue: () -> [SDStepCarouselCenterCandidate]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Carousel (горизонтальная) — интро/саммари из StepIntroSum
public struct SDStepCarousel: View {
    public var title: String
    public var items: [SDStepItem]
    @Binding public var activeIndex: Int
    public var subtitle: String?
    public var learned: Set<Int>
    public var favorites: Set<Int>
    public var onTap: (SDStepItem)->Void
    public var onPlay: (SDStepItem)->Void
    public var onFav: (SDStepItem)->Void
    public var onDone: (SDStepItem)->Void
    public var onActiveIndexChange: ((Int) -> Void)?
    public var onNext: (SDStepItem) -> Void
    public var onFavAt: ((Int, SDStepItem) -> Void)?
    public var onDoneAt: ((Int, SDStepItem) -> Void)?
    // Optional builders injected from StepIntroSum to avoid DS hard dependency
    public var introContentView: (() -> AnyView)?
    public var summaryContentView: (() -> AnyView)?
    public var introCTAView: (() -> AnyView)?
    public var summaryCTAView: (() -> AnyView)?
    public var isOverlay: Bool
    public var allowLearning: Bool

    private let carouselID = UUID()
    @State private var didInitialScroll: Bool = false
    @State private var isProgrammaticScroll: Bool = false
    
    public init(
        title: String,
        items: [SDStepItem],
        activeIndex: Binding<Int>,
        subtitle: String? = nil,
        learned: Set<Int> = [],
        favorites: Set<Int> = [],
        onTap: @escaping (SDStepItem)->Void = {_ in},
        onPlay: @escaping (SDStepItem)->Void = {_ in},
        onFav: @escaping (SDStepItem)->Void = {_ in},
        onDone: @escaping (SDStepItem)->Void = {_ in},
        onActiveIndexChange: ((Int) -> Void)? = nil,
        onNext: @escaping (SDStepItem) -> Void = { _ in },
        onFavAt: ((Int, SDStepItem) -> Void)? = nil,
        onDoneAt: ((Int, SDStepItem) -> Void)? = nil,
        introContentView: (() -> AnyView)? = nil,
        summaryContentView: (() -> AnyView)? = nil,
        introCTAView: (() -> AnyView)? = nil,
        summaryCTAView: (() -> AnyView)? = nil,
        isOverlay: Bool = false,
        allowLearning: Bool = true
    ) {
        self.title = title
        self.items = items
        self._activeIndex = activeIndex
        self.subtitle = subtitle
        self.learned = learned
        self.favorites = favorites
        self.onTap = onTap
        self.onPlay = onPlay
        self.onFav = onFav
        self.onDone = onDone
        self.onActiveIndexChange = onActiveIndexChange
        self.onNext = onNext
        self.onFavAt = onFavAt
        self.onDoneAt = onDoneAt
        self.introContentView = introContentView
        self.summaryContentView = summaryContentView
        self.introCTAView = introCTAView
        self.summaryCTAView = summaryCTAView
        self.isOverlay = isOverlay
        self.allowLearning = allowLearning
    }

    // TEMP: Back-compat overloads to keep old call-sites working while we migrate to explicit `isOverlay:`. Remove after rollout.
    @available(*, deprecated, message: "Use init(..., isOverlay:) and pass isOverlay explicitly. This overload will be removed after call-sites are updated.")
    public init(
        title: String,
        items: [SDStepItem],
        activeIndex: Binding<Int>,
        learned: Set<Int> = [],
        favorites: Set<Int> = [],
        onTap: @escaping (SDStepItem)->Void = {_ in},
        onPlay: @escaping (SDStepItem)->Void = {_ in},
        onFav: @escaping (SDStepItem)->Void = {_ in},
        onDone: @escaping (SDStepItem)->Void = {_ in},
        onActiveIndexChange: ((Int) -> Void)? = nil,
        onNext: @escaping (SDStepItem) -> Void = { _ in },
        introContentView: (() -> AnyView)? = nil,
        summaryContentView: (() -> AnyView)? = nil,
        introCTAView: (() -> AnyView)? = nil,
        summaryCTAView: (() -> AnyView)? = nil
    ) {
        self.init(
            title: title,
            items: items,
            activeIndex: activeIndex,
            subtitle: nil,
            learned: learned,
            favorites: favorites,
            onTap: onTap,
            onPlay: onPlay,
            onFav: onFav,
            onDone: onDone,
            onActiveIndexChange: onActiveIndexChange,
            onNext: onNext,
            onFavAt: nil,
            onDoneAt: nil,
            introContentView: introContentView,
            summaryContentView: summaryContentView,
            introCTAView: introCTAView,
            summaryCTAView: summaryCTAView,
            isOverlay: false,
            allowLearning: true
        )
    }

    @available(*, deprecated, message: "Use init(..., isOverlay:) and pass isOverlay explicitly. This overload will be removed after call-sites are updated.")
    public init(
        title: String,
        items: [SDStepItem],
        activeIndex: Binding<Int>
    ) {
        self.init(
            title: title,
            items: items,
            activeIndex: activeIndex,
            subtitle: nil,
            learned: [],
            favorites: [],
            onTap: { _ in },
            onPlay: { _ in },
            onFav: { _ in },
            onDone: { _ in },
            onActiveIndexChange: nil,
            onNext: { _ in },
            onFavAt: nil,
            onDoneAt: nil,
            introContentView: nil,
            summaryContentView: nil,
            introCTAView: nil,
            summaryCTAView: nil,
            isOverlay: false,
            allowLearning: true
        )
    }

    @available(*, deprecated, message: "Use init(..., isOverlay:) and pass isOverlay explicitly. This overload will be removed after call-sites are updated.")
    public init(
        title: String,
        items: [SDStepItem],
        activeIndex: Binding<Int>,
        subtitle: String?,
        learned: Set<Int> = [],
        favorites: Set<Int> = [],
        onTap: @escaping (SDStepItem)->Void = {_ in},
        onPlay: @escaping (SDStepItem)->Void = {_ in},
        onFav: @escaping (SDStepItem)->Void = {_ in},
        onDone: @escaping (SDStepItem)->Void = {_ in},
        onActiveIndexChange: ((Int) -> Void)? = nil,
        onNext: @escaping (SDStepItem) -> Void = { _ in },
        introContentView: (() -> AnyView)? = nil,
        summaryContentView: (() -> AnyView)? = nil,
        introCTAView: (() -> AnyView)? = nil,
        summaryCTAView: (() -> AnyView)? = nil
    ) {
        self.init(
            title: title,
            items: items,
            activeIndex: activeIndex,
            subtitle: subtitle,
            learned: learned,
            favorites: favorites,
            onTap: onTap,
            onPlay: onPlay,
            onFav: onFav,
            onDone: onDone,
            onActiveIndexChange: onActiveIndexChange,
            onNext: onNext,
            onFavAt: nil,
            onDoneAt: nil,
            introContentView: introContentView,
            summaryContentView: summaryContentView,
            introCTAView: introCTAView,
            summaryCTAView: summaryCTAView,
            isOverlay: false,
            allowLearning: true
        )
    }

    public var body: some View {
        // высота слота чуть больше самой высокой карты (лайфхак),
        // чтобы карта оставалась центрированной и не обрезалась, но без лишнего воздуха
        let baseHeight = max(CardDS.Metrics.stepWordCardHeight,
                             CardDS.Metrics.stepLifehackCardHeight)
        let slotHeight = baseHeight + PD.Spacing.block * 2

        return VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                header
            }

            GeometryReader { geo in
                // только карусель, без лишнего внутреннего воздуха
                cardsHStack(geo: geo)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .center)
                    .padding(.top, 2)
                    .padding(.bottom, PD.Spacing.block * 0.5)
            }
            .frame(height: slotHeight + PD.Spacing.block)
        }
    }

    @ViewBuilder
    private func cardsHStack(geo: GeometryProxy) -> some View {
        let baseSize = stepCardSize(for: .word)
        let cardWidth: CGFloat = baseSize.width
        let itemSpacing: CGFloat = 8

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    ForEach(items.indices, id: \.self) { idx in
                        let item = items[idx]
                        let isFav = favorites.contains(idx)
                        let effective = withFavorite(item, fav: isFav)
                        let size = stepCardSize(for: item.visualKind)

                        GeometryReader { itemGeo in
                            let frame = itemGeo.frame(in: .named("carousel"))
                            let viewportCenterX = geo.size.width / 2
                            let centerX = frame.midX
                            let dist = abs(centerX - viewportCenterX)
                            let denom = max(1.0, geo.size.width * 0.65)
                            let norm = min(1.0, dist / denom)
                            let baseScale: CGFloat = 0.86
                            let extraScale: CGFloat = 0.18
                            let scale: CGFloat = baseScale + extraScale * (1.0 - norm)
                            let opacity: CGFloat = 0.55 + 0.45 * (1.0 - norm)
                            let direction: CGFloat = centerX < viewportCenterX ? 1 : -1
                            let maxAngle: CGFloat = 26
                            let angleDeg: Double = Double(maxAngle * norm * direction)

                            carouselItemTransformed(
                                effective: effective,
                                idx: idx,
                                cardWidth: size.width,
                                cardHeight: size.height,
                                scale: scale,
                                opacity: opacity,
                                angleDeg: angleDeg,
                                norm: norm,
                                viewportCenterX: viewportCenterX
                            )
                            .frame(width: size.width, height: size.height)
                            .background(
                                Color.clear.preference(
                                    key: SDStepCarouselCenterPreferenceKey.self,
                                    value: [SDStepCarouselCenterCandidate(index: idx, norm: norm, carouselID: carouselID)]
                                )
                            )
                        }
                        .frame(width: size.width, height: size.height)
                        .id(idx)
                    }
                }
                .padding(.horizontal, max(0, (geo.size.width - cardWidth) / 2))
            }
            .coordinateSpace(name: "carousel")
            .id(isOverlay ? "overlayCarousel" : "stepsCarousel")
            .onAppear {
                guard !didInitialScroll else { return }
                guard items.indices.contains(activeIndex) else { return }
                didInitialScroll = true
                isProgrammaticScroll = true
                DispatchQueue.main.async {
                    proxy.scrollTo(activeIndex, anchor: .center)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isProgrammaticScroll = false
                    }
                }
            }
            .onChange(of: items) { _, _ in
                // New dataset -> re-scroll to bound activeIndex (e.g. skip leading PRO gate)
                guard items.indices.contains(activeIndex) else { return }
                didInitialScroll = true
                isProgrammaticScroll = true
                DispatchQueue.main.async {
                    proxy.scrollTo(activeIndex, anchor: .center)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProgrammaticScroll = false
                    }
                }
            }
            .onChange(of: activeIndex) { _, newValue in
                guard items.indices.contains(newValue) else { return }
                didInitialScroll = true
                isProgrammaticScroll = true
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProgrammaticScroll = false
                    }
                }
            }
            .onPreferenceChange(SDStepCarouselCenterPreferenceKey.self) { candidates in
                guard !candidates.isEmpty else { return }
                guard items.count > 0 else { return }
                guard didInitialScroll else { return }
                guard !isProgrammaticScroll else { return }

                let local = candidates.filter { $0.carouselID == carouselID }
                guard !local.isEmpty else { return }

                if let best = local.min(by: { $0.norm < $1.norm }) {
                    let clamped = min(max(0, best.index), items.count - 1)
                    if clamped != activeIndex {
                        activeIndex = clamped
                        onActiveIndexChange?(clamped)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("УРОК")
                .font(PD.FontToken.caption(12, weight: .medium))
                .foregroundColor(PD.ColorToken.textSecondary.opacity(0.9))

            Spacer(minLength: 8)

            Text(normalizeIntroTitle(title))
                .font(PD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .lineLimit(1)
        }
        .padding(.horizontal, PD.Spacing.screen)
        .padding(.bottom, 2)
    }

    // Normalize header "УРОК: ПРИВЕТСТВИЯ" → "Приветствия"
    private func normalizeIntroTitle(_ header: String) -> String {
        let raw: String = {
            if let colon = header.firstIndex(of: ":") {
                return header[header.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
            let prefix = "УРОК"
            if header.uppercased().hasPrefix(prefix) {
                return header.dropFirst(prefix.count).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            }
            return header
        }()
        return sentenceCase(raw)
    }

    // Lowercase the string and capitalize the first letter (sentence case).
    private func sentenceCase(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lowered = trimmed.lowercased()
        let first = String(lowered.prefix(1)).uppercased()
        let rest = String(lowered.dropFirst())
        return first + rest
    }

    @ViewBuilder
    private func stepCardBody(for effective: SDStepItem, idx: Int) -> some View {
        SDStepCard(
            item: effective,
            onTap: {
                activeIndex = idx
                onActiveIndexChange?(idx)
                onTap(effective)
            },
            onPlay: { onPlay(effective) },
            onToggleFavorite: {
                onFav(effective)
                onFavAt?(idx, effective)
            },
            onMarkLearned: {
                onDone(effective)
                onDoneAt?(idx, effective)
            },
            onNext: {
                let newIndex = min(max(0, idx + 1), items.count - 1)
                if activeIndex != newIndex {
                    activeIndex = newIndex
                    onActiveIndexChange?(newIndex)
                }
                onNext(effective)
            },
            initialLearned: learned.contains(idx),
            introContent: {
                if let v = introContentView { return v() }
                return AnyView(_IntroPlaceholder())
            },
            summaryContent: {
                if let v = summaryContentView { return v() }
                return AnyView(_SummaryPlaceholder())
            },
            introCTA: {
                if let v = introCTAView { return v() }
                return AnyView(SDStepCard.defaultIntroActionBar())
            },
            summaryCTA: {
                if let v = summaryCTAView { return v() }
                return AnyView(SDStepCard.defaultSummaryActionBar())
            },
            isReadOnly: !allowLearning,
            isOverlay: isOverlay,
            isActive: false
        )
    }

    // Card-style depth transform driven by normalized scale/opacity from CardDS preview
    @ViewBuilder
    private func carouselItemTransformed(
        effective: SDStepItem,
        idx: Int,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        scale: CGFloat,
        opacity: CGFloat,
        angleDeg: Double,
        norm: CGFloat,
        viewportCenterX: CGFloat
    ) -> some View {
        let base = AnyView(
            stepCardBody(for: effective, idx: idx)
                .frame(width: cardWidth)
                .frame(minHeight: cardHeight)
        )

        // лайфхаки чуть уменьшаем по базовой шкале, чтобы тень/радиусы
        // не упирались в границы секции и не казались обрезанными
        let kindBaseScale: CGFloat = (effective.visualKind == .tip) ? 0.94 : 1.0
        let finalScale = scale * kindBaseScale

        base
            .scaleEffect(finalScale)
            .rotation3DEffect(
                .degrees(angleDeg),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.8
            )
            .opacity(opacity)
            .shadow(
                color: Color.black.opacity(finalScale >= 1.04 ? 0.26 : 0.10),
                radius: finalScale >= 1.04 ? 7 : 2,
                x: 0,
                y: finalScale >= 1.04 ? 3 : 1
            )
            .zIndex(Double(1.0 - norm))
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func carouselCustomTransformed(
        view: AnyView,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        scale: CGFloat,
        opacity: CGFloat,
        angleDeg: Double,
        norm: CGFloat
    ) -> some View {
        view
            .frame(width: cardWidth)
            .frame(minHeight: cardHeight)
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(angleDeg),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.8
            )
            .opacity(opacity)
            .shadow(
                color: Color.black.opacity(scale >= 1.04 ? 0.26 : 0.10),
                radius: scale >= 1.04 ? 7 : 2,
                x: 0,
                y: scale >= 1.04 ? 3 : 1
            )
            .zIndex(Double(1.0 - norm))
            .contentShape(Rectangle())
    }
}

// Typing dots helper
struct SDTypingDots: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 4) {
            Circle().frame(width: 6, height: 6)
                .opacity(phase.truncatingRemainder(dividingBy: 3) >= 0 ? 1 : 0.35)
            Circle().frame(width: 6, height: 6)
                .opacity(phase.truncatingRemainder(dividingBy: 3) >= 1 ? 1 : 0.35)
            Circle().frame(width: 6, height: 6)
                .opacity(phase.truncatingRemainder(dividingBy: 3) >= 2 ? 1 : 0.35)
        }
        .foregroundColor(PD.ColorToken.textSecondary)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }
}

// MARK: - Hints (TAIKA FM) section for steps
public struct SDHintBubble: View {
    public var mascot: Image?
    public var text: String
    public init(text: String, mascot: Image? = Image("mascot.step")) {
        self.text = text
        self.mascot = mascot
    }
    public var body: some View {
        HStack(alignment: .center, spacing: PD.Spacing.inner) {
            mascot?
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
            Text(text)
                .font(PD.FontToken.body(16, weight: .regular))
                .foregroundColor(PD.ColorToken.text)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PD.Spacing.inner)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                        .stroke(PD.ColorToken.stroke, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        .frame(minHeight: 72)
    }
}

public struct SDStepHintsSection: View {
    public var title: String
    public var subtitle: String?
    public var hints: [String]

    // Animation tuning (unused, but left for compatibility)
    public var typingDuration: TimeInterval = 2.0
    public var showDuration: TimeInterval = 3.2
    public var typingCharInterval: TimeInterval = 0.045

    @State private var idx: Int = 0
    @State private var isTyping: Bool = true
    @State private var shown: String = ""
    @State private var charIndex: Int = 0

    public init(title: String = "", subtitle: String? = nil, hints: [String]) {
        self.title = title
        self.subtitle = subtitle
        self.hints = hints
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 12) {
            heroHeader
            hintBubble
        }
        .padding(.horizontal, PD.Spacing.screen)
        .padding(.bottom, PD.Spacing.block * 2.5)
    }

    @ViewBuilder
    private var heroHeader: some View {
        VStack(spacing: 6) {
            // brand wordmark
            Text("taikA")
                .font(.custom("ONMARK Trial", size: 30))
                .foregroundColor(PD.ColorToken.textSecondary.opacity(0.92))
                .kerning(0.2)

            // lesson title (thin subtitle under brand)
            if !title.isEmpty {
                Text(title)
                    .font(PD.FontToken.body(16, weight: .medium))
                    .foregroundColor(PD.ColorToken.textSecondary.opacity(0.82))
                    .lineLimit(1)
            }

            // meta/description line (e.g., "вступление • 8 карт • итоги")
            if let sub = subtitle, !sub.isEmpty {
                Text(sub)
                    .font(PD.FontToken.caption(12, weight: .regular))
                    .foregroundColor(PD.ColorToken.textSecondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, PD.Spacing.block * 2)
    }

    @ViewBuilder
    private var hintBubble: some View {
        // Compact tools chip instead of typing bubble
        let msg = hints.first ?? ""
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PD.ColorToken.textSecondary)
            Text(msg)
                .font(PD.FontToken.body(15, weight: .regular))
                .foregroundColor(PD.ColorToken.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(PD.ColorToken.stroke, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .frame(maxWidth: 420, alignment: .center)
    }
}
// MARK: - Hero mascot (standalone, above carousels)
public struct SDStepHeroMascot: View {
    private var image: Image
    public var maxHeight: CGFloat
    public init(imageName: String = "mascot.step.main2", maxHeight: CGFloat = 200) {
        self.image = Image(imageName)
        self.maxHeight = maxHeight
    }
    public var body: some View {
        image
            .resizable()
            .renderingMode(.template)
            .foregroundColor(PD.ColorToken.textSecondary.opacity(0.55))
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: maxHeight)
            .padding(.horizontal, PD.Spacing.screen)
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
    }
}


// MARK: - Step Progress Bar (DS)
public struct SDStepProgress: View {
    public var total: Int
    public var activeIndex: Int?
    public var learned: Set<Int>
    public var favorites: Set<Int>
    public var tipIndices: Set<Int>
    public var onTap: ((Int) -> Void)?

    public init(total: Int,
                activeIndex: Int? = nil,
                learned: Set<Int> = [],
                favorites: Set<Int> = [],
                tipIndices: Set<Int> = [],
                onTap: ((Int) -> Void)? = nil) {
        self.total = total
        self.learned = learned
        self.favorites = favorites
        self.tipIndices = tipIndices
        self.onTap = onTap
        // Clamp activeIndex into 0..<total if provided; allow nil (no highlight)
        if let idx = activeIndex, total > 0 {
            self.activeIndex = min(max(0, idx), total - 1)
        } else {
            self.activeIndex = nil
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ПРОГРЕСС")
                .font(PD.FontToken.caption(13, weight: .semibold))
                .foregroundColor(PD.ColorToken.textSecondary)
                .padding(.horizontal, PD.Spacing.screen)

            // Decide: center bar (no scroll) if it fits; otherwise use scrollable bar
            GeometryReader { geo in
                let segmentWidth: CGFloat = 22
                let spacing: CGFloat = 6
                let horizontalPadding = PD.Spacing.screen * 2
                let perRow = 10
                let visibleInRow = min(total, perRow)
                let needScroll = false // Always render as centered multi-row, no horizontal scroll

                if needScroll {
                    scrollableBar(segmentWidth: segmentWidth, spacing: spacing)
                } else {
                    centeredBar(segmentWidth: segmentWidth, spacing: spacing)
                }
            }
            .frame(height: 36 + (total > 10 ? CGFloat((total - 1) / 10) * (36 + 6) : 0))
        }
    }

    // Helper: renders a single segment capsule for the progress bar
    @ViewBuilder
    private func segmentCapsule(index i: Int, width: CGFloat) -> some View {
        let isActive = (activeIndex ?? -1) == i
        let isLearned = learned.contains(i)
        let isFav = favorites.contains(i)

        SDStepProgressSegment(
            width: width,
            isActive: isActive,
            isLearned: isLearned,
            isFavorite: isFav,
            index: i,
            onTap: onTap
        )
        .id(i)
    }

    @ViewBuilder
    private func centeredBar(segmentWidth: CGFloat, spacing: CGFloat) -> some View {
        let perRow = 10
        let rows: [Range<Int>] = stride(from: 0, to: total, by: perRow).map { start in
            let end = min(start + perRow, total)
            return start..<end
        }
        VStack(alignment: .center, spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, range in
                HStack(spacing: spacing) {
                    ForEach(range, id: \.self) { i in
                        segmentCapsule(index: i, width: segmentWidth)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, PD.Spacing.screen)
        .frame(height: 36 + (rows.count > 1 ? CGFloat(rows.count - 1) * (36 + spacing) : 0))
    }

    @ViewBuilder
    private func scrollableBar(segmentWidth: CGFloat, spacing: CGFloat) -> some View {
        // Always use centered multi-row layout, no horizontal scroll
        centeredBar(segmentWidth: segmentWidth, spacing: spacing)
    }
}


extension SDStepProgress {
    @ViewBuilder
    fileprivate func progressSegments(width: CGFloat) -> some View {
        Group {
            ForEach(0..<total, id: \.self) { i in
                segmentCapsule(index: i, width: width)
            }
        }
    }
}

#if DEBUG
struct SDStep_Previews: PreviewProvider {
    static let mockItems: [SDStepItem] = [
        .init(kind: .word, titleRU: "Кофе", subtitleTH: "กาแฟ (kaa-fae)", phonetic: "ка-фа́э"),
        .init(kind: .word, titleRU: "Вода", subtitleTH: "น้ำ (náam)", phonetic: "на́м"),
        .init(kind: .phrase, titleRU: "Большое спасибо", subtitleTH: "ขอบคุณมาก (kh̄xbkhuṇ mâak)", phonetic: "коп-ку́н ма́к"),
        .init(kind: .phrase, titleRU: "Доброе утро", subtitleTH: "สวัสดีตอนเช้า (s̄wạs̄dī txn chêa)", phonetic: "са-ва́т-ди тон ча́о"),
        .init(kind: .tip, titleRU: "Ассоциация", subtitleTH: "Свяжи \"коп-ку́н\" с благодарностью — говори после помощи.", phonetic: ""),
        .init(kind: .word, titleRU: "Счёт", subtitleTH: "บิล (bin)", phonetic: "бин"),
        .init(kind: .word, titleRU: "Чек", subtitleTH: "เช็ค (chék)", phonetic: "чек"),
        .init(kind: .phrase, titleRU: "Где туалет?", subtitleTH: "ห้องน้ำอยู่ไหน (h̄̂xngn̂ả yùu năi)", phonetic: "хонг-на́м ю́ най?"),
        .init(kind: .phrase, titleRU: "Можно меню?", subtitleTH: "ขอเมนูได้ไหม (kȟx menû dị̂ h̄ım)", phonetic: "хо́ ме-ну́ дай май?"),
        .init(kind: .tip, titleRU: "Повторение", subtitleTH: "Повтори вслух 3 раза утром и вечером — лучше закрепится.", phonetic: "")
    ]

    static var previews: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()

            VStack(spacing: PD.Spacing.block * 2) {
                TaikaFMBubbleTyping(
                    messages: TaikaFMData.shared.messages(for: .step),
                    reactions: TaikaFMData.shared.reactionGroups(for: .step),
                    repeats: false
                )
                .padding(.horizontal, PD.Spacing.screen)

                SDStepCarousel(
                    title: "УРОК: ПРИВЕТСТВИЯ",
                    items: mockItems,
                    activeIndex: .constant(0),
                    subtitle: "вступление • 8 карт • итоги",
                    isOverlay: false
                )
                .padding(.top, PD.Spacing.block)

                SDStepProgress(
                    total: mockItems.count,
                    activeIndex: 0,
                    learned: Set([0, 1, 4]),
                    favorites: Set([2, 5])
                )
                .padding(.top, 4)

                Spacer(minLength: PD.Spacing.block * 2)
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif


    // Helper to combine isFavorite state for effective display
    private func withFavorite(_ item: SDStepItem, fav: Bool) -> SDStepItem {
        var c = item
        c.isFavorite = fav || item.isFavorite
        return c
    }


