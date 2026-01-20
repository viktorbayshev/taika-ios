
//  MainDS.swift
//  taika
//
//  Created by product on 23.08.2025.
//


import SwiftUI
import Combine
import Foundation

// MARK: - Thailand canonical calendar (Asia/Bangkok) for DS date logic
fileprivate enum MDBangkokCalendar {
    static let tz: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }()
}

// MARK: - Brand gradient helper (local to MainDS)
private struct BrandGradient {
    // Unified accent gradient used across Main DS components
    private static let colors: [Color] = [
        // deeper start for better contrast, then the two brand-pinks
        Color(red: 0.96, green: 0.32, blue: 0.67),
        Color(red: 0.98, green: 0.52, blue: 0.80),
        Color(red: 0.91, green: 0.62, blue: 0.98)
    ]

    static let linear = LinearGradient(
        colors: colors,
        startPoint: .leading,
        endPoint: .trailing
    )
}

// Safe index access for arrays (file-scope)
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: CTA pill (sticker style)
private struct MDCTAPill: View {
    enum Style { case fill, outline }
    var title: String
    var icon: String? = nil
    var style: Style = .outline
    var shadowed: Bool = false
    var wide: Bool = false

    var body: some View {
        let label = HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(title)
        }
        .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
        .kerning(0.6)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Capsule())

        switch style {
        case .fill:
            label
                .foregroundStyle(Color.black)
                .background(Capsule().fill(BrandGradient.linear))
                .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
                .shadow(color: shadowed ? Color.black.opacity(0.15) : .clear, radius: 10, y: shadowed ? 6 : 0)
                .frame(height: 36)
                .frame(maxWidth: wide ? .infinity : nil, alignment: .center)
        case .outline:
            label
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .background(Capsule().fill(Color.clear))
                .overlay(Capsule().stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.2))
                .frame(height: 36)
                .frame(maxWidth: wide ? .infinity : nil, alignment: .center)
        }
    }
}


private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

public struct MDContinueSection: View {
    public var title: String
    public var items: [(String, Double)]
    public var onTap: (Int) -> Void

    public typealias BannerInfo = (title: String, progress: Double, category: String)
    public typealias WeeklyStats = (stars: Int, likes: Int, drills: Int)
    public var bannerProvider: ((Date) -> BannerInfo)? = nil
    public var weekProvider: ((Int) -> [WeeklyResumeItem])? = nil
    public var statsProvider: ((Int) -> WeeklyStats)? = nil // input: weekOffset
    public var onTapEmptyDay: ((WeeklyResumeItem) -> Void)? = nil
    public var onTapDaySummary: ((WeeklyResumeItem) -> Void)? = nil

    @State private var selected: Int = 3
    public var selectedIndex: Binding<Int>? = nil
    @State private var weekOffset: Int = 0
    @State private var didInit: Bool = false

    public init(
        _ title: String = "ПРОДОЛЖИТЬ",
        items: [(String, Double)],
        bannerProvider: ((Date) -> BannerInfo)? = nil,
        weekProvider: ((Int) -> [WeeklyResumeItem])? = nil,
        statsProvider: ((Int) -> WeeklyStats)? = nil,
        onTapEmptyDay: ((WeeklyResumeItem) -> Void)? = nil,
        onTapDaySummary: ((WeeklyResumeItem) -> Void)? = nil,
        selectedIndex: Binding<Int>? = nil,
        onTap: @escaping (Int) -> Void
    ) {
        self.title = title
        self.items = items
        self.bannerProvider = bannerProvider
        self.weekProvider = weekProvider
        self.statsProvider = statsProvider
        self.onTapEmptyDay = onTapEmptyDay
        self.onTapDaySummary = onTapDaySummary
        self.selectedIndex = selectedIndex
        self.onTap = onTap
    }


    public var body: some View {
        // Precompute week slice and header outside ViewBuilder
        let week: [WeeklyResumeItem] = {
            let cal = MDBangkokCalendar.cal
            let now = Date()
            let startThisWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startThisWeek) ?? startThisWeek
            if let makeWeek = weekProvider { return makeWeek(weekOffset) }
            return (0..<7).map { i in
                let day = cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
                let weekdayIndex = max(1, min(7, cal.component(.weekday, from: day)))
                let wd = cal.shortWeekdaySymbols[weekdayIndex - 1].lowercased()
                return WeeklyResumeItem(weekdayShort: wd, date: day)
            }
        }()

