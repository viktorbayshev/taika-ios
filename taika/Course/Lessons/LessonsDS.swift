// Fallback DS tokens for Lessons (bridging to CourseDS/CardDS values)
// Carousel tokens (single source of truth; mirror CourseDS)
fileprivate let CDCarouselPeekMin: CGFloat = 22
fileprivate let CDDepthYOffsetMax: CGFloat = 16
// Unified horizontal spacing between carousel cards (mirror CourseDS)
fileprivate let CDCarouselContainerHeight: CGFloat = CardDS.Metrics.courseCardHeight + CDDepthYOffsetMax * 2 + 20

import SwiftUI

// MARK: - Namespace
public enum LS {
    public struct Item: Identifiable, Hashable {
        public let id: String
        public let index: Int
        public let title: String
        public let subtitle: String?
        public let durationMinutes: Int
        public let isPro: Bool
        public let status: Status
        public let tags: [String]
        public let progress: Double?
        public let cardCount: Int?
        public let favoriteCount: Int
        public init(id: String = UUID().uuidString,
                    index: Int,
                    title: String,
                    subtitle: String? = nil,
                    durationMinutes: Int,
                    isPro: Bool,
                    status: Status,
                    tags: [String] = [],
                    progress: Double? = nil,
                    cardCount: Int? = nil,
                    favoriteCount: Int = 0) {
            self.id = id
            self.index = index
            self.title = title
            self.subtitle = subtitle
            self.durationMinutes = durationMinutes
            self.isPro = isPro
            self.status = status
            self.tags = tags
            self.progress = progress
            self.cardCount = cardCount
            self.favoriteCount = favoriteCount
        }
    }

    public enum Status: String, Hashable {
        case locked, inProgress, completed
    }
}

// MARK: - Header Section (no title; isolates the header as a DS section)
public struct LSHeaderSection: View {
    private let title: String
    private let subtitle: String
    private let ctaText: String?
    private let onCTA: (() -> Void)?
    private let progressCompleted: Int?
    private let progressTotal: Int?
    private let lessonsCount: Int?
    private let chipText: String?
    private let progressSlots: [Double]?
    private let bottomReserve: CGFloat?
    private let selectedIndex: Int?
    private let onTapSlot: ((Int) -> Void)?

    /// Optional bottom gap override. If nil, uses Theme.Layout.sectionGap.
    private let bottomGap: CGFloat?

    public init(
        title: String,
        subtitle: String,
        ctaText: String? = nil,
        onCTA: (() -> Void)? = nil,
        progressCompleted: Int? = nil,
        progressTotal: Int? = nil,
        lessonsCount: Int? = nil,
        chipText: String? = nil,
        progressSlots: [Double]? = nil,
        bottomReserve: CGFloat? = nil,
        selectedIndex: Int? = nil,
        onTapSlot: ((Int) -> Void)? = nil,
        bottomGap: CGFloat? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.onCTA = onCTA
        self.progressCompleted = progressCompleted
        self.progressTotal = progressTotal
        self.lessonsCount = lessonsCount
        self.chipText = chipText
        self.progressSlots = progressSlots
        self.bottomReserve = bottomReserve
        self.selectedIndex = selectedIndex
        self.onTapSlot = onTapSlot
        self.bottomGap = bottomGap
    }

    public var body: some View {
        let gap = bottomGap ?? Theme.Layout.sectionGap
        return LSLessonHeader(
            title: title,
            subtitle: subtitle,
            ctaText: ctaText,
            onCTA: onCTA,
            progressCompleted: progressCompleted,
            progressTotal: progressTotal,
            lessonsCount: lessonsCount,
            chipText: chipText,
            progressSlots: progressSlots,
            bottomReserve: bottomReserve,
            selectedIndex: selectedIndex,
            onTapSlot: onTapSlot
        )
        .lsSectionPadding(bottom: gap)
    }
}

// MARK: - Hometask namespace (mock)
public enum HT {
    public struct Item: Identifiable, Hashable {
        public let id: String
        public let index: Int
        public let title: String
        public let subtitle: String?
        public let durationMinutes: Int?
        public let isLocked: Bool
        public init(id: String = UUID().uuidString,
                    index: Int,
                    title: String,
                    subtitle: String? = nil,
                    durationMinutes: Int? = nil,
                    isLocked: Bool = false) {
            self.id = id
            self.index = index
            self.title = title
            self.subtitle = subtitle
            self.durationMinutes = durationMinutes
            self.isLocked = isLocked
        }
    }
}

// MARK: - Header (unified with app header)
public struct LSLessonHeader: View {
    let title: String
    let subtitle: String
    let ctaText: String?
    let onCTA: (() -> Void)?
    let progressCompleted: Int?
    let progressTotal: Int?
    let lessonsCount: Int?
    let chipText: String?
    let progressSlots: [Double]?
    let bottomReserve: CGFloat?
    public var selectedIndex: Int? = nil
    public var onTapSlot: ((Int) -> Void)? = nil

