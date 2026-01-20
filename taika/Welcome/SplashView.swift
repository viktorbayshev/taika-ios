//
//  SplashView.swift
//  taika
//
//  Created by product on 16.09.2025.
//
import SwiftUI

// MARK: - Split‑Flap Letter (masked split, readable + divider)
private struct SplitFlapLetter: View {
    let target: String
    let accent: Bool
    var onSettle: (() -> Void)? = nil

    // readable charset: A–Z + a–z
    private let charset: [String] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz").map { String($0) }

    // state
    @State private var current: String = ""
    @State private var running = true
    @State private var angleTop: CGFloat = 0
    @State private var angleBottom: CGFloat = 0
    @State private var interimAlpha: Double = 0.92
    @State private var interimAccent: Bool = false

    // tuning
    var startDelay: TimeInterval = 0.0
    var tick: TimeInterval = 0.075
    var cycles: Int = 12
    var tileSize: CGSize = CGSize(width: 60, height: 90)
    var fontSize: CGFloat = 68

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.98, green: 0.52, blue: 0.80),
                     Color(red: 0.91, green: 0.62, blue: 0.98)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        let glyph = current.isEmpty ? target : current
        let runningStyle: AnyShapeStyle = interimAccent
            ? AnyShapeStyle(accentGradient)
            : AnyShapeStyle(Color.white.opacity(interimAlpha))
        let finalStyle: AnyShapeStyle = accent ? AnyShapeStyle(accentGradient) : AnyShapeStyle(Color.white)

        return ZStack {
            // Tile background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)

            // TOP half (masked)
            ZStack {
                Text(glyph)
                    .font(.custom("ONMARK Trial", size: fontSize))
                    .kerning(0.8)
                    .foregroundStyle(running ? runningStyle : finalStyle)
                    .minimumScaleFactor(0.85)
                    .frame(width: tileSize.width, height:
                            tileSize.height, alignment: .center)
            }
            .mask(
                VStack(spacing: 0) {
                    Color.white.frame(height: tileSize.height/2)
                    Color.clear
                }
            )
            .rotation3DEffect(.degrees(angleTop), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.7)

            // BOTTOM half (masked)
            ZStack {
                Text(glyph)
                    .font(.custom("ONMARK Trial", size: fontSize))
                    .kerning(0.8)
                    .foregroundStyle(running ? runningStyle : finalStyle)
                    .minimumScaleFactor(0.85)
                    .frame(width: tileSize.width, height: tileSize.height, alignment: .center)
            }
            .mask(
                VStack(spacing: 0) {
                    Color.clear
                    Color.white.frame(height: tileSize.height/2)
                }
            )
            .rotation3DEffect(.degrees(angleBottom), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.7)
        }
        .frame(width: tileSize.width, height: tileSize.height)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) { start() }
        }
    }

    private func start() {
        current = charset.randomElement() ?? target
        var remaining = cycles
        running = true

        func flipOnce(to char: String, localTick: TimeInterval, settle: Bool) {
            // top flips down
            withAnimation(.easeIn(duration: localTick/2)) { angleTop = -90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + localTick/2) {
                current = char
                withAnimation(.easeOut(duration: localTick/2)) { angleTop = 0 }
                // bottom flips up
                withAnimation(.easeIn(duration: localTick/2)) { angleBottom = 90 }
                DispatchQueue.main.asyncAfter(deadline: .now() + localTick/2) {
                    withAnimation(.easeOut(duration: localTick/2)) { angleBottom = 0 }
                    if settle {
                        running = false
                        DispatchQueue.main.async { onSettle?() }
                    }
                }
            }
        }

        func loop() {
            guard running else { return }
            let progress = 1.0 - Double(remaining) / Double(max(1, cycles))
            // decelerate towards the end
            let localTick = tick * (0.75 + 1.8 * pow(progress, 1.25))

            if remaining > 0 {
                remaining -= 1
                var next = charset.randomElement() ?? target
                // слегка мешаем регистр (невысокая доля для читабельности)
                if Double.random(in: 0...1) < 0.18 { next = next.lowercased() }
                interimAlpha = Double.random(in: 0.7...0.96)
                interimAccent = Double.random(in: 0...1) < 0.10
                flipOnce(to: next, localTick: localTick, settle: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + localTick) { loop() }
            } else {
                interimAlpha = 1.0
                interimAccent = false
                flipOnce(to: target, localTick: tick * 1.9, settle: true)
            }
        }
        loop()
    }
}

