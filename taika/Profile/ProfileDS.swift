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
}

// MARK: - Header Card
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

// MARK: - Section container (title + card)
public struct PDSection<Content: View>: View {
    public var title: String
    @ViewBuilder public var content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(PD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(PD.ColorToken.textSecondary)
                .padding(.horizontal, PD.Spacing.screen)
            
            // Content itself (e.g., PDListGroup) draws its own card.
            content
                .padding(.horizontal, PD.Spacing.screen)
        }
        .padding(.top, 16)
    }
}

// MARK: - Row cell with chevron
public struct PDRow: View {
    public var systemIcon: String
    public var title: String
    public var action: () -> Void

    public init(icon: String, title: String, action: @escaping () -> Void) {
        self.systemIcon = icon
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: PD.Spacing.inner) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PD.ColorToken.chip)
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PD.ColorToken.stroke, lineWidth: 1)
                        )
                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PD.ColorToken.text)
                }
                Text(title)
                    .font(PD.FontToken.body(17, weight: .regular))
                    .foregroundColor(PD.ColorToken.text)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PD.ColorToken.textSecondary)
            }
            .padding(.horizontal, PD.Spacing.inner)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PD.ColorToken.stroke)
                .frame(height: 1)
                .padding(.leading, 68)
        }
    }
}

// MARK: - Grouped list helper
public struct PDListGroup: View {
    public var rows: [Row]
    public struct Row { public var icon: String; public var title: String; public var action: () -> Void }

    public init(_ rows: [Row]) { self.rows = rows }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, r in
                PDRow(icon: r.icon, title: r.title, action: r.action)
                    .overlay(alignment: .bottom) {
                        if idx == rows.count - 1 { EmptyView() } // hide separator on last
                    }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .fill(PD.ColorToken.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .stroke(PD.ColorToken.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview("Profile DS") {
    ZStack {
        PD.ColorToken.background.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 0) {
                PDHeaderCard(
                    title: "Профиль и настройки",
                    subtitle: "Управляй прогрессом и подпиской",
                    cta: "Мой прогресс",
                    mascot: Image("mascot.profile")) {
                        // stub
                    }
                PDSection("Учёба") {
                    PDListGroup([
                        .init(icon: "graduationcap", title: "Мой прогресс", action: {}),
                        .init(icon: "star", title: "Избранное", action: {}),
                        .init(icon: "clock", title: "История уроков", action: {}),
                    ])
                }
                PDSection("Аккаунт") {
                    PDListGroup([
                        .init(icon: "rectangle.and.pencil.and.ellipsis", title: "Личная информация", action: {}),
                        .init(icon: "lock", title: "Вход и безопасность", action: {}),
                        .init(icon: "creditcard", title: "Оплата и подписка", action: {}),
                    ])
                }
                PDSection("Служба") {
                    PDListGroup([
                        .init(icon: "gear", title: "Настройки", action: {}),
                        .init(icon: "questionmark.circle", title: "Помощь и поддержка", action: {}),
                        .init(icon: "paperplane", title: "Написать нам", action: {}),
                    ])
                }
            }
            .padding(.vertical, 20)
        }
    }
}