    public init(
        title: String,
        subtitle: String,
        ctaText: String? = nil,
        onCTA: (() -> Void)? = nil,
        progressCompleted: Int? = nil,
        progressTotal: Int? = nil,
        lessonsCount: Int? = nil,
        chipText: String? = nil,
        progressSlots: [Double]? = nil,
        bottomReserve: CGFloat? = nil,
        selectedIndex: Int? = nil,
        onTapSlot: ((Int) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.onCTA = onCTA
        self.progressCompleted = progressCompleted
        self.progressTotal = progressTotal
        self.lessonsCount = lessonsCount
        self.chipText = chipText
        self.progressSlots = progressSlots
        self.bottomReserve = bottomReserve
        self.selectedIndex = selectedIndex
        self.onTapSlot = onTapSlot
    }

    // Use lessonsCount if provided, else fallback to progressTotal for compatibility
    private var totalLessons: Int? { lessonsCount ?? progressTotal }

    // [[...]] segments are tinted with accent color
    private func accentText(_ raw: String) -> Text {
        var result = Text("")
        var buffer = ""
        var isAccent = false
        for ch in raw {
            if ch == "[" {
                if buffer.hasSuffix("[") {
                    // start accent
                    buffer.removeLast()
                    if !buffer.isEmpty { result = result + Text(buffer) }
                    buffer = ""
                    isAccent = true
                } else {
                    buffer.append(ch)
                }
            } else if ch == "]" {
                if buffer.hasSuffix("]") {
                    // end accent
                    buffer.removeLast()
                    if !buffer.isEmpty {
                        result = result + Text(buffer).foregroundStyle(ThemeManager.shared.currentAccentFill)
                    }
                    buffer = ""
                    isAccent = false
                } else {
                    buffer.append(ch)
                }
            } else {
                buffer.append(ch)
            }
        }
        if !buffer.isEmpty {
            if isAccent {
                result = result + Text(buffer).foregroundStyle(ThemeManager.shared.currentAccentFill)
            } else {
                result = result + Text(buffer)
            }
        }
        return result
    }



    // Progress strip for lessons: completed, active, upcoming
    private struct LSProgressStrip: View {
        let done: Int
        let total: Int
        /// Fractional progress **inside текущего урока** (0...1).
        /// По умолчанию 0, чтобы старые вызовы не ломались.
        let currentFraction: Double
        let progressSlots: [Double]?

        init(done: Int, total: Int, currentFraction: Double = 0, progressSlots: [Double]? = nil) {
            self.done = done
            self.total = total
            self.currentFraction = currentFraction
            self.progressSlots = progressSlots
        }

        var body: some View {
            let completed = max(0, done)
            let cappedTotal = max(1, total)
            let maxSlots = 10

            // Нормализуем долю текущего урока (0...1). При старых вызовах = 0.
            let clampedFraction: Double = max(0.0, min(1.0, currentFraction))

            // How many whole slots are filled

            GeometryReader { geo in
                let blockW = geo.size.width
                let blockH = geo.size.height
                let outerH: CGFloat = 6
                let outerW: CGFloat = 10
                let innerW = max(0, blockW - outerW * 2)
                let innerH = max(0, blockH - outerH * 2)
                let spacing: CGFloat = 10
                let targetHFactor: CGFloat = 0.90
                let minSide: CGFloat = 32
                let maxSide: CGFloat = 44
                let baseSide = max(minSide, min(maxSide, floor(innerH * targetHFactor)))
                // Per-slot fractions provided from manager (0...1 per slot)
                let fractions: [Double] = self.progressSlots ?? []
                let visibleSlots = fractions.isEmpty ? self.total : fractions.count
                // Active index is a purely visual highlight, not tied to fill
                let activeIndex = -1 // no highlight in fallback strip
                let sideByWidth = visibleSlots > 0 ? (innerW - spacing * CGFloat(visibleSlots - 1)) / CGFloat(visibleSlots) : 0
                let side = floor(min(baseSide, sideByWidth))
                let contentWidth = side * CGFloat(visibleSlots) + spacing * CGFloat(visibleSlots - 1)
                let sideInset = max(0, floor((innerW - contentWidth) / 2))

                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: spacing) {
                        ForEach(0..<visibleSlots, id: \.self) { i in
                            let fillAmount = fractions.indices.contains(i) ? min(1, max(0, fractions[i])) : 0
                            let isCompleted = fillAmount >= 0.999
                            let isActive = (i == activeIndex)
                            let base = RoundedRectangle(cornerRadius: 12, style: .continuous)

                            ZStack(alignment: .bottom) {
                                base.fill(Color.white.opacity(0.10))
                                if isCompleted {
                                    base.fill(ThemeManager.shared.currentAccentFill)
                                } else if fillAmount > 0 {
                                    GeometryReader { g in
                                        base
                                            .fill(ThemeManager.shared.currentAccentFill)
                                            .frame(height: max(1, g.size.height * CGFloat(fillAmount)))
                                            .frame(maxWidth: .infinity, alignment: .bottom)
                                    }
                                    .clipShape(base)
                                }
                            }
                            .shadow(color: isActive ? Color.black.opacity(0.20) : .clear, radius: isActive ? 3 : 0, x: 0, y: isActive ? 1 : 0)
                            .overlay(
                                Group {
                                    if isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.black))
                                            .foregroundStyle(Color.black.opacity(0.9))
                                            .shadow(color: Color.white.opacity(0.25), radius: 1, x: 0, y: 0)
                                    } else {
                                        Text("\(i + 1)")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(
                                                isActive ? Color.white.opacity(0.98) :
                                                Color.white.opacity(0.45)
                                            )
                                            .minimumScaleFactor(0.8)
                                    }
                                }
                            )
                            .frame(width: side, height: max(44, side * 1.28))
                        }
                    }
                    .padding(.horizontal, outerW + sideInset)
                    .padding(.vertical, outerH)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 56)
        }
    }

    // Fixed card min height for consistent layout (balanced paddings/air)
    private let minHeight: CGFloat = 156

    // Background with a small notebook-like notch in the top-left corner
    @ViewBuilder
    private func cardBackgroundWithNotch() -> some View {
        ZStack(alignment: .topLeading) {
            let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)

            // use unified card surface from ThemeDS (same as other cards)
            Theme.Surfaces.card(round)

            // notch (punch a hole)
            Circle()
                .frame(width: 18, height: 18)
                .offset(x: 12, y: 12)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    public var body: some View {
        // unified vertical metrics
        let sideInsetH: CGFloat = Theme.Layout.sectionInner
        let edgeInsetTop: CGFloat = Theme.Layout.pageTopAfterHeader
        // allow caller to reserve extra bottom space when needed
        let edgeInsetBottom: CGFloat = (bottomReserve ?? 18)
        let titleSubtitleSpacing: CGFloat = 10
        let subtitleProgressSpacing: CGFloat = 14

        // Inner content (title + subtitle + progress)
        let content = VStack(alignment: .center, spacing: 0) {
            // Title & subtitle
            VStack(alignment: .center, spacing: titleSubtitleSpacing) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)

                accentText(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineSpacing(2)
                    .shadow(color: Color.black.opacity(0.6), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // space between subtitle and progress row
            Spacer(minLength: subtitleProgressSpacing).frame(height: subtitleProgressSpacing)

            // Progress row
            Group {
                if let slots = progressSlots, !slots.isEmpty {
                    LSProgressSlotsStrip(slots: slots, selectedIndex: selectedIndex, onTapSlot: onTapSlot)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let done = progressCompleted, let ttl = totalLessons, ttl > 0 {
                    LSProgressStrip(done: done, total: ttl, progressSlots: progressSlots)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.top, 8)
        }

        // Card with perfectly balanced vertical padding (same top & bottom)
        return ZStack {
            cardBackgroundWithNotch()
            VStack(spacing: 0) {
                Spacer(minLength: edgeInsetTop)
                content
                    .padding(.horizontal, sideInsetH)
                Spacer(minLength: edgeInsetBottom)
            }
        }
        .frame(minHeight: minHeight, alignment: .center)
        .contentShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Progress strip adapter (done/total -> slot fractions)
public struct LSProgressStrip: View {
    let done: Int
    let total: Int
    // if caller already has detailed slot fractions – forward them; otherwise we compute from done/total
    var progressSlots: [Double]?

    public init(done: Int, total: Int, progressSlots: [Double]? = nil) {
        self.done = max(0, done)
        self.total = max(1, total)
        self.progressSlots = progressSlots
    }

    private func makeSlots() -> [Double] {
        // If explicit slots are provided (e.g., from ProgressManager) – use them as-is
        if let slots = progressSlots, !slots.isEmpty { return slots.map { min(1.0, max(0.0, $0)) } }

        // Otherwise convert done/total into N slot fractions, where N = total (clamped 1...20)
        let n = max(1, min(20, total))
        let progress = min(1.0, max(0.0, Double(done) / Double(total)))
        let exact = progress * Double(n)
        let full = Int(floor(exact))
        let partial = max(0.0, min(1.0, exact - Double(full)))

        var result = Array(repeating: 0.0, count: n)
        for i in 0..<min(full, n) { result[i] = 1.0 }
        if full < n { result[full] = partial }
        return result
    }

    public var body: some View {
        LSProgressSlotsStrip(slots: makeSlots(), selectedIndex: nil, onTapSlot: nil)
    }
}

// MARK: - Progress strip (per-slot fractions, 0…1 with partial fill)
public struct LSProgressSlotsStrip: View {
    let slots: [Double]
    let selectedIndex: Int?
    let onTapSlot: ((Int) -> Void)?

    public init(slots: [Double], selectedIndex: Int? = nil, onTapSlot: ((Int) -> Void)? = nil) {
        self.slots = slots
        self.selectedIndex = selectedIndex
        self.onTapSlot = onTapSlot
    }

    private var accentFill: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

// New MiniSlot implementation for per-slot rendering
    private struct MiniSlot: View {
        let fill: Double
        let index: Int
        let isActive: Bool
        let accentFill: AnyShapeStyle
        let onTap: (() -> Void)?

        var body: some View {
            let base = RoundedRectangle(cornerRadius: 12, style: .continuous)
            GeometryReader { geo in
                ZStack {
                    // Unified, lighter card background layer
                    base
                        .fill(Color.black.opacity(0.15))
                    // Apply glass tint only when the slot is fully completed
                    if fill >= 0.999 {
                        CD.GradientToken.pro
                            .blur(radius: 2.5)
                            .opacity(0.55)
                            .mask(base)
                    }
                    // Subtle white highlight stroke for shimmer
                    base
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    // Subtle white gradient overlay for gentle light
                    base
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    // Bottom-up fill rectangle clipped to the same rounded shape
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(accentFill)
                            .frame(height: geo.size.height * CGFloat(max(0.0, min(1.0, fill))))
                            .clipped()
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(base)

                    // Centered label (always perfectly centered inside the slot)
                    ZStack {
                        // When the slot is fully filled, show a dark checkmark
                        if fill >= 0.999 {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.black.opacity(0.9))
                        } else {
                            // If the bottom-up fill covers the vertical center of the slot,
                            // use dark text for contrast; otherwise keep light text.
                            let centerCovered = fill >= 0.55
                            Text("\(index + 1)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(
                                    centerCovered
                                    ? Color.black.opacity(0.9)
                                    : (isActive ? Color.white : Color.white.opacity(0.45))
                                )
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .contentShape(base)
            .onTapGesture { onTap?() }
            .allowsHitTesting(true)
            .animation(.linear(duration: 0.16), value: fill)
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let total = max(1, slots.count)
            let spacing: CGFloat = 10
            let outerH: CGFloat = 6
            let outerW: CGFloat = 10
            let innerW = max(0, geo.size.width - outerW * 2)
            let innerH = max(0, geo.size.height - outerH * 2)
            let targetHFactor: CGFloat = 0.90
            let minSide: CGFloat = 32
            let maxSide: CGFloat = 44
            let baseSide = max(minSide, min(maxSide, floor(innerH * targetHFactor)))
            let sideByWidth = (innerW - spacing * CGFloat(total - 1)) / CGFloat(total)
            let side = floor(min(baseSide, sideByWidth))
            let contentWidth = side * CGFloat(total) + spacing * CGFloat(total - 1)
            let sideInset = max(0, floor((innerW - contentWidth) / 2))

            HStack { Spacer(minLength: 0)
                HStack(spacing: spacing) {
                    ForEach(Array(slots.enumerated()), id: \.offset) { idx, raw in
                        MiniSlot(
                            fill: min(1.0, max(0.0, raw)),
                            index: idx,
                            isActive: (selectedIndex == idx),
                            accentFill: accentFill,
                            onTap: { onTapSlot?(idx) }
                        )
                        .frame(width: side, height: 44)
                    }
                }
                .padding(.horizontal, outerW + sideInset)
                .padding(.vertical, outerH)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 56)
    }
}

// MARK: - Unified external spacing for DS sections
public extension View {
    /// Standard container spacing for DS sections: horizontal screen inset + bottom rhythm.
    /// Use this in View-level integration so every section is isolated and doesn't overlap neighbors.
    func lsSectionPadding() -> some View {
        self.lsSectionPadding(bottom: Theme.Layout.sectionGap)
    }

    /// Same as `lsSectionPadding()`, but allows overriding the bottom gap.
    func lsSectionPadding(bottom: CGFloat) -> some View {
        self
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.bottom, bottom)
    }
}

// MARK: - Lessons Count Mono Chip (top-right tag)
public struct LSLessonsMonoChip: View {
    let count: Int
    public init(_ count: Int) { self.count = count }
    public var body: some View {
        return Text("\(count) карточек")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(ThemeManager.shared.currentAccentFill)
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(Color.black.opacity(0.85))
    }
}

public struct LSMonoChip: View {
    let text: String
    public init(text: String) { self.text = text }
    public var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(PD.ColorToken.accent.opacity(0.16))
        )
        .overlay(
            Capsule().stroke(PD.ColorToken.accent.opacity(0.28), lineWidth: 1)
        )
        // Remove .foregroundStyle(accent) here so gradient applies to text only
    }
}

// MARK: - Marquee Section (header + mascot outside + fixed-height typing bubble)
public struct LSMarqueeSection: View {
    let title: String
    let messages: [String]
    let typingSpeed: Double
    let maxLines: Int
    let bubbleHeight: CGFloat

    @State private var currentIndex: Int = 0
    @State private var shownText: String = ""
    @State private var dotsPhase: Int = 0
    private enum Mode { case typing, thinking }
    @State private var mode: Mode = .typing

    private var longestMessage: String { messages.max(by: { $0.count < $1.count }) ?? "" }
    private var textHeight: CGFloat {
        // match .subheadline line height (~20pt) to align with card subtitles
        return CGFloat(max(1, maxLines)) * 20.0
    }

    public init(title: String = "taika fm",
                messages: [String],
                typingSpeed: Double = 0.045,
                maxLines: Int = 2,
                bubbleHeight: CGFloat = 64) {
        self.title = title
        self.messages = messages
        self.typingSpeed = typingSpeed
        self.maxLines = maxLines
        self.bubbleHeight = bubbleHeight
    }

    public var body: some View {
        let configMessages = TaikaFMData.shared.messages(for: .lessons)
        let configReactions = TaikaFMData.shared.reactionGroups(for: .lessons)

        let effectiveMessages = messages.isEmpty ? configMessages : messages
        let effectiveReactions = configReactions

        return VStack(alignment: .leading, spacing: 8) {
            LSSectionTitle(title)

            TaikaFMBubbleTyping(
                messages: effectiveMessages,
                reactions: effectiveReactions,
                repeats: false
            )
        }
    }
}

// MARK: - Toolbar Back Button
public struct LSBackToCoursesButton: View {
    public var title: String
    public var onTap: () -> Void

    public init(title: String = "Назад к курсам", onTap: @escaping () -> Void) {
        self.title = title
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(PD.FontToken.body(16, weight: .semibold))
            }
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("backToCoursesButton")
    }
}
// MARK: - Toolbar helper (reuse the same back button in toolbars)
public struct LSBackToolbarModifier: ViewModifier {
    public let title: String
    public let onTap: () -> Void

    public func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { // iOS 17+
                    LSBackToCoursesButton(title: title, onTap: onTap)
                }
            }
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

public extension View {
    /// Attach a standard "Назад к курсам" button in the leading toolbar, same look as in Step.
    func lsBackToCoursesToolbar(title: String = "Назад к курсам", onTap: @escaping () -> Void) -> some View {
        self.modifier(LSBackToolbarModifier(title: title, onTap: onTap))
    }
}
// MARK: - CTA Badge (icon-only circular CTA, gradient, dark icon, accessible)
public struct LSLessonCTABadge: View {
    let status: LS.Status
    public init(status: LS.Status) { self.status = status }
    private var titleIcon: (String, String) {
        switch status {
        case .locked: return ("начать", "play.fill")
        case .inProgress: return ("сбросить", "backward.end.fill")
        case .completed: return ("повторить", "arrow.clockwise")
        }
    }
    public var body: some View {
        let (title, icon) = titleIcon
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.9))
            .accessibilityLabel(Text(title.capitalized))
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - PRO Badge (mono, compact)
public struct LSLessonProBadge: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                ThemeManager.shared.currentAccentFill
            ).opacity(0.85)
        )
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .foregroundColor(Color.black.opacity(0.85))
    }
}

// MARK: - Start Badge (CTA for free)
public struct LSLessonStartBadge: View {
    let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .kerning(0.3)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.16)))
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
            .foregroundStyle(Color.white.opacity(0.95))
    }
}

