
import SwiftUI

// Temporary Theme shim for preview (maps to app tokens later)
public enum Theme {
    public enum Colors {
        public static let backgroundPrimary   = Color(red: 0.06, green: 0.06, blue: 0.07)
        public static let backgroundSecondary = Color(red: 0.09, green: 0.09, blue: 0.10)
        public static let card                = Color(red: 0.12, green: 0.12, blue: 0.13)
        public static let accent              = Color(red: 0.96, green: 0.48, blue: 0.82) // TODO: bind to design token
        public static let textPrimary         = Color(red: 0.93, green: 0.96, blue: 1.00) // cool off‑white for richer ink on dark bg
    }
    // unified layout rhythm for screens (root views) — use instead of magic numbers
    public enum Layout {
        /// horizontal page padding for root screens
        public static let pageHorizontal: CGFloat = 16
        /// vertical gap between global header and the first section on root screens
        public static let pageTopAfterHeader: CGFloat = 55
        public static let pageTopAfterBackHeader: CGFloat = 55
        /// default vertical gap between major sections
        public static let sectionGap: CGFloat = 16
        /// vertical gap between a big header-card (e.g. lesson/course header) and the next section
        /// (needs to be larger than sectionGap to avoid card shadow/chrome overlap)
        public static let headerToSection: CGFloat = 24
        /// inner padding for section containers (cards/panels)
        public static let sectionInner: CGFloat = 16
        /// bottom safe gap (keeps content above bottom toolbar)
        public static let pageBottomSafeGap: CGFloat = 44
        /// legacy alias used by some screens
        public static let pageBottom: CGFloat = pageBottomSafeGap

        // MARK: - global bottom insets (avoid magic numbers in views)
        /// minimum bottom padding for scroll content
        public static let bottomInsetMin: CGFloat = 16
        /// reserved height for the bottom tab bar (toolbar)
        public static let bottomToolbarHeight: CGFloat = 56

        // MARK: - paywall layout (glass)
        public static let paywallHPad: CGFloat = 16
        /// reserved space for pro chip + close in the chrome
        public static let paywallChromeReserve: CGFloat = 58
        /// minimum gap between header / carousel / cta
        public static let paywallMinSectionGap: CGFloat = 18
        public static let paywallBottomInset: CGFloat = 16
        public static let paywallCarouselHeight: CGFloat = 232
        /// fixed height for paywall card (empty vs content)
        public static let paywallCardHeightEmpty: CGFloat = 520
        public static let paywallCardHeightFull: CGFloat = 680
        /// internal padding for glass content
        public static let paywallInnerVPad: CGFloat = 18
        public static let paywallInnerHPad: CGFloat = 20

        // MARK: - course ds bridging tokens (keep values stable)
        /// vertical spacing between stacked cards/rows inside a section (course ds)
        public static let sectionContentV: CGFloat = 12
        /// spacing from section title row to section content (course ds)
        public static let sectionTitleToContent: CGFloat = 14
        /// spacing between sections (top padding applied by course ds sections)
        public static let sectionTop: CGFloat = 20
        /// vertical padding for carousels inside sections (top+bottom)
        public static let carouselVPad: CGFloat = 4

        // MARK: - intra-section (course ds)
        public static let rowV: CGFloat = 10
        public static let rowH: CGFloat = 10
        public static let chipGap: CGFloat = 10
        public static let metaGap: CGFloat = 6
        public static let iconGap: CGFloat = 8
        public static let inlineDividerGap: CGFloat = 6
        
        // MARK: - lessons ds: lesson header internal layout
        /// horizontal padding inside lesson header container
        public static let lessonHeaderHPad: CGFloat = PD.Spacing.screen
        /// top inset inside lesson header container
        public static let lessonHeaderTopInset: CGFloat = 28
        /// bottom inset inside lesson header container
        public static let lessonHeaderBottomInset: CGFloat = 20
        /// spacing between title and subtitle
        public static let lessonHeaderTitleToSubtitle: CGFloat = 12
        /// spacing between subtitle and progress row
        public static let lessonHeaderSubtitleToProgress: CGFloat = 18
        /// extra top padding applied to subtitle block (keeps air)
        public static let lessonHeaderSubtitleExtraTop: CGFloat = 8
        /// top padding applied to progress group
        public static let lessonHeaderProgressTop: CGFloat = 8