        VStack(alignment: .leading, spacing: 12) {

            // --- Section title row: only title now, без календаря и стрелок
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
                    .kerning(0.6)
                    .foregroundColor(PD.ColorToken.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)

            WeeklyResumeStrip(
                items: week,
                layout: .carousel,
                onTapDay: { tapped in
                    if let idx = week.firstIndex(where: { MDBangkokCalendar.cal.isDate($0.date, inSameDayAs: tapped.date) }) {
                        if let selectedIndex {
                            selectedIndex.wrappedValue = idx
                        } else {
                            selected = idx
                        }
                    }
                    if tapped.isEmpty {
                        onTapEmptyDay?(tapped)
                    } else {
                        onTapDaySummary?(tapped)
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.vertical, 2)

        }
        .padding(.top, 20)
        .padding(.bottom, 4)
        .onAppear {
            // if selection is controlled by the View layer, do not auto-reset here
            guard selectedIndex == nil else { return }
            guard !didInit else { return }
            didInit = true

            let hasItems = !items.isEmpty
            let weekMax = max(0, week.count - 1)
            let itemsMax = hasItems ? max(0, items.count - 1) : weekMax
            let effectiveMax = min(weekMax, itemsMax)

            // for the fixed [-3,+3] carousel today is always index 3
            if selected < 0 || selected > effectiveMax {
                selected = min(max(0, 3), effectiveMax)
            }
        }
        .onChange(of: weekOffset) { _ in
            guard selectedIndex == nil else { return }
            let hasItems = !items.isEmpty
            let weekMax = max(0, week.count - 1)
            let itemsMax = hasItems ? max(0, items.count - 1) : weekMax
            let effectiveMax = min(weekMax, itemsMax)

            let prevIndex = selected
            let clampedPrev = max(0, min(prevIndex, effectiveMax))

            selected = clampedPrev
        }
    }
}

// MARK: - Lightweight exports for View-layer composition

/// minimal calendar carousel without headers/stats/cta
public struct MDWeekCarousel: View {
    public var items: [WeeklyResumeItem]
    @Binding public var selected: Int
    public var onTapDay: ((WeeklyResumeItem) -> Void)?

    public init(
        items: [WeeklyResumeItem],
        selected: Binding<Int>,
        onTapDay: ((WeeklyResumeItem) -> Void)? = nil
    ) {
        self.items = items
        self._selected = selected
        self.onTapDay = onTapDay
    }

    public var body: some View {
        WeeklyResumeStrip(
            items: items,
            layout: .carousel,
            onTapDay: { tapped in
                // update selection to the tapped day
                if let idx = items.firstIndex(where: { MDBangkokCalendar.cal.isDate($0.date, inSameDayAs: tapped.date) }) {
                    selected = idx
                }
                onTapDay?(tapped)
            }
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DS: two-row carousel (free row + pro row)

/// A pure-DS layout helper: renders two horizontal rows (Free then Pro).
/// Card visuals are provided by the caller via `card` builder.
public struct MDTwoRowCourseCarousel<Item: Identifiable, Card: View>: View {

    public struct RowConfig: Equatable {
        public var title: String
        public var showsTitle: Bool
        public var topPadding: CGFloat
        public var bottomPadding: CGFloat

        public init(title: String, showsTitle: Bool = false, topPadding: CGFloat = 8, bottomPadding: CGFloat = 6) {
            self.title = title
            self.showsTitle = showsTitle
            self.topPadding = topPadding
            self.bottomPadding = bottomPadding
        }
    }

    public var freeTitle: RowConfig
    public var proTitle: RowConfig

    public var free: [Item]
    public var pro: [Item]

    public var cardWidth: CGFloat
    public var cardSpacing: CGFloat

    @ViewBuilder public var card: (Item) -> Card

    public init(
        freeTitle: RowConfig = .init(title: "free", showsTitle: false),
        proTitle: RowConfig  = .init(title: "pro", showsTitle: false),
        free: [Item],
        pro: [Item],
        cardWidth: CGFloat = 268,
        cardSpacing: CGFloat = 12,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.freeTitle = freeTitle
        self.proTitle = proTitle
        self.free = free
        self.pro = pro
        self.cardWidth = cardWidth
        self.cardSpacing = cardSpacing
        self.card = card
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if !free.isEmpty {
                row(title: freeTitle, items: free)
            }

            if !pro.isEmpty {
                row(title: proTitle, items: pro)
            }
        }
    }

    @ViewBuilder
    private func row(title: RowConfig, items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if title.showsTitle {
                Text(title.title.uppercased())
                    .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
                    .kerning(0.6)
                    .foregroundColor(PD.ColorToken.textSecondary)
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: cardSpacing) {
                    ForEach(items) { it in
                        card(it)
                            .frame(width: cardWidth)
                    }
                }
                .padding(.horizontal, Theme.Layout.pageHorizontal)
            }
        }
        .padding(.top, title.topPadding)
        .padding(.bottom, title.bottomPadding)
    }
}

// MARK: - DS: Add Courses overlay content (two rows: free + pro)

/// Pure DS content for the "add courses" overlay.
/// Renders two horizontal rows: Free (tap-enabled in View layer) and Pro (disabled/upsell in View layer).
/// Visuals are provided by the caller via `card` builder.
public struct MDAddCoursesOverlayContent<Item: Identifiable, Card: View>: View {

