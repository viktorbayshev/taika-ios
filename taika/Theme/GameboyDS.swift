import SwiftUI
import AVKit

// MARK: - Public showcase entry for the console screen
public struct GameboyShowcase: View {
    @State private var index: Int = 0
    private var externalIndex: Binding<Int>? = nil

    public init(index: Binding<Int>? = nil) { self.externalIndex = index }

    public var body: some View {
        let selection = externalIndex ?? Binding<Int>(get: { index }, set: { index = $0 })
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TabView(selection: selection) {
                    ForEach(Array(GBShowcaseStyle.allCases.enumerated()), id: \.offset) { i, style in
                        GBShowcaseCard(style: style)
                            .tag(i)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                GBShowcaseDots(count: GBShowcaseStyle.allCases.count, index: selection.wrappedValue)
                    .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Styles
public enum GBShowcaseStyle: CaseIterable { case promoPairs, promoDialogs, promoSpell }

// MARK: - Card wrapper
fileprivate struct GBShowcaseCard: View {
    let style: GBShowcaseStyle
    var body: some View {
        ZStack {
            switch style {
            case .promoPairs:   GBPromoPairsView()
            case .promoDialogs: GBPromoDialogsView()
            case .promoSpell:   GBPromoSpellView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}


// MARK: - Promo 1: Find-a-Pair (найди пару)
fileprivate struct GBPromoPairsView: View {
    // Two cards centered; cycle: mismatch → flip back → match → bounce → back
    @State private var step: Int = 0           // 0 backs, 1 mismatch faces, 2 backs, 3 match faces
    @State private var leftAngle: Double = 0
    @State private var rightAngle: Double = 0
    @State private var isPausedAt80: Bool = false
    @State private var bounceAmount: CGFloat = 0
    @State private var sparklePositions: [CGPoint] = []
    @State private var sparkleOpacity: [Double] = [0, 0, 0]
    private let timer = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()

    // Pairs for mismatch and match states
    private let mismatchPair: (String, String) = ("чай", "mai")
    private let matchPair: (String, String) = ("сава ди", "krap")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gap: CGFloat = 22
            let cardW = min((w - gap) / 2 - 18, h * 0.60) * 0.95
            let cardH = cardW * 1.38

            HStack(spacing: gap) {
                ZStack {
                    card(
                        angle: leftAngle,
                        back: promoBack(true),
                        face: faceView(text: (step == 3 ? matchPair.0 : mismatchPair.0), isMatch: step == 3)
                    )
                    .frame(width: cardW, height: cardH)
                    .rotation3DEffect(.degrees(leftAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
                    .offset(y: bounceAmount)
                    if step == 4 {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(CD.GradientToken.pro)
                                .frame(width: 6, height: 6)
                                .position(sparklePositions.indices.contains(i) ? sparklePositions[i] : .zero)
                                .opacity(sparkleOpacity[i])
                                .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.15), value: sparkleOpacity[i])
                        }
                    }
                }
                ZStack {
                    card(
                        angle: rightAngle,
                        back: promoBack(false),
                        face: faceView(text: (step == 3 ? matchPair.1 : mismatchPair.1), isMatch: step == 3)
                    )
                    .frame(width: cardW, height: cardH)
                    .rotation3DEffect(.degrees(rightAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
                    .offset(y: bounceAmount)
                    if step == 4 {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(CD.GradientToken.pro)
                                .frame(width: 6, height: 6)
                                .position(sparklePositions.indices.contains(i) ? sparklePositions[i] : .zero)
                                .opacity(sparkleOpacity[i])
                                .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.15), value: sparkleOpacity[i])
                        }
                    }
                }
                // Animated heart on match
                if step == 3 {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CD.GradientToken.pro)
                        .transition(.scale)
                        .padding(.leading, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.top, max(0, (h - cardH) / 2 - 4))
            .padding(.bottom, max(0, (h - cardH) / 2 + 20))
            .onReceive(timer) { _ in advance() }
        }
    }

    // MARK: - Pieces
    private func promoBack(_ isAccent: Bool) -> some View {
        let r: CGFloat = 16
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.black.opacity(0.90), Color.black.opacity(0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(isAccent ? AnyShapeStyle(CD.GradientToken.pro) : AnyShapeStyle(Color.white.opacity(0.20)), lineWidth: 1)
            )
            .overlay(
                Text("taikA")
                    .font(.taikaLogo(32))
                    .foregroundStyle(isAccent ? AnyShapeStyle(CD.GradientToken.pro) : AnyShapeStyle(Color.white.opacity(0.85)))
                    .opacity(0.9)
            )
    }
    @ViewBuilder private func card(angle: Double, back: some View, face: some View) -> some View {
        ZStack {
            // Back visible until 90º
            back
                .opacity(angle <= 90 ? 1 : 0)
            // Face visible after 90º; counter-rotated to avoid mirrored text
            face
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(angle > 90 ? 1 : 0)
        }
    }

    private func faceView(text: String, isMatch: Bool) -> some View {
        let r: CGFloat = 12
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                Text(text)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isMatch ? AnyShapeStyle(CD.GradientToken.pro) : AnyShapeStyle(Color.white.opacity(0.92)))
            )
            .overlay(
                Group {
                    if isMatch {
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .stroke(CD.GradientToken.pro, lineWidth: 2)
                            .shadow(color: CD.ColorToken.accent.opacity(0.35), radius: 8)
                    }
                }
            )
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.5)) {
            if step == 0 { // дисмэтч
                leftAngle = 180; rightAngle = 180; step = 1
            } else if step == 1 { // назад
                leftAngle = 0; rightAngle = 0; step = 2
            } else if step == 2 { // мэтч + сердце + искры
                leftAngle = 180; rightAngle = 180; step = 3
                bounceAmount = -10
                sparklePositions = [CGPoint(x: 40, y: 20), CGPoint(x: 60, y: 10), CGPoint(x: 50, y: 30)]
                sparkleOpacity = [1, 1, 1]
                withAnimation(.easeOut(duration: 0.3)) {
                    bounceAmount = 0; sparkleOpacity = [0, 0, 0]
                }
            } else { // сброс
                leftAngle = 0; rightAngle = 0; step = 0
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}


fileprivate struct GBPromoCard: View {
    let isHighlighted: Bool
    let progress: CGFloat
    let iconIndex: Int
    var body: some View {
        let r: CGFloat = 12
        ZStack {
            // base face
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            // icon
            Image(systemName: promoIcon(for: iconIndex))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))

            // highlight (brand) for the matched pair
            if isHighlighted {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(CD.GradientToken.pro, lineWidth: 2)
                    .shadow(color: CD.ColorToken.accent.opacity(0.35), radius: 10, x: 0, y: 0)
                    .opacity(0.9)
                    .scaleEffect(1.0 + 0.02 * sin(progress * .pi * 2))
            }
        }
        .animation(.easeInOut(duration: 0.9), value: isHighlighted)
    }
    private func promoIcon(for i: Int) -> String {
        let icons = ["leaf.fill","bolt.fill","heart.fill","moon.fill","flame.fill","hare.fill"]
        return icons[i % icons.count]
    }
}

// MARK: - Promo 2: Dialog Constructor (конструктор диалогов)
fileprivate struct GBPromoDialogsView: View {
    @State private var phase: Int = 0 // 0 typing L, 1 L text, 2 typing R, 3 R text
    private let leftText = "Привет!"
    private let rightText = "Погнали 🚀"
    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            // Left side
            HStack {
                if phase == 0 { typing() } else { bubble(leftText) }
                Spacer(minLength: 0)
            }
            // Right side
            HStack {
                Spacer(minLength: 0)
                if phase == 2 { typing() }
                else if phase == 3 { bubble(rightText) }
            }
        }
        .padding(.horizontal, 8)
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                phase = (phase + 1) % 4
            }
        }
    }

    private func bubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }

    private func typing() -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Promo 3: Spelling mini-game (спелл)