        // intra-section rhythm (padding and spacing INSIDE a section)
        public enum Section {
            /// horizontal inset for section content blocks
            public static let contentHorizontal: CGFloat = 16
            /// top inset for section content (under the section title/header row)
            public static let contentTop: CGFloat = 12
            /// bottom inset for section content
            public static let contentBottom: CGFloat = 16
            /// vertical gap between a section title row and its content
            public static let titleToContentGap: CGFloat = 12
            /// vertical gap between items inside a section content stack
            public static let itemGap: CGFloat = 12
        }
    }
    
    public enum Fonts {
        public static func appTitle(_ size: CGFloat) -> Font { .custom("ONMARK Trial", size: size) }
        public static let heading: Font = .system(size: 22, weight: .semibold, design: .rounded)
        public static let body: Font    = .system(size: 16, weight: .regular, design: .rounded)
        public static let caption: Font = .system(size: 12, weight: .regular, design: .rounded)
    }
    public enum Radii {
        public static let card: CGFloat = 16
        public static let chip: CGFloat = 12
    }
    public enum Spacing {
        public static let outer: CGFloat = 16
    }
    public enum Gradients {
        /// Subtle glossy overlay used for panels/cards
        public static let panelGloss = LinearGradient(
            colors: [
                Color.white.opacity(0.08),   // очень мягкий верхний хайлайт
                Color.white.opacity(0.0)     // плавный уход в ноль
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        /// Neutral, low-contrast overlay for secondary chips/filters
        public static let chipNeutral = LinearGradient(
            colors: [Color.white.opacity(0.04), .white.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        /// Accent gradient for highlighted inline text (brighter pink → gentle lilac)
        public static let accentText = LinearGradient(
            colors: [
                // vivid pink start
                Color(red: 1.00, green: 0.52, blue: 0.85).opacity(1.0),
                // rosy mid (keeps warmth without washing out)
                Color(red: 0.98, green: 0.65, blue: 0.92).opacity(0.98),
                // soft lilac end (not white)
                Color(red: 0.90, green: 0.78, blue: 1.00).opacity(0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// compatibility alias (older DS code)
        public static let accentPink = accentText
        /// Ultra‑subtle ink sheen for primary text (opt‑in)
        public static let textPrimarySheen = LinearGradient(
            colors: [Color.white.opacity(0.06), .clear],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Accent variant — Azure (softer jungle → sky)
        public static let accentAzure = LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.40, blue: 0.24), // wild jungle green
                Color(red: 0.20, green: 0.62, blue: 0.58), // soft lagoon teal (softer mid)
                Color(red: 0.78, green: 0.90, blue: 1.00)  // pale clear-sky blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Accent variant — Sun (yolk yellow → ember)
        public static let accentSun = LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.97, blue: 0.70), // clear sunny yellow (lighter start)
                Color(red: 1.00, green: 0.88, blue: 0.36), // warm midday yellow
                Color(red: 0.93, green: 0.34, blue: 0.08)  // ember orange (deeper, like coals)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Accent variant — Thai Tricolor (red‑currant → deep ocean blue)
        public static let accentThaiTricolor = LinearGradient(
            colors: [
                Color(red: 0.88, green: 0.15, blue: 0.28), // red‑currant
                Color(red: 0.10, green: 0.24, blue: 0.58)  // deep ocean blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public enum Surfaces {
        /// Unified card surface: glassy, layered look
        public static func card<S: Shape>(_ shape: S) -> some View {
            shape
                .fill(Color.clear)
                .background(
                    .ultraThinMaterial
                        .opacity(0.72)
                )
                .clipShape(shape)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.02),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 28)
                    .mask(shape)
                )
                .overlay(
                    shape.stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        }
    }

    public struct AccentInlineText: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .compositingGroup() // isolate from parent foreground/overlays
                .foregroundStyle(Theme.Gradients.accentText)
                // inner vertical gloss (as in LessonsDS)
                .overlay(
                    LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .blendMode(.screen)
                        .mask(content)
                )
                // shadows tuned to LessonsDS
                .shadow(color: Color.black.opacity(0.40), radius: 1.0, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.28), radius: 5, x: 0, y: 7)
                // keep crispness
                .saturation(1.08)
                .contrast(1.04)
        }
    }
}

struct ThemePreview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: — Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("taikA — Design Moodboard")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text("Quick glance at colors, type, and components")
                        .font(.caption)
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

// MARK: — Colors Grid
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Colors")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        Swatch(name: "backgroundPrimary", desc: "Main background", color: Theme.Colors.backgroundPrimary)
                        Swatch(name: "backgroundSecondary", desc: "Secondary surface", color: Theme.Colors.backgroundSecondary)
                        Swatch(name: "card", desc: "Card surface", color: Theme.Colors.card)
                        Swatch(name: "accent", desc: "Accent / action", color: Theme.Colors.accent)
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Accent Variants (Gradients)
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Accent Variants")
                    VStack(spacing: 12) {
                        GradientSwatch(name: "accentAzure", desc: "лазурно‑голубой → зелёный", gradient: Theme.Gradients.accentAzure)
                        GradientSwatch(name: "accentSun", desc: "светло‑жёлтый (желток) → костёр", gradient: Theme.Gradients.accentSun)
                        GradientSwatch(name: "accentThaiTricolor", desc: "триколор Таиланда", gradient: Theme.Gradients.accentThaiTricolor)
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Typography (removed legacy panel; see FontShowcaseView below)

                // MARK: — Typography • Brand Set (showcase)
                FontShowcaseView()
                    .padding(20)
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Components snapshot
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Components")
                    VStack(spacing: 12) {
                        SpecCard(title: "Привет", subtitle: "са-ват-ди", tag: "Приветствие")
                        HStack(spacing: 12) {
                            PrimaryButtonPreview(title: "добавить в избранное")
                            OutlineButtonPreview(title: "играть ещё")
                        }
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Chips & Filters
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Chips & Filters")
                    HStack(spacing: 10) {
                        ChipPreview(title: "все", style: .neutral)
                        ChipPreview(title: "любимые", style: .active)
                        ChipPreview(title: "скрытые", style: .disabled)
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Tokens quicklook
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(text: "Tokens")
                    LabeledValue(label: "Card radius", value: "\(Int(Theme.Radii.card))")
                    LabeledValue(label: "Chip radius", value: "\(Int(Theme.Radii.chip))")
                    LabeledValue(label: "Outer spacing", value: "\(Int(Theme.Spacing.outer))")
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer(minLength: 8)
            }
            .padding(16)
            .background(Theme.Colors.backgroundPrimary)
            .foregroundColor(Theme.Colors.textPrimary)
        }
    }

    // Subviews & helpers
    private var panel: some View {
        Theme.Colors.backgroundSecondary
            .overlay(Theme.Gradients.panelGloss)
    }
}

private struct SectionHeader: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.Colors.accent.opacity(0.6)).frame(width: 6, height: 6)
            Text(text).font(.system(size: 14, weight: .semibold, design: .rounded)).opacity(0.9)
        }
    }
}

