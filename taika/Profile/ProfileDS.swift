
import SwiftUI


// MARK: - Profile Design System (PD)
// Lightweight UI kit used by Profile screens. 100% SwiftUI.
// All tokens have sensible defaults and can later be mapped to ThemeDesign.

public enum PD {
    // MARK: Tokens
    public enum ColorToken {
        public static var background: SwiftUI.Color { Color(red: 0.06, green: 0.06, blue: 0.07) } // near-black
        public static var card: SwiftUI.Color { Color(red: 0.10, green: 0.10, blue: 0.12) }      // dark card
        public static var stroke: SwiftUI.Color { Color.white.opacity(0.08) }                    // subtle outline
        public static var text: SwiftUI.Color { Color.white }                                    // primary text
        public static var textSecondary: SwiftUI.Color { Color.white.opacity(0.6) }              // secondary
        public static var accent: SwiftUI.Color { Color(red: 0.95, green: 0.36, blue: 0.65) }    // accent pink
        public static var chip: SwiftUI.Color { Color.white.opacity(0.06) }                      // soft chip fill
    }

    public enum Radius {
        public static var card: CGFloat { 20 }
        public static var chip: CGFloat { 12 }
    }

    public enum Spacing {
        public static var screen: CGFloat { 20 }
        public static var inner: CGFloat { 12 }
        public static var tiny: CGFloat { 6 }

        // Aliases for cross-DS compatibility
        public static var small: CGFloat { tiny }
        public static var medium: CGFloat { inner }   // use inner as medium spacing
        public static var block: CGFloat { screen }   // use screen as outer block spacing
    }

    public enum FontToken {
        public static func title(_ size: CGFloat = 32, weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded) }
        public static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .rounded) }
        public static func caption(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .rounded) }
    }

    public enum BrandFont {
        public static func appTitle(_ size: CGFloat) -> Font {
            // Use brand font if available; fallback to rounded system
            if UIFont(name: "OnmarkTRIAL", size: size) != nil { return .custom("OnmarkTRIAL", size: size) }
            return .system(size: size, weight: .bold, design: .rounded)
        }
    }

    public enum GradientToken {
        public static var pro: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.52, blue: 0.80),
                    Color(red: 0.91, green: 0.62, blue: 0.98)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - pdstyle (inject appds tokens here)
public struct PDStyle: Sendable {
    public var background: Color
    public var card: Color
    public var stroke: Color
    public var text: Color
    public var textSecondary: Color
    public var accent: Color
    public var accentFill: AnyShapeStyle
    public var chip: Color

    public init(
        background: Color,
        card: Color,
        stroke: Color,
        text: Color,
        textSecondary: Color,
        accent: Color,
        accentFill: AnyShapeStyle,
        chip: Color
    ) {
        self.background = background
        self.card = card
        self.stroke = stroke
        self.text = text
        self.textSecondary = textSecondary
        self.accent = accent
        self.accentFill = accentFill
        self.chip = chip
    }

    public static var legacy: PDStyle {
        .init(
            background: PD.ColorToken.background,
            card: PD.ColorToken.card,
            stroke: PD.ColorToken.stroke,
            text: PD.ColorToken.text,
            textSecondary: PD.ColorToken.textSecondary,
            accent: PD.ColorToken.accent,
            accentFill: AnyShapeStyle(PD.ColorToken.accent),
            chip: PD.ColorToken.chip
        )
    }

    public static var appDS: PDStyle {
        var s = legacy
        // take canonical accent from app theme (so profile graphs + chips match the rest of the app)
        s.accentFill = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        return s
    }
}

// MARK: - Header Card
@available(*, deprecated, message: "Use AppHeader/AppBackHeader from AppDS instead of PDHeaderCard")
public struct PDHeaderCard: View {
    public var title: String
    public var subtitle: String
    public var cta: String
public var mascot: Image? = Image("mascot.profile")
    public var onTapCTA: () -> Void

