//  CardDS.swift
//  taika
//  Created by product on 30.09.2025.

import SwiftUI
import AVKit

// MARK: - Title font (system – Helvetica‑like)
private enum TaikaFontPS {
    static let title = "ONMARK Trial" // PostScript name
}
// MARK: - StepProGateCard (DS atom: step-style PRO gate card; same shell as StepWordCard)
public struct StepProGateCard: View {
    public let title: String
    public let subtitle: String
    public let footnote: String?
    public let label: String

    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle

    public let primaryTitle: String
    public let onPrimaryTap: () -> Void

    public init(
        title: String,
        subtitle: String,
        footnote: String? = "нужно pro",
        label: String = "pro",
        primaryTitle: String = "открыть pro",
        size: CGSize = CGSize(width: CardDS.Metrics.stepWordWidth, height: CardDS.Metrics.stepWordHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        onPrimaryTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.footnote = footnote
        self.label = label
        self.primaryTitle = primaryTitle
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.onPrimaryTap = onPrimaryTap
    }

    public var body: some View {
        CardBase(
            title: title,
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            top: {
                HStack {
                    Text("taikA")
                        .font(.taikaLogo(16))
                        .foregroundStyle(CD.ColorToken.text)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        AppMiniChip(
                            title: label.lowercased(),
                            style: .accent
                        ) { }
                    }
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .padding(.top, 8)
            },
            bottom: {
                Button(action: onPrimaryTap) {
                    Text(primaryTitle.lowercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CD.ColorToken.card)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(CD.ColorToken.stroke.opacity(0.35), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CardDS.Metrics.contentX)
            },
            meta: {
                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)

                        Text(title)
                            .font(.taikaTitle(24))
                            .foregroundStyle(CD.ColorToken.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)

                        Text(subtitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)

                        if let footnote, !footnote.isEmpty {
                            Text(footnote)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .allowsTightening(true)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .padding(.vertical, 18)
            },
            tags: { EmptyView() },
            belowTitle: { EmptyView() }
        )
    }
}
// MARK: - StepWordCardVisual (adapter from SDStepItem → StepWordCard visual)
public struct StepWordCardVisual: View {
    public let item: SDStepItem
    public let label: String
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let phoneticView: AnyView?
    public let isFavorite: Bool
    public let isLearned: Bool
    public let allowLearn: Bool
    public let onPlay: (() -> Void)?
    public let onFavorite: () -> Void
    public let onLearn: () -> Void

    public init(
        item: SDStepItem,
        label: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.stepCardWidth,
                              height: CardDS.Metrics.stepWordCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        phoneticView: AnyView? = nil,
        isFavorite: Bool = false,
        isLearned: Bool = false,
        allowLearn: Bool = true,
        onPlay: (() -> Void)? = nil,
        onFavorite: @escaping () -> Void = {},
        onLearn: @escaping () -> Void = {}
    ) {
        self.item = item
        // default label depends on kind, but falls back to "слово"
        if let label {
            self.label = label
        } else {
            switch item.visualKind {
            case .word, .phrase, .casual:
                self.label = "слово"
            default:
                self.label = "слово"
            }
        }
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.phoneticView = phoneticView
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.allowLearn = allowLearn
        self.onPlay = onPlay
        self.onFavorite = onFavorite
        self.onLearn = onLearn
    }

    public var body: some View {
        StepWordCard(
            title: item.titleRU,
            translit: item.phonetic,
            thai: item.subtitleTH,
            label: label,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            phoneticView: phoneticView,
            isFavorite: isFavorite,
            isLearned: isLearned,
            allowLearn: allowLearn,
            onPlay: onPlay,
            onFavorite: onFavorite,
            onLearn: onLearn
        )
    }
}

// MARK: - StepLifehackCardVisual (adapter from SDStepItem → StepLifehack visual)
public struct StepLifehackCardVisual: View {
    public let item: SDStepItem
    public let label: String
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let isFavorite: Bool
    public let onFavorite: () -> Void
    public let onNext: (() -> Void)?

    public init(
        item: SDStepItem,
        label: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.stepCardWidth,
                              height: CardDS.Metrics.stepLifehackCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        isFavorite: Bool = false,
        onFavorite: @escaping () -> Void = {},
        onNext: (() -> Void)? = nil
    ) {
        self.item = item
        if let label {
            self.label = label
        } else {
            switch item.visualKind {
            case .tip:
                self.label = "лайфхак"
            default:
                self.label = "заметка"
            }
        }
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.isFavorite = isFavorite
        self.onFavorite = onFavorite
        self.onNext = onNext
    }

    public var body: some View {
        StepLifehackCardLegacy(
            body: item.subtitleTH,
            label: label,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            isFavorite: isFavorite,
            onFavorite: onFavorite,
            onNext: onNext
        )
    }
}

// MARK: - StepLifehackCard (DS atom: lifehack card)
public struct StepLifehackCardLegacy: View {
    public let bodyText: String      // основной текст лайфхака
    public let label: String         // чип в правом верхнем углу, по умолчанию "лайфхак"
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let isFavorite: Bool
    public let onFavorite: () -> Void
    public let onNext: (() -> Void)?

    public init(
        body: String,
        label: String = "лайфхак",
        size: CGSize = CGSize(width: CardDS.Metrics.stepLifehackWidth,
                              height: CardDS.Metrics.stepLifehackHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        isFavorite: Bool = false,
        onFavorite: @escaping () -> Void = {},
        onNext: (() -> Void)? = nil
    ) {
        self.bodyText = body
        self.label = label
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.isFavorite = isFavorite
        self.onFavorite = onFavorite
        self.onNext = onNext
    }

    public var body: some View {
        CardBase(
            title: "",
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            top: {
                HStack {
                    Text("taikA")
                        .font(.taikaLogo(16))
                        .foregroundStyle(CD.ColorToken.text)
                    Spacer(minLength: 0)

                    let chipLabel = label.lowercased()

                    AppMiniChip(
                        title: chipLabel,
                        style: (chipLabel == "лайфхак" || chipLabel == "запомнил")
                            ? .accent
                            : .neutral
                    ) { }
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .padding(.top, 8)
            },
            bottom: {
                StepCardActionBar(
                    isFavorite: isFavorite,
                    isLearned: false,
                    allowLearn: false,
                    isTip: true,
                    onPlay: nil,
                    onFavorite: onFavorite,
                    onLearn: {},
                    onNext: onNext
                )
            },
            meta: {
                VStack(spacing: 0) {
                    // чуть больше воздуха сверху и снизу, как у StepWordCard
                    Spacer(minLength: 16)
                    VStack(spacing: 8) {
                        taikaFMStyledText(bodyText)
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .lineLimit(6)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .padding(.vertical, 18)
            },
            tags: {
                EmptyView()
            },
            belowTitle: {
                EmptyView()
            }
        )
    }
}

extension Font {
    /// UI titles: use system (Helvetica/SF-like), not the app logo font
    static func taikaTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// App logo only — ONMARK Trial
    static func taikaLogo(_ size: CGFloat) -> Font {
        .custom(TaikaFontPS.title, size: size, relativeTo: .title2)
    }
}

extension UIFont {
    /// UI titles: system font
    static func taikaTitle(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .semibold)
    }
    /// App logo only — ONMARK Trial
    static func taikaLogo(_ size: CGFloat) -> UIFont {
        UIFont(name: TaikaFontPS.title, size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }
}

// MARK: - Namespacing (size & spacing only)
public enum CardDS {
    public enum SectionChrome { case none, fold, lines, rail, zones, seps, sepsLR }
    public enum ChromeStyle { case brand, cards }

    public struct Metrics {
        public static let radius: CGFloat = 16
        public static let contentX: CGFloat = 18
        public static let contentYTop: CGFloat = 24
        public static let contentYBottom: CGFloat = 32
        public static let vSpacing: CGFloat = 10
        public static let footerRailSpacing: CGFloat = 12
        public static let footerHeight: CGFloat = 38
        public static let titleTopGap: CGFloat = 4
        public static let titleBottomGap: CGFloat = 6
        // Unified card sizing for course and lesson cards (canonical dimensions)
        // made slightly more compact so they don't feel oversized on main and course screens
        public static let courseWidth: CGFloat  = 280
        public static let courseHeight: CGFloat = 360
        public static let courseCardWidth: CGFloat  = courseWidth
        public static let courseCardHeight: CGFloat = courseHeight

        // lessons use same footprint as courses
        public static let lessonWidth: CGFloat  = courseWidth
        public static let lessonHeight: CGFloat = courseHeight
        public static let lessonCardWidth: CGFloat  = lessonWidth
        public static let lessonCardHeight: CGFloat = lessonHeight

        // step cards sizing (shared by StepDS and previews)
        // независимые размеры степ‑карточек, чтобы изменения курсов/уроков не влияли на степы
        // делаем все степ‑карты квадратными, чтобы центр секции в StepView выглядел чище
        public static let stepCardWidth: CGFloat = 290            // ширина всех степ‑карт
        public static let stepWordCardHeight: CGFloat = 290       // учебная квадратная
        public static let stepLifehackCardHeight: CGFloat = 360   // лайфхак теперь тоже квадратный

        // алиасы для старых имён, чтобы не ломать существующие вызовы
        public static let stepWordWidth: CGFloat = stepCardWidth
        public static let stepWordHeight: CGFloat = stepWordCardHeight
        public static let stepLifehackWidth: CGFloat = stepCardWidth
        public static let stepLifehackHeight: CGFloat = stepLifehackCardHeight

        // note cards sizing (independent from step cards)
        // noteCourse/noteText are square; noteStep is a shorter rectangle.
        public static let noteCardWidth: CGFloat = 290
        public static let noteCardHeight: CGFloat = 290
        public static let noteStepHeight: CGFloat = 220
        // note card paddings (keep top/bottom symmetric)
        public static let noteTopPadding: CGFloat = 14
        public static let noteBottomPadding: CGFloat = 14

        public static let topBandHeight: CGFloat = 56
        public static let bottomBandHeight: CGFloat = 80
        public static let bannerHeight: CGFloat = 340
        public static let bannerHeightCompact: CGFloat = 170 // half-height banner for calendar detail
        public static let weeklyCellWidth: CGFloat = 120
        public static let weeklyCellHeight: CGFloat = 260

        // Global inter-card spacing token for carousels (used by CourseDS/LessonsDS)
        public static let carouselSpacing: CGFloat = 20

        // Isolated block metrics
        public static let blockSpacing: CGFloat = 12       // space between content blocks
        public static let titleMinHeight: CGFloat = 56     // reserve space for multi-line titles
        public static let descMinHeight: CGFloat = 18      // single-line description
        public static let metaRowMinHeight: CGFloat = 24   // chips (timer/cards)
        public static let tagsRowMinHeight: CGFloat = 24   // tags (optional)

        // ConsoleCard metrics
        public static let consoleWidth: CGFloat = 408
        public static let consoleHeight: CGFloat = 280
        public static let tearStripHeight: CGFloat = 26
        public static let tearTabWidth: CGFloat = 42
        public static let tearTabGap: CGFloat = 10
        public static let tearPerforationDash: [CGFloat] = [4, 4]
        public static let consoleContentX: CGFloat = 14
    }
}

// MARK: - Chrome (background only)
public struct CardChrome: View {
    let style: CardDS.ChromeStyle
    public init(style: CardDS.ChromeStyle = .brand) { self.style = style }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous)
        switch style {
        case .brand, .cards:
            return AnyView(
                Theme.Surfaces.card(shape)
            )
        }
    }
}



// MARK: - Footer rail (CTA left, actions right)
public struct CardFooterRail<Left: View, Right: View>: View {
    let left: Left
    let right: Right
    public init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left(); self.right = right()
    }
    public var body: some View {
        HStack(spacing: CardDS.Metrics.footerRailSpacing) {
            left
            Spacer(minLength: 8)
            right
        }
        .frame(height: CardDS.Metrics.footerHeight)
    }
}

// MARK: - Single template: Course/Lesson card (layout only, atoms come from AppDS)

/// Usage (compose with AppDS atoms):
/// CardBase(title: ..., subtitle: ...) { // top, optional via trailing label
///   // top: e.g. AppStatusChip + AppProChip (from AppDS)
/// } bottom: {
///   // bottom: e.g. AppCTAButtons + AppCardIconButton (from AppDS)
/// } meta: {
///   // meta row: e.g. AppInlineMeta/AppTagChip from AppDS
/// }
public struct CardBase<Top: View, Meta: View, BelowTitle: View, Tags: View, Bottom: View>: View {
    // content
    let title: String
    let subtitle: String?
    let size: CGSize
    let sectionChrome: CardDS.SectionChrome
    let chromeStyle: CardDS.ChromeStyle
    let showTitle: Bool
    let isFluidWidth: Bool
    let brandText: String?

    // provided slots
    let top: Top          // e.g. статус/PRO-ряд (из AppDS)
    let meta: Meta        // inline metrics only
    let belowTitle: BelowTitle        // inline content directly under the title
    let tags: Tags        // optional tags slot (bottom-right of CONTENT)
    let bottom: Bottom    // e.g. CTA/иконки (из AppDS)

    public init(
        title: String,
        subtitle: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.courseWidth, height: CardDS.Metrics.courseHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        showTitle: Bool = true,
        isFluidWidth: Bool = false,
        brandText: String? = nil,
        @ViewBuilder top: () -> Top = { EmptyView() as! Top },
        @ViewBuilder bottom: () -> Bottom = { EmptyView() as! Bottom },
        @ViewBuilder meta: () -> Meta,
        @ViewBuilder tags: () -> Tags = { EmptyView() as! Tags },
        @ViewBuilder belowTitle: () -> BelowTitle = { EmptyView() as! BelowTitle }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.showTitle = showTitle
        self.isFluidWidth = isFluidWidth
        self.brandText = brandText
        self.top = top()
        self.bottom = bottom()
        self.meta = meta()
        self.tags = tags()
        self.belowTitle = belowTitle()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous)
        // Core layout
        let base = ZStack {
            CardChrome(style: chromeStyle)
            VStack(spacing: 0) {
                // TOP zone (status/PRO area only — AppDS atoms), vertically centered
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        top
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .frame(height: CardDS.Metrics.topBandHeight)

                // CONTENT zone — center-left text/meta; tags pinned bottom-right
                ZStack {
                    // Center-left text/meta block
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: CardDS.Metrics.blockSpacing) {
                            // META block — items that must appear ABOVE the title
                            meta
                                .frame(maxWidth: .infinity,
                                       minHeight: CardDS.Metrics.metaRowMinHeight,
                                       alignment: .leading)

                            // TITLE block — central element (optional)
                            if showTitle {
                                Text(title)
                                    .font(.taikaTitle(24))
                                    .kerning(0.05)
                                    .foregroundStyle(CD.ColorToken.text)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.88)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(minHeight: CardDS.Metrics.titleMinHeight, alignment: .leading)
                            }

                            // BELOW-TITLE block — e.g. inline progress for courses
                            belowTitle
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // DESCRIPTION block — one calm line
                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.95))
                                    .lineLimit(2)
                                    .frame(minHeight: CardDS.Metrics.descMinHeight, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                    }

                    // Tags pinned to the bottom-right of CONTENT area, very close to bottom
                    HStack(spacing: 10) { tags }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.bottom, 4)
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // BOTTOM zone (CTA/actions area), vertically centered
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    bottom
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .frame(height: CardDS.Metrics.bottomBandHeight)
            }
        }