private struct Swatch: View {
    let name: String
    let desc: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(width: 56, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.caption.bold())
                Text(desc).font(.caption).opacity(0.65)
            }
            Spacer()
        }
    }
}

private struct SpecCard: View {
    let title: String
    let subtitle: String
    let tag: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .taikaAccentText()
            HStack {
                Image(systemName: "heart.fill").font(.footnote)
                Text(tag).font(.footnote)
                Spacer()
                Image(systemName: "speaker.wave.2.fill")
            }
            .opacity(0.8)
        }
        .padding(16)
        .background(
            ZStack {
                Theme.Colors.card
                Theme.Gradients.panelGloss
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radii.card).stroke(Color.white.opacity(0.06)))
    }
}

private struct PrimaryButtonPreview: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(
                LinearGradient(colors: [Theme.Colors.accent.opacity(0.9), Theme.Colors.accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
    }
}

private struct OutlineButtonPreview: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.Colors.backgroundPrimary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.accent.opacity(0.6), lineWidth: 1))
    }
}

private struct ChipPreview: View {
    enum Style { case neutral, active, disabled }
    let title: String
    let style: Style
    var body: some View {
        let fg: Color = {
            switch style {
            case .active:   return Color.black.opacity(0.88)   // dark text on accent
            case .disabled: return Color.white.opacity(0.55)
            case .neutral:  return Theme.Colors.textPrimary
            }
        }()
        let stroke: Color = {
            switch style {
            case .active:   return Theme.Colors.accent.opacity(0.85)
            case .disabled: return Color.white.opacity(0.06)
            case .neutral:  return Color.white.opacity(0.12)
            }
        }()

        let base: some View = Group {
            switch style {
            case .neutral:
                ZStack {
                    Theme.Colors.backgroundSecondary
                    Theme.Gradients.chipNeutral
                    // soft top highlight for glassy feel
                    LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center)
                        .blendMode(.screen)
                }
            case .active:
                ZStack {
                    LinearGradient(colors: [Theme.Colors.accent.opacity(0.95), Theme.Colors.accent.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    // inner glossy highlight
                    LinearGradient(colors: [Color.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                        .blendMode(.screen)
                }
            case .disabled:
                ZStack {
                    Theme.Colors.backgroundSecondary.opacity(0.7)
                    LinearGradient(colors: [Color.white.opacity(0.04), .clear], startPoint: .top, endPoint: .bottom)
                        .blendMode(.screen)
                }
            }
        }

        return Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(fg)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                Capsule().fill(.clear).overlay(base.clipShape(Capsule()))
            )
            .overlay(
                Capsule().stroke(stroke, lineWidth: 1)
                    .overlay(
                        // inner stroke for depth
                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5).blendMode(.overlay)
                    )
            )
            .shadow(color: Color.black.opacity(style == .active ? 0.18 : 0.10), radius: style == .active ? 10 : 6, x: 0, y: 4)
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.caption.bold()).opacity(0.85)
        }
        .padding(.vertical, 2)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.06)), alignment: .bottom)
    }
}