    public init(title: String, subtitle: String, cta: String, mascot: Image? = Image("mascot.profile"), onTapCTA: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.cta = cta
        self.mascot = mascot
        self.onTapCTA = onTapCTA
    }

    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 10) {
                // App logo in brand font
                Text("taikA")
                    .font(PD.BrandFont.appTitle(32))
                    .foregroundColor(PD.ColorToken.text)
                    .kerning(0.0)
                
                VStack(alignment: .leading, spacing: PD.Spacing.tiny) {
                    Text(title)
                        .font(PD.FontToken.title(20, weight: .bold))
                        .foregroundColor(PD.ColorToken.text)
                    Text(subtitle)
                        .font(PD.FontToken.body(16, weight: .regular))
                        .foregroundColor(PD.ColorToken.textSecondary)
                }
                
                Button(action: onTapCTA) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(cta)
                    }
                    .font(PD.FontToken.caption())
                    .foregroundColor(PD.ColorToken.text)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(PD.ColorToken.chip)
                    .clipShape(RoundedRectangle(cornerRadius: PD.Radius.chip, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PD.Radius.chip, style: .continuous)
                            .stroke(PD.ColorToken.stroke, lineWidth: 1)
                    )
                }
                .padding(.top, 6)
            }
            Spacer(minLength: PD.Spacing.inner)
            mascot?
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 96, height: 96)
                .opacity(0.9)
        }
        .padding(PD.Spacing.inner)
        .background(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .fill(PD.ColorToken.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .stroke(PD.ColorToken.stroke, lineWidth: 1)
        )
        .padding(.horizontal, PD.Spacing.screen)
    }
}

// MARK: - Typing dots (inline, subtle)
struct PDTypingDots: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 4) {
            Circle().frame(width: 6, height: 6)
                .opacity(Double((phase.truncatingRemainder(dividingBy: 3) >= 0) ? 1 : 0.35))
            Circle().frame(width: 6, height: 6)
                .opacity(Double((phase.truncatingRemainder(dividingBy: 3) >= 1) ? 1 : 0.35))
            Circle().frame(width: 6, height: 6)
                .opacity(Double((phase.truncatingRemainder(dividingBy: 3) >= 2) ? 1 : 0.35))
        }
        .foregroundColor(PD.ColorToken.textSecondary)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }
}

// MARK: - Marquee / assistant stripe (fixed height, no layout jump)
public struct PDProfileMarquee: View {
    public var messages: [String]
    public var mascot: Image?
    public var typingDuration: TimeInterval = 2.2
    public var showDuration: TimeInterval = 3.2
    public var typingCharInterval: TimeInterval = 0.045
    public var style: PDStyle = .appDS

    @State private var idx: Int = 0
    @State private var isTyping: Bool = true
    @State private var shown: String = ""
    @State private var charIndex: Int = 0
    @State private var hasStarted: Bool = false

    public init(messages: [String], mascot: Image? = Image("mascot.profile"), style: PDStyle = .appDS) {
        self.messages = messages
        self.mascot = mascot
        self.style = style
    }

    public var body: some View {
        HStack(alignment: .center, spacing: PD.Spacing.inner) {
            mascot?
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            ZStack(alignment: .leading) {
                // Fixed bubble to avoid height jumps
                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                    .fill(style.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                            .stroke(style.stroke, lineWidth: 1)
                    )

                // Content
                HStack(alignment: .center, spacing: 8) {
                    if isTyping {
                        PDTypingDots()
                    } else {
                        Text(shown)
                            .font(PD.FontToken.body(14, weight: .regular))
                            .foregroundColor(style.text)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            startCycle()
        }
        .onDisappear {
            // stop further cycles when view leaves screen (previews/navigation)
            hasStarted = false
        }
    }

    private func startCycle() {
        guard hasStarted, !messages.isEmpty else { return }
        // Phase 1: thinking dots
        shown = ""
        charIndex = 0
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            // Phase 2: typewriter reveal
            withAnimation(.easeInOut(duration: 0.2)) { isTyping = false }
            beginTyping(message: messages[safe: idx] ?? "")
        }
    }

    private func beginTyping(message: String) {
        shown = ""
        charIndex = 0
        typeNextChar(message: message)
    }

    private func typeNextChar(message: String) {
        guard charIndex < message.count else {
            // Phase 3: linger full text
            DispatchQueue.main.asyncAfter(deadline: .now() + showDuration) {
                guard hasStarted else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    idx = (idx + 1) % max(messages.count, 1)
                    isTyping = true
                }
                startCycle()
            }
            return
        }
        let i = message.index(message.startIndex, offsetBy: charIndex)
        shown.append(message[i])
        charIndex += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + typingCharInterval) {
            guard hasStarted else { return }
            typeNextChar(message: message)
        }
    }
}

// Safe index helper
private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Ready-to-use section: "ТАЙКА FM"
public struct PDFMSection: View {
    public var title: String = "ТАЙКА FM"
    public var messages: [String]
    public var mascot: Image?
    public var style: PDStyle = .appDS
    
