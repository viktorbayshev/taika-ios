//
//  HomeTaskDS.swift
//  taika
//
//  DS for a single game: "Подобрать пару" (phonetic ↔ ru)
//  Identity: dark, glassy cards, accentPink (from CD tokens), lowercase labels.
//  No business logic here — only reusable UI building blocks for the game screen.
//

import SwiftUI

// MARK: - Model used by DS (visual only)
public enum MPItemState { case idle, selected, matched, wrong }

public struct MPItem: Identifiable, Hashable {
    public let id: UUID = .init()
    public let pairId: String      // stable id to compare pairs
    public let text: String        // visible text (ph or ru)
    public let side: Side          // left: phonetic, right: ru
    public var state: MPItemState  // visual state
    public var hasAudio: Bool = false   // show speaker button when revealed
    public enum Side { case left, right }
    public init(pairId: String, text: String, side: Side, state: MPItemState = .idle, hasAudio: Bool = false) {
        self.pairId = pairId; self.text = text; self.side = side; self.state = state; self.hasAudio = hasAudio
    }
}

// MARK: - Card Back style
public enum MPBackStyle { case light, accent }

// MARK: - Card (mini) — brand identity
public struct MPCardMini: View {
    let text: String
    let isActive: Bool
    let isMatched: Bool
    let isWrong: Bool
    @EnvironmentObject private var theme: ThemeManager

    public init(text: String, isActive: Bool, isMatched: Bool, isWrong: Bool) {
        self.text = text
        self.isActive = isActive
        self.isMatched = isMatched
        self.isWrong = isWrong
    }

    public var body: some View {
        Text(text)
            .textCase(.lowercase)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .font(CD.FontToken.body(17, weight: .regular))
            .foregroundStyle(CD.ColorToken.text)
            .padding(.horizontal, 14).padding(.vertical, 14)
            .frame(minWidth: 120)
            .background(CD.ColorToken.card)
            .overlay(
                RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous)
                    .foregroundStyle(theme.currentAccentFill)
                    .opacity(isMatched ? 0.10 : (isActive ? 0.06 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous)
                    .stroke(
                        isMatched || isActive
                        ? AnyShapeStyle(theme.currentAccentFill)
                        : AnyShapeStyle(CD.ColorToken.stroke),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous))
            .shadow(color: (isMatched || isActive) ? CD.ColorToken.accent.opacity(0.16) : .clear, radius: 10, x: 0, y: 6)
            .scaleEffect(isWrong ? 0.98 : (isActive ? 1.02 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isActive)
            .animation(.spring(response: 0.20, dampingFraction: 0.78), value: isWrong)
    }
}

// MARK: - Flip Card (memory-style)
public struct MPFlipCard: View {
    let text: String
    let isRevealed: Bool
    let state: MPItemState
    let side: MPItem.Side
    let backTitle: String
    let hasAudio: Bool
    let onPlay: (() -> Void)?
    @State private var matchedFlash: Bool = false
    @State private var selectedPulse: Bool = false
    @EnvironmentObject private var theme: ThemeManager

    public init(text: String, isRevealed: Bool, state: MPItemState, side: MPItem.Side, backTitle: String = "taika", hasAudio: Bool = false, onPlay: (() -> Void)? = nil) {
        self.text = text
        self.isRevealed = isRevealed
        self.state = state
        self.side = side
        self.backTitle = backTitle
        self.hasAudio = hasAudio
        self.onPlay = onPlay
    }