    public struct Texts: Equatable {
        public var title: String
        public var subtitle: String

        public init(
            title: String = "добавить курс",
            subtitle: String = "выбери курс, чтобы добавить его в план на этот день"
        ) {
            self.title = title
            self.subtitle = subtitle
        }
    }

    public var texts: Texts

    public var free: [Item]
    public var pro: [Item]

    public var cardWidth: CGFloat
    public var cardSpacing: CGFloat

    @ViewBuilder public var card: (Item) -> Card

    public init(
        texts: Texts = .init(),
        free: [Item],
        pro: [Item],
        cardWidth: CGFloat = 268,
        cardSpacing: CGFloat = 12,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.texts = texts
        self.free = free
        self.pro = pro
        self.cardWidth = cardWidth
        self.cardSpacing = cardSpacing
        self.card = card
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {
                Text(texts.title)
                    .font(PD.FontToken.title(22, weight: Font.Weight.semibold))
                    .foregroundColor(PD.ColorToken.text)

                Text(texts.subtitle)
                    .font(PD.FontToken.body(14, weight: .regular))
                    .foregroundColor(PD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.top, 4)

            if free.isEmpty && pro.isEmpty {
                // DS-only empty state (View can override with its own)
                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                    .fill(PD.ColorToken.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                            .stroke(PD.ColorToken.stroke, lineWidth: 1)
                    )
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 6) {
                            Text("нет курсов")
                                .font(PD.FontToken.body(14, weight: Font.Weight.semibold))
                                .foregroundColor(PD.ColorToken.text)
                            Text("выбери курс для добавления")
                                .font(PD.FontToken.body(13, weight: .regular))
                                .foregroundColor(PD.ColorToken.textSecondary)
                        }
                        .padding(.horizontal, Theme.Layout.pageHorizontal)
                    )
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
            } else {
                // Variant B: two separate rows (visually clean)
                MDTwoRowCourseCarousel(
                    freeTitle: .init(title: "free", showsTitle: true, topPadding: 2, bottomPadding: 6),
                    proTitle:  .init(title: "pro",  showsTitle: true, topPadding: 6, bottomPadding: 2),
                    free: free,
                    pro: pro,
                    cardWidth: cardWidth,
                    cardSpacing: cardSpacing,
                    card: card
                )
            }
        }
        .padding(.bottom, 6)
    }
}

/// Convenience splitter for callers (e.g. split by `isPro` flag in View layer).
public enum MDCourseRowSplit {
    public static func split<T>(
        _ items: [T],
        isPro: (T) -> Bool
    ) -> (free: [T], pro: [T]) {
        var free: [T] = []
        var pro: [T] = []
        free.reserveCapacity(items.count)
        pro.reserveCapacity(items.count)
        for it in items {
            if isPro(it) { pro.append(it) } else { free.append(it) }
        }
        return (free, pro)
    }
}