// MARK: - Gradient Spinner
private struct GradientSpinner: View {
    let size: CGFloat
    @State private var rotate = false
    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98),
                Color(red: 0.98, green: 0.52, blue: 0.80)
            ]),
            center: .center
        )
    }
    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.92)
            .stroke(gradient, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: rotate)
            .onAppear { rotate = true }
    }
}

struct SplashTaikaView: View {
    let onFinished: (() -> Void)?

    @State private var show = false
    @State private var fadeOut = false
    @State private var t: Double = 0
    @State private var scanX: CGFloat = -220

    private let logo = ["t", "a", "i", "k", "a"]

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.98, green: 0.52, blue: 0.80),
                     Color(red: 0.91, green: 0.62, blue: 0.98)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.10),
                Color(red: 0.05, green: 0.05, blue: 0.07),
                Color(red: 0.10, green: 0.06, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            // background: minimal, alive, but not noisy
            ZStack {
                bgGradient
                    .ignoresSafeArea()

                Circle()
                    .fill(accentGradient)
                    .frame(width: 520, height: 520)
                    .blur(radius: 140)
                    .opacity(0.16)
                    .offset(x: -140 + 90 * CGFloat(sin(t * .pi * 2)), y: -170 + 70 * CGFloat(cos(t * .pi * 2)))

                Circle()
                    .fill(accentGradient)
                    .frame(width: 420, height: 420)
                    .blur(radius: 140)
                    .opacity(0.10)
                    .offset(x: 170 + 90 * CGFloat(cos(t * .pi * 2)), y: 190 + 70 * CGFloat(sin(t * .pi * 2)))

                RadialGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.60)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 560
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 14) {
                Spacer(minLength: 160)

                // wordmark
                ZStack {
                    HStack(spacing: 8) {
                        ForEach(Array(logo.enumerated()), id: \.offset) { idx, ch in
                            Text(ch)
                                .font(.custom("ONMARK Trial", size: 72))
                                .kerning(1.2)
                                .foregroundStyle(idx == 0 || idx == 4 ? AnyShapeStyle(accentGradient) : AnyShapeStyle(Color.white.opacity(0.92)))
                                .opacity(show ? 1 : 0)
                                .offset(y: show ? 0 : 10)
                                .blur(radius: show ? 0 : 2)
                                .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.05 * Double(idx)), value: show)
                        }
                    }
                    .padding(.horizontal, 18)

                    // subtle scanning highlight (mubert-ish)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.0), Color.white.opacity(0.16), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 90, height: 92)
                        .blendMode(.screen)
                        .offset(x: scanX)
                        .opacity(show ? 1 : 0)
                        .mask(
                            HStack(spacing: 8) {
                                ForEach(Array(logo.enumerated()), id: \.offset) { _, ch in
                                    Text(ch)
                                        .font(.custom("ONMARK Trial", size: 72))
                                        .kerning(1.2)
                                }
                            }
                            .padding(.horizontal, 18)
                        )
                }

                Text("thai lessons · taika fm")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .opacity(show ? 1 : 0)
                    .animation(.easeIn(duration: 0.30).delay(0.20), value: show)

                Spacer(minLength: 150)

                HStack(spacing: 8) {
                    GradientSpinner(size: 18)
                    Text("загружаем уроки")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .opacity(show ? 1 : 0)
                .animation(.easeIn(duration: 0.30).delay(0.25), value: show)

                Spacer(minLength: 40)
            }
            .opacity(fadeOut ? 0 : 1)
            .animation(.easeOut(duration: 0.35), value: fadeOut)
        }
        .onAppear {
            show = true
            withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: true)) { t = 1 }

            // scanning shimmer
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                scanX = 220
            }

            // safety timeout: never hang on splash
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                guard !fadeOut else { return }
                withAnimation(.easeOut(duration: 0.35)) { fadeOut = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onFinished?()
                }
            }
        }
    }
}

#Preview { SplashTaikaView(onFinished: nil) }