    public var body: some View {
        let radius: CGFloat = 16
        let len = text.count
        let baseRight: CGFloat = 20
        let baseLeft: CGFloat  = 17
        let fontSize: CGFloat = len > 28 ? 15 : (len > 20 ? 17 : 19)

        let front = ZStack {
            // base fill
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.96))
            // subtle top highlight
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
                .blendMode(.plusLighter)
            // state-specific backgrounds
            switch state {
            case .selected:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            case .matched:
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .foregroundStyle(theme.currentAccentFill)
                        .opacity(0.08)
                    // subtle brand gloss
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .blendMode(.plusLighter)
                }
            case .wrong:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.red.opacity(0.06))
            case .idle:
                EmptyView()
            }
            // subtle lift for selected left cards (helps contrast)
            if side == .left && state == .selected {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            }
            // content
            Text(text)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .font(CD.FontToken.body(fontSize, weight: (side == .right ? .semibold : .medium)))
                .foregroundStyle(
                    side == .right
                    ? AnyShapeStyle(CD.ColorToken.text)
                    : AnyShapeStyle(theme.currentAccentFill)
                )
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .padding(.horizontal, 14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .overlay {
            if state == .selected {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        // (brand watermark overlay removed)

        ZStack {
            // BACK (shows when not revealed)
            MPCardBack(style: side == .left ? .light : .accent)
                .rotation3DEffect(.degrees(isRevealed ? -180 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                .opacity(isRevealed ? 0 : 1)

            // FRONT (content)
            front
                .rotation3DEffect(.degrees(isRevealed ? 0 : 180), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                .opacity(isRevealed ? 1 : 0)
        }
        .frame(width: 172, height: 84)
        .overlay {
            if matchedFlash {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
                    .opacity(0.85)
                    .shadow(color: CD.ColorToken.accent.opacity(0.25), radius: 8, x: 0, y: 5)
                    .scaleEffect(matchedFlash ? 1.06 : 0.7)
                    .opacity(matchedFlash ? 0.0 : 0.75)
                    .animation(.easeOut(duration: 0.48), value: matchedFlash)
            }
        }
        .shadow(color: (state == .matched ? CD.ColorToken.accent.opacity(0.18) : (state == .selected ? Color.white.opacity(0.18) : .clear)),
                radius: state == .matched ? 12 : (state == .selected ? 12 : 0), x: 0, y: 8)
        .scaleEffect(state == .wrong ? 0.96 : (state == .selected ? 1.04 : (state == .matched ? 1.02 : 1.0)))
        .scaleEffect(matchedFlash ? 1.04 : 1.0)
        .modifier(ShakeEffect(pct: state == .wrong ? 1 : 0))
        .animation(.easeInOut(duration: 0.34), value: isRevealed)
        .animation(.linear(duration: 0.22), value: state == .wrong)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: state == .selected)
        .opacity(matchedFlash ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.6), value: matchedFlash)
        .onChange(of: state) { _, newValue in
            if newValue == .matched {
                matchedFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    matchedFlash = false
                }
            }
            if newValue == .selected {
                selectedPulse = true
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    selectedPulse.toggle()
                }
            } else {
                selectedPulse = false
            }
        }
    }

    private var isGlowing: Bool { state == .selected || state == .matched }
    private var glowColor: Color {
        switch state {
        case .matched: return CD.ColorToken.accent
        case .wrong:   return CD.ColorToken.accent.opacity(0.4)
        default:       return CD.ColorToken.accent
        }
    }
    private var borderColor: Color {
        switch state {
        case .matched:
            return CD.ColorToken.accent.opacity(0.65)
        case .selected:
            return CD.ColorToken.accent.opacity(0.9)
        case .wrong:
            return Color.red.opacity(0.5)
        default:
            return CD.ColorToken.stroke.opacity(0.7)
        }
    }
}

// MARK: - Card Back (brand templates)
public struct MPCardBack: View {
    public let style: MPBackStyle
    public var width: CGFloat
    public var height: CGFloat
    @EnvironmentObject private var theme: ThemeManager

    public init(style: MPBackStyle, width: CGFloat = 172, height: CGFloat = 84) {
        self.style = style
        self.width = width
        self.height = height
    }

    public var body: some View {
        let radius: CGFloat = 16
        ZStack {
            // base plate
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.96))
            // soft top highlight
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
                .blendMode(.plusLighter)
            // (brand title removed)
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    style == .accent
                    ? AnyShapeStyle(theme.currentAccentFill)
                    : AnyShapeStyle(Color.white.opacity(0.22)),
                    lineWidth: 1
                )
                .opacity(style == .accent ? 0.55 : 1.0)
        )
    }
}

public struct MPCardBackLight: View { public var body: some View { MPCardBack(style: .light) } }
public struct MPCardBackAccent: View { public var body: some View { MPCardBack(style: .accent) } }