/// tiny helpers to reuse date/label logic from DS in Views without pulling the whole section
public enum MDWeekHelpers {
    /// "Неделя N · 1–7 окт" (TH locale uses Buddhist calendar & "d MMM y")
    public static func label(forWeekOffset weekOffset: Int, locale: Locale = .current) -> String {
        let cal = MDBangkokCalendar.cal
        let startThisWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startThisWeek) ?? startThisWeek
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekNumber = cal.component(.weekOfYear, from: weekStart)

        let isThai = locale.identifier.lowercased().contains("_th") || locale.languageCode?.lowercased() == "th"
        let df = DateFormatter()
        df.locale = locale
        if isThai {
            df.calendar = Calendar(identifier: .buddhist)
            df.dateFormat = "d MMM y"
        } else {
            df.calendar = cal
            df.dateFormat = "d MMM"
        }
        return "Неделя \(weekNumber) · \(df.string(from: weekStart))–\(df.string(from: weekEnd))"
    }
}

// MARK: - Daily Picks (stub, non-bloating)
#if DEBUG
/// demo-only wrapper for previews; do not use in production.
/// use `MDDailyPicksComposite` from the View layer with real data + callbacks.
@available(*, deprecated, message: "demo-only; use MDDailyPicksComposite from View layer with real data")
internal struct MDDailyPicksDemoSection: View {
    @State private var steps: [SDStepItem] = []
    @State private var activeIndex: Int = 0
    init() {}
    var body: some View {
        SDStepCarousel(
            title: "ПОДБОРКА ДНЯ",
            items: steps,
            activeIndex: $activeIndex
        )
        .padding(.top, 12)
        .onAppear {
            // local preview/demo data — not compiled into release
            let base: [StepItem] = StepData.shared.allItems()
            let picked = Array(base.shuffled().prefix(5))
            self.steps = picked.map { it in
                let mappedKind: SDStepItem.Kind = {
                    switch it.kind {
                    case .word:   return .word
                    case .phrase: return .phrase
                    default:      return .phrase
                    }
                }()
                return SDStepItem(
                    kind: mappedKind,
                    titleRU: it.ru ?? "",
                    subtitleTH: it.thai ?? "",
                    phonetic: it.phonetic ?? ""
                )
            }
        }
    }
}
#endif

// MARK: - Daily Picks + Meta (course chip • lesson link • CTA)
// Pure DS: visuals only; actions are passed in from View layer.
public struct MDDailyPicksMetaRow: View {
    public var courseShort: String
    public var lessonShort: String
    public var onTapCourse: () -> Void
    public var onTapLesson: () -> Void
    public var onOpenCourse: () -> Void

    public init(
        courseShort: String,
        lessonShort: String,
        onTapCourse: @escaping () -> Void,
        onTapLesson: @escaping () -> Void,
        onOpenCourse: @escaping () -> Void
    ) {
        self.courseShort = courseShort
        self.lessonShort = lessonShort
        self.onTapCourse = onTapCourse
        self.onTapLesson = onTapLesson
        self.onOpenCourse = onOpenCourse
    }

    public var body: some View {
        let trimmedCourse = courseShort.trimmingCharacters(in: .whitespacesAndNewlines)
        // let trimmedLesson = lessonShort.trimmingCharacters(in: .whitespacesAndNewlines)
        let leftLabel = trimmedCourse

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if !leftLabel.isEmpty {
                Text(leftLabel)
                    .font(PD.FontToken.body(13, weight: Font.Weight.semibold))
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Button(action: onOpenCourse) {
                Text("ОТКРЫТЬ КУРС")
                    .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
                    .kerning(0.6)
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
            }
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
    }
}

public struct MDDailyPicksComposite: View {
    public var title: String
    public var items: [SDStepItem]
    public var courseShortNames: [String]     // parallel to items
    public var lessonShortNames: [String]     // parallel to items
    public var learned: Set<Int>
    public var favorites: Set<Int>
    @Binding public var activeIndex: Int
    public var onTapCourse: (Int) -> Void
    public var onTapLesson: (Int) -> Void
    public var onOpenCourse: (Int) -> Void
    public var onPlay: ((Int) -> Void)?
    public var onDone: ((Int) -> Bool)?
    public var onFav: ((Int) -> Bool)?
    public var onIndexChange: ((Int) -> Void)?

