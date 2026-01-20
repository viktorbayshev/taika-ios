//
//  VisualEffectsDS.swift
//  taika
//
//  Created by product on 31.10.2025.
//
import SwiftUI

// MARK: - единые метрики карточек (как в CourseDS)
public enum DSMetrics {
    public static let cardWidth:  CGFloat = CardDS.Metrics.courseCardWidth
    public static let cardHeight: CGFloat = CardDS.Metrics.courseCardHeight
    public static let reelSpacing: CGFloat = 18
}

// MARK: - общий градиент/цвета токены (оборачиваем ThemeManager)
public enum DSFill {
    public static var accent: AnyShapeStyle { AnyShapeStyle(ThemeManager.shared.currentAccentFill) }
    public static var card: Color { PD.ColorToken.card }
}

// MARK: - единый 3D-эффект глубины (как в CourseDS)
public struct DSDepth3D: ViewModifier {
    let tilt: Double
    let scale: CGFloat
    let opacity: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    public func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.78)
            .scaleEffect(scale)
            .opacity(opacity)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
            .compositingGroup()
    }
}

public enum DSDepth {
    @inline(__always)
    public static func params(dx: CGFloat, outerWidth: CGFloat)
    -> (tilt: Double, scale: CGFloat, opacity: CGFloat, shadowOpacity: Double, shadowRadius: CGFloat, shadowY: CGFloat) {

        let dx0: CGFloat = (abs(dx) < 0.75) ? 0 : dx
        let denom = max(1, outerWidth * 0.72)
        let norm  = min(1.0, abs(dx0) / denom)
        let t     = 1.0 - norm

        let tilt  = Double(-dx0 / 14.0)
        let scale = 0.88 + 0.22 * CGFloat(t * t)
        let opacity       = 0.55 + 0.45 * CGFloat(t)
        let isCenter      = scale >= 1.095
        let shadowOpacity = isCenter ? 0.30 : 0.10
        let shadowRadius: CGFloat = isCenter ? 9.0 : 2.0
        let shadowY: CGFloat = isCenter ? 3.0 : 1.0

        return (tilt, scale, opacity, shadowOpacity, shadowRadius, shadowY)
    }
}

public extension View {
    /// быстрый сахар: применить DS-глубину по dx
    func dsDepth3D(dx: CGFloat, outerWidth: CGFloat) -> some View {
        let p = DSDepth.params(dx: dx, outerWidth: outerWidth)
        return self.modifier(DSDepth3D(tilt: p.tilt, scale: p.scale,
                                       opacity: p.opacity,
                                       shadowOpacity: p.shadowOpacity,
                                       shadowRadius: p.shadowRadius,
                                       shadowY: p.shadowY))
    }

    /// единый внешний паддинг секций
    func dsSectionPadding(bottom: CGFloat = 24) -> some View {
        self.padding(.horizontal, PD.Spacing.screen).padding(.bottom, bottom)
    }
}


#if DEBUG
private struct _VE_PreviewHost<Content: View>: View {
    @StateObject private var theme = ThemeManager.shared
    let content: () -> Content
    var body: some View {
        content().environmentObject(theme)
    }
}
#Preview("DSDepth3D Demo") {
    _VE_PreviewHost {
        GeometryReader { outer in
            HStack(spacing: DSMetrics.reelSpacing) {
                ForEach(-2..<3, id: \.self) { offset in
                    let dx = CGFloat(offset) * 120
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DSFill.card)
                        .frame(width: DSMetrics.cardWidth, height: DSMetrics.cardHeight)
                        .overlay(
                            Text("card \(offset)")
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                        .dsDepth3D(dx: dx, outerWidth: outer.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
        }
    }
}
#endif