    public init(
        messages: [String] = [
            "Проверь бейджи за сегодня",
            "Напомнить о целях на неделю?",
            "Нужна помощь с подпиской или оплатой?"
        ],
        mascot: Image? = Image("mascot.profile"),
        style: PDStyle = .appDS
    ) {
        self.messages = messages
        self.mascot = mascot
        self.style = style
    }
    
    public var body: some View {
        PDSection(title, style: style) {
            // canonical taika fm bubble (from cardds)
            TaikaFMBubbleTyping(messages: messages)
        }
    }
}
// MARK: - Section container (title + card)
public struct PDSection<Content: View>: View {
    public var title: String
    public var style: PDStyle = .appDS
    public let content: Content

    public init(_ title: String, style: PDStyle = .appDS, @ViewBuilder content: () -> Content) {
        self.title = title
        self.style = style
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(PD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(style.textSecondary)
                .padding(.horizontal, PD.Spacing.screen)
            
            // Content itself (e.g., PDListGroup) draws its own card.
            content
                .padding(.horizontal, PD.Spacing.screen)
        }
        .padding(.top, 16)
    }
}

// MARK: - Row cell with chevron (supports expand)
public struct PDRow: View {
    public var systemIcon: String
    public var title: String
    public var showsChevron: Bool
    public var isExpanded: Bool
    public var style: PDStyle = .appDS
    public var action: () -> Void

    public var expandedContent: AnyView?


    public init(
        icon: String,
        title: String,
        showsChevron: Bool = true,
        isExpanded: Bool = false,
        style: PDStyle = .appDS,
        action: @escaping () -> Void,
        expandedContent: AnyView? = nil
    ) {
        self.systemIcon = icon
        self.title = title
        self.showsChevron = showsChevron
        self.isExpanded = isExpanded
        self.style = style
        self.action = action
        self.expandedContent = expandedContent
    }