    public init(
        title: String = "ПОДБОРКА ДНЯ",
        items: [SDStepItem],
        courseShortNames: [String] = [],
        lessonShortNames: [String] = [],
        learned: Set<Int> = [],
        favorites: Set<Int> = [],
        activeIndex: Binding<Int>,
        onTapCourse: @escaping (Int) -> Void = { _ in },
        onTapLesson: @escaping (Int) -> Void = { _ in },
        onOpenCourse: @escaping (Int) -> Void = { _ in },
        onPlay: ((Int) -> Void)? = nil,
        onDone: ((Int) -> Bool)? = nil,
        onFav: ((Int) -> Bool)? = nil,
        onIndexChange: ((Int) -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.courseShortNames = courseShortNames
        self.lessonShortNames = lessonShortNames
        self.learned = learned
        self.favorites = favorites
        self._activeIndex = activeIndex
        self.onTapCourse = onTapCourse
        self.onTapLesson = onTapLesson
        self.onOpenCourse = onOpenCourse
        self.onPlay = onPlay
        self.onDone = onDone
        self.onFav = onFav
        self.onIndexChange = onIndexChange
    }

    public init(
        title: String = "ПОДБОРКА ДНЯ",
        items: [SDStepItem],
        courseShortNames: [String] = [],
        lessonShortNames: [String] = [],
        learnedMask: [Bool] = [],
        favoritesMask: [Bool] = [],
        activeIndex: Binding<Int>,
        onTapCourse: @escaping (Int) -> Void = { _ in },
        onTapLesson: @escaping (Int) -> Void = { _ in },
        onOpenCourse: @escaping (Int) -> Void = { _ in },
        onPlay: ((Int) -> Void)? = nil,
        onDone: ((Int) -> Bool)? = nil,
        onFav: ((Int) -> Bool)? = nil,
        onIndexChange: ((Int) -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.courseShortNames = courseShortNames
        self.lessonShortNames = lessonShortNames
        let maxCount = items.count
        var learnedSet: Set<Int> = []
        var favoritesSet: Set<Int> = []
        for i in 0..<maxCount {
            if i < learnedMask.count, learnedMask[i] { learnedSet.insert(i) }
            if i < favoritesMask.count, favoritesMask[i] { favoritesSet.insert(i) }
        }
        self.learned = learnedSet
        self.favorites = favoritesSet
        self._activeIndex = activeIndex
        self.onTapCourse = onTapCourse
        self.onTapLesson = onTapLesson
        self.onOpenCourse = onOpenCourse
        self.onPlay = onPlay
        self.onDone = onDone
        self.onFav = onFav
        self.onIndexChange = onIndexChange
    }

    public init(
        title: String = "ПОДБОРКА ДНЯ",
        items: [SDStepItem]
    ) {
        self.title = title
        self.items = items
        self.courseShortNames = []
        self.lessonShortNames = []
        self.learned = []
        self.favorites = []
        self._activeIndex = .constant(0)
        self.onTapCourse = { _ in }
        self.onTapLesson = { _ in }
        self.onOpenCourse = { _ in }
        self.onPlay = nil
        self.onDone = nil
        self.onFav = nil
        self.onIndexChange = nil
    }

    private func lessonNameDerived(at i: Int) -> String {
        if i >= 0, i < lessonShortNames.count {
            let val = lessonShortNames[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !val.isEmpty { return val }
        }
        return ""
    }
    private func courseNameDerived(at i: Int) -> String {
        if i >= 0, i < courseShortNames.count, !courseShortNames[i].isEmpty { return courseShortNames[i] }
        return ""
    }

    private func nextIndex(from i: Int) -> Int { min(max(0, i + 1), max(0, items.count - 1)) }
    private func prevIndex(from i: Int) -> Int { max(0, min(items.count - 1, i - 1)) }

    public var body: some View {
        VStack(spacing: 0) {
            // header: title (left) + mini-progress (right)
            HStack(alignment: .center, spacing: 12) {
                Text(title.uppercased())
                    .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
                    .kerning(0.6)
                    .foregroundColor(PD.ColorToken.textSecondary)
                    .padding(.top, 1)

                Spacer(minLength: 0)

                if !items.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(items.indices), id: \.self) { idx in
                            let isActive = (idx == activeIndex)
                            let isPro = items[idx].isPro
                            let isLearned = isPro ? true : learned.contains(idx)
                            let isFavorite = isPro ? false : favorites.contains(idx)

                            ZStack {
                                // PRO gates: filled segment without heart; crown overlay indicates PRO.
                                SDStepProgressSegment(
                                    width: 22,
                                    isActive: isActive,
                                    isLearned: isLearned,
                                    isFavorite: isFavorite,
                                    index: idx,
                                    onTap: { tapped in
                                        guard tapped >= 0, tapped < items.count else { return }
                                        activeIndex = tapped
                                        onIndexChange?(activeIndex)
                                    }
                                )

                                if isPro {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.9))
                                        .offset(y: -0.5)
                                }
                            }
                            .accessibilityLabel(isPro ? "pro" : "")
                        }
                    }
                    .padding(.top, 1)
                }
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)

