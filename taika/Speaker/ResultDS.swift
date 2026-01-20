//
//  ResultDS.swift
//  taika
//
//  Created by product on 15.01.2026.
//

import SwiftUI

// result ds: animation-only overlay layer.
// ds draws visuals only; view/manager decide when to show.
// IMPORTANT: no cards, no content duplication. this overlay is a short-lived event.

enum ResultOverlayKind: Equatable {
    case success
    case mismatch
    case neutral
}

struct ResultOverlayV: View {
    let kind: ResultOverlayKind
    let title: String?
    let isLooping: Bool
    let focusRect: CGRect?

    init(
        kind: ResultOverlayKind = .neutral,
        title: String? = nil,
        isLooping: Bool = false,
        focusRect: CGRect? = nil
    ) {
        self.kind = kind
        self.title = title
        self.isLooping = isLooping
        self.focusRect = focusRect
    }

    var body: some View {
        ResultSketchOverlayV(kind: kind, title: title, isLooping: isLooping, focusRect: focusRect)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

// MARK: - sketch doodles overlay (minimal 2d)

private struct ResultSketchOverlayV: View {
    let kind: ResultOverlayKind
    let title: String?
    let isLooping: Bool
    let focusRect: CGRect?

    @State private var fade: CGFloat = 1
    @State private var pulse: CGFloat = 0

    private var dimAlpha: CGFloat {
        switch kind {
        case .success: return 0.11
        case .mismatch: return 0.14
        case .neutral: return 0.10
        }
    }

    private var tint: Color {
        switch kind {
        case .success:
            return Color(red: 1.0, green: 0.55, blue: 0.90) // taika pink-ish
        case .mismatch:
            return Color.white
        case .neutral:
            return Color.white
        }
    }

    private var pillText: String {
        if let t = title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t.lowercased()
        }
        switch kind {
        case .success: return "круто"
        case .mismatch: return "ещё раз"
        case .neutral: return "ок"
        }
    }

    private var hintText: String? {
        // ultra-short learning hint (kept minimal; view/manager may pass a better one later)
        switch kind {
        case .success:
            return "ударение ок"
        case .mismatch:
            return "чётче гласные"
        case .neutral:
            return nil
        }
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // glass layer (telegram-ish): material + subtle dark tint
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Color.black.opacity(dimAlpha)
                    )
                    .opacity(fade)
                    .ignoresSafeArea()

                // spotlight cutout + glow (card stays bright)
                if let r0 = focusRect, r0.width > 10, r0.height > 10 {
                    let inset: CGFloat = 12
                    let r = r0.insetBy(dx: -inset, dy: -inset)
                    let radius: CGFloat = 32

                    // cutout
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.black)
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .blendMode(.destinationOut)
                        .opacity(fade)

                    // glow (base)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(tint.opacity(kind == .mismatch ? 0.18 : 0.32), lineWidth: 1.25)
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .shadow(color: tint.opacity(kind == .mismatch ? 0.06 : 0.12), radius: 18)
                        .shadow(color: tint.opacity(kind == .mismatch ? 0.04 : 0.08), radius: 36)
                        .opacity(fade)
                        .allowsHitTesting(false)

                    // win cue (pulse)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(tint.opacity(kind == .mismatch ? 0.10 : 0.20), lineWidth: 2)
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .scaleEffect(1 + (kind == .mismatch ? 0.010 : 0.018) * pulse)
                        .opacity(fade * pulse * (kind == .mismatch ? 0.65 : 0.90))
                        .shadow(color: tint.opacity((kind == .mismatch ? 0.06 : 0.12) * pulse), radius: 22)
                        .shadow(color: tint.opacity((kind == .mismatch ? 0.04 : 0.08) * pulse), radius: 44)
                        .allowsHitTesting(false)
                    
                    // card-attached micro pill (game feedback)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tint.opacity(kind == .mismatch ? 0.22 : 0.34))
                            .frame(width: 8, height: 8)

                        Text(pillText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 12)
                    .opacity(fade)
                    .position(x: r.maxX - 74, y: r.maxY - 18)
                    .allowsHitTesting(false)

                    if kind == .success {
                        Text("+1")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(tint.opacity(0.16))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.14), radius: 10)
                            .opacity(fade)
                            .position(x: r.maxX - 22, y: r.minY + 18)
                            .allowsHitTesting(false)
                    }

                    if kind == .mismatch, let h = hintText {
                        Text(h)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.18))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .opacity(fade)
                            .position(x: r.maxX - 86, y: r.maxY - 48)
                            .allowsHitTesting(false)
                    }
                }
            }
            .compositingGroup()
            .allowsHitTesting(false)
            .onAppear {
                fade = 1
                pulse = 0
                withAnimation(.easeOut(duration: 0.28)) {
                    pulse = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        pulse = 0
                    }
                }

                guard !isLooping else { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                    withAnimation(.easeOut(duration: 0.22)) {
                        fade = 0
                    }
                }
            }
        }
    }
}


// MARK: - previews

#Preview("result overlay") {
    ZStack {
        LinearGradient(colors: [Color.black, Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        // mock active card
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            )
            .frame(width: 340, height: 420)
            .position(x: 215, y: 360)

        ResultOverlayV(
            kind: .success,
            title: "совпало",
            isLooping: true,
            focusRect: CGRect(x: 45, y: 150, width: 340, height: 420)
        )
    }
    .frame(width: 430, height: 860)
}

#Preview("result overlay mismatch") {
    ZStack {
        LinearGradient(colors: [Color.black, Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        // mock active card
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            )
            .frame(width: 340, height: 420)
            .position(x: 215, y: 360)

        ResultOverlayV(
            kind: .mismatch,
            title: "не совпало",
            isLooping: true,
            focusRect: CGRect(x: 45, y: 150, width: 340, height: 420)
        )
    }
    .frame(width: 430, height: 860)
}