        // Clean base chrome: no legacy overlays — all visual tokens come from Theme (CD.ColorToken.card, etc.)
        return base
            .clipShape(RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous))
            .compositingGroup()
            .frame(width: isFluidWidth ? nil : size.width, height: size.height, alignment: .topLeading)
            .frame(maxWidth: isFluidWidth ? .infinity : nil)
    }
}

extension CardBase where Top == EmptyView, BelowTitle == EmptyView, Tags == EmptyView, Bottom == EmptyView {
    public init(
        title: String,
        subtitle: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.courseWidth, height: CardDS.Metrics.courseHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        showTitle: Bool = true,
        isFluidWidth: Bool = false,
        brandText: String? = nil,
        @ViewBuilder meta: () -> Meta
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: showTitle,
            isFluidWidth: isFluidWidth,
            brandText: brandText,
            top: { EmptyView() },
            bottom: { EmptyView() },
            meta: meta,
            tags: { EmptyView() },
            belowTitle: { EmptyView() }
        )
    }
}

// MARK: - Unified step card action bar (CTA for word/tip cards)
public struct StepCardActionBar: View {
    public let isFavorite: Bool
    public let isLearned: Bool
    public let allowLearn: Bool
    public let isTip: Bool
    public let onPlay: (() -> Void)?
    public let onFavorite: () -> Void
    public let onLearn: () -> Void
    public let onNext: (() -> Void)?

    public init(
        isFavorite: Bool,
        isLearned: Bool,
        allowLearn: Bool = true,
        isTip: Bool = false,
        onPlay: (() -> Void)? = nil,
        onFavorite: @escaping () -> Void,
        onLearn: @escaping () -> Void,
        onNext: (() -> Void)? = nil
    ) {
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.allowLearn = allowLearn
        self.isTip = isTip
        self.onPlay = onPlay
        self.onFavorite = onFavorite
        self.onLearn = onLearn
        self.onNext = onNext
    }