// MARK: - Cards Count Chip (bottom-right accent)
public struct LSLessonCountChip: View {
    let count: Int
    public init(_ count: Int) { self.count = count }
    private var title: String { "\(count) карточек" }
    public var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .kerning(0.3)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(ThemeManager.shared.currentAccentFill).opacity(0.65)
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(Color.white)
    }
}

// MARK: - Skill Tag (bottom-right)
public struct LSLessonSkillTag: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            .foregroundStyle(Color.white.opacity(0.95))
    }
}

// Simple Russian pluralization for lessons
fileprivate func lsRuPlural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let n10 = n % 10
    let n100 = n % 100
    if n10 == 1 && n100 != 11 { return one }
    if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
    return many
}

// MARK: - Inline Meta (icon + text, no pill)
public struct LSInlineMeta: View {
    let icon: String
    let text: String
    public init(icon: String, text: String) { self.icon = icon; self.text = text }
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(Color.white.opacity(0.90))
    }
}

// MARK: - Info Pills (duration / pro)
public struct LSLessonInfoPills: View {
    let minutes: Int
    let cardCount: Int?
    let compact: Bool
    public init(minutes: Int, cardCount: Int?, compact: Bool = false) {
        self.minutes = minutes
        self.cardCount = cardCount
        self.compact = compact
    }
    public var body: some View {
        HStack(spacing: 10) {
            LSInlineMeta(icon: "clock", text: "≈ \(minutes) мин")
            Text("•").foregroundStyle(Color.white.opacity(0.6))
            if let c = cardCount, c > 0 {
                LSInlineMeta(icon: "book.closed", text: "\(c) \(lsRuPlural(c, "карточка", "карточки", "карточек"))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Info Pills (vertical, for right rail)
public struct LSLessonInfoPillsVertical: View {
    let minutes: Int
    let cardCount: Int?
    public init(minutes: Int, cardCount: Int?) {
        self.minutes = minutes
        self.cardCount = cardCount
    }
    public var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            LSInlineMeta(icon: "clock", text: "≈ \(minutes) мин")
            if let c = cardCount, c > 0 {
                LSInlineMeta(icon: "book.closed", text: "\(c) \(lsRuPlural(c, "урок", "урока", "уроков"))")
            }
        }
    }
}

// MARK: - Assistant Card (Taika chat teaser)
public struct LSLessonAssistantCard: View {
    let avatar: Image
    let messages: [String]
    let typingSpeed: Double
    let maxLines: Int
    let textHeight: CGFloat
    let onTap: () -> Void

    @State private var currentIndex: Int = 0
    @State private var shownText: String = ""
    @State private var isTyping: Bool = true
    @State private var dotsPhase: Int = 0
    private enum Mode { case typing, thinking }
    @State private var mode: Mode = .typing
    private var longestMessage: String { messages.max(by: { $0.count < $1.count }) ?? "" }

    public init(avatar: Image = Image("mascot.profile"),
                messages: [String],
                typingSpeed: Double = 0.045,
                maxLines: Int = 2,
                onTap: @escaping () -> Void) {
        self.avatar = avatar
        self.messages = messages
        self.typingSpeed = typingSpeed
        self.maxLines = maxLines
        // Approximate fixed height for body text lines (iOS body ≈ 17pt line-height). Add headroom.
        self.textHeight = CGFloat(max(1, maxLines)) * 20.0
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // avatar
                avatar
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    // reserve height by laying out the longest message invisibly
                    ZStack(alignment: .topLeading) {
                        Text(longestMessage)
                            .font(.subheadline)
                            .lineLimit(maxLines)
                            .foregroundStyle(.clear)
                            .frame(height: textHeight, alignment: .topLeading)

                        // message or thinking dots (messenger-style)
                        Group {
                            if mode == .typing {
                                Text(shownText)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(maxLines)
                                    .animation(.none, value: shownText)
                                    .frame(height: textHeight, alignment: .topLeading)
                            } else {
                                // thinking between messages — align to avatar center line
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 4) {
                                        ForEach(0..<3, id: \.self) { i in
                                            Circle()
                                                .fill(Color.white.opacity(dotsPhase == i ? 0.9 : 0.35))
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .frame(height: 12)
                                    .padding(.top, 12) // 36pt avatar center minus 12pt dots height ≈ 12pt
                                    Spacer(minLength: 0)
                                }
                                .frame(height: textHeight, alignment: .topLeading)
                                .accessibilityLabel("taika печатает")
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                    .fill(PD.ColorToken.card)
            )
            // No border – matches unified APP DS visuals
        }
        .buttonStyle(.plain)
        .onAppear {
            startDotsTimer()
            startTyping()
        }
    }

    private func startDotsTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            dotsPhase = (dotsPhase + 1) % 3
        }
    }

    private func startTyping() {
        guard messages.indices.contains(currentIndex) else { return }
        shownText = ""
        isTyping = true
        mode = .typing
        let text = messages[currentIndex]
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: typingSpeed, repeats: true) { t in
            if i < text.count {
                let idx = text.index(text.startIndex, offsetBy: i)
                shownText.append(text[idx])
                i += 1
            } else {
                t.invalidate()
                // reading pause based on length (clamped)
                let pause = min(3.0, max(1.2, 0.03 * Double(text.count)))
                DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
                    // show thinking dots between messages
                    isTyping = false
                    mode = .thinking
                    dotsPhase = 0
                    let thinking = 1.1
                    DispatchQueue.main.asyncAfter(deadline: .now() + thinking) {
                        currentIndex = (currentIndex + 1) % max(1, messages.count)
                        startTyping()
                    }
                }
            }
        }
        RunLoop.current.add(timer, forMode: .common)
    }
}