            // Carousel
            VStack(spacing: 0) {
                ZStack(alignment: .center) {
                    SDStepCarousel(
                        title: "",
                        items: items,
                        activeIndex: $activeIndex,
                        learned: learned,
                        favorites: favorites,
                        onPlay: { item in
                            if let idx = items.firstIndex(where: { $0.id == item.id }) { onPlay?(idx) }
                        },
                        onFav: { item in
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                let isNowLiked = onFav?(idx) ?? false
                                if isNowLiked {
                                    let delay: TimeInterval = 0.45
                                    let next = min(max(0, activeIndex + 1), max(0, items.count - 1))
                                    if next != activeIndex {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                                activeIndex = next
                                            }
                                            onIndexChange?(activeIndex)
                                        }
                                    }
                                }
                            }
                        },
                        onDone: { item in
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                let shouldAdvance = onDone?(idx) ?? true
                                if shouldAdvance {
                                    let delay: TimeInterval = 0.45
                                    let next = min(max(0, activeIndex + 1), max(0, items.count - 1))
                                    if next != activeIndex {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                                activeIndex = next
                                            }
                                            onIndexChange?(activeIndex)
                                        }
                                    }
                                }
                            }
                        },
                        isOverlay: false
                    )
                    .onChange(of: activeIndex) { newValue in
                        onIndexChange?(newValue)
                    }
                }
            }

            // course title + CTA under the cards (stable layout)
            if !items.isEmpty {
                let courseTitle = courseNameDerived(at: activeIndex)

                HStack(alignment: .center, spacing: 12) {
                    Text(courseTitle.uppercased())
                        .font(PD.FontToken.caption(13, weight: Font.Weight.semibold))
                        .kerning(0.6)
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppCTAButtons(
                        primaryTitle: "открыть курс",
                        secondaryTitle: "",
                        onPrimary: { onOpenCourse(activeIndex) },
                        onSecondary: { },
                        scale: .xs,
                        unifiedWidth: false,
                        visual: .brandOutline
                    )
                }
                .frame(height: 40)
                .padding(.horizontal, Theme.Layout.pageHorizontal)
                .padding(.top, Theme.Layout.Section.itemGap)
            }
        }
        .padding(.top, Theme.Layout.Section.contentTop)
        .padding(.bottom, Theme.Layout.Section.contentBottom)
    }
}



// MARK: Vertical "reels" style card for horizontal carousel


// MARK: Vertical list section (editorial picks)



// MARK: - DS: Search (Main)

/// Pure DS search bar for Main screen.
/// View-layer decides how to handle filtering/navigation; DS renders only visuals.
public struct MDSearchSection: View {
    @Binding public var query: String
    public var placeholder: String

    public init(
        query: Binding<String>,
        placeholder: String = "поиск по курсам и урокам"
    ) {
        self._query = query
        self.placeholder = placeholder
    }