    public var body: some View {
        HStack(spacing: 28) {
            if !isTip {
                StepIconCircleButton(
                    systemName: "speaker.wave.2.fill",
                    isActive: false,
                    action: { onPlay?() }
                )
            }
            AppCardIconButton(
                kind: .favorite,
                isActive: isFavorite,
                onTap: { onFavorite() }
            )
            if isTip {
                StepIconCircleButton(
                    systemName: "chevron.right",
                    isActive: false,
                    action: { onNext?() }
                )
            } else {
                if isLearned {
                    AppMiniChip(
                        title: "запомнил",
                        style: .accent
                    ) {
                        if allowLearn {
                            onLearn()
                        }
                    }
                } else {
                    StepIconCircleButton(
                        systemName: "checkmark",
                        isActive: false,
                        action: {
                            if allowLearn {
                                onLearn()
                            }
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(CD.ColorToken.textSecondary)
    }
}
// MARK: - StepCardBase (shared shell for step cards – layout only, no logic)

fileprivate struct StepIconCircleButton: View {
    let systemName: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isActive ? Color.white.opacity(0.14) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            isActive
            ? Color.white
            : CD.ColorToken.textSecondary
        )
    }
}
public struct StepCardBase<Content: View, Bottom: View>: View {
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    private let content: Content
    private let bottom: Bottom

    public init(
        size: CGSize = CGSize(width: CardDS.Metrics.stepWordWidth, height: CardDS.Metrics.stepWordHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.content = content()
        self.bottom = bottom()
    }

    public var body: some View {
        CardBase(
            title: "",
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            isFluidWidth: false,
            brandText: nil,
            top: { EmptyView() },
            bottom: { bottom },
            meta: {
                content
            },
            tags: {
                EmptyView()
            },
            belowTitle: {
                EmptyView()
            }
        )
    }
}


public struct CardNoteBase<Content: View, Bottom: View>: View {
    public let label: String?
    public let topTrailing: AnyView?
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let contentTopSpacer: CGFloat
    public let contentBottomSpacer: CGFloat
    public let contentInsetsY: CGFloat

    private let content: Content
    private let bottom: Bottom

    public init(
        label: String? = nil,
        topTrailing: AnyView? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        contentTopSpacer: CGFloat = 16,
        contentBottomSpacer: CGFloat = 20,
        contentInsetsY: CGFloat = 18,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.label = label
        self.topTrailing = topTrailing
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.contentTopSpacer = contentTopSpacer
        self.contentBottomSpacer = contentBottomSpacer
        self.contentInsetsY = contentInsetsY
        self.content = content()
        self.bottom = bottom()
    }

    public var body: some View {
        // CardBase has fixed top/bottom bands (56/80) tuned for course/lesson cards.
        // For note cards we draw the header + CTA inside the CONTENT zone and compensate the band delta
        // so the note layout stays visually symmetric.
        let bandDelta = CardDS.Metrics.bottomBandHeight - CardDS.Metrics.topBandHeight
        let bandCompTop: CGFloat = max(0, bandDelta / 2)

        return CardBase(
            title: "",
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            isFluidWidth: false,
            brandText: nil,
            top: { EmptyView() },
            bottom: { EmptyView() },
            meta: {
                VStack(spacing: 0) {
                    // header (brand + top-right chips)
                    HStack(alignment: .top, spacing: 8) {
                        Text("taikA")
                            .font(.taikaLogo(16))
                            .foregroundStyle(CD.ColorToken.text)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 0) {
                            if let topTrailing {
                                topTrailing
                            } else if let label, !label.isEmpty {
                                AppMiniChip(
                                    title: label.lowercased(),
                                    style: .neutral
                                ) { }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .topTrailing)
                    }
                    .padding(.top, CardDS.Metrics.noteTopPadding + bandCompTop)
                    .padding(.horizontal, CardDS.Metrics.contentX)

                    // content area (centered)
                    VStack(spacing: 0) {
                        Spacer(minLength: contentTopSpacer)

                        content
                            .frame(maxWidth: .infinity)

                        Spacer(minLength: contentBottomSpacer)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.vertical, contentInsetsY)

                    // bottom area (CTA / actions)
                    bottom
                        .padding(.horizontal, CardDS.Metrics.contentX)
                        .padding(.bottom, CardDS.Metrics.noteBottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            tags: {
                EmptyView()
            },
            belowTitle: {
                EmptyView()
            }
        )
    }
}

extension CardNoteBase where Bottom == EmptyView {
    public init(
        label: String? = nil,
        topTrailing: AnyView? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        contentTopSpacer: CGFloat = 16,
        contentBottomSpacer: CGFloat = 20,
        contentInsetsY: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            label: label,
            topTrailing: topTrailing,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            contentTopSpacer: contentTopSpacer,
            contentBottomSpacer: contentBottomSpacer,
            contentInsetsY: contentInsetsY,
            content: content,
            bottom: { EmptyView() }
        )
    }
}
// MARK: - Note cards (built on CardNoteBase)

public extension CardDS {
    /// note-course: big title + subtitle (closest to your screenshot)
    struct NoteCourseCardV: View {
        public let label: String
        public let categoryChip: String?
        public let title: String
        public let subtitle: String
        public let progress: Double?
        public let progressText: String?
        public let ctaTitle: String?
        public let onTap: (() -> Void)?
        public let showsProBadge: Bool

        public enum ActionKind: Equatable {
            case add        // not selected yet
            case added      // selected (toggle on)
            case continueCourse
        }

        public let actionKind: ActionKind?
        public let onActionTap: (() -> Void)?

        // legacy initializer (kept for back-compat)
        public init(
            label: String = "заметка",
            categoryChip: String? = nil,
            title: String,
            subtitle: String,
            progressFraction: Double? = nil,
            ctaTitle: String? = nil,
            onCTATap: (() -> Void)? = nil,
            topRightChip: String? = nil,
            showsProBadge: Bool = false,
            actionKind: ActionKind? = nil,
            onActionTap: (() -> Void)? = nil
        ) {
            self.label = label
            self.categoryChip = topRightChip ?? categoryChip
            self.title = title
            self.subtitle = subtitle
            self.progress = progressFraction
            self.progressText = nil
            self.ctaTitle = ctaTitle
            self.onTap = onCTATap
            self.actionKind = actionKind
            self.onActionTap = onActionTap
            self.showsProBadge = showsProBadge
        }

        // new initializer (MainView-friendly)
        public init(
            label: String = "заметка",
            categoryChip: String? = nil,
            title: String,
            subtitle: String,
            progress: Double = 0,
            progressText: String? = nil,
            ctaTitle: String? = nil,
            onTap: @escaping () -> Void,
            topRightChip: String? = nil,
            showsProBadge: Bool = false,
            actionKind: ActionKind? = nil,
            onActionTap: (() -> Void)? = nil
        ) {
            self.label = label
            self.categoryChip = topRightChip ?? categoryChip
            self.title = title
            self.subtitle = subtitle
            self.progress = progress
            self.progressText = progressText
            self.ctaTitle = ctaTitle
            self.onTap = onTap
            self.actionKind = actionKind
            self.onActionTap = onActionTap
            self.showsProBadge = showsProBadge
        }

        private func actionPill(kind: ActionKind, onTap: @escaping () -> Void) -> some View {
            let cfg: (title: String, icon: String, isFilled: Bool, strokeWidth: CGFloat) = {
                switch kind {
                case .add:
                    return ("добавить", "plus", false, 1.5)
                case .added:
                    return ("добавлено", "checkmark", true, 1.0)
                case .continueCourse:
                    return ("продолжить", "play.fill", true, 1.0)
                }
            }()

            return Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: cfg.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(cfg.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(height: 24)
                .foregroundStyle(cfg.isFilled ? Color.black.opacity(0.85) : CD.ColorToken.text)
                .background(
                    Capsule(style: .continuous)
                        .fill(cfg.isFilled
                              ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                              : AnyShapeStyle(CD.ColorToken.card))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    cfg.isFilled
                                        ? AnyShapeStyle(CD.ColorToken.stroke.opacity(0.25))
                                        : AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.85)),
                                    lineWidth: cfg.strokeWidth
                                )
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private func ctaPill(title: String, onTap: @escaping () -> Void) -> some View {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }) {
                Text(title.lowercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(CD.ColorToken.card)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(ThemeManager.shared.currentAccentFill.opacity(0.9), lineWidth: 1.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }

        public var body: some View {
            let size = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight)
            let sectionChrome: CardDS.SectionChrome = .seps
            let chromeStyle: CardDS.ChromeStyle = .cards
            let chipTitle = (categoryChip?.isEmpty == false ? categoryChip! : label).lowercased()

            CardNoteBase(
                label: nil,
                topTrailing: AnyView(
                    VStack(alignment: .trailing, spacing: 6) {
                        if showsProBadge {
                            AppProChip(title: "pro")
                                .allowsHitTesting(false)
                        }
                        AppMiniChip(
                            title: chipTitle,
                            style: .neutral
                        ) { }
                        .allowsHitTesting(false)
                    }
                ),
                size: size,
                sectionChrome: sectionChrome,
                chromeStyle: chromeStyle,
                contentTopSpacer: 16,
                contentBottomSpacer: 20,
                contentInsetsY: 18,
                content: {
                    // main block: centered vertically, left-aligned text (stable for different subtitle lengths)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(title.lowercased())
                                .font(.taikaTitle(24))
                                .foregroundStyle(CD.ColorToken.text)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .allowsTightening(true)

                            Text(subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let p = progress {
                                if let progressText, !progressText.isEmpty {
                                    Text(progressText)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                        .lineLimit(1)
                                }

                                CourseInlineProgressView(fraction: p)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                },
                bottom: {
                    // cta: bottom-right, aligned with the top-right chips
                    HStack {
                        Spacer(minLength: 0)

                        if let actionKind, let onActionTap {
                            actionPill(kind: actionKind, onTap: onActionTap)
                        } else if let ctaTitle, !ctaTitle.isEmpty, let onTap {
                            ctaPill(title: ctaTitle, onTap: onTap)
                        } else if let ctaTitle, !ctaTitle.isEmpty {
                            // visual-only fallback (no tap)
                            ctaPill(title: ctaTitle, onTap: { })
                                .allowsHitTesting(false)
                        }
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
        }
    }

    // Back-compat exposure
    typealias NoteCourseCard = NoteCourseCardV
}

// Back-compat (non-namespaced)
public typealias NoteCourseCard = CardDS.NoteCourseCardV

/// note-text: mini lifehack-like block (shorter, denser)
public struct NoteTextCard: View {
    public let label: String
    public let text: String
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle

    public init(
        label: String = "заметка",
        text: String,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards
    ) {
        self.label = label
        self.text = text
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
    }

    public var body: some View {
        CardNoteBase(
            label: label,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .lineLimit(8)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// note-step: step-like mini card (same shell as CardNoteBase, step-like content inside)
public struct NoteStepCard: View {
    public let label: String
    public let order: Int?
    public let wordTitle: String
    public let accentSubtitle: String
    public let meta: String

    public let showsProBadge: Bool

    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle

    public init(
        label: String = "шаг",
        order: Int? = nil,
        wordTitle: String,
        accentSubtitle: String,
        meta: String,
        showsProBadge: Bool = true,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteStepHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards
    ) {
        self.label = label
        self.order = order
        self.wordTitle = wordTitle
        self.accentSubtitle = accentSubtitle
        self.meta = meta
        self.showsProBadge = showsProBadge
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
    }

    public var body: some View {
        CardNoteBase(
            label: nil,
            topTrailing: AnyView(
                Group {
                    if showsProBadge {
                        AppProChip(title: "pro")
                    }
                }
            ),
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            contentTopSpacer: 0,
            contentBottomSpacer: 0,
            contentInsetsY: 12,
            content: {
                // centered step preview text
                VStack(spacing: 10) {
                    Text(wordTitle.lowercased())
                        .font(.taikaTitle(22))
                        .foregroundStyle(CD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)

                    Text(accentSubtitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)

                    Text(meta.lowercased())
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .lineSpacing(1)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            },
            bottom: {
                // bottom chip centered horizontally (improved centering)
                let chipTitle = order.map { "\($0). \(label.lowercased())" } ?? label.lowercased()
                HStack {
                    AppMiniChip(
                        title: chipTitle,
                        style: .neutral
                    ) { }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, CardDS.Metrics.noteBottomPadding)
            }
        )
    }
}



// shared pill shape for taika bubbles (no tail)
fileprivate struct TaikaBubblePillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corner = min(rect.height / 2, 22)
        let bodyRect = rect.insetBy(dx: 0, dy: 0)
        path.addRoundedRect(
            in: bodyRect,
            cornerSize: CGSize(width: corner, height: corner)
        )
        return path
    }
}

// MARK: - Taika FM message bubble (universal shell)
public struct TaikaFMBubble<Content: View>: View {
    public let label: String
    public let reactions: [String]
    public let onReactionTap: ((String) -> Void)?
    private let content: Content

    /// универсальный бабл: сюда кладём только контент сообщения.
    /// заголовок «taika fm» и прочие подписи живут в соответствующих DS.
    public init(
        label: String = "taika fm",
        reactions: [String] = [],
        onReactionTap: ((String) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.reactions = reactions
        self.onReactionTap = onReactionTap
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // аватар таики слева (единый по приложению)
            Image("mascot.course")
                .resizable()
                .scaledToFit()
                .scaleEffect(x: -1, y: 1, anchor: .center) // смотрит в сторону бабла
                .frame(width: 60, height: 60)

            // сам чат‑бабл — максимально близко к привычным мессенджерам
            ZStack(alignment: .bottomTrailing) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 64)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(
                        Theme.Surfaces.card(
                            TaikaBubblePillShape()
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320, alignment: .leading)
                // reactions UI removed
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Search bubble (same layout as TaikaFMBubble, but with mascot.profile + search field)
public struct TaikaSearchBubble: View {
    @Binding public var query: String
    public let placeholder: String
    public let onSubmit: ((String) -> Void)?

    public init(
        query: Binding<String>,
        placeholder: String = "поиск",
        onSubmit: ((String) -> Void)? = nil
    ) {
        self._query = query
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // mascot for search
            Image("mascot.profile")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)

            // bubble with search chrome
            ZStack(alignment: .center) {
                HStack(spacing: 10) {
                    TextField("", text: $query, prompt: Text(placeholder).foregroundStyle(CD.ColorToken.textSecondary.opacity(0.75)))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.text)
                        .tint(ThemeManager.shared.currentAccentFill)
                        .submitLabel(.search)
                        .onSubmit { onSubmit?(query) }

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)

                    if !query.isEmpty {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            query = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Theme.Surfaces.card(
                        TaikaBubblePillShape()
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Taika FM message bubble typing animation

// lightweight inline chunk model for [[accent]] parsing inside TaikaFMBubbleTyping
fileprivate struct TaikaFMInlineChunk {
    let text: String
    let isAccent: Bool
}

/// simple [[...]] parser: splits string into chunks and marks accent segments
fileprivate func taikaFMParseAccentChunks(_ raw: String) -> [TaikaFMInlineChunk] {
    var result: [TaikaFMInlineChunk] = []
    var buffer = ""
    var isAccent = false

    var index = raw.startIndex

    func flushBuffer() {
        guard !buffer.isEmpty else { return }
        result.append(TaikaFMInlineChunk(text: buffer, isAccent: isAccent))
        buffer.removeAll(keepingCapacity: true)
    }

    while index < raw.endIndex {
        if raw[index...].hasPrefix("[[") {
            flushBuffer()
            isAccent = true
            index = raw.index(index, offsetBy: 2)
            continue
        }
        if raw[index...].hasPrefix("]]") {
            flushBuffer()
            isAccent = false
            index = raw.index(index, offsetBy: 2)
            continue
        }

        buffer.append(raw[index])
        index = raw.index(after: index)
    }

    flushBuffer()
    return result
}

/// builds styled Text from raw TaikaFM string, mirroring LessonsDS accent behaviour
fileprivate func taikaFMStyledText(_ s: String) -> Text {
    let chunks = taikaFMParseAccentChunks(s)
    guard !chunks.isEmpty else {
        return Text(s).foregroundStyle(CD.ColorToken.text)
    }

    var result = Text("")
    for chunk in chunks {
        let base = Text(chunk.text)
        if chunk.isAccent {
            result = result + base.foregroundStyle(ThemeManager.shared.currentAccentFill)
        } else {
            result = result + base.foregroundStyle(CD.ColorToken.text)
        }
    }
    return result
}

public struct TaikaFMBubbleTyping: View {
    public let messages: [String]
    public let reactions: [[String]]
    public let repeats: Bool

    private enum Phase {
        case typing
        case showing
    }

    @State private var phase: Phase = .typing
    @State private var phaseStart: Date = .init()
    @State private var dotsStep: Int = 0
    @State private var currentIndex: Int = 0
    @State private var didCompleteCycle: Bool = false

    // один таймер, который крутит и точки, и фазы
    @State private var timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    /// основной инициализатор: массив сообщений + опциональные реакции
    public init(messages: [String], reactions: [[String]] = [], repeats: Bool = true) {
        self.messages = messages
        self.reactions = reactions
        self.repeats = repeats
    }

    /// совместимость со старым контрактом (один текст, без реакций)
    public init(text: String, repeats: Bool = true) {
        self.init(messages: [text], reactions: [], repeats: repeats)
    }

    private var currentText: String {
        guard !messages.isEmpty else { return "" }
        let safeIndex = min(currentIndex, messages.count - 1)
        return messages[safeIndex]
    }

    private var currentReactions: [String] {
        guard !reactions.isEmpty else { return [] }
        let safeIndex = min(currentIndex, reactions.count - 1)
        return reactions[safeIndex]
    }

    public var body: some View {
        let bubbleReactions: [String] = []
        TaikaFMBubble(label: "taika fm", reactions: [], onReactionTap: nil) {
            Group {
                switch phase {
                case .typing:
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { idx in
                            Circle()
                                .frame(width: 6, height: 6)
                                .foregroundStyle(CD.ColorToken.text.opacity(0.85))
                                .opacity(dotsStep >= idx ? 1.0 : 0.25)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 13, weight: .regular))

                case .showing:
                    taikaFMStyledText(currentText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            phase = .typing
            phaseStart = Date()
            dotsStep = 0
            currentIndex = 0
            didCompleteCycle = false
        }
        .onDisappear {
            phase = .typing
            dotsStep = 0
            currentIndex = 0
            didCompleteCycle = false
        }
        .onReceive(timer) { _ in
            // special case: no messages (e.g. step lifehack) — keep typing dots forever
            if messages.isEmpty {
                phase = .typing
                dotsStep = (dotsStep + 1) % 4
                return
            }
            // если цикл уже один раз прошёл и repeats == false — просто держим последнее сообщение

            let now = Date()
            let typingDuration: TimeInterval = 1.8   // сколько таика "печатает"
            let showDuration: TimeInterval = 6.0     // сколько держим показанным текст

            switch phase {
            case .typing:
                // анимируем точки, пока идёт фаза печати
                dotsStep = (dotsStep + 1) % 4
                if now.timeIntervalSince(phaseStart) >= typingDuration {
                    phase = .showing
                    phaseStart = now
                }

            case .showing:
                // если ещё есть следующие сообщения — переходим к следующему
                if now.timeIntervalSince(phaseStart) >= showDuration {
                    let lastIndex = max(0, messages.count - 1)
                    if currentIndex < lastIndex {
                        currentIndex += 1
                        phase = .typing
                        phaseStart = now
                        dotsStep = 0
                    } else {
                        // достигли конца списка
                        if repeats {
                            currentIndex = 0
                            phase = .typing
                            phaseStart = now
                            dotsStep = 0
                        } else {
                            didCompleteCycle = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Inline progress view for CourseLessonCard (matches WeeklyResumeCell style)
fileprivate struct CourseInlineProgressView: View {
    let fraction: Double

    var body: some View {
        let clamped = fraction.clamped01
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let barH: CGFloat = 6
                RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: w, height: barH)
                    .overlay(
                        RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                            .fill(ThemeManager.shared.currentAccentFill)
                            .frame(
                                width: max(0, w * CGFloat(clamped)),
                                height: barH
                            ),
                        alignment: .leading
                    )
            }
            .frame(height: 12)

            Text("\(Int(clamped * 100))% пройдено")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
        }
    }
}

// MARK: - Ready wrapper for Course/Lesson cards (uses AppDS atoms)
public struct CourseLessonCard: View {
    // Content
    public let title: String
    public let subtitle: String?
    public let lessonsCount: Int?
    public let durationText: String?
    public let statusKind: AppStatusKind?
    public let courseCategory: String?
    public let isPro: Bool
    public let tags: [String]
    public let brandText: String?

    // Layout
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle

    // CTA
    public let primaryCTA: AppCTAType
    public let scale: AppCTAScale

    // Actions
    public let onPrimaryTap: (() -> Void)?

    // Icon states (visual-only here)
    public let isFavoriteActive: Bool
    public let isConsoleEnabled: Bool
    // Drives console availability based on lesson completion
    public let completionFraction: Double?

    // Controls whether we show inline progress on the card face
    public let showsInlineProgress: Bool

    // Optional favorite counter (if set, we show counter instead of toggle)
    public let favoriteCount: Int?

    // Optional taps (can be nil to keep visual-only)
    public let onFavoriteTap: (() -> Void)?
    public let onConsoleTap: (() -> Void)?

    // Icons
    public let showFavorite: Bool
    public let showConsole: Bool

    // Optional visual modifiers for carousel (non-breaking; default = identity)
    public let visualScale: CGFloat
    public let visualOpacity: CGFloat
    public let visualRotateY: Double

    @State private var isMetaBubbleVisible: Bool = false


    public init(
        title: String,
        subtitle: String? = nil,
        lessonsCount: Int? = nil,
        durationText: String? = nil,
        statusKind: AppStatusKind? = nil,
        courseCategory: String? = nil,
        isPro: Bool = false,
        tags: [String] = [],
        brandText: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.courseWidth, height: CardDS.Metrics.courseHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        primaryCTA: AppCTAType = .start,
        scale: AppCTAScale = .s,
        showFavorite: Bool = true,
        showConsole: Bool = true,
        onPrimaryTap: (() -> Void)? = nil,
        isFavoriteActive: Bool = false,
        isConsoleEnabled: Bool = false,
        completionFraction: Double? = nil,
        favoriteCount: Int? = nil,
        onFavoriteTap: (() -> Void)? = nil,
        onConsoleTap: (() -> Void)? = nil,
        showsInlineProgress: Bool = false,
        visualScale: CGFloat = 1.0,
        visualOpacity: CGFloat = 1.0,
        visualRotateY: Double = 0.0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.lessonsCount = lessonsCount
        self.durationText = durationText
        self.statusKind = statusKind
        self.courseCategory = courseCategory
        self.isPro = isPro
        self.tags = tags
        self.brandText = brandText
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.primaryCTA = primaryCTA
        self.scale = scale
        self.showFavorite = showFavorite
        self.showConsole = showConsole
        self.onPrimaryTap = onPrimaryTap
        self.isFavoriteActive = isFavoriteActive
        self.isConsoleEnabled = isConsoleEnabled
        self.completionFraction = completionFraction
        self.favoriteCount = favoriteCount
        self.onFavoriteTap = onFavoriteTap
        self.onConsoleTap = onConsoleTap
        self.showsInlineProgress = showsInlineProgress
        self.visualScale = visualScale
        self.visualOpacity = visualOpacity
        self.visualRotateY = visualRotateY
    }

    public var body: some View {
        let consoleIsEnabled = isConsoleEnabled || ((completionFraction ?? 0) >= 0.999)
        let metaInfo: String? = {
            var parts: [String] = []
            if let lessonsCount = lessonsCount {
                parts.append("\(lessonsCount) уроков")
            }
            if let durationText = durationText {
                parts.append(durationText)
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }()

        let progressFraction: Double? = showsInlineProgress ? (completionFraction ?? 0).clamped01 : nil

        let baseCard = CardBase(
            title: title.lowercased(),
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: true,
            isFluidWidth: false,
            brandText: brandText,
            top: {
                HStack(alignment: .top, spacing: 8) {
                    Text("taikA")
                        .font(.taikaLogo(16))
                        .foregroundStyle(CD.ColorToken.text)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        if let statusKind {
                            AppStatusChip(kind: statusKind)
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 0)
            },
            bottom: {
                HStack(spacing: 24) {
                    AppCardIconButton(
                        kind: .info,
                        isActive: isMetaBubbleVisible,
                        onTap: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                isMetaBubbleVisible.toggle()
                            }
                        }
                    )
                    AppCardIconButton(
                        kind: .console,
                        isEnabled: consoleIsEnabled,
                        onTap: { onConsoleTap?() }
                    )
                    AppCardIconButton(
                        kind: .favorite,
                        isActive: isFavoriteActive,
                        onTap: { onFavoriteTap?() }
                    )
                    AppCardIconButton(
                        kind: .play,
                        onTap: { onPrimaryTap?() }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 18)
                .overlay(alignment: .topLeading) {
                    if let metaInfo, isMetaBubbleVisible {
                        Text(metaInfo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CD.ColorToken.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(CD.ColorToken.card)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
                            .offset(x: 4, y: -36)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            },
            meta: {
                HStack(spacing: 8) {
                    if let courseCategory, !courseCategory.isEmpty {
                        AppMiniChip(
                            title: courseCategory.lowercased(),
                            style: .neutral
                        ) { }
                    }
                    if isPro {
                        AppProChip(title: "pro")
                    }
                }
                .padding(.bottom, 2)
            },
            tags: {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { t in
                        Text(t)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                }
            },
            belowTitle: {
                if let f = progressFraction {
                    CourseInlineProgressView(fraction: f)
                }
            }
        )

        return baseCard
            .fixedSize(horizontal: false, vertical: false)
            .compositingGroup()
            .scaleEffect(visualScale)
            .rotation3DEffect(.degrees(visualRotateY), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
            .opacity(visualOpacity)
            .frame(width: CardDS.Metrics.courseWidth, height: CardDS.Metrics.courseHeight)
            .padding(.horizontal, 0)
    }
}

// MARK: - Thailand calendar helpers (UI must match MainManager)
fileprivate enum BangkokCalendar {
    static let tz: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }()
}

// MARK: - WeeklyResumeStrip (7-day calendar style “Continue”)

// MARK: - WeeklyResumeStrip (7-day calendar style “Continue”)

/// Lightweight model for a single day cell.
public struct WeeklyResumeItem: Identifiable, Hashable {
    public let id = UUID()
    public let weekdayShort: String    // "Пн", "Вт", ...
    public let date: Date              // for comparisons
    public let title: String?          // optional short title
    public let progress: Double?       // 0...1 or nil
    public let secondaryTitle: String?
    public let secondaryProgress: Double?
    public let coursesCount: Int?
    public let isToday: Bool
    public let isEmpty: Bool
    /// optional daily counters for calendar card footer
    public let learnedCount: Int?
    public let favCount: Int?
    public let audioMinutes: Int?

    public var dayKey: String {
        let cal = BangkokCalendar.cal
        let dc = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", dc.year ?? 0, dc.month ?? 0, dc.day ?? 0)
    }

    public init(
        weekdayShort: String,
        date: Date,
        title: String? = nil,
        progress: Double? = nil,
        secondaryTitle: String? = nil,
        secondaryProgress: Double? = nil,
        coursesCount: Int? = nil,
        isToday: Bool = false,
        isEmpty: Bool = false,
        learnedCount: Int? = nil,
        favCount: Int? = nil,
        audioMinutes: Int? = nil
    ) {
        self.weekdayShort = weekdayShort
        self.date = date
        self.title = title
        self.progress = progress
        self.secondaryTitle = secondaryTitle
        self.secondaryProgress = secondaryProgress
        self.coursesCount = coursesCount
        self.isToday = isToday
        self.isEmpty = isEmpty
        self.learnedCount = learnedCount
        self.favCount = favCount
        self.audioMinutes = audioMinutes
    }
}

public enum WeeklyResumeLayout { case board, row, carousel }

// lightweight day summary adapter so CardDS can render the same panel as MainDS without importing it
public struct CardDS_DaySummary {
    public let learned: Int
    public let favs: Int
    public let audioMinutes: Int
    public init(learned: Int, favs: Int, audioMinutes: Int) {
        self.learned = learned
        self.favs = favs
        self.audioMinutes = audioMinutes
    }
}

// Helper to avoid overlay type-inference ambiguity
fileprivate struct DayBadgeBorder: View {
    let isToday: Bool
    var body: some View {
        Capsule()
            .stroke(isToday ? Color.black.opacity(0.10) : Color.white.opacity(0.10), lineWidth: 1)
    }
}

// MARK: - Weekly calendar atoms (exposed for reuse in MainDS)
public struct WeeklyDayBadge: View {
    let item: WeeklyResumeItem
    let isSelected: Bool
    public var body: some View {
        // Precompute values to help the type-checker
        let dayNumber = BangkokCalendar.cal.component(.day, from: item.date)
        let isToday = BangkokCalendar.cal.isDateInToday(item.date)

        HStack(spacing: 6) {
            Text(item.weekdayShort.uppercased())
                .font(.system(size: 11, weight: .bold))
            Text("\(dayNumber)")
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.9)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(CD.ColorToken.text)
        .background(
            Capsule(style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(CD.ColorToken.stroke.opacity(0.35), lineWidth: 1)
                )
        )
        .overlay(
            Group {
                if isSelected {
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 2)
                }
            }
        )
    }
}

fileprivate struct WeeklyResumePill: View {
    let item: WeeklyResumeItem
    let isSelected: Bool
    let onTap: (WeeklyResumeItem) -> Void
    var body: some View {
        Button(action: { onTap(item) }) {
            WeeklyDayBadge(item: item, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.weekdayShort), \(BangkokCalendar.cal.component(.day, from: item.date))"))
    }
}


/// Small cell view for a single day (uses AppDS visual tokens through CD.ColorToken).
/// small calendar day cell used by WeeklyResumeStrip.
/// shows a weekday badge + a mini card area with optional progress bar.
/// public so it can be previewed or composed directly in MainDS without using the full strip.

// unified counters panel (matches MainDS pill style)

fileprivate struct WeeklyAppIconChip: View {
    enum Kind {
        case courses
        case planned
    }

    let kind: Kind
    let count: Int

    private var iconName: String {
        switch kind {
        case .courses: return "graduationcap.fill"
        case .planned: return "alarm.fill"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .opacity(0.95)

            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.92)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(CD.ColorToken.text)
        .background(
            Capsule(style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(CD.ColorToken.stroke.opacity(0.35), lineWidth: 1)
                )
        )
        .frame(height: 24)
    }
}

public struct WeeklyResumeCell: View {
    let item: WeeklyResumeItem
    let isSelected: Bool
    let onTap: (WeeklyResumeItem) -> Void
    // optional adapter for pulling real DaySummary from MainDS (by date)
    let daySummaryProvider: ((Date) -> CardDS_DaySummary?)?

    public init(
        item: WeeklyResumeItem,
        isSelected: Bool,
        onTap: @escaping (WeeklyResumeItem) -> Void,
        daySummaryProvider: ((Date) -> CardDS_DaySummary?)? = nil
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onTap = onTap
        self.daySummaryProvider = daySummaryProvider
    }

    public var body: some View {
        // calendar cell background
        let cellShape = RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous)

        let cal = BangkokCalendar.cal
        let todayStart = cal.startOfDay(for: Date())
        let itemDayStart = cal.startOfDay(for: item.date)

        let isTrulyEmpty: Bool = item.isEmpty || ((item.title == nil || item.title?.isEmpty == true) && item.progress == nil)
        let isPastEmptyDay: Bool = isTrulyEmpty && itemDayStart < todayStart
        let isDisabled: Bool = isPastEmptyDay
        let isPastDay: Bool = itemDayStart < todayStart

        let tapAction: () -> Void = {
            if isDisabled { return }
            onTap(item)
        }

        let primaryCount: Int = (item.title == nil || item.title?.isEmpty == true) ? 0 : 1
        let secondaryCount: Int = (item.secondaryTitle == nil || item.secondaryTitle?.isEmpty == true) ? 0 : 1
        let inferredCoursesCount: Int = primaryCount + secondaryCount
        let totalCoursesCount: Int = item.coursesCount ?? inferredCoursesCount
        // planned-only: course(s) selected for the day, but no learning activity yet
        let isPlannedOnly: Bool = totalCoursesCount > 0
            && (item.learnedCount ?? 0) == 0
            && (item.favCount ?? 0) == 0
            && (item.audioMinutes ?? 0) == 0
            && ((item.progress ?? 0) <= 0.0001)
            && ((item.secondaryProgress ?? 0) <= 0.0001)

        let isTodayDay: Bool = BangkokCalendar.cal.isDateInToday(item.date)
        let isTodayPlanned: Bool = isTodayDay && isPlannedOnly

        // planned state (works for both: empty planned stub and chosen planned day)
        let isPlanned: Bool = totalCoursesCount > 0
            && (item.learnedCount ?? 0) == 0
            && (item.favCount ?? 0) == 0
            && (item.audioMinutes ?? 0) == 0
            && ((item.progress ?? 0) <= 0.0001)
            && ((item.secondaryProgress ?? 0) <= 0.0001)
        let isPastPlannedFailed: Bool = isPastDay && totalCoursesCount > 0 && isPlanned

        let coursesChipView: AnyView = {
            if totalCoursesCount > 0 {
                return AnyView(
                    Group {
                        if isPlanned {
                            WeeklyAppIconChip(kind: .planned, count: totalCoursesCount)
                        } else {
                            WeeklyAppIconChip(kind: .courses, count: totalCoursesCount)
                        }
                    }
                    .offset(y: 16)
                )
            }
            return AnyView(EmptyView())
        }()

        return Button(action: tapAction) {
            VStack(spacing: 12) {
                WeeklyDayBadge(item: item, isSelected: isSelected)
                    .frame(maxWidth: .infinity, alignment: .center)

                // board cell — тот же surface, что и у остальных карточек, плюс stub title/progress
                ZStack {
                    CardChrome(style: .cards)
                        .clipShape(cellShape)
                        .overlay(
                            Group {
                                if isTodayPlanned {
                                    cellShape
                                        .stroke(ThemeManager.shared.currentAccentFill.opacity(0.55), lineWidth: 2)
                                }
                            }
                        )

                    if isTrulyEmpty {
                        VStack(spacing: 10) {
                            Spacer(minLength: 0)

                            VStack(spacing: 8) {
                                if isPastEmptyDay {
                                    if isPastPlannedFailed {
                                        Image(systemName: "alarm.waves.left.and.right")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                            .opacity(0.65)

                                        VStack(spacing: 4) {
                                            Text("план проспан")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("\(totalCoursesCount) курс\(totalCoursesCount == 1 ? "" : (totalCoursesCount >= 2 && totalCoursesCount <= 4 ? "а" : "ов")) • 0 из \(totalCoursesCount)")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    } else {
                                        Image(systemName: "moon.zzz.fill")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                            .opacity(0.65)

                                        VStack(spacing: 4) {
                                            Text("без активности")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("в этот день ты ничего не учил")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    }
                                } else {
                                    // empty day for today / future.
                                    let isTodayDay = BangkokCalendar.cal.isDateInToday(item.date)

                                    if isTodayDay {
                                        Image(systemName: "dice.fill")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)

                                        VStack(spacing: 4) {
                                            Text("случайный курс")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("тап → открыть рандомный курс")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 32, weight: .semibold))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)

                                        VStack(spacing: 4) {
                                            Text("добавить курс")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("выбрать курс на эту неделю")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 72)
                            .padding(.horizontal, 4)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .opacity(isPastEmptyDay ? 0.95 : 1.0)
                    } else {
                        // planned-only: keep "+" identity + show planned alarm + show chosen course names (no progress)
                        if isPlannedOnly {
                            VStack {
                                Spacer(minLength: 10)

                                VStack(alignment: .leading, spacing: 12) {
                                    // primary icon: future planned = plus, today planned = alarm (reminder)
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: isTodayDay ? "alarm.fill" : "plus")
                                            .font(.system(size: 26, weight: .semibold))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: 6) {
                                            // title(s)
                                            if let t = item.title, !t.isEmpty {
                                                Text(t.lowercased())
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(CD.ColorToken.text)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                    .minimumScaleFactor(0.85)
                                            } else {
                                                Text(BangkokCalendar.cal.isDateInToday(item.date) ? "план на сегодня" : "план на день")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(CD.ColorToken.text)
                                                    .lineLimit(1)
                                            }

                                            if let t2 = item.secondaryTitle, !t2.isEmpty {
                                                Text(t2.lowercased())
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.95))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.9)
                                            }

                                            Text("\(totalCoursesCount) курс\(totalCoursesCount == 1 ? "" : (totalCoursesCount >= 2 && totalCoursesCount <= 4 ? "а" : "ов")) • запланировано")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.88))
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: 0)
                                    }

                                    Text(isTodayDay ? "сегодня: тап → открыть • изменить план" : "тап → открыть • плюс → изменить")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                                        .lineLimit(1)
                                        .padding(.top, 2)
                                }

                                Spacer(minLength: 16)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            VStack {
                                // spacer to push content slightly down from the very top
                                Spacer(minLength: 10)

                                VStack(alignment: .leading, spacing: 10) {
                                    // first course
                                    if let t = item.title, !t.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(t.lowercased())
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .minimumScaleFactor(0.85)

                                            if let p = item.progress {
                                                let clamped = max(0.0, min(1.0, p))
                                                VStack(alignment: .leading, spacing: 4) {
                                                    GeometryReader { geo in
                                                        let w = geo.size.width
                                                        let barH: CGFloat = 6
                                                        RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                            .fill(Color.white.opacity(0.14))
                                                            .frame(width: w, height: barH)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                                    .fill(ThemeManager.shared.currentAccentFill)
                                                                    .frame(
                                                                        width: max(0, w * CGFloat(clamped)),
                                                                        height: barH
                                                                    ),
                                                                alignment: .leading
                                                            )
                                                    }
                                                    .frame(height: 12)

                                                    Text("\(Int(clamped * 100))% пройдено")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                }
                                            }
                                        }
                                    }

                                    // second course (optional)
                                    if let t2 = item.secondaryTitle, !t2.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(t2.lowercased())
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .minimumScaleFactor(0.85)

                                            if let p2 = item.secondaryProgress {
                                                let clamped2 = max(0.0, min(1.0, p2))
                                                VStack(alignment: .leading, spacing: 4) {
                                                    GeometryReader { geo in
                                                        let w = geo.size.width
                                                        let barH: CGFloat = 6
                                                        RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                            .fill(Color.white.opacity(0.14))
                                                            .frame(width: w, height: barH)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                                    .fill(ThemeManager.shared.currentAccentFill)
                                                                    .frame(
                                                                        width: max(0, w * CGFloat(clamped2)),
                                                                        height: barH
                                                                    ),
                                                                alignment: .leading
                                                            )
                                                    }
                                                    .frame(height: 12)

                                                    Text("\(Int(clamped2 * 100))% пройдено")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                }
                                            }
                                        }
                                    }
                                }

                                // extra spacer so content не прилипает к низу, но и не уезжает слишком высоко
                                Spacer(minLength: 16)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
                .overlay(coursesChipView, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .contentShape(cellShape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(item.weekdayShort), \(BangkokCalendar.cal.component(.day, from: item.date))")
        )
    }
}

// production: use .carousel; .board/.row are legacy/preview-only
/// Seven-day horizontal strip. Supply exactly 7 items for a full week.
public struct WeeklyResumeStrip: View {
    public let items: [WeeklyResumeItem]            // legacy: can be empty when using provider
    public let onTapDay: (WeeklyResumeItem) -> Void
    public let layout: WeeklyResumeLayout
    @State private var selected: WeeklyResumeItem?
    @State private var didInitialCenter: Bool = false

    // optional, used to fetch real DaySummary from MainDS by date
    public let daySummaryProvider: ((Date) -> CardDS_DaySummary?)?

    // NEW: optional provider for week-based data and current offset from the current week (0 = this week)
    public let weekProvider: ((Int) -> [WeeklyResumeItem])?
    @State private var itemsState: [WeeklyResumeItem] = []

    // Legacy init — uses static items (no week navigation)
    public init(items: [WeeklyResumeItem], layout: WeeklyResumeLayout = .board, daySummaryProvider: ((Date) -> CardDS_DaySummary?)? = nil, onTapDay: @escaping (WeeklyResumeItem) -> Void) {
        self.items = items
        self.onTapDay = onTapDay
        self.weekProvider = nil
        self.layout = layout
        self.daySummaryProvider = daySummaryProvider
        _itemsState = State(initialValue: [])
        let defaultSelected = items.first(where: { $0.isToday })
            ?? items.first(where: { ($0.progress ?? 0) > 0 })
            ?? items.first
        _selected = State(initialValue: defaultSelected)
    }

    // New init — supplies a provider for fixed-week data (supports swipe between weeks)
    public init(weekProvider: @escaping (Int) -> [WeeklyResumeItem], layout: WeeklyResumeLayout = .board, daySummaryProvider: ((Date) -> CardDS_DaySummary?)? = nil, onTapDay: @escaping (WeeklyResumeItem) -> Void) {
        self.items = []
        self.onTapDay = onTapDay
        self.weekProvider = weekProvider
        self.layout = layout
        self.daySummaryProvider = daySummaryProvider

        // Fetch initial items from provider once; no week navigation logic here
        let baseItems = weekProvider(0)
        _itemsState = State(initialValue: baseItems)

        let defaultSelected = baseItems.first(where: { $0.isToday })
            ?? baseItems.first(where: { ($0.progress ?? 0) > 0 })
            ?? baseItems.first
        _selected = State(initialValue: defaultSelected)
    }

    public var body: some View {
        let currentItems: [WeeklyResumeItem] = {
            if weekProvider == nil { return items }
            return itemsState.isEmpty ? items : itemsState
        }()
        // decide columns: 7 -> board mode (4 columns => 2 rows 4+3), 8–10 -> 5 columns, otherwise compact
        let columnsCount: Int = {
            if currentItems.count == 7 { return 4 }
            if currentItems.count >= 8 { return 5 }
            return max(3, currentItems.count)
        }()
        let cellSpacing: CGFloat = 20
        let columns = Array(repeating: GridItem(.flexible(), spacing: cellSpacing, alignment: .top), count: columnsCount)
        // grid of big day cards
        let board = LazyVGrid(columns: columns, alignment: .center, spacing: cellSpacing) {
            ForEach(currentItems) { item in
                let isSel: Bool = {
                    if let s = selected { return BangkokCalendar.cal.isDate(s.date, inSameDayAs: item.date) }
                    return false
                }()
                WeeklyResumeCell(item: item, isSelected: isSel, onTap: { tapped in
                    onTapDay(tapped)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { selected = tapped }
                }, daySummaryProvider: daySummaryProvider)
            }
        }
        .padding(.horizontal, CardDS.Metrics.contentX)
        .padding(.top, 6)
        .padding(.bottom, 2)
        // (gesture removed)

        let row = ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(currentItems) { item in
                    let isSel: Bool = {
                        if let s = selected { return BangkokCalendar.cal.isDate(s.date, inSameDayAs: item.date) }
                        return false
                    }()
                    WeeklyResumeCell(item: item, isSelected: isSel, onTap: { tapped in
                        onTapDay(tapped)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { selected = tapped }
                    }, daySummaryProvider: daySummaryProvider)
                }
            }
            .padding(.horizontal, CardDS.Metrics.contentX)
            .padding(.vertical, 8)
        }

        let carousel = GeometryReader { outer in
            // compute side inset so the first/last cell can sit centered in the viewport
            let cellW = CardDS.Metrics.weeklyCellWidth * 1.5
            let sideInset = max(0, (outer.size.width - cellW) / 2)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: CardDS.Metrics.carouselSpacing * 0.5) {
                        ForEach(currentItems) { item in
                            GeometryReader { cellGeo in
                                let isSel: Bool = {
                                    if let s = selected { return BangkokCalendar.cal.isDate(s.date, inSameDayAs: item.date) }
                                    return false
                                }()
                                // distance of cell midX to the visible viewport center
                                let viewportCenterX = outer.size.width / 2
                                let cellCenterX = cellGeo.frame(in: .named("weeklyCarousel")).midX
                                let dist = abs(cellCenterX - viewportCenterX)
                                // normalize and derive visual weights (with 3D rotation)
                                let norm = min(1.0, dist / max(1.0, outer.size.width * 0.65))
                                let scale = 0.85 + 0.25 * (1.0 - norm)   // center ≈1.10, sides ≈0.85 (stronger depth)
                                let opacity = 0.45 + 0.55 * (1.0 - norm) // center 1.0, sides ≈0.45

                                WeeklyResumeCell(item: item, isSelected: isSel, onTap: { tapped in
                                    if !(selected?.date == tapped.date) {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    onTapDay(tapped)
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                        selected = tapped
                                        proxy.scrollTo(item.dayKey, anchor: .center)
                                    }
                                }, daySummaryProvider: daySummaryProvider)
                                .frame(width: CardDS.Metrics.weeklyCellWidth * 1.5, height: CardDS.Metrics.weeklyCellHeight)
                                .padding(.horizontal, 4)
                                .scaleEffect(scale)
                                .rotation3DEffect(
                                    .degrees(Double((cellCenterX - viewportCenterX) / -10.0)),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.8
                                )
                                .opacity(opacity)
                                .shadow(color: Color.black.opacity(scale >= 1.08 ? 0.28 : 0.10),
                                        radius: scale >= 1.08 ? 8 : 2,
                                        x: 0,
                                        y: scale >= 1.08 ? 3 : 1)
                                .zIndex(Double(1.0 - norm))
                            }
                            .frame(width: CardDS.Metrics.weeklyCellWidth * 1.5, height: CardDS.Metrics.weeklyCellHeight)
                            .id(item.dayKey)
                        }
                    }
                    .padding(.horizontal, sideInset)
                }
                .onAppear {
                    // center only once on initial render; never auto-recenter later
                    guard didInitialCenter == false else { return }
                    didInitialCenter = true
                    if let sel = selected {
                        proxy.scrollTo(sel.dayKey, anchor: .center)
                    }
                }
            }
            .coordinateSpace(name: "weeklyCarousel")
        }
        .frame(height: CardDS.Metrics.weeklyCellHeight + 80)

        return VStack(spacing: 12) {
            switch layout {
            case .board:
                board
            case .row:
                row
            case .carousel:
                carousel
            }
        }
        .padding(.top, 8)
        .background(Color.clear)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 0)
        // .onAppear and .onReceive removed
        .onChange(of: items) { newItems in
            guard weekProvider == nil else { return }

            // keep current selection if it's still present in the newItems (same day)
            if let sel = selected, newItems.contains(where: { BangkokCalendar.cal.isDate($0.date, inSameDayAs: sel.date) }) {
                return
            }

            let defaultSelected = newItems.first(where: { BangkokCalendar.cal.isDateInToday($0.date) })
                ?? newItems.first(where: { ($0.progress ?? 0) > 0 })
                ?? newItems.first

            selected = defaultSelected
            // allow initial centering again only if selection became nil (rare)
            if selected == nil { didInitialCenter = false }
        }
    }
}


// MARK: - StepWordCard (DS atom: large word card)
public struct StepWordCard: View {
    public let title: String       // русское слово, крупным
    public let translit: String    // латиницей, акцентным цветом
    public let thai: String        // тайский текст, вторичный
    public let label: String       // чип в правом верхнем углу, по умолчанию "слово"
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let phoneticView: AnyView?
    public let isFavorite: Bool
    public let isLearned: Bool
    public let allowLearn: Bool
    public let onPlay: (() -> Void)?
    public let onFavorite: () -> Void
    public let onLearn: () -> Void

    public init(
        title: String,
        translit: String,
        thai: String,
        label: String = "слово",
        size: CGSize = CGSize(width: CardDS.Metrics.stepWordWidth, height: CardDS.Metrics.stepWordHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        phoneticView: AnyView? = nil,
        isFavorite: Bool = false,
        isLearned: Bool = false,
        allowLearn: Bool = true,
        onPlay: (() -> Void)? = nil,
        onFavorite: @escaping () -> Void = {},
        onLearn: @escaping () -> Void = {}
    ) {
        self.title = title
        self.translit = translit
        self.thai = thai
        self.label = label
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.phoneticView = phoneticView
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.allowLearn = allowLearn
        self.onPlay = onPlay
        self.onFavorite = onFavorite
        self.onLearn = onLearn
    }

    public var body: some View {
        CardBase(
            title: title,
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            top: {
                HStack {
                    Text("taikA")
                        .font(.taikaLogo(16))
                        .foregroundStyle(CD.ColorToken.text)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        let chipLabel = label.lowercased()

                        AppMiniChip(
                            title: chipLabel,
                            style: (chipLabel == "лайфхак" || chipLabel == "запомнил")
                                ? .accent
                                : .neutral
                        ) { }
                    }
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .padding(.top, 8)
            },
            bottom: {
                StepCardActionBar(
                    isFavorite: isFavorite,
                    isLearned: isLearned,
                    allowLearn: allowLearn,
                    isTip: false,
                    onPlay: onPlay,
                    onFavorite: onFavorite,
                    onLearn: onLearn,
                    onNext: nil
                )
            },
            meta: {
                VStack(spacing: 0) {
                    // чуть больше воздуха сверху и снизу относительно текстового блока
                    Spacer(minLength: 16)
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.taikaTitle(28))
                            .foregroundStyle(CD.ColorToken.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)

                        if let phoneticView {
                            phoneticView
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .allowsTightening(true)
                        } else {
                            phoneticStyledText(translit)
                                .font(.system(size: 17, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .allowsTightening(true)
                        }

                        // тайский делаем чуть спокойнее и отделяем дополнительным отступом,
                        // чтобы фокус был на первых двух строках
                        Text(thai)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, CardDS.Metrics.contentX)
                .padding(.vertical, 18)
            },
            tags: {
                EmptyView()
            },
            belowTitle: {
                EmptyView()
            }
        )
    }
}

fileprivate func phoneticStyledText(_ s: String) -> Text {
    // всё, что без ударения — вторичный цвет текста;
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

    // быстрый путь: если нет ни одного ударения — просто вторичный цвет
    guard s.unicodeScalars.contains(where: { accentScalars.contains($0) }) else {
        return Text(s).foregroundStyle(CD.ColorToken.textSecondary.opacity(0.96))
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
            result = result + base.foregroundStyle(CD.ColorToken.textSecondary.opacity(0.96))
        }
        currentChunk = ""
    }

    for ch in s {
        if separators.contains(ch) {
            // сначала выкидываем накопленный слог
            flushChunk()
            // сам разделитель добавляем тонким серым
            let sepText = Text(String(ch))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.96))
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


fileprivate extension Double {
    var clamped01: Double { min(1, max(0, self)) }
}



fileprivate struct CardNoteCarouselPreviewView: View {
    fileprivate enum Item: Identifiable {
        case course(label: String, title: String, subtitle: String, progress: Double?, cta: String?)
        case text(label: String, text: String)
        case step(label: String, title: String)

        var id: String {
            switch self {
            case let .course(label, title, _, _, _):
                return "course:\(label):\(title)"
            case let .text(label, text):
                return "text:\(label):\(text.prefix(12))"
            case let .step(label, title):
                return "step:\(label):\(title)"
            }
        }
    }

    private let items: [Item] = [
        .course(label: "заметка", title: "как учиться", subtitle: "10 минут в день лучше, чем 2 часа раз в неделю.", progress: 0.42, cta: "продолжить"),
        .step(label: "шаг", title: "мини‑карточка"),
        .text(label: "лайфхак", text: "говори медленнее — тайцы ценят интонацию сильнее скорости. и да, паузы — это ок."),
        .course(label: "pro", title: "расширь подборку", subtitle: "открой pro и получи ещё карточки в подборке дня.", progress: nil, cta: "открыть pro"),
        .step(label: "слово", title: "как в избранном"),
        .text(label: "заметка", text: "если сегодня нет сил — просто открой один шаг. привычка важнее объёма.")
    ]

    var body: some View {
        GeometryReader { outer in
            let cardW: CGFloat = CardDS.Metrics.noteCardWidth
            let cardH: CGFloat = CardDS.Metrics.noteCardHeight
            let spacing: CGFloat = 15
            let sideInset: CGFloat = max(0, (outer.size.width - cardW) / 2)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                        let itemH: CGFloat = {
                            switch item {
                            case .step:
                                return CardDS.Metrics.noteStepHeight
                            default:
                                return cardH
                            }
                        }()
                        NoteCarouselCellPreview(
                            idx: idx,
                            item: item,
                            cardW: cardW,
                            cardH: itemH,
                            outerWidth: outer.size.width
                        )
                    }
                }
                .padding(.horizontal, sideInset)
                .padding(.vertical, 8)
            }
            .coordinateSpace(name: "noteCarouselPreview")
        }
    }

    // MARK: - cell preview (extracted to help the compiler)
    fileprivate struct NoteCarouselCellPreview: View {
        let idx: Int
        let item: Item
        let cardW: CGFloat
        let cardH: CGFloat
        let outerWidth: CGFloat

        var body: some View {
            GeometryReader { geo in
                // precompute all values outside of modifiers to help type-checker
                let viewportCenterX: CGFloat = outerWidth / 2
                let cellCenterX: CGFloat = geo.frame(in: .named("noteCarouselPreview")).midX
                let dist: CGFloat = abs(cellCenterX - viewportCenterX)
                let denom: CGFloat = max(1.0, outerWidth * 0.65)
                let norm: CGFloat = min(1.0, dist / denom)

                let scale: CGFloat = 0.90 + 0.16 * (1.0 - norm)
                let opacity: CGFloat = 0.45 + 0.55 * (1.0 - norm)
                let angleDeg: Double = Double((cellCenterX - viewportCenterX) / -14.0)

                content
                    .frame(width: cardW, height: cardH)
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
            }
            .frame(width: cardW, height: cardH)
            .id(idx)
        }

        @ViewBuilder
        private var content: some View {
            switch item {
            case let .course(label, title, subtitle, progress, cta):
                CardDS.NoteCourseCardV(
                    label: label,
                    categoryChip: nil,
                    title: title,
                    subtitle: subtitle,
                    progressFraction: progress,
                    ctaTitle: cta,
                    onCTATap: nil,
                    topRightChip: nil
                )

            case let .text(label, text):
                NoteTextCard(
                    label: label,
                    text: text,
                    size: CGSize(width: cardW, height: cardH),
                    sectionChrome: .seps,
                    chromeStyle: .cards
                )

            case let .step(label, title):
                NoteStepCard(
                    label: label,
                    wordTitle: title,
                    accentSubtitle: "мини‑превью шага",
                    meta: "6 карточек · pro",
                    showsProBadge: true,
                    size: CGSize(width: cardW, height: cardH),
                    sectionChrome: .seps,
                    chromeStyle: .cards
                )
            }
        }

        // lightweight stub extracted to reduce builder complexity
        fileprivate struct NoteStepMiniStub: View {
            var body: some View {
                HStack(spacing: 10) {
                    ForEach(1...6, id: \.self) { i in
                        Text("\(i)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(CD.ColorToken.card.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(CD.ColorToken.stroke.opacity(0.25), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct CardNoteBaseCarousel_Previews: PreviewProvider {
    static var previews: some View {
        CardNoteCarouselPreviewView()
            .frame(width: 680)
            .padding(12)
            .background(Color.black)
            .preferredColorScheme(.dark)
            .previewDisplayName("CardNoteBase — carousel (preview)")
            .environmentObject(ThemeManager.shared)
    }
}

struct WeeklyResumeCell_PlannedStub_Previews: PreviewProvider {
    static var previews: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let in2 = cal.date(byAdding: .day, value: 2, to: today) ?? today
        let in3 = cal.date(byAdding: .day, value: 3, to: today) ?? today


        // 2) planned-only with title + plus (your target after selecting 1 course from “+”)
        let plannedChosen = WeeklyResumeItem(
            weekdayShort: "ср",
            date: in2,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 1,
            isToday: false,
            isEmpty: false,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 3) planned-only with 2 courses chosen
        let plannedChosen2 = WeeklyResumeItem(
            weekdayShort: "чт",
            date: in3,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: "thai basics: food",
            secondaryProgress: 0.0,
            coursesCount: 2,
            isToday: false,
            isEmpty: false,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 3a) today planned (planned-only on today — should show accent outline)
        let todayPlanned = WeeklyResumeItem(
            weekdayShort: "пн",
            date: today,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 1,
            isToday: true,
            isEmpty: false,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 3b) today empty (random course dice state)
        let todayEmptyRandom = WeeklyResumeItem(
            weekdayShort: "пн",
            date: today,
            title: nil,
            progress: nil,
            coursesCount: 0,
            isToday: true,
            isEmpty: true,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 4) empty future day (plus)
        let emptyFuture = WeeklyResumeItem(
            weekdayShort: "пт",
            date: cal.date(byAdding: .day, value: 4, to: today) ?? today,
            title: nil,
            progress: nil,
            coursesCount: 0,
            isToday: false,
            isEmpty: true
        )

        // 5) past empty day (disabled “no activity” state)
        let pastEmpty = WeeklyResumeItem(
            weekdayShort: "вс",
            date: yesterday,
            title: nil,
            progress: nil,
            coursesCount: 0,
            isToday: false,
            isEmpty: true
        )

        // 5b) past planned but failed day (planned courses, no activity)
        let pastPlannedFailed = WeeklyResumeItem(
            weekdayShort: "ср",
            date: cal.date(byAdding: .day, value: -3, to: today) ?? today,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 2,
            isToday: false,
            isEmpty: true,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 6) active day (single course)
        let active = WeeklyResumeItem(
            weekdayShort: "пн",
            date: today,
            title: "thai basics",
            progress: 0.35,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 1,
            isToday: true,
            isEmpty: false,
            learnedCount: 4,
            favCount: 2,
            audioMinutes: 8
        )

        // 7) active day (two courses)
        let active2 = WeeklyResumeItem(
            weekdayShort: "сб",
            date: cal.date(byAdding: .day, value: -2, to: today) ?? today,
            title: "thai basics",
            progress: 0.62,
            secondaryTitle: "thai basics: food",
            secondaryProgress: 0.18,
            coursesCount: 2,
            isToday: false,
            isEmpty: false,
            learnedCount: 7,
            favCount: 1,
            audioMinutes: 12
        )

        let samples: [(String, WeeklyResumeItem, Bool)] = [
            ("planned chosen (title + plus)", plannedChosen, false),
            ("planned chosen (2 courses)", plannedChosen2, false),
            ("today planned (accent)", todayPlanned, true),
            ("today empty (random dice)", todayEmptyRandom, false),
            ("empty future (+)", emptyFuture, false),
            ("past empty (disabled)", pastEmpty, false),
            ("past planned failed", pastPlannedFailed, false),
            ("active (today)", active, true),
            ("active (2 courses)", active2, false)
        ]

        return ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.0.lowercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(.horizontal, 2)

                        WeeklyResumeCell(item: s.1, isSelected: s.2, onTap: { _ in })
                            .frame(width: 240, height: 300)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .environmentObject(ThemeManager.shared)
        .previewDisplayName("weekly resume — all states")
    }
}
// MARK: - shared word carousel (favorite + speaker)
public extension CardDS {

    // shared carousel model (used by Favorite + Speaker)
    struct CDWordCarouselItem: Identifiable, Hashable {
        public let id: String
        public let title: String            // ru
        public let phonetic: String         // latin
        public let thai: String             // thai
        public let label: String            // top-right chip

        // optional extra strings (Speaker can reuse)
        public let subtitle: String?        // optional
        public let meta: String?            // e.g. tone hint (optional)
        public let lessonTitle: String?     // optional (ignored for now)

        public let isFavorite: Bool
        public let isLearned: Bool

        public init(
            id: String,
            title: String,
            phonetic: String,
            thai: String,
            label: String = "слово",
            subtitle: String? = nil,
            meta: String? = nil,
            lessonTitle: String? = nil,
            isFavorite: Bool = false,
            isLearned: Bool = false
        ) {
            self.id = id
            self.title = title
            self.phonetic = phonetic
            self.thai = thai
            self.label = label
            self.subtitle = subtitle
            self.meta = meta
            self.lessonTitle = lessonTitle
            self.isFavorite = isFavorite
            self.isLearned = isLearned
        }
    }

    // shared mini card (visual parity with FavoriteDS word tile)
    struct CDWordMiniCard: View {
        public let item: CDWordCarouselItem
        public let size: CGSize

        public let onPlay: (() -> Void)?
        public let onFavorite: (() -> Void)?
        public let onPractice: (() -> Void)?

        @State private var showWave: Bool = false

        public init(
            item: CDWordCarouselItem,
            size: CGSize,
            onPlay: (() -> Void)? = nil,
            onFavorite: (() -> Void)? = nil,
            onPractice: (() -> Void)? = nil
        ) {
            self.item = item
            self.size = size
            self.onPlay = onPlay
            self.onFavorite = onFavorite
            self.onPractice = onPractice
        }

        public var body: some View {
            CardBase(
                title: item.title,
                subtitle: nil,
                size: size,
                sectionChrome: .seps,
                chromeStyle: .cards,
                showTitle: false,
                top: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("taikA")
                                .font(.taikaLogo(16))
                                .foregroundStyle(CD.ColorToken.text)

                            Spacer(minLength: 0)

                            // top-right tag: word/phrase/slang (card type)
                            if !item.label.isEmpty {
                                AppMiniChip(
                                    title: item.label.lowercased(),
                                    style: .neutral
                                ) { }
                            }
                        }
                    }
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.top, 12)
                },
                bottom: {
                    HStack {
                        Spacer(minLength: 0)

                        // lesson title chip (favorite-style accent capsule)
                        if let lessonTitle = item.lessonTitle, !lessonTitle.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.92))

                                Text(lessonTitle.lowercased())
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.92))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                Capsule().fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            )
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.bottom, 14)
                },
                meta: {
                    VStack(spacing: 0) {
                        Spacer(minLength: 18)

                        VStack(spacing: 12) {
                            // speaker control above the title (icon-only; waveform overlays inside the same capsule)
                            AppAudioWaveButton(isPlaying: showWave) {
                                onPlay?()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                    showWave = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showWave = false
                                    }
                                }
                            }
                            .accessibilityLabel(Text("прослушать"))

                            // ru title (primary)
                            Text(item.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(CD.ColorToken.text)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .allowsTightening(true)

                            // phonetic (accent)
                            phoneticStyledText(item.phonetic)
                                .font(.system(size: 16, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .allowsTightening(true)

                            // thai (secondary)
                            Text(item.thai)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .allowsTightening(true)

                            // optional meta (tone hint etc.)
                            if let m = item.meta, !m.isEmpty {
                                Text(m)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.9)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.vertical, 10)
                },
                tags: { EmptyView() },
                belowTitle: { EmptyView() }
            )
        }
    }

    // Small helper waveform view for CDWordMiniCard
    fileprivate struct CDMiniWaveform: View {
        let isActive: Bool

        init(isActive: Bool) {
            self.isActive = isActive
        }

        var body: some View {
            Group {
                if isActive {
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        bars(time: t)
                    }
                } else {
                    // static baseline (no animation)
                    bars(time: 0)
                }
            }
        }

        @ViewBuilder
        private func bars(time t: TimeInterval) -> some View {
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { i in
                    let base: CGFloat = 6
                    let amp: CGFloat = 10
                    let phase = t * 6.0 + Double(i) * 0.55
                    let h: CGFloat = isActive ? (base + abs(sin(phase)) * amp) : (base + (CGFloat(i % 3) * 2))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(CD.ColorToken.textSecondary.opacity(0.55))
                        .frame(width: 3, height: h)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.clear)
            )
        }
    }

    // shared carousel view (Favorite + Speaker)
    struct CDWordCarousel: View {
        public let items: [CDWordCarouselItem]
        public let cardSize: CGSize

        public let onPlay: ((CDWordCarouselItem) -> Void)?
        public let onFavorite: ((CDWordCarouselItem) -> Void)?
        public let onPractice: ((CDWordCarouselItem) -> Void)?
        public let onDelete: ((CDWordCarouselItem) -> Void)?

        @Binding public var isEditing: Bool

        public init(
            items: [CDWordCarouselItem],
            cardSize: CGSize = CGSize(width: 280, height: 220),
            isEditing: Binding<Bool> = .constant(false),
            onPlay: ((CDWordCarouselItem) -> Void)? = nil,
            onFavorite: ((CDWordCarouselItem) -> Void)? = nil,
            onPractice: ((CDWordCarouselItem) -> Void)? = nil,
            onDelete: ((CDWordCarouselItem) -> Void)? = nil
        ) {
            self.items = items
            self.cardSize = cardSize
            self._isEditing = isEditing
            self.onPlay = onPlay
            self.onFavorite = onFavorite
            self.onPractice = onPractice
            self.onDelete = onDelete
        }

        public var body: some View {
            GeometryReader { outer in
                let cardW = cardSize.width
                let cardH = cardSize.height
                let spacing: CGFloat = 14
                let sideInset: CGFloat = max(0, (outer.size.width - cardW) / 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: spacing) {
                        ForEach(items) { item in
                            GeometryReader { cellGeo in
                                let viewportCenterX: CGFloat = outer.size.width / 2
                                let cellCenterX: CGFloat = cellGeo.frame(in: .named("cdWordCarousel")).midX
                                let dist: CGFloat = abs(cellCenterX - viewportCenterX)
                                let denom: CGFloat = max(1.0, outer.size.width * 0.65)
                                let norm: CGFloat = min(1.0, dist / denom)

                                // favorite-style depth: center is bigger + clearer
                                let scale: CGFloat = 0.90 + 0.16 * (1.0 - norm)
                                let opacity: CGFloat = 0.55 + 0.45 * (1.0 - norm)
                                let angleDeg: Double = Double((cellCenterX - viewportCenterX) / -14.0)

                                CDWordCarouselCell(
                                    item: item,
                                    size: cardSize,
                                    isEditing: $isEditing,
                                    onPlay: { tapped in onPlay?(tapped) },
                                    onFavorite: { tapped in onFavorite?(tapped) },
                                    onPractice: { tapped in onPractice?(tapped) },
                                    onDelete: { tapped in onDelete?(tapped) }
                                )
                                .frame(width: cardW, height: cardH)
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
                            }
                            .frame(width: cardW, height: cardH)
                        }
                    }
                    .padding(.horizontal, sideInset)
                    .padding(.vertical, 8)
                }
            }
            .coordinateSpace(name: "cdWordCarousel")
            .frame(height: cardSize.height + 16)
        }

        // MARK: - single cell
        fileprivate struct CDWordCarouselCell: View {
            let item: CDWordCarouselItem
            let size: CGSize
            @Binding var isEditing: Bool

            let onPlay: (CDWordCarouselItem) -> Void
            let onFavorite: (CDWordCarouselItem) -> Void
            let onPractice: (CDWordCarouselItem) -> Void
            let onDelete: (CDWordCarouselItem) -> Void

            @State private var isJiggling: Bool = false

            var body: some View {
                CDWordMiniCard(
                    item: item,
                    size: size,
                    onPlay: { onPlay(item) },
                    onFavorite: { onFavorite(item) },
                    onPractice: { onPractice(item) }
                )
                .overlay(alignment: .topTrailing) {
                    if isEditing {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onDelete(item)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(CD.ColorToken.text)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(CD.ColorToken.card))
                                .overlay(
                                    Circle().stroke(CD.ColorToken.stroke.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
                .rotationEffect(.degrees(isEditing ? (isJiggling ? -1.2 : 1.2) : 0))
                .animation(
                    isEditing ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default,
                    value: isJiggling
                )
                .onChange(of: isEditing) { editing in
                    isJiggling = editing
                }
            }
        }
    }
}