fileprivate struct GBPromoSpellView: View {
    @State private var t: CGFloat = 0
    private let word = "taikA"
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let progressBase = t * 2
            let underlineProgress = max(0.08, abs(sin(t * 1.2)))
            let underlineWidth = (w * 0.6) * underlineProgress
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    ForEach(Array(word.enumerated()), id: \.offset) { i, ch in
                        let phase = progressBase + CGFloat(i)
                        let scale = 1.0 + 0.04 * sin(phase)
                        let alpha = 0.85 + 0.15 * sin(phase)
                        Text(String(ch))
                            .font(.taikaLogo(36))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .scaleEffect(scale)
                            .opacity(alpha)
                            .overlay(
                                LinearGradient(colors: [Color.white.opacity(0.0), Color.white.opacity(0.6), Color.white.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                                    .blendMode(.screen)
                                    .mask(Text(String(ch)).font(.taikaLogo(36)))
                            )
                    }
                }
                .padding(.bottom, 6)
                // progress underline
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 3)
                    Capsule().fill(CD.GradientToken.pro).frame(width: underlineWidth, height: 3)
                }
                .frame(width: w * 0.6)
                Spacer(minLength: 0)
            }
            .frame(width: w, height: h)
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) { t = 1 }
            }
        }
    }
}

// MARK: - Progress dots
fileprivate struct GBShowcaseDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(count, 1), id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i == index ? AnyShapeStyle(CD.GradientToken.pro) : AnyShapeStyle(Color.white.opacity(0.25)))
                    .frame(width: i == index ? 14 : 5, height: 3)
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: index)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.14))
                .overlay(
                    Capsule(style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview env helper
fileprivate enum GBPreviewEnv { static var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" } }


#if DEBUG
import SwiftUI

struct GameboyDS_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GameboyShowcase()
                .frame(width: 408, height: 300)
                .background(Color.black.opacity(0.6))
                .preferredColorScheme(.dark)
                .previewDisplayName("Gameboy Showcase — card size")

            GameboyShowcase()
                .frame(width: 600, height: 300)
                .background(Color.black.opacity(0.6))
                .preferredColorScheme(.dark)
                .previewDisplayName("Gameboy Showcase — wide")
        }
    }
}
#endif