    public var body: some View {
        let hPad = max(0, Theme.Layout.pageHorizontal - 4)

        return VStack(alignment: .leading, spacing: 10) {
            Text("ПОИСК")
                .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
                .kerning(0.6)
                .foregroundColor(PD.ColorToken.textSecondary)
                .padding(.horizontal, Theme.Layout.pageHorizontal)

            TaikaSearchBubble(
                query: $query,
                placeholder: placeholder,
                onSubmit: { _ in }
            )
            .padding(.horizontal, hPad)
        }
        .padding(.top, Theme.Layout.Section.contentTop)
        .padding(.bottom, Theme.Layout.Section.contentBottom)
    }
}


// MARK: - DS: Taika FM Section
public struct MDFMSection: View {
    public var title: String
    public var messages: [String]

    public init(_ title: String = "ТАЙКА FM", messages: [String]) {
        self.title = title
        self.messages = messages
    }

    public var body: some View {
        let configMessages = TaikaFMData.shared.messages(for: .main)
        let configReactions = TaikaFMData.shared.reactionGroups(for: .main)

        let effectiveMessages = messages.isEmpty ? configMessages : messages
        let effectiveReactions = configReactions

        return VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
                .kerning(0.6)
                .foregroundColor(PD.ColorToken.textSecondary)
                .padding(.horizontal, Theme.Layout.pageHorizontal)

            TaikaFMBubbleTyping(
                messages: effectiveMessages,
                reactions: effectiveReactions,
                repeats: false
            )
        }
        .padding(.top, Theme.Layout.Section.contentTop)
    }
}


// MARK: - Preview helpers
#if DEBUG
private struct MDDailyPicksPreviewHost: View {
    @State private var idx: Int = 0
    let demoItems: [SDStepItem]
    let courseNames: [String]
    let lessonNames: [String]

    var body: some View {
        MDDailyPicksComposite(
            title: "ПОДБОРКА ДНЯ",
            items: demoItems,
            courseShortNames: courseNames,
            lessonShortNames: lessonNames,
            learnedMask: [],
            favoritesMask: [],
            activeIndex: $idx,
            onTapCourse: { _ in },
            onTapLesson: { _ in },
            onOpenCourse: { _ in }
        )
    }
}

private struct MDSearchPreviewHost: View {
    @State private var q: String = ""
    var body: some View {
        MDSearchSection(query: $q)
    }
}
#endif

// MARK: - Preview
 #Preview("Main DS") {
    ZStack {
        PD.ColorToken.background.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 20) {
            MDFMSection("ТАЙКА FM", messages: [])

            MDContinueSection(
                "ПЛАН НА НЕДЕЛЮ",
                items: [
                    ("Разговорный минимум", 0.25),
                    ("Алфавит и чтение", 0.0),
                    ("Фразы на каждый день", 0.0)
                ],
                onTap: { _ in }
            )

            MDSearchPreviewHost()

            // 3) Подборка дня (как в главном экране)
            let demoItems: [SDStepItem] = [
                SDStepItem(kind: .phrase, titleRU: "привет", subtitleTH: "สวัสดี", phonetic: "sa-wat-dee"),
                SDStepItem(kind: .word,   titleRU: "спасибо", subtitleTH: "ขอบคุณ", phonetic: "khop-khun"),
                SDStepItem(kind: .tip,    titleRU: "лайфхак", subtitleTH: "Свяжи «кхоп-кхун» с благодарностью — говори после помощи.", phonetic: "khop-khun krab"),
                SDStepItem(kind: .phrase, titleRU: "где туалет?", subtitleTH: "ห้องน้ำอยู่ไหน", phonetic: "hong-nam yu nai"),
                SDStepItem(kind: .phrase, titleRU: "сколько стоит?", subtitleTH: "ราคาเท่าเร่าไหร่", phonetic: "ra-kha thao-rai")
            ]
            let courseNames = ["разговорный минимум", "алфавит и чтение", "выживание в тай", "фразы на каждый день"]
            let lessonNames = ["урок 1", "урок 5", "урок 2", "урок 7"]

            MDDailyPicksPreviewHost(demoItems: demoItems, courseNames: courseNames, lessonNames: lessonNames)
            }
            .padding(.vertical, 20)
        }
        .safeAreaPadding(.top, 16)
        .safeAreaPadding(.bottom, 24)
    }
    .preferredColorScheme(.dark)
}