// MARK: - Primary CTA Pill (text + icon)
public struct LSLessonCTAPill: View {
    let status: LS.Status
    let fullWidth: Bool
    public init(status: LS.Status, fullWidth: Bool = false) { self.status = status; self.fullWidth = fullWidth }
    private var config: (title: String, icon: String) {
        switch status {
        case .locked:    return ("начать", "play.fill")
        case .inProgress:return ("продолжить", "pause.fill")
        case .completed: return ("повторить", "arrow.clockwise")
        }
    }
    public var body: some View {
        let c = config
        HStack(spacing: 6) {
            Image(systemName: c.icon)
                .font(.caption2.weight(.semibold))
            Text(c.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.14))
        )
        // No chip stroke – matches unified APP DS visuals
        .foregroundStyle(Color.white.opacity(0.95))
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 36)
        .contentShape(Rectangle())
    }
}

// MARK: - Lesson Row
public struct LSLessonRow: View {
    let item: LS.Item
    let onTap: (LS.Item) -> Void

    public init(item: LS.Item, onTap: @escaping (LS.Item) -> Void) {
        self.item = item
        self.onTap = onTap
    }

    public var body: some View {
        // Map to CardDS props
        let statusKind: AppStatusKind = {
            switch item.status {
            case .locked:      return .new
            case .inProgress:  return .inProgress
            case .completed:   return .completed
            }
        }()
        let primaryCTA: AppCTAType = {
            switch item.status {
            case .locked:      return .start
            case .inProgress:  return .resume
            case .completed:   return .reinforce
            }
        }()
        let durationText = "≈ \(item.durationMinutes) мин"

        return CourseLessonCard(
            title: item.title,
            subtitle: item.subtitle,
            lessonsCount: item.cardCount,
            durationText: durationText,
            statusKind: statusKind,
            isPro: item.isPro,
            tags: item.tags,
            sectionChrome: .seps,
            primaryCTA: primaryCTA,
            scale: .s,
            showFavorite: true,
            showConsole: true,
            onPrimaryTap: {
                LSLessonActivity.mark(item.id)
                onTap(item)
            },
            completionFraction: (item.status == .completed ? 1.0 : nil),
            favoriteCount: item.favoriteCount
        )
    }
}