// Brand font showcase helper view
private struct FontShowcaseView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(text: "Typography — Brand Set")

            // Название приложения (ONMARK Trial)
            VStack(alignment: .leading, spacing: 4) {
                Text("Название приложения")
                    .font(.caption)
                    .opacity(0.65)
                Text("taikA")
                    .font(Theme.Fonts.appTitle(36))
            }

            Divider().opacity(0.08)

            // Название курса (Heading)
            VStack(alignment: .leading, spacing: 4) {
                Text("Название курса (Heading)")
                    .font(.caption)
                    .opacity(0.65)
                Text("Основы тайского языка")
                    .font(Theme.Fonts.heading)
            }

            // Описание курса (Body)
            VStack(alignment: .leading, spacing: 4) {
                Text("Описание курса (Body)")
                    .font(.caption)
                    .opacity(0.65)
                Text("Короткое описание курса — русская транслитерация, тайские слова и примеры предложений.")
                    .font(Theme.Fonts.body)
                    .opacity(0.92)
            }

            // Заголовок секции (Semibold 22)
            VStack(alignment: .leading, spacing: 4) {
                Text("Заголовок секции (Semibold 22)")
                    .font(.caption)
                    .opacity(0.65)
                Text("Избранное • повторы • мини‑игры")
                    .font(Theme.Fonts.heading)
            }

            // Текст кнопки (Semibold 14)
            VStack(alignment: .leading, spacing: 4) {
                Text("Текст кнопки (Semibold 14)")
                    .font(.caption)
                    .opacity(0.65)
                Text("играть ещё")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }

            // Подпись / Caption (12)
            VStack(alignment: .leading, spacing: 4) {
                Text("Подпись / Caption (12)")
                    .font(.caption)
                    .opacity(0.65)
                Text("са‑ват‑ди • приветствие")
                    .font(Theme.Fonts.caption)
                    .opacity(0.9)
            }

            // Accent inline text (градиентный токен)
            VStack(alignment: .leading, spacing: 4) {
                Text("Accent inline (taikaAccentText)")
                    .font(.caption)
                    .opacity(0.65)
                Text("тайка — акцентный текст")
                    .font(Theme.Fonts.body)
                    .taikaAccentText()
            }
        }
    }
}

#Preview {
    ThemePreview()
}

// Convenience View extension for taika accent inline text
extension View {
    /// Apply taika inline accent text (1:1 with LessonsDS)
    func taikaAccentText() -> some View {
        modifier(Theme.AccentInlineText())
    }
}
private struct GradientSwatch: View {
    let name: String
    let desc: String
    let gradient: LinearGradient
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(gradient)
                .frame(width: 56, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.caption.bold())
                Text(desc).font(.caption).opacity(0.65)
            }
            Spacer()
        }
    }
}