// MARK: - Shake Effect
fileprivate struct ShakeEffect: GeometryEffect {
    var pct: CGFloat // 0 → 1
    var amplitude: CGFloat = 6
    var shakes: CGFloat = 3
    var animatableData: CGFloat {
        get { pct }
        set { pct = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(pct * .pi * shakes) * amplitude
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Two Columns Grid (left: phonetic, right: ru)
public struct MPMatchPairsGrid: View {
    public let left: [MPItem]      // side == .left, phonetic
    public let right: [MPItem]     // side == .right, ru
    public let selectedLeft: Int?  // index in left
    public let selectedRight: Int? // index in right
    public let leftTitle: String?
    public let rightTitle: String?
    public let onTapLeft: (Int) -> Void
    public let onTapRight: (Int) -> Void
    public let revealedIds: Set<String>?

    public init(left: [MPItem], right: [MPItem], selectedLeft: Int?, selectedRight: Int?, leftTitle: String? = nil, rightTitle: String? = nil, onTapLeft: @escaping (Int) -> Void, onTapRight: @escaping (Int) -> Void, revealedIds: Set<String>? = nil) {
        self.left = left; self.right = right
        self.selectedLeft = selectedLeft; self.selectedRight = selectedRight
        self.leftTitle = leftTitle; self.rightTitle = rightTitle
        self.onTapLeft = onTapLeft; self.onTapRight = onTapRight
        self.revealedIds = revealedIds
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                if let t = leftTitle { header(t) }
                column(left, isLeft: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                if let t = rightTitle { header(t) }
                column(right, isLeft: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, 36)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(CD.FontToken.caption())
            .tracking(0.5)
            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func column(_ items: [MPItem], isLeft: Bool) -> some View {
        VStack(alignment: .center, spacing: 22) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                let isActive = (isLeft ? selectedLeft == idx : selectedRight == idx)
                let isWrong = (it.state == .wrong)
                MPFlipCard(
                    text: it.text,
                    isRevealed: (revealedIds?.contains(it.pairId) ?? (isActive || it.state == .matched || it.state == .wrong)),
                    state: it.state,
                    side: it.side,
                    backTitle: "taika",
                    hasAudio: it.hasAudio,
                    onPlay: nil
                )
                .contentShape(Rectangle())
                .onTapGesture { (isLeft ? onTapLeft(idx) : onTapRight(idx)) }
            }
        }
    }
}

// MARK: - Compact progress bar (brand style)
fileprivate struct MPProgressBar: View {
    let value: Double   // 0...1
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(CD.ColorToken.card.opacity(0.9))
            GeometryReader { geo in
                let w = max(4, geo.size.width * value)
                Capsule()
                    .fill(LinearGradient(colors: [CD.ColorToken.accent, CD.ColorToken.accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
            }
        }
        .frame(height: 6)
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Lightweight HUD used in DS previews / optional in host
fileprivate struct MPMatchHUD: View {
    let title: String
    let pairsDone: Int
    let total: Int
    let tries: Int
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            // centered title
            Text(title)
                .textCase(.lowercase)
                .font(CD.FontToken.title(24, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            // subtle inline hint (no capsule)
            HStack(spacing: 8) {
                Circle()
                    .foregroundStyle(theme.currentAccentFill)
                    .frame(width: 6, height: 6)
                Text("найди совпадения слева и справа")
                    .font(CD.FontToken.body(13, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }
}

#if DEBUG

/// Interactive DS playground (no business logic) — tap to preview visual states
struct MPMatchPairs_Playground: View {
    @State private var leftItems: [MPItem]
    @State private var rightItems: [MPItem]
    @State private var selL: Int? = nil
    @State private var selR: Int? = nil

    init() {
        let sample: [(String,String,String)] = [
            ("pŏm", "Я", "pair1"),
            ("kun", "ты", "pair2"),
            ("káo", "он", "pair3"),
            ("chán", "я (жен.)", "pair4"),
            ("rao", "мы", "pair5"),
            ("kun-táo", "вы", "pair6")
        ]
        let left = sample.map { MPItem(pairId: $0.2, text: $0.0, side: .left, hasAudio: true) }
        let right = sample.map { MPItem(pairId: $0.2, text: $0.1, side: .right) }
        _leftItems = State(initialValue: Array(left.prefix(5)))
        _rightItems = State(initialValue: Array(right.prefix(5)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MPMatchHUD(title: "подобрать пару", pairsDone: 0, total: 0, tries: 0)
                HStack(spacing: 20) {
                    MPCardBack(style: .light)
                    MPCardBack(style: .accent)
                }
                .padding(.bottom, 8)
                MPMatchPairsGrid(
                    left: leftItems,
                    right: rightItems,
                    selectedLeft: selL,
                    selectedRight: selR,
                    leftTitle: "транслит",
                    rightTitle: "перевод",
                    onTapLeft: { onTapLeft($0) },
                    onTapRight: { onTapRight($0) }
                )
                .frame(maxHeight: 560)
                .padding(.top, 24)
            }
            .padding(20)
        }
        .background(CD.ColorToken.background)
        .preferredColorScheme(.dark)
    }

    private func onTapLeft(_ i: Int) {
        if let p = selL { leftItems[p].state = .idle }
        selL = i
        leftItems[i].state = .selected
        resolve()
    }

    private func onTapRight(_ j: Int) {
        if let p = selR { rightItems[p].state = .idle }
        selR = j
        rightItems[j].state = .selected
        resolve()
    }

    private func resolve() {
        guard let li = selL, let rj = selR else { return }
        if leftItems[li].pairId == rightItems[rj].pairId {
            leftItems[li].state = .matched
            rightItems[rj].state = .matched
            selL = nil; selR = nil
        } else {
            leftItems[li].state = .wrong
            rightItems[rj].state = .wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                leftItems[li].state = .idle
                rightItems[rj].state = .idle
                selL = nil; selR = nil
            }
        }
    }
}

struct MPMatchPairs_Previews: PreviewProvider {
    static var previews: some View {
        MPMatchPairs_Playground().environmentObject(ThemeManager.shared)
    }
}
#endif