// MARK: - Lesson List (Section)
public struct LSLessonList: View {
    let title: String
    let items: [LS.Item]
    let onTap: (LS.Item) -> Void

    public init(_ title: String, items: [LS.Item], onTap: @escaping (LS.Item) -> Void) {
        self.title = title
        self.items = items
        self.onTap = onTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .kerning(0.8)
                .foregroundStyle(.secondary)

            VStack(spacing: 14) {
                ForEach(items) { it in
                    LSLessonRow(item: it, onTap: onTap)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Card Role (learnable vs supporting)

public enum LSLessonActivity {
    private static let key = "LSLessonActivity.lastActiveLessonId"
    public static func mark(_ id: String) { UserDefaults.standard.set(id, forKey: key) }
    public static func last() -> String? { UserDefaults.standard.string(forKey: key) }
}
public enum LSCardRole {
    case learnable
    case support // e.g., лайфхаки/сцены — не влияют на прогресс, только избранное
}

// MARK: - Lesson Card (vertical for carousel)
public struct LSLessonCardV: View {
    let item: LS.Item
    let role: LSCardRole
    let onTap: (LS.Item) -> Void
    let onFavorite: (() -> Void)?
    let favoriteCount: Int
    let onConsole: (() -> Void)?
    @AppStorage("LSLessonActivity.lastActiveLessonId") private var lastActiveLessonId: String = ""

    public init(item: LS.Item,
                role: LSCardRole = .learnable,
                onTap: @escaping (LS.Item) -> Void,
                onFavorite: (() -> Void)? = nil,
                favoriteCount: Int = 0,
                onConsole: (() -> Void)? = nil) {
        self.item = item
        self.role = role
        self.onTap = onTap
        self.onFavorite = onFavorite
        self.favoriteCount = favoriteCount
        self.onConsole = onConsole
    }

    // MARK: - Extracted subviews to help the type-checker
    // Precomputed gradient for heart/badge
    private var heartGrad: LinearGradient {
        LinearGradient(colors: [
            Color(red:0.98, green:0.52, blue:0.80),
            Color(red:0.91, green:0.62, blue:0.98)
        ], startPoint: .leading, endPoint: .trailing)
    }


    @ViewBuilder
    private var heartBadge: some View {
        if favoriteCount > 0 {
            Text("\(favoriteCount)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(heartGrad.opacity(0.95))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .offset(x: 4, y: -4) // keep badge inside the button bounds
                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                .transition(.scale.combined(with: .opacity))
        }
    }


    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            AppStatusChip(kind: {
                switch item.status {
                case .locked:      return .new
                case .inProgress:  return .inProgress
                case .completed:   return .completed
                }
            }())
            Spacer(minLength: 8)
            if item.isPro { LSLessonProBadge() }
        }
        .padding(.top, 6)
    }

    private var centerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.system(size: 19, weight: .semibold))
                .kerning(0.15)
                .foregroundStyle(Color.white.opacity(0.90))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1.2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LSLessonInfoPills(minutes: item.durationMinutes, cardCount: item.cardCount, compact: false)
                .padding(.top, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bottomRail: some View {
        HStack(spacing: 12) {
            if role == .learnable {
                let primaryKind: AppCTAType = {
                    switch item.status {
                    case .locked:      return .start
                    case .inProgress:  return .resume
                    case .completed:   return .resume
                    }
                }()
                AppCTAButtons(
                    primary: primaryKind,
                    onPrimary: {
                        LSLessonActivity.mark(item.id)
                        onTap(item)
                    },
                    scale: .xs,
                    unifiedWidth: true
                )
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                // unified like button from AppDS
                Button(action: { onFavorite?() }) {
                    ZStack(alignment: .topTrailing) {
                        AppCardIconButton(kind: .favorite)
                        heartBadge
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить в избранное")
                .accessibilityValue("избранное: \(favoriteCount)")
                .animation(.spring(response: 0.28, dampingFraction: 0.8), value: favoriteCount)

                if role == .learnable {
                    Button(action: { onConsole?() }) {
                        AppCardIconButton(kind: .console)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 36, alignment: .center)
            .contentShape(Rectangle())
            .padding(.trailing, 2)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 10)
    }

    public var body: some View {
        // Map LS.Status → AppStatusKind used by CardDS
        let statusKind: AppStatusKind = {
            switch item.status {
            case .locked:      return .new
            case .inProgress:  return .inProgress
            case .completed:   return .completed
            }
        }()

        // Map LS.Status → primary CTA
        let primaryCTA: AppCTAType = {
            switch item.status {
            case .locked:      return .start
            case .inProgress:  return .resume
            case .completed:   return .reinforce
            }
        }()

        // Build duration text (same format, reused by CardDS)
        let durationText = "≈ \(item.durationMinutes) мин"

        return CourseLessonCard(
            title: item.title,
            subtitle: item.subtitle,
            lessonsCount: item.cardCount,
            durationText: durationText,
            statusKind: statusKind,
            isPro: item.isPro,
            tags: item.tags,
            sectionChrome: .none,
            primaryCTA: primaryCTA,
            scale: .s,
            showFavorite: true,
            showConsole: true,
            onPrimaryTap: {
                LSLessonActivity.mark(item.id)
                onTap(item)
            },
            completionFraction: (item.status == .completed ? 1.0 : nil),
            favoriteCount: favoriteCount,
            onConsoleTap: { onConsole?() }
        )
    }
}

// Reusable Console embed (from CardDS) to drop into any section


// MARK: - Depth tokens (mirrored from CourseDS)
private let CDDepthNormWidthFactor: CGFloat = 0.70
private let CDDepthScaleSide:       CGFloat = 0.92
private let CDDepthScaleCenter:     CGFloat = 1.04
private let CDDepthOpacitySide:     CGFloat = 0.82
private let CDDepthOpacityCenter:   CGFloat = 1.00

// Track horizontal scroll offset for the carousel (like in CourseDS)
private struct LSScrollXKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
private struct LSViewportMidXKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

public struct LSLessonReels: View {
    let title: String
    let items: [LS.Item]
    let collapsible: Bool
    let startExpanded: Bool
    let autoplay: Bool
    let interval: Double
    public let selectedIndex: Int?
    let onTap: (LS.Item) -> Void
    let onTapAccessory: ((LS.Item) -> Void)?

    @State private var currentIndex: Int = 0
    @State private var isCollapsed: Bool
    @State private var scrollX: CGFloat = 0
    @State private var viewportMidX: CGFloat = 0

    public init(_ title: String,
                items: [LS.Item],
                collapsible: Bool = true,
                startExpanded: Bool = true,
                autoplay: Bool = false,
                interval: Double = 4.0,
                onTap: @escaping (LS.Item) -> Void,
                onTapAccessory: ((LS.Item) -> Void)? = nil,
                selectedIndex: Int? = nil) {
        self.title = title
        self.items = items
        self.collapsible = collapsible
        self.startExpanded = startExpanded
        self._isCollapsed = State(initialValue: !startExpanded)
        self.autoplay = autoplay
        self.interval = interval
        self.onTap = onTap
        self.onTapAccessory = onTapAccessory
        self.selectedIndex = selectedIndex
    }

    public var body: some View {
        let total = max(1, items.count)
        let loopCount = max(1, total * 3)
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        LSSectionTitle(title)
                        Spacer(minLength: 0)
                        if collapsible {
                            Button(action: { withAnimation(.easeInOut(duration: 0.22)) { isCollapsed.toggle() } }) {
                                HStack(spacing: 6) {
                                    Text("").textCase(.lowercase)
                                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                }
                                .font(.caption.weight(.semibold))
                                .kerning(0.4)
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Group {
                        if isCollapsed {
                            EmptyView().frame(height: 0)
                        } else {
                            GeometryReader { geometry in
                                let width = geometry.size.width
                                let cardW = width * CDDepthNormWidthFactor
                                let spacing: CGFloat = CDCarouselSpacing
                                let peekMin: CGFloat = CDCarouselPeekMin
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: spacing) {
                                            ForEach(0..<loopCount, id: \.self) { idx in
                                                let sourceIndex = idx % total
                                                let it = items[sourceIndex]
                                                GeometryReader { cg in
                                                    let cardMidX = cg.frame(in: .global).midX
                                                    let dx = cardMidX - viewportMidX
                                                    let norm = min(abs(dx / cardW), 1)

                                                    let vScale   = CDDepthScaleSide + (CDDepthScaleCenter - CDDepthScaleSide) * (1 - norm)
                                                    let vOpacity = CDDepthOpacitySide + (CDDepthOpacityCenter - CDDepthOpacitySide) * (1 - norm)
                                                    let vYOffset = CDDepthYOffsetMax * norm

                                                    ZStack {
                                                        LSLessonCardV(
                                                            item: it,
                                                            onTap: onTap,
                                                            favoriteCount: it.favoriteCount,
                                                            onConsole: { onTapAccessory?(it) }
                                                        )
                                                    }
                                                    .id(idx)
                                                    .scaleEffect(vScale)
                                                    .opacity(vOpacity)
                                                    .offset(y: vYOffset)
                                                    .zIndex(Double(1.0 - norm))
                                                }
                                                .frame(width: cardW)
                                            }
                                        }
                                        .padding(.horizontal, peekMin)
                                        .padding(.vertical, CDDepthYOffsetMax)
                                    }
                                    .overlay(
                                        GeometryReader { g in
                                            Color.clear
                                                .preference(key: LSScrollXKey.self,
                                                            value: -g.frame(in: .named("LSCarousel")).minX)
                                        }
                                    )
                                    .overlay(
                                        GeometryReader { g in
                                            Color.clear
                                                .preference(key: LSViewportMidXKey.self,
                                                            value: g.frame(in: .global).midX)
                                        }
                                    )
                                    .coordinateSpace(name: "LSCarousel")
                                    .onPreferenceChange(LSScrollXKey.self) { scrollX = $0 }
                                    .onPreferenceChange(LSViewportMidXKey.self) { viewportMidX = $0 }
                                    .onAppear {
                                        // стартуем сразу с "среднего" блока, чтобы не было видимого начала/конца
                                        if total > 1 {
                                            let middle = total // вторая "полоса" из тройного массива
                                            proxy.scrollTo(middle, anchor: .center)
                                        }
                                    }
                                    .frame(height: CDCarouselContainerHeight)
                                }
                            }
                            .frame(height: CDCarouselContainerHeight)
                            .transition(.opacity)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: isCollapsed)
            }
        }
    }
}

// MARK: - Course Stats (model)
public struct LSCourseStats: Hashable {
    public let completedLessons: Int
    public let totalLessons: Int
    public let learnedWords: Int
    public let favorites: Int
    public let streakDays: Int
    public let timeMinutes: Int

    public init(completedLessons: Int, totalLessons: Int, learnedWords: Int, favorites: Int, streakDays: Int, timeMinutes: Int) {
        self.completedLessons = max(0, completedLessons)
        self.totalLessons = max(1, totalLessons)
        self.learnedWords = max(0, learnedWords)
        self.favorites = max(0, favorites)
        self.streakDays = max(0, streakDays)
        self.timeMinutes = max(0, timeMinutes)
    }
}

// MARK: - Course Overview (summary header)
public struct LSCourseOverview: View {
    public let stats: LSCourseStats
    public let category: String
    public let onCTA: () -> Void
    public let onReset: () -> Void
    public let showInlineProgress: Bool

    private var progress: Double {
        guard stats.totalLessons > 0 else { return 0 }
        return min(1.0, max(0.0, Double(stats.completedLessons) / Double(stats.totalLessons)))
    }

    private var grad: LinearGradient { ThemeManager.shared.currentAccentFill }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.14)))
        // No chip stroke – matches unified APP DS visuals
        .foregroundStyle(Color.white.opacity(0.92))
    }

    public var body: some View {
        ctaRow
    }
    // MARK: - Extracted small views to help the type-checker
    private var headerRowCompact: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(Int(round(progress * 100)))%")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text("уроков \(stats.completedLessons)/\(stats.totalLessons)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var progressLinearBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.10))
                .frame(height: 10)
            GeometryReader { geo in
                let width = max(0, min(geo.size.width, geo.size.width * progress))
                Capsule()
                    .fill(grad)
                    .frame(width: width, height: 10)
            }
            .frame(height: 10)
            .mask(Capsule())
        }
        .frame(height: 10)
        .padding(.top, 2)
    }

    private var pillsRowCompact: some View {
        HStack(spacing: 10) {
            statChip(icon: "text.book.closed.fill", text: "\(stats.learnedWords) слов")
            statChip(icon: "heart.fill", text: "\(stats.favorites) избранное")
            statChip(icon: "clock", text: "\(stats.timeMinutes) мин")
        }
        .padding(.top, 2)
    }

    private var ctaCompact: some View {
        Button(action: onCTA) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 14, weight: .semibold))
                Text("Следующий урок").font(.callout.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(grad))
            // No chip stroke – matches unified APP DS visuals
            .foregroundStyle(Color.black.opacity(0.92))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }


    private var ctaRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: Reset progress (text pill, same height as primary CTA)
            Button(action: onReset) {
                HStack(spacing: 6) {
                    Image(systemName: "backward.end.fill").font(.system(size: 14, weight: .semibold))
                    Text("Сбросить прогресс").font(.callout.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .foregroundStyle(Color.white.opacity(0.95))
            }
            .accessibilityLabel("Сбросить прогресс")
            .accessibilityIdentifier("resetCourseButton")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    // MARK: - Private computed properties for UI extraction
    private var categoryChip: some View {
        HStack {
            Spacer()
            Text(category)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(grad)
                )
                // No chip stroke – matches unified APP DS visuals
                .foregroundStyle(Color.black.opacity(0.92))
        }
        .padding(.top, 2)
        .padding(.trailing, 2)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 10)
                .frame(width: 96, height: 96)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(grad, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)
            VStack(spacing: 2) {
                Text("\(Int(round(progress * 100)))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("уроков \(stats.completedLessons)/\(stats.totalLessons)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 2)
    }

    private var statChips: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                statChip(icon: "text.book.closed.fill", text: "\(stats.learnedWords) слов")
                statChip(icon: "heart.fill", text: "\(stats.favorites) избранное")
            }
            HStack(spacing: 10) {
                statChip(icon: "flame.fill", text: "\(stats.streakDays) дней серия")
                statChip(icon: "clock", text: "\(stats.timeMinutes) мин")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var ctaButton: some View {
        Button(action: onCTA) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Продолжить курс")
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(grad)
            )
            // No chip stroke – matches unified APP DS visuals
            .foregroundStyle(Color.black.opacity(0.92))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    public init(stats: LSCourseStats,
                category: String,
                onCTA: @escaping () -> Void,
                onReset: @escaping () -> Void = {},
                showInlineProgress: Bool = false) {
        self.stats = stats
        self.category = category
        self.onCTA = onCTA
        self.onReset = onReset
        self.showInlineProgress = showInlineProgress
    }
}