    public var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: PD.Spacing.inner) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(style.chip)
                            .frame(width: 42, height: 42)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(style.stroke, lineWidth: 1)
                            )
                        Image(systemName: systemIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(style.text)
                    }
                    Text(title)
                        .font(PD.FontToken.body(17, weight: .regular))
                        .foregroundColor(style.text)
                    Spacer()

                    if showsChevron {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(style.accent)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isExpanded)
                    }
                }
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded, let expandedContent {
                expandedContent
                    .padding(.horizontal, PD.Spacing.inner)
                    .padding(.bottom, PD.Spacing.inner)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Grouped list helper (supports expandable rows)
public struct PDListGroup: View {
    public var rows: [Row]
    public var style: PDStyle = .appDS

    public struct Row {
        public var icon: String
        public var title: String
        public var isExpanded: Bool
        public var action: () -> Void
        public var expandedContent: AnyView?

        public init(
            icon: String,
            title: String,
            isExpanded: Bool = false,
            action: @escaping () -> Void,
            expandedContent: AnyView? = nil
        ) {
            self.icon = icon
            self.title = title
            self.isExpanded = isExpanded
            self.action = action
            self.expandedContent = expandedContent
        }
    }

    public init(_ rows: [Row], style: PDStyle = .appDS) {
        self.rows = rows
        self.style = style
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, r in
                PDRow(
                    icon: r.icon,
                    title: r.title,
                    showsChevron: true,
                    isExpanded: r.isExpanded,
                    style: style,
                    action: r.action,
                    expandedContent: r.expandedContent
                )

                if idx != rows.count - 1 {
                    Rectangle()
                        .fill(style.stroke)
                        .frame(height: 1)
                        .padding(.leading, 68)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .fill(style.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .stroke(style.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Progress scope (courses vs lessons)
public enum PDProgressScope: String, CaseIterable {
    case courses = "курсы"
    case lessons = "уроки"
}

// MARK: - Segmented tabs (2 items)
public struct PDTabbedSwitch: View {
    public var items: [PDProgressScope] = PDProgressScope.allCases
    public var selected: PDProgressScope
    public var onSelect: (PDProgressScope) -> Void


    public init(
        items: [PDProgressScope] = PDProgressScope.allCases,
        selected: PDProgressScope,
        onSelect: @escaping (PDProgressScope) -> Void
    ) {
        self.items = items
        self.selected = selected
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.self) { it in
                let isSelected = (it == selected)
                Button {
                    onSelect(it)
                } label: {
                    Text(it.rawValue)
                        .font(PD.FontToken.caption(13, weight: .semibold))
                        .foregroundColor(isSelected ? PD.ColorToken.text : PD.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? PD.ColorToken.chip.opacity(1.0) : PD.ColorToken.chip)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? PD.ColorToken.accent.opacity(0.55) : PD.ColorToken.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}


// MARK: - PDMetric (data-only type for metrics)
public struct PDMetric: Hashable {
    public var key: String
    public var title: String
    public var value7d: String
    public var delta7d: String?

    public init(key: String, title: String, value7d: String, delta7d: String? = nil) {
        self.key = key
        self.title = title
        self.value7d = value7d
        self.delta7d = delta7d
    }
}

// MARK: - Stat graphs (mock-friendly, DS-only)
public struct PDStatSparkline: View {
    public var values: [Double]
    public var style: PDStyle = .appDS

    public init(values: [Double], style: PDStyle = .appDS) {
        self.values = values
        self.style = style
    }

    public var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(maxV - minV, 0.0001)

            ZStack {
                // area fill
                Path { p in
                    guard values.count >= 2 else { return }
                    for i in values.indices {
                        let x = w * (Double(i) / Double(max(values.count - 1, 1)))
                        let yN = (values[i] - minV) / span
                        let y = h - (h * yN)
                        if i == values.startIndex {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(style.accentFill)
                .opacity(0.14)

                // line
                Path { p in
                    guard values.count >= 2 else { return }
                    for i in values.indices {
                        let x = w * (Double(i) / Double(max(values.count - 1, 1)))
                        let yN = (values[i] - minV) / span
                        let y = h - (h * yN)
                        if i == values.startIndex {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(style.accentFill, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }
}

public struct PDStatBars7d: View {
    public var values: [Double]
    public var style: PDStyle = .appDS

    public init(values: [Double], style: PDStyle = .appDS) {
        self.values = values
        self.style = style
    }

    public var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 0.0001)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(style.accentFill)
                        .frame(height: max(8, geo.size.height * (v / maxV)))
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
        }
    }
}

public struct PDTwoGraphBlock: View {
    public var weekly: [Double]
    public var last7: [Double]
    public var style: PDStyle = .appDS

    @State private var showWeeklyInfo: Bool = false
    @State private var showLast7Info: Bool = false

    public init(weekly: [Double], last7: [Double], style: PDStyle = .appDS) {
        self.weekly = weekly
        self.last7 = last7
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // weekly
            HStack(spacing: 8) {
                Text("по неделям")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundColor(style.textSecondary)
                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showWeeklyInfo.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.textSecondary)
                        .opacity(0.85)
                }
                .buttonStyle(.plain)
            }

            if showWeeklyInfo {
                Text("общий тренд по выбранной метрике, агрегировано по неделям")
                    .font(PD.FontToken.caption(13, weight: .regular))
                    .foregroundColor(style.textSecondary)
                    .transition(.opacity)
            }

            PDStatSparkline(values: weekly, style: style)
                .frame(height: 128)

            // last 7 days
            HStack(spacing: 8) {
                Text("последние 7 дней")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundColor(style.textSecondary)
                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showLast7Info.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.textSecondary)
                        .opacity(0.85)
                }
                .buttonStyle(.plain)
            }

            if showLast7Info {
                Text("распределение по дням за последнюю неделю")
                    .font(PD.FontToken.caption(13, weight: .regular))
                    .foregroundColor(style.textSecondary)
                    .transition(.opacity)
            }

            PDStatBars7d(values: last7, style: style)
                .frame(height: 128)
        }
    }
}


// MARK: - progress panel (ds owns visuals; view will own data later)
public struct PDProgressPanel: View {
    public var scope: PDProgressScope
    public var onScopeChange: (PDProgressScope) -> Void

    public var coursesMetrics: [PDMetric]
    public var lessonsMetrics: [PDMetric]

    public var selectedCourseMetricKey: Binding<String>
    public var selectedLessonMetricKey: Binding<String>

    public var onSelectCourseMetric: (String) -> Void
    public var onSelectLessonMetric: (String) -> Void

    public var weeklyByCourseMetric: [String: [Double]]
    public var last7ByCourseMetric: [String: [Double]]
    public var weeklyByLessonMetric: [String: [Double]]
    public var last7ByLessonMetric: [String: [Double]]

    public var style: PDStyle = .appDS

    public init(
        scope: PDProgressScope,
        onScopeChange: @escaping (PDProgressScope) -> Void,
        coursesMetrics: [PDMetric],
        lessonsMetrics: [PDMetric],
        selectedCourseMetricKey: Binding<String>,
        selectedLessonMetricKey: Binding<String>,
        onSelectCourseMetric: @escaping (String) -> Void,
        onSelectLessonMetric: @escaping (String) -> Void,
        weeklyByCourseMetric: [String: [Double]],
        last7ByCourseMetric: [String: [Double]],
        weeklyByLessonMetric: [String: [Double]],
        last7ByLessonMetric: [String: [Double]],
        style: PDStyle = .appDS
    ) {
        self.scope = scope
        self.onScopeChange = onScopeChange
        self.coursesMetrics = coursesMetrics
        self.lessonsMetrics = lessonsMetrics
        self.selectedCourseMetricKey = selectedCourseMetricKey
        self.selectedLessonMetricKey = selectedLessonMetricKey
        self.onSelectCourseMetric = onSelectCourseMetric
        self.onSelectLessonMetric = onSelectLessonMetric
        self.weeklyByCourseMetric = weeklyByCourseMetric
        self.last7ByCourseMetric = last7ByCourseMetric
        self.weeklyByLessonMetric = weeklyByLessonMetric
        self.last7ByLessonMetric = last7ByLessonMetric
        self.style = style
    }

    public init(
        scope: PDProgressScope,
        onScopeChange: @escaping (PDProgressScope) -> Void,
        coursesMetrics: [PDMetric],
        lessonsMetrics: [PDMetric],
        selectedCourseMetricKey: String,
        selectedLessonMetricKey: String,
        onSelectCourseMetric: @escaping (String) -> Void,
        onSelectLessonMetric: @escaping (String) -> Void,
        weeklyByCourseMetric: [String: [Double]],
        last7ByCourseMetric: [String: [Double]],
        weeklyByLessonMetric: [String: [Double]],
        last7ByLessonMetric: [String: [Double]],
        style: PDStyle = .appDS
    ) {
        self.init(
            scope: scope,
            onScopeChange: onScopeChange,
            coursesMetrics: coursesMetrics,
            lessonsMetrics: lessonsMetrics,
            selectedCourseMetricKey: .constant(selectedCourseMetricKey),
            selectedLessonMetricKey: .constant(selectedLessonMetricKey),
            onSelectCourseMetric: onSelectCourseMetric,
            onSelectLessonMetric: onSelectLessonMetric,
            weeklyByCourseMetric: weeklyByCourseMetric,
            last7ByCourseMetric: last7ByCourseMetric,
            weeklyByLessonMetric: weeklyByLessonMetric,
            last7ByLessonMetric: last7ByLessonMetric,
            style: style
        )
    }

    // Convenience: DS-only mock panel (lets ProfileView compile while data wiring is pending)
    public init() {
        self.scope = .courses
        self.onScopeChange = { _ in }

        self.coursesMetrics = [
            .init(key: "courses_completed", title: "пройдено", value7d: "1", delta7d: "+1"),
            .init(key: "courses_started", title: "начато", value7d: "2", delta7d: "+0"),
            .init(key: "courses_active", title: "активно", value7d: "3", delta7d: "+1"),
        ]
        self.lessonsMetrics = [
            .init(key: "lessons_completed", title: "уроки", value7d: "3", delta7d: "+1"),
            .init(key: "words_learned", title: "слова", value7d: "42", delta7d: "+8"),
            .init(key: "phrases_learned", title: "фразы", value7d: "9", delta7d: "+2"),
        ]

        self.selectedCourseMetricKey = .constant("courses_completed")
        self.selectedLessonMetricKey = .constant("lessons_completed")

        self.onSelectCourseMetric = { _ in }
        self.onSelectLessonMetric = { _ in }

        self.weeklyByCourseMetric = [
            "courses_completed": [0, 0, 1, 1, 1, 2, 2, 3],
            "courses_started": [1, 1, 1, 2, 2, 2, 3, 3],
            "courses_active": [2, 2, 3, 3, 4, 4, 4, 5],
        ]
        self.last7ByCourseMetric = [
            "courses_completed": [0, 0, 0, 1, 0, 0, 0],
            "courses_started": [0, 1, 0, 0, 0, 1, 0],
            "courses_active": [1, 1, 1, 1, 1, 1, 1],
        ]
        self.weeklyByLessonMetric = [
            "lessons_completed": [1, 2, 2, 3, 3, 4, 4, 5],
            "words_learned": [10, 14, 16, 18, 24, 30, 36, 42],
            "phrases_learned": [2, 3, 3, 4, 5, 6, 8, 9],
        ]
        self.last7ByLessonMetric = [
            "lessons_completed": [0, 1, 0, 1, 0, 1, 0],
            "words_learned": [4, 6, 3, 7, 5, 9, 8],
            "phrases_learned": [1, 1, 0, 2, 1, 2, 2],
        ]
        self.style = .appDS
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                AppMiniChip(
                    title: PDProgressScope.courses.rawValue,
                    style: (scope == .courses) ? .accent : .neutral
                ) {
                    onScopeChange(.courses)
                }

                AppMiniChip(
                    title: PDProgressScope.lessons.rawValue,
                    style: (scope == .lessons) ? .accent : .neutral
                ) {
                    onScopeChange(.lessons)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)

            if scope == .courses {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(coursesMetrics, id: \.key) { m in
                            AppMetricDeltaChip(
                                item: AppMetricDeltaItem(
                                    title: m.title,
                                    value: m.value7d,
                                    delta: (m.delta7d ?? "")
                                ),
                                onTap: {
                                    onSelectCourseMetric(m.key)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                let w = weeklyByCourseMetric[selectedCourseMetricKey.wrappedValue] ?? [2, 3, 4, 3, 5, 6, 6, 7]
                let d = last7ByCourseMetric[selectedCourseMetricKey.wrappedValue] ?? [0, 1, 1, 2, 1, 3, 2]

                PDTwoGraphBlock(
                    weekly: w,
                    last7: d,
                    style: style
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(lessonsMetrics, id: \.key) { m in
                            AppMetricDeltaChip(
                                item: AppMetricDeltaItem(
                                    title: m.title,
                                    value: m.value7d,
                                    delta: (m.delta7d ?? "")
                                ),
                                onTap: {
                                    onSelectLessonMetric(m.key)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                let w = weeklyByLessonMetric[selectedLessonMetricKey.wrappedValue] ?? [6, 7, 8, 7, 9, 10, 11, 12]
                let d = last7ByLessonMetric[selectedLessonMetricKey.wrappedValue] ?? [2, 3, 1, 4, 2, 5, 3]

                PDTwoGraphBlock(
                    weekly: w,
                    last7: d,
                    style: style
                )
            }
        }
        .padding(.bottom, 2)
        .padding(.top, 2)
    }
}

// MARK: - preview/demo wrapper (state only for previews)
private struct PDProgressPanelDemo: View {
    @State private var scope: PDProgressScope = .courses
    @State private var selectedCourseMetric: String = "courses_completed"
    @State private var selectedLessonMetric: String = "lessons_completed"

    private let coursesMetrics: [PDMetric] = [
        .init(key: "courses_completed", title: "пройдено", value7d: "1", delta7d: "+1"),
        .init(key: "courses_started", title: "начато", value7d: "2", delta7d: "+0"),
        .init(key: "courses_active", title: "активно", value7d: "3", delta7d: "+1")
    ]

    private let lessonsMetrics: [PDMetric] = [
        .init(key: "lessons_completed", title: "уроки", value7d: "3", delta7d: "+1"),
        .init(key: "words_learned", title: "слова", value7d: "42", delta7d: "+8"),
        .init(key: "phrases_learned", title: "фразы", value7d: "9", delta7d: "+2")
    ]

    private let weeklyByCourse: [String: [Double]] = [
        "courses_completed": [0, 0, 1, 1, 1, 2, 2, 3],
        "courses_started": [1, 1, 1, 2, 2, 2, 3, 3],
        "courses_active": [2, 2, 3, 3, 4, 4, 4, 5]
    ]

    private let last7ByCourse: [String: [Double]] = [
        "courses_completed": [0, 0, 0, 1, 0, 0, 0],
        "courses_started": [0, 1, 0, 0, 0, 1, 0],
        "courses_active": [1, 1, 1, 1, 1, 1, 1]
    ]

    private let weeklyByLesson: [String: [Double]] = [
        "lessons_completed": [1, 2, 2, 3, 3, 4, 4, 5],
        "words_learned": [10, 14, 16, 18, 24, 30, 36, 42],
        "phrases_learned": [2, 3, 3, 4, 5, 6, 8, 9]
    ]

    private let last7ByLesson: [String: [Double]] = [
        "lessons_completed": [0, 1, 0, 1, 0, 1, 0],
        "words_learned": [4, 6, 3, 7, 5, 9, 8],
        "phrases_learned": [1, 1, 0, 2, 1, 2, 2]
    ]

    var body: some View {
        PDProgressPanel(
            scope: scope,
            onScopeChange: { scope = $0 },
            coursesMetrics: coursesMetrics,
            lessonsMetrics: lessonsMetrics,
            selectedCourseMetricKey: $selectedCourseMetric,
            selectedLessonMetricKey: $selectedLessonMetric,
            onSelectCourseMetric: { selectedCourseMetric = $0 },
            onSelectLessonMetric: { selectedLessonMetric = $0 },
            weeklyByCourseMetric: weeklyByCourse,
            last7ByCourseMetric: last7ByCourse,
            weeklyByLessonMetric: weeklyByLesson,
            last7ByLessonMetric: last7ByLesson,
            style: .appDS
        )
    }
}


// MARK: - Activity (last 7 days heat + day note)
public struct PDActivityDay: Hashable {
    public var key: String            // stable id (e.g. yyyy-mm-dd)
    public var title: String          // e.g. "вчера", "сегодня", "пн"
    public var intensity01: Double    // 0...1 (storage stays simple; mapping to AppDS is inside the panel)

    // legacy/fallback (kept for now)
    public var lines: [String]        // short summary lines

    // AppDS lego payload (preferred)
    public var events: [PDActivityEvent]

    public init(key: String, title: String, intensity: Double, lines: [String] = [], events: [PDActivityEvent] = []) {
        self.key = key
        self.title = title
        self.intensity01 = max(0, min(1, intensity))
        self.lines = lines
        self.events = events
    }

    public var summary: String {
        if !lines.isEmpty { return lines.joined(separator: " • ") }
        if events.isEmpty { return "нет активности" }

        // compact summary from events (title/value)
        let parts: [String] = events.compactMap {
            if let v = $0.value, !v.isEmpty { return "\($0.title): \(v)" }
            return $0.title
        }
        return parts.isEmpty ? "нет активности" : parts.joined(separator: " • ")
    }
}

public struct PDActivityEvent: Hashable {
    public var kind: AppActivityEventKind
    public var title: String
    public var subtitle: String?
    public var value: String?

    public init(kind: AppActivityEventKind, title: String, subtitle: String? = nil, value: String? = nil) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.value = value
    }
}

public struct PDActivityPanel: View {
    public var days: [PDActivityDay]
    public var selectedIndex: Binding<Int?>
    public var onSelect: (Int?) -> Void
    public var style: PDStyle = .appDS

    @State private var showInfo: Bool = false

    public init(
        days: [PDActivityDay],
        selectedIndex: Binding<Int?>,
        onSelect: @escaping (Int?) -> Void,
        style: PDStyle = .appDS
    ) {
        self.days = days
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        self.style = style
    }

    // DS-only mock: do NOT reference concrete AppActivityEventKind cases here.
    // AppDS owns the enum cases; ProfileDS should compile even if AppDS changes them.
    public init(style: PDStyle = .appDS) {
        self.days = [
            .init(key: "d-6", title: "", intensity: 0.05, events: []),
            .init(key: "d-5", title: "", intensity: 0.20, events: []),
            .init(key: "d-4", title: "", intensity: 0.35, events: []),
            .init(key: "d-3", title: "", intensity: 0.55, events: []),
            .init(key: "d-2", title: "", intensity: 0.15, events: []),
            .init(key: "d-1", title: "", intensity: 0.75, events: []),
            .init(key: "d0", title: "", intensity: 0.00, events: [])
        ]
        self.selectedIndex = .constant(nil)
        self.onSelect = { _ in }
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("последние 7 дней")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundColor(style.textSecondary)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showInfo.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.textSecondary)
                        .opacity(0.85)
                }
                .buttonStyle(.plain)
            }

            if showInfo {
                Text("яркость квадрата = интенсивность дня. тап — показать, что происходило")
                    .font(PD.FontToken.caption(13, weight: .regular))
                    .foregroundColor(style.textSecondary)
                    .transition(.opacity)
            }

            // AppDS lego: week heat row
            AppActivityWeekRow(
                intensities: days.map { AppActivityIntensity.from01($0.intensity01) },
                selectedIndex: selectedIndex.wrappedValue ?? -1,
                onSelect: { idx in
                    if idx < 0 || idx >= days.count {
                        selectedIndex.wrappedValue = nil
                        onSelect(nil)
                    } else {
                        selectedIndex.wrappedValue = idx
                        onSelect(idx)
                    }
                }
            )
            .frame(height: 32)

            // (weekday label row removed)

            if let i = selectedIndex.wrappedValue, days.indices.contains(i) {
                let d = days[i]
                AppActivityDayNoteCard(
                    dayTitle: "",
                    summary: d.summary,
                    intensity: AppActivityIntensity.from01(d.intensity01),
                    events: d.events.map {
                        AppActivityEvent(
                            kind: $0.kind,
                            title: $0.title,
                            subtitle: $0.subtitle
                        )
                    },
                    onDetails: {}
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedIndex.wrappedValue)
        .padding(.top, 2)
    }
}

// MARK: - Compatibility aliases (for existing ProfileView references)
// Do NOT use these in new code. Kept only to avoid breaking old call sites.

public typealias PDMyProgressPanel = PDProgressPanel
public typealias PDMyActivityPanel = PDActivityPanel


// MARK: - Study accordion (list + one detail panel)
public enum PDStudyPanel: Hashable {
    case progress
    case activity
}

public struct PDStudyAccordion: View {
    // compatibility shim: older call sites reference PDStudyAccordion.Selection
    public typealias Selection = PDStudyPanel
    public var selected: PDStudyPanel?
    public var onSelect: (PDStudyPanel?) -> Void
    public var progressContent: AnyView
    public var activityContent: AnyView
    public var style: PDStyle = .appDS

    public init(
        selected: PDStudyPanel?,
        onSelect: @escaping (PDStudyPanel?) -> Void,
        progressContent: AnyView,
        activityContent: AnyView,
        style: PDStyle = .appDS
    ) {
        self.selected = selected
        self.onSelect = onSelect
        self.progressContent = progressContent
        self.activityContent = activityContent
        self.style = style
    }

    public init(
        selected: PDStudyPanel?,
        onSelect: @escaping (PDStudyPanel?) -> Void,
        @ViewBuilder progressContent: () -> some View,
        @ViewBuilder activityContent: () -> some View,
        style: PDStyle = .appDS
    ) {
        self.selected = selected
        self.onSelect = onSelect
        self.progressContent = AnyView(progressContent())
        self.activityContent = AnyView(activityContent())
        self.style = style
    }

    public var body: some View {
        PDListGroup([
            .init(
                icon: "graduationcap",
                title: "мой прогресс",
                isExpanded: selected == .progress,
                action: {
                    onSelect(selected == .progress ? nil : .progress)
                },
                expandedContent: (selected == .progress)
                    ? AnyView(
                        progressContent
                            .padding(.top, PD.Spacing.tiny)
                            .transition(.opacity)
                    )
                    : nil
            ),
            .init(
                icon: "chart.bar",
                title: "моя активность",
                isExpanded: selected == .activity,
                action: {
                    onSelect(selected == .activity ? nil : .activity)
                },
                expandedContent: (selected == .activity)
                    ? AnyView(
                        activityContent
                            .padding(.top, PD.Spacing.tiny)
                            .transition(.opacity)
                    )
                    : nil
            )
        ], style: style)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: selected)
    }
}

// MARK: - Preview
#Preview("Profile DS") {
    ZStack {
        PDStyle.appDS.background.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 0) {
                PDFMSection()

                PDSection("Учёба") {
                    _PDStudyAccordionDemo()
                }

                PDSection("Аккаунт") {
                    PDListGroup([
                        .init(icon: "creditcard", title: "Оплата и подписка", action: {}),
                        .init(icon: "rectangle.and.pencil.and.ellipsis", title: "Личная информация", action: {}),
                    ])
                }

                PDSection("Служба") {
                    PDListGroup([
                        .init(icon: "questionmark.circle", title: "Помощь и поддержка", action: {}),
                    ])
                }
            }
            .padding(.vertical, 20)
        }
    }
}

private struct _PDStudyAccordionDemo: View {
    @State private var selected: PDStudyPanel? = .progress

    var body: some View {
        PDStudyAccordion(
            selected: selected,
            onSelect: { selected = $0 },
            progressContent: AnyView(PDProgressPanelDemo()),
            activityContent: AnyView(_PDActivityPanelDemo())
        )
    }
}

private struct _PDActivityPanelDemo: View {
    @State private var selected: Int? = nil

    var body: some View {
        let mock = PDActivityPanel(style: .appDS)
        PDActivityPanel(
            days: mock.days,
            selectedIndex: $selected,
            onSelect: { selected = $0 },
            style: .appDS
        )
    }
}


// MARK: - Helper: Map 0...1 to AppActivityIntensity
private extension AppActivityIntensity {
    static func from01(_ v: Double) -> AppActivityIntensity {
        let x = max(0, min(1, v))
        // keep ProfileDS strictly aligned with AppDS contract: only use cases that exist there.
        // AppDS currently exposes `.low` and `.high` (no `.none`, `.medium`, `.max`).
        if x < 0.45 { return .low }
        return .high
    }
}
