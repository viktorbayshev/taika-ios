//
//  CourseAnimation.swift
//  taika
//
//  Created by product on 20.09.2025.
//

import SwiftUI

// MARK: - Public surface
//
// используем в DS только при необходимости:
//   .modifier(CourseGlowModifier(active: isActive))
//
// используем в Course/Base View:
//   CourseAnimation.markLastOpened(courseId)
//   CourseAnimation.scrollToLastIfAny(proxy: proxy, anchor: .center)
//
public enum CourseAnimation {
    // MARK: last-opened course (autoscroll support)
    private static let lastOpenedKey = "CourseAnimation.lastOpenedCourseId"

    /// Запомнить последний открытый курс (вызови при входе на CourseDetail)
    public static func markLastOpened(_ courseId: String) {
        UserDefaults.standard.set(courseId, forKey: lastOpenedKey)
    }

    /// Прочитать сохранённый id
    public static func lastOpened() -> String? {
        UserDefaults.standard.string(forKey: lastOpenedKey)
    }

    /// Автоскролл к последнему открытому курсу.
    /// Вызывать внутри ScrollViewReader.
    public static func scrollToLastIfAny(
        proxy: ScrollViewProxy,
        anchor: UnitPoint = .center,
        animated: Bool = true
    ) {
        guard let id = lastOpened() else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.45)) {
                proxy.scrollTo(id, anchor: anchor)
            }
        } else {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}

// MARK: - Tones (palette)


// MARK: - Outline geometry options
public enum CourseOutlineStyle: CaseIterable {
    case plain          // ровный контур
}

// MARK: - Glow Modifier (reusable, non-intrusive)
public struct CourseGlowModifier: ViewModifier {
    public var active: Bool
    public var outlineStyle: CourseOutlineStyle = .plain
    public var cornerRadius: CGFloat = CD.Radius.card

    @State private var angle: Double = 0

    public init(
        active: Bool,
        outlineStyle: CourseOutlineStyle = .plain,
        cornerRadius: CGFloat = CD.Radius.card
    ) {
        self.active = active
        self.outlineStyle = outlineStyle
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .overlay(outlineLayer, alignment: .center)
            .onAppear { startDynamicIfNeeded() }
            .onChange(of: active) { _ in startDynamicIfNeeded() }
            .onChange(of: outlineStyle) { _ in startDynamicIfNeeded() }
    }

    private var cardMask: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var outlineLayer: some View {
        Group {
            if active {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ZStack {
                        // 1) Outline stroke with dynamic animated gradient (metallic/pearl palette)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.85),
                                        Color.gray.opacity(0.6),
                                        Color.white.opacity(0.95),
                                        Color.gray.opacity(0.6),
                                        Color.white.opacity(0.85)
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(angle),
                                    endAngle: .degrees(angle + 360)
                                ),
                                lineWidth: 1
                            )
                            .blur(radius: 5)
                            .opacity(0.9)
                            .blendMode(.screen)
                            .allowsHitTesting(false)

                        // 4) Soft halo (common, subtle)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.20),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                ),
                                lineWidth: 1
                            )
                            .blur(radius: 3)
                            .opacity(0.28)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                    .mask(cardMask)
                }
            }
        }
    }

    private func startDynamicIfNeeded() {
        guard active else { angle = 0; return }
        // перезапуск анимации
        angle = 0
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }
}

// MARK: - Convenience API
public extension View {
    /// Применить светящееся оформление к карточке курса (outline only).
    func courseGlow(
        active: Bool,
        outlineStyle: CourseOutlineStyle = .plain,
        cornerRadius: CGFloat = CD.Radius.card
    ) -> some View {
        self.modifier(
            CourseGlowModifier(
                active: active,
                outlineStyle: outlineStyle,
                cornerRadius: cornerRadius
            )
        )
    }
}

// MARK: - Preview (cards with controls)
struct CourseGlowPreview: View {
    @State private var active = true

    var body: some View {
        VStack(spacing: 16) {
            // Controls
            HStack {
                Toggle("Active", isOn: $active)
                Spacer()
            }

            // Demo cards (match DS geometry roughly)
            HStack(spacing: 16) {
                demoCard(title: "Course Card", size: CGSize(width: 220, height: 360))
                demoCard(title: "Reel Card", size: CGSize(width: 180, height: 280))
            }
        }
        .padding()
        .background(PD.ColorToken.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func demoCard(title: String, size: CGSize) -> some View {
        ZStack {
            // base DS card look
            RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous)
                        .stroke(CD.ColorToken.stroke, lineWidth: 1)
                )

            VStack(spacing: 8) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text("Outline: Plain (accent dynamic)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(width: size.width, height: size.height)
        .courseGlow(active: active)
        .animation(Animation.easeInOut, value: active)
    }
}

struct CourseGlowPreview_Previews: PreviewProvider {
    static var previews: some View {
        CourseGlowPreview()
            .preferredColorScheme(.dark)
    }
}