// MARK: - Section Title (shared style)
public struct LSSectionTitle: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public init(title: String) { self.text = title }
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(text.uppercased())
                .font(.caption.weight(.semibold))
                .kerning(0.8)
                .foregroundStyle(.secondary) // unified gray, like in Favorites
                .opacity(0.98)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview helpers
struct LSSampleData {
    static let list: [LS.Item] = [
        .init(index: 1, title: "Приветствие и small talk", subtitle: "Первые фразы, ice‑breakers. Научимся начинать разговор уверенно.", durationMinutes: 6, isPro: false, status: .completed, tags: ["разговор"], cardCount: 12),
        .init(index: 2, title: "Заказать кофе", subtitle: "Как без стресса попросить и уточнить. Практикуем вежливые формулы.", durationMinutes: 8, isPro: false, status: .inProgress, tags: ["кофейня"], cardCount: 16),
        .init(index: 3, title: "Такси и адрес", subtitle: "Вежливо, но уверенно. Закрепим полезные фразы и короткие диалоги.", durationMinutes: 10, isPro: true, status: .locked, tags: ["такси"], cardCount: 9)
    ]
    static let content: [LS.ContentItem] = [
        .init(kind: .intro,
              text: "Немного разогреемся: что говорить при знакомстве и как уверенно начать разговор.",
              imageName: "mascot.profile"),
        .init(kind: .outline,
              text: "Из чего состоит урок: мини‑диалоги, полезные фразы и короткая практика.",
              imageName: "mascot.profile"),
        .init(kind: .outcome,
              text: "По итогам поймёшь базовые структуры, начнёшь говорить увереннее и быстрее подбирать фразы.",
              imageName: "mascot.profile"),
        .init(kind: .apply,
              text: "Где применять: кафе, такси, короткие small talk — сразу пробуешь в жизни.",
              imageName: "mascot.profile")
    ]
    static let hometasks: [HT.Item] = [
        .init(index: 1, title: "домашка: small talk", subtitle: "2 короткие диалога и 1 запись голоса", durationMinutes: 5),
        .init(index: 2, title: "домашка: кофе без стресса", subtitle: "потренируй форму вежливости", durationMinutes: 6),
        .init(index: 3, title: "домашка: адрес для такси", subtitle: "проговори адрес и уточнение 3 раза", durationMinutes: 7)
    ]
    static let stats = LSCourseStats(
        completedLessons: 5,
        totalLessons: 8,
        learnedWords: 207, // 145 words + 62 phrases
        favorites: 23,
        streakDays: 9,
        timeMinutes: 118
    )
}

// MARK: - Progress Section (modeled after CDProgressSection)
public struct LSProgressSection: View {
    public let lessonsDone: Int
    public let lessonsTotal: Int

    private var progress: Double {
        guard lessonsTotal > 0 else { return 0 }
        return min(1.0, max(0.0, Double(lessonsDone) / Double(lessonsTotal)))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header (LEFT: gray title, RIGHT: lessons label)
            HStack(alignment: .center) {
                Text("ПРОГРЕСС")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(PD.ColorToken.textSecondary)

                Spacer()

                Text("уроков \(lessonsDone)/\(lessonsTotal)")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }

            // Single thin progress bar – reuse unified App progress widget
            AppProgressBar(value: CGFloat(progress), height: 10)
                .padding(.trailing, 2)
        }
    }
}

// MARK: - Preview host to inject ThemeManager
private struct _ThemePreviewHost<Content: View>: View {
    @StateObject private var theme = ThemeManager.shared
    let content: () -> Content
    var body: some View { content().environmentObject(theme) }
}

#Preview("Lessons DS – List") {
    _ThemePreviewHost {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    LSLessonHeader(
                        title: "Разговорный минимум",
                        subtitle: "Учимся [[простому]] и [[полезному]] каждодневно",
                        progressCompleted: 3,
                        progressTotal: 8,
                        lessonsCount: 8,
                        progressSlots: [0.5, 0.4, 1.0, 0.0, 0.2, 0.85, 0.0, 0.0],
                        selectedIndex: 1
                    )
                    .lsSectionPadding()

                    LSMarqueeSection(
                        title: "taika fm",
                        messages: [
                            "давай закрепим тему: закажем кофе без стресса ☕️",
                            "повтори: ‘кафе йаак, капхе йаак’ — я подскажу произношение"
                        ]
                    )
                    .lsSectionPadding()

                    LSContentReels("содержание", items: LSSampleData.content)
                        .lsSectionPadding()

                    LSLessonReels("уроки", items: LSSampleData.list, collapsible: true, startExpanded: true, autoplay: false) { _ in }
                        .lsSectionPadding()

                    // Progress Section (after lesson reels, before hometask)
                    LSProgressSection(
                        lessonsDone: 5,
                        lessonsTotal: 8
                    )
                    .lsSectionPadding()


                    LSSectionTitle("итоги курса")
                        .lsSectionPadding(bottom: 0)
                    LSCourseOverview(
                        stats: LSCourseStats(
                            completedLessons: 3,
                            totalLessons: 10,
                            learnedWords: 25,
                            favorites: 5,
                            streakDays: 7,
                            timeMinutes: 120
                        ),
                        category: "разговорный",
                        onCTA: {},
                        onReset: {},
                        showInlineProgress: false
                    )
                    .lsSectionPadding()
                }
                .padding(.top, Theme.Layout.pageTopAfterHeader)
            }
            .background(PD.ColorToken.background.ignoresSafeArea())
        }
        .lsBackToCoursesToolbar(title: "Назад к курсам") {
            print("backToCourses tapped in preview")
        }
        .preferredColorScheme(.dark)
    }
}
// MARK: - Content (section below assistant)

public extension LS {
    enum ContentKind: String, Hashable {
        case intro, outline, outcome, apply

        var chipTitle: String {
            switch self {
            case .intro:   return "Вводная"
            case .outline: return "Состав урока"
            case .outcome: return "Результат"
            case .apply:   return "Где применить"
            }
        }
    }

    struct ContentItem: Identifiable, Hashable {
        public let id: String
        public let kind: ContentKind
        public let text: String
        public let imageName: String?

        public init(id: String = UUID().uuidString,
                    kind: ContentKind,
                    text: String,
                    imageName: String? = nil) {
            self.id = id
            self.kind = kind
            self.text = text
            self.imageName = imageName
        }
    }
}

// Small reusable capsule chip
public struct LSChip: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.white.opacity(0.14))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(height: 26)
    }
}

// Adapter: LSContentCard now delegates to CardDS NoteCard
public struct LSContentCard: View {
    let item: LS.ContentItem
    public init(item: LS.ContentItem) { self.item = item }

    public var body: some View {
        NoteTextCard(
            label: item.kind.chipTitle.lowercased(),
            text: item.text,
            sectionChrome: .seps,
            chromeStyle: .cards
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// Horizontal reels of content cards with section title
public struct LSContentReels: View {
    let title: String
    let items: [LS.ContentItem]
    let collapsible: Bool

    @State private var currentIndex: Int = 0
    @State private var isCollapsed: Bool = true

    public init(_ title: String,
                items: [LS.ContentItem],
                autoplay: Bool = false,
                interval: Double = 4.0,
                collapsible: Bool = true) {
        self.title = title
        self.items = items
        self.collapsible = collapsible
    }

    public var body: some View {
        if items.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    LSSectionTitle(title)
                    Spacer(minLength: 0)
                    if collapsible {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isCollapsed.toggle()
                            }
                        }) {
                            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                .font(.caption.weight(.semibold))
                                .kerning(0.4)
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isCollapsed ? "раскрыть содержание" : "скрыть содержание")
                    }
                }

                Group {
                    if isCollapsed {
                        EmptyView().frame(height: 0)
                    } else {
                        GeometryReader { geo in
                            let width = geo.size.width
                            // content cards should feel like a compact carousel, not full-width posters
                            let cardW = min(420, max(260, floor(width * 0.84)))
                            let spacing: CGFloat = 12
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: spacing) {
                                    ForEach(items) { it in
                                        LSContentCard(item: it)
                                            .frame(width: cardW, height: CardDS.Metrics.noteCardHeight)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 2)
                            }
                        }
                        // note cards are tall; reserve full height so the next section doesn't get overlapped
                        .frame(height: CardDS.Metrics.noteCardHeight + 8)
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isCollapsed)
        )
    }
}
// MARK: - Status Badge
