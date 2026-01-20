//
//  CourseDS.swift
//  taika
//
//  Created by product on 23.08.2025.
//

import SwiftUI
import UIKit

// MARK: - Course Design System (CD)
// Mirrors PD style but tailored for the Course screen.
public enum CD {
    public enum ColorToken {
        public static var background: SwiftUI.Color { Color(red: 0.06, green: 0.06, blue: 0.07) }
        public static var card: SwiftUI.Color { Color(red: 0.10, green: 0.10, blue: 0.12) }
        public static var stroke: SwiftUI.Color { Color.white.opacity(0.08) }
        public static var text: SwiftUI.Color { Color.white }
        public static var textSecondary: SwiftUI.Color { Color.white.opacity(0.6) }
        public static var accent: SwiftUI.Color { Color(red: 0.95, green: 0.36, blue: 0.65) }
        public static var chip: SwiftUI.Color { Color.white.opacity(0.06) }
    }
    public enum Radius {
        public static var card: CGFloat { 20 }
        public static var chip: CGFloat { 12 }
    }
    public enum Spacing {
        public static var screen: CGFloat { 20 }
        public static var inner: CGFloat { 12 }
        public static var tiny: CGFloat { 6 }
        public static var headerGap: CGFloat { 6 }
    }
    public enum FontToken {
        public static func title(_ size: CGFloat = 32, weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded) }
        public static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .rounded) }
        public static func caption(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .rounded) }
    }
    public enum BrandFont {
        public static func appTitle(_ size: CGFloat) -> Font {
            if UIFont(name: "OnmarkTRIAL", size: size) != nil { return .custom("OnmarkTRIAL", size: size) }
            return .system(size: size, weight: .bold, design: .rounded)
        }
    }

    public enum GradientToken {
        public static var pro: LinearGradient {
            // Unified pink gradient (matches PRO badge)
            LinearGradient(
                colors: [
                    Color(red:0.95, green:0.36, blue:0.65),
                    Color(red:0.91, green:0.62, blue:0.98)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }
}

// MARK: - Shared mini components (unified with Lessons DS)
public struct CDProBadge: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill").font(.system(size: 12, weight: .semibold))
            Text("PRO").font(CD.FontToken.caption(11, weight: .semibold))
        }
        .foregroundStyle(Color.black.opacity(0.86))
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(CD.GradientToken.pro)
        .clipShape(RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}


public struct CDInfoPill: View {
    let icon: String
    let text: String
    public init(icon: String, text: String) { self.icon = icon; self.text = text }
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(CD.FontToken.caption(12, weight: .medium))
        .foregroundStyle(Color.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.14)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

public struct CDIconPillButton: View {
    let icon: String
    let action: () -> Void
    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(CD.ColorToken.chip))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gradient CTA (unified with PRO look)
public struct CDGradientCTA: View {
    let title: String
    let icon: String?
    let action: () -> Void
    public init(title: String, icon: String? = "wand.and.stars", action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(CD.FontToken.caption(12, weight: .semibold))
            }
            .foregroundStyle(Color.black.opacity(0.86))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(CD.GradientToken.pro)
            .clipShape(RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ghost CTA (subtle, for less visual noise)
public struct CDGhostCTA: View {
    let title: String
    let icon: String?
    let action: () -> Void
    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(CD.FontToken.caption(12, weight: .semibold))
            }
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule().fill(CD.ColorToken.chip)
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Homework capsule button (Домашка)
public struct CDHomeworkButton: View {
    public var total: Int
    public var done: Int
    public var onTap: () -> Void
    @State private var badgeAppear: Bool = false

    public init(total: Int, done: Int, onTap: @escaping () -> Void) {
        self.total = total
        self.done = done
        self.onTap = onTap
    }

    private var shouldShow: Bool { total > 0 }
    private var newCount: Int { max(0, total - done) }
    private var badgeText: String { newCount > 99 ? "99+" : "\(newCount)" }

    public var body: some View {
        Group {
            if shouldShow {
                Button(action: {
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                    onTap()
                }) {
                    ZStack(alignment: .topTrailing) {
                        // circular chip with just an icon
                        Circle()
                            .fill(CD.ColorToken.chip)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: "checklist")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.92))
                            )

                        // iOS-like badge for new homework (smaller + animated)
                        if newCount > 0 {
                            Text(badgeText)
                                .font(CD.FontToken.caption(9, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(CD.GradientToken.pro)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                                .scaleEffect(badgeAppear ? 1.0 : 0.6)
                                .opacity(badgeAppear ? 1.0 : 0.0)
                                .offset(x: 7, y: -7)
                                .onAppear {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        badgeAppear = true
                                    }
                                }
                        }
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: newCount)
                .buttonStyle(.plain)
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Домашка \(done) из \(total)"))
                .accessibilityHint(Text(newCount > 0 ? "Есть новые задания" : "Новых заданий нет"))
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Typing dots (inline, subtle) for Course DS
struct CDTypingDots: View {
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
        .foregroundColor(CD.ColorToken.textSecondary)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }
}

// MARK: - Marquee / assistant stripe (fixed height, typewriter) for Course DS
public struct CDMarquee: View {
    public var messages: [String]
    public var mascot: Image?
    public var typingDuration: TimeInterval = 2.2    // dots phase
    public var showDuration: TimeInterval = 3.2       // linger full text
    public var typingCharInterval: TimeInterval = 0.045 // typewriter speed

    @State private var idx: Int = 0
    @State private var isTyping: Bool = true
    @State private var shown: String = ""
    @State private var charIndex: Int = 0

    public init(messages: [String], mascot: Image? = Image("mascot.course")) {
        self.messages = messages
        self.mascot = mascot
    }

    public var body: some View {
        HStack(alignment: .center, spacing: CD.Spacing.inner) {
            mascot?
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 56, height: 56)
                .opacity(0.95)
                .scaleEffect(x: -1, y: 1)

            ZStack(alignment: .leading) {
                // Single bubble (no outer card) to avoid double outline
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CD.ColorToken.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(CD.ColorToken.stroke, lineWidth: 1)
                    )

                HStack(alignment: .center, spacing: 8) {
                    if isTyping {
                        CDTypingDots()
                    } else {
                        Text(shown)
                            .font(CD.FontToken.body(14, weight: .regular))
                            .foregroundColor(CD.ColorToken.text)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, CD.Spacing.inner)
                .padding(.vertical, 12)
            }
            .frame(minHeight: 64, maxHeight: 64)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .onAppear { startCycle() }
    }

    private func startCycle() {
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
            typeNextChar(message: message)
        }
    }
}
// Safe index helper (local to Course DS)
private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

private extension String {
    var taika_trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Assistant card (like Lessons DS, PD style)
public struct CDAssistantCard: View {
    let messages: [String]
    let typingSpeed: Double
    let onTap: () -> Void

    @State private var currentIndex: Int = 0
    @State private var shownText: String = ""
    @State private var isTyping: Bool = true
    @State private var dotsPhase: Int = 0

    // timers
    @State private var dotsTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    @State private var typingTask: Task<Void, Never>? = nil

    // fixed sizing to avoid jumping
    private let fixedHeight: CGFloat = 72

    private func startCycle() {
        typingTask?.cancel()
        guard !messages.isEmpty else { return }
        let text = messages[currentIndex]
        shownText = ""
        isTyping = true

        typingTask = Task { @MainActor in
            // thinking pause
            try? await Task.sleep(nanoseconds: UInt64(0.9 * 1_000_000_000))
            // typewriter
            for ch in text {
                if Task.isCancelled { return }
                shownText.append(ch)
                let base = max(typingSpeed, 0.035)
                try? await Task.sleep(nanoseconds: UInt64(base * 1_000_000_000))
            }
            isTyping = false
            // keep full message on screen to read
            try? await Task.sleep(nanoseconds: UInt64(2.8 * 1_000_000_000))
            // go next
            currentIndex = (currentIndex + 1) % messages.count
            startCycle()
        }
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.06))
                Image("mascot.course")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))

            // single bubble that contains either typing dots or text
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CD.ColorToken.card)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(CD.ColorToken.stroke, lineWidth: 1))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if isTyping {
                        // inline typing dots (messenger-like)
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .frame(width: 6, height: 6)
                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(i == dotsPhase ? 0.95 : 0.55))
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(shownText)
                            .font(CD.FontToken.body(15, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, minHeight: fixedHeight - 24, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CD.ColorToken.stroke, lineWidth: 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { onTap() }
        .frame(height: fixedHeight)
        .onAppear { startCycle() }
        .onChange(of: currentIndex) { _ in /* keep cycle */ }
        .onReceive(dotsTimer) { _ in if isTyping { dotsPhase = (dotsPhase + 1) % 3 } }
        .onDisappear { typingTask?.cancel() }
    }
}


// MARK: - Header (brand left, mascot right, no subtitle)
public struct CDHeaderCard: View {
    public var title: String
    public var messages: [String] = []
    public var mascot: Image?
    public var showTitle: Bool = false   // keeps API, but we always show title in this layout

    // fixed sizing to avoid jumps
    private let containerHeight: CGFloat = 136
    @State private var showDots: Bool = true
    @State private var msgIndex: Int = 0
    @State private var typingKey: UUID = UUID()

    public init(
        title: String,
        messages: [String] = [],
        mascot: Image? = Image("mascot.course.fm"),
        showTitle: Bool = false
    ) {
        self.title = title
        self.messages = messages
        self.mascot = mascot
        self.showTitle = showTitle
    }

    public var body: some View {
        ZStack {
            // full‑width rounded container within screen margins
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(CD.ColorToken.stroke, lineWidth: 1)
                )

            HStack(alignment: .center, spacing: CD.Spacing.inner) {
                // Mascot on the left (fixed size)
                if let mascot {
                    mascot
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .scaleEffect(x: -1, y: 1) // face towards content
                        .padding(.leading, 2)
                }

                // Right column: title + divider + typewriter/dots
                VStack(alignment: .leading, spacing: 12) {
                    // Title (always visible for clearer context)
                    Text(title)
                        .font(CD.FontToken.title(24, weight: .bold))
                        .foregroundStyle(CD.ColorToken.text)
                        .lineLimit(1)

                    // Soft divider
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 2)

                    // Typing dots and rotating messages share the same place
                    ZStack(alignment: .leading) {
                        if showDots {
                            CDTypingDots()
                                .transition(.opacity)
                        }

                        CDTypewriterText(
                            text: messages[safe: msgIndex] ?? "",
                            charInterval: 0.04,
                            maxLines: 2,
                            delayBeforeStart: 0.9,
                            onStart: {
                                withAnimation(.easeInOut(duration: 0.2)) { showDots = false }
                            },
                            onFinish: {
                                // keep full text visible a bit, then cycle
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                                    msgIndex = (msgIndex + 1) % max(messages.count, 1)
                                    typingKey = UUID()
                                    withAnimation(.easeInOut(duration: 0.2)) { showDots = true }
                                }
                            }
                        )
                        .id(typingKey)
                        .font(CD.FontToken.body(14))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                    }
                    .frame(minHeight: 52, alignment: .top)
                }
                .padding(.vertical, 16)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, CD.Spacing.inner)
        }
        .frame(height: containerHeight)
        .padding(.horizontal, CD.Spacing.screen) // align to the same grid as other sections
        .padding(.top, CD.Spacing.screen)
    }
}

// Lightweight inline typewriter text (no extra bubble)
fileprivate struct CDTypewriterText: View {
    let text: String
    let charInterval: Double
    let maxLines: Int?
    let delayBeforeStart: Double
    @State private var count: Int = 0
    var onStart: (() -> Void)? = nil
    var onFinish: (() -> Void)? = nil

    init(
        text: String,
        charInterval: Double = 0.04,
        maxLines: Int? = 2,
        delayBeforeStart: Double = 0.0,
        onStart: (() -> Void)? = nil,
        onFinish: (() -> Void)? = nil
    ) {
        self.text = text
        self.charInterval = charInterval
        self.maxLines = maxLines
        self.delayBeforeStart = delayBeforeStart
        self.onStart = onStart
        self.onFinish = onFinish
    }

    var body: some View {
        Text(String(text.prefix(count)))
            .lineLimit(maxLines)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                guard count == 0 else { return }
                let total = text.count
                guard total > 0 else { onFinish?(); return }

                let startTyping = {
                    onStart?()
                    Timer.scheduledTimer(withTimeInterval: charInterval, repeats: true) { t in
                        if count < total {
                            count += 1
                        } else {
                            t.invalidate()
                            onFinish?()
                        }
                    }
                }

                if delayBeforeStart > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delayBeforeStart) {
                        startTyping()
                    }
                } else {
                    startTyping()
                }
            }
    }
}


// MARK: - Chips / Filters
public struct CDChip: View {
    public var label: String
    public var isSelected: Bool
    public var action: () -> Void

    public init(_ label: String, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label; self.isSelected = isSelected; self.action = action
    }

    private func niceCase(_ s: String) -> String {
        let lower = s.localizedLowercase
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    public var body: some View {
        Button(action: action) {
            Text(niceCase(label))
                .font(CD.FontToken.caption(12, weight: .medium))
                .foregroundStyle(
                    isSelected
                    ? AnyShapeStyle(Color.black.opacity(0.9))
                    : AnyShapeStyle(CD.ColorToken.textSecondary)
                )
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous)
                        .fill(
                            isSelected
                            ? AnyShapeStyle(CD.GradientToken.pro)
                            : AnyShapeStyle(Color.clear)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous)
                        .stroke(
                            isSelected
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.16),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
public enum CDCourseStatus { case new, inProgress, done }

public struct CDStatusBadge: View {
    public var status: CDCourseStatus
    public init(_ status: CDCourseStatus) { self.status = status }

    private var title: String {
        switch status {
        case .new:        return "Новый"
        case .inProgress: return "В процессе"
        case .done:       return "Пройден"
        }
    }

    public var body: some View {
        let font = CD.FontToken.caption(11, weight: .semibold)
        let padV: CGFloat = 4
        let padH: CGFloat = 8

        Group {
            switch status {
            case .new:
                Text(title)
                    .font(font)
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

            case .inProgress:
                Text(title)
                    .font(font)
                    .foregroundStyle(CD.ColorToken.text)
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.98, green: 0.52, blue: 0.80),
                                             Color(red: 0.91, green: 0.62, blue: 0.98)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.2
                            )
                    )

            case .done:
                Text(title)
                    .font(font)
                    .foregroundStyle(Color.white)
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .background(
                        Capsule().fill(CD.GradientToken.pro)
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }
}


public struct CDSortControl: View {
    public var isActive: Bool
    public var action: () -> Void
    public init(isActive: Bool, action: @escaping () -> Void) { self.isActive = isActive; self.action = action }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: CDLayout.iconGap) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                Text("Сортировка")
                    .font(CD.FontToken.caption(12, weight: .medium))
            }
            .foregroundStyle(isActive ? Color.black.opacity(0.9) : CD.ColorToken.textSecondary)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(isActive ? AnyShapeStyle(CD.GradientToken.pro) : AnyShapeStyle(CD.ColorToken.chip))
            .clipShape(RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous)
                    .stroke(isActive ? Color.white.opacity(0.18) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filters Counter/Reset Pill (compact, always visible)
public struct CDFiltersCounterPill: View {
    public var activeCount: Int
    public var onReset: () -> Void
    public init(activeCount: Int, onReset: @escaping () -> Void) {
        self.activeCount = activeCount
        self.onReset = onReset
    }
    public var body: some View {
        Button(action: onReset) {
            HStack(spacing: CDLayout.iconGap) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14, weight: .semibold))
                if activeCount > 0 {
                    Text("Фильтры: \(activeCount)")
                        .font(CD.FontToken.caption(12, weight: .medium))
                } else {
                    Text("Сбросить")
                        .font(CD.FontToken.caption(12, weight: .medium))
                }
            }
            .foregroundStyle(activeCount > 0 ? AnyShapeStyle(CD.ColorToken.text) : AnyShapeStyle(CD.ColorToken.textSecondary))
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(CD.ColorToken.chip)
            .clipShape(RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(activeCount >= 0 ? 1 : 0)
    }
}

// MARK: - Filters hub icon (badge when filters active)
public struct CDFiltersHubIcon: View {
    public var activeCount: Int
    public var onTap: () -> Void
    @State private var badgeAppear: Bool = false
    public init(activeCount: Int, onTap: @escaping () -> Void) {
        self.activeCount = activeCount; self.onTap = onTap
    }
    private var hasActive: Bool { activeCount > 0 }
    private var badgeText: String { activeCount > 99 ? "99+" : "\(activeCount)" }
    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(CD.ColorToken.chip)
                    .frame(width: 34, height: 34)
                    // removed circle stroke
                    .overlay(
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(hasActive ? AnyShapeStyle(CD.ColorToken.text) : AnyShapeStyle(CD.ColorToken.textSecondary))
                    )

                if hasActive {
                    Text(badgeText)
                        .font(CD.FontToken.caption(9, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(CD.GradientToken.pro)
                        .clipShape(Capsule())
                        // removed badge stroke
                        .scaleEffect(badgeAppear ? 1.0 : 0.6)
                        .opacity(badgeAppear ? 1.0 : 0.0)
                        .offset(x: 6, y: -6)
                        .onAppear {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { badgeAppear = true }
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}






// MARK: - Russian Pluralization Helper
fileprivate func ruPlural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let n10 = n % 10
    let n100 = n % 100
    if n10 == 1 && n100 != 11 { return one }
    if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
    return many
}

// Consistent spacing between course cards in all carousels
public let CDCarouselSpacing: CGFloat = 32
fileprivate let CDCardWidth: CGFloat = 268   // match canonical Course/Lesson card width (~268×340)
fileprivate let CDCardHeight: CGFloat = 420  // keep in sync with CourseLessonCard preferred height
// depth & peek tokens to match CardDS calendar
fileprivate let CDCarouselPeekMin: CGFloat = 24           // visible neighbors per side
fileprivate let CDDepthNormWidthFactor: CGFloat = 0.60    // wider influence → сильнее эффект
fileprivate let CDDepthScaleSide: CGFloat = 0.85          // глубже сжатие по краям
fileprivate let CDDepthScaleCenter: CGFloat = 1.06        // легкое усиление центра
fileprivate let CDDepthOpacitySide: CGFloat = 0.45        // затемнение по краям
fileprivate let CDDepthOpacityCenter: CGFloat = 1.00      // центр без затемнения
fileprivate let CDDepthYOffsetMax: CGFloat = 10           // лёгкий подъем центра
// MARK: - Layout tokens (section-level)
public enum CDLayout {
    // MARK: - section-level
    /// vertical spacing between stacked cards/rows inside a section
    public static let sectionContentV: CGFloat = Theme.Layout.sectionContentV
    /// spacing from section title row to section content
    public static let sectionTitleToContent: CGFloat = Theme.Layout.sectionTitleToContent
    /// spacing between sections (top padding applied by CDSection / CDSectionWithAction)
    public static let sectionTop: CGFloat = Theme.Layout.sectionTop

    /// vertical padding for carousels inside sections (top+bottom)
    public static let carouselVPad: CGFloat = Theme.Layout.carouselVPad

    // MARK: - intra-section
    /// default vertical spacing between rows/items inside a section content
    public static let rowV: CGFloat = Theme.Layout.rowV
    /// default horizontal spacing inside rows (icon+text, small groups)
    public static let rowH: CGFloat = Theme.Layout.rowH
    /// spacing between chips/pills in a row
    public static let chipGap: CGFloat = Theme.Layout.chipGap
    /// spacing between SF Symbol and text in meta rows
    public static let metaGap: CGFloat = Theme.Layout.metaGap
    /// spacing between icon and label in compact buttons/pills
    public static let iconGap: CGFloat = Theme.Layout.iconGap
    /// spacing around inline separators (e.g., "•") in meta lines
    public static let inlineDividerGap: CGFloat = Theme.Layout.inlineDividerGap
}

// Backward-compatible aliases (keep usage sites simple)
fileprivate let CDCardVerticalSpacing: CGFloat = CDLayout.sectionContentV
fileprivate let CDSectionTitleToContentSpacing: CGFloat = CDLayout.sectionTitleToContent
fileprivate let CDSectionTopSpacing: CGFloat = CDLayout.sectionTop
fileprivate let CDCarouselContainerHeight: CGFloat = CDCardHeight

// helper: side inset so first/last cards can center perfectly inside section bounds
fileprivate var CDCarouselSideInset: CGFloat {
    let screen = UIScreen.main.bounds.width
    let available = screen - (2 * CD.Spacing.screen)
    return max((available - CDCardWidth) / 2.0, 0)
}

// Map CourseDS status to AppDS status
fileprivate func toAppStatus(_ s: CDCourseStatus) -> AppStatusKind {
    switch s {
    case .new:        return .new
    case .inProgress: return .inProgress
    case .done:       return .completed
    }
}

// MARK: - Inline Meta (icon + text, no pill)
public struct CDMetaInline: View {
    let icon: String
    let text: String
    public init(icon: String, text: String) { self.icon = icon; self.text = text }
    public var body: some View {
        HStack(spacing: CDLayout.metaGap) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(CD.FontToken.caption(12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(CD.ColorToken.textSecondary)
    }
}

// MARK: - Unified Meta Tag (compact, neutral, ghost)
public struct CDMetaTag: View {
    public enum Style { case neutral, accent, ghost }
    let icon: String
    let text: String
    var style: Style = .neutral
    public init(icon: String, text: String, style: Style = .neutral) {
        self.icon = icon; self.text = text; self.style = style
    }
    public var body: some View {
        let isGhost = (style == .ghost)
        let bg: AnyShapeStyle = (style == .accent) ? AnyShapeStyle(CD.GradientToken.pro) : AnyShapeStyle(isGhost ? AnyShapeStyle(Color.clear) : AnyShapeStyle(CD.ColorToken.chip))
        let strokeColor: Color = {
            if style == .accent { return Color.white.opacity(0.18) }
            if isGhost { return Color.white.opacity(0.14) }
            return Color.white.opacity(0.10)
        }()
        HStack(spacing: CDLayout.metaGap) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(CD.FontToken.caption(12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .baselineOffset(0)
        }
        .foregroundStyle(CD.ColorToken.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous).fill(bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CD.Radius.chip, style: .continuous).stroke(strokeColor, lineWidth: 1)
        )
    }
}

// MARK: - CTA Pill (unified for Lessons & Courses)
public struct CDLessonCTAPill: View {
    public var title: String
    public var icon: String
    public var action: () -> Void

    public init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        let kind: AppCTAType = {
            let t = title.lowercased()
            if t.contains("нач") { return .start }
            if t.contains("продолж") { return .resume }
            if t.contains("закреп") { return .reinforce }
            if t.contains("повтор") { return .resume }
            return .start
        }()
        AppCTAButtons(primary: kind, onPrimary: action, scale: .xs, unifiedWidth: true)
    }
}



// MARK: - Vertical "Reel" Course Card (compact, no progress)
public struct CDReelCourseCard: View {
    public var title: String
    public var subtitle: String
    public var lessons: Int
    public var durationMin: Int
    public var isPro: Bool
    public var status: CDCourseStatus?
    public var cta: String?
    public var progress: Double = 0.0
    private var _homeworkTotal: Int = 0
    private var _homeworkDone: Int = 0
    private var _onTapHomework: (() -> Void)?
    public var onTap: () -> Void
    public var isFavorite: Bool = false
    public var onToggleFavorite: () -> Void = {}
    public var isActive: Bool = false
    // Placement for chips (time, lessons)
    public enum ChipsPlacement { case belowDescription, bottomBar }
    public var chipsPlacement: ChipsPlacement = .belowDescription

    public init(
        title: String,
        subtitle: String,
        lessons: Int,
        durationMin: Int,
        isPro: Bool,
        status: CDCourseStatus? = nil,
        cta: String? = nil,
        progress: Double = 0.0,
        homeworkTotal: Int = 0,
        homeworkDone: Int = 0,
        onTapHomework: (() -> Void)? = nil,
        isActive: Bool = false,
        chipsPlacement: ChipsPlacement = .belowDescription,
        onTap: @escaping ()->Void,
        isFavorite: Bool = false,
        onToggleFavorite: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.lessons = lessons
        self.durationMin = durationMin
        self.isPro = isPro
        self.status = status
        self.cta = cta
        self.progress = progress
        self._homeworkTotal = homeworkTotal
        self._homeworkDone = homeworkDone
        self._onTapHomework = onTapHomework
        self.isActive = isActive
        self.chipsPlacement = chipsPlacement
        self.onTap = onTap
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
    }

    private let cardWidth: CGFloat = CDCardWidth
    private let cardHeight: CGFloat = CDCardHeight

    // Helper for CTA icon/label (copied from CDCourseCard)
    private func ctaIconAndLabel(_ text: String) -> (String, String) {
        let t = text.lowercased()
        if t.contains("нач") { return ("play.fill", "Начать") }
        if t.contains("продолж") { return ("pause.fill", "Продолжить") }
        if t.contains("повтор") { return ("arrow.clockwise", "Повторить") }
        return ("play.fill", text)
    }

    @ViewBuilder
    private func chipsRow() -> some View {
        HStack(spacing: CDLayout.rowH) {
            CDMetaInline(icon: "clock", text: "≈ \(durationMin) мин")
            Text("•").foregroundStyle(CD.ColorToken.textSecondary.opacity(0.6))
            CDMetaInline(icon: "book.closed", text: "\(lessons) \(ruPlural(lessons, "урок", "урока", "уроков"))")
            Spacer(minLength: 0)
        }
    }

    public var body: some View {
        CourseLessonCard(
            title: title,
            subtitle: subtitle,
            lessonsCount: lessons,
            durationText: "≈ \(durationMin) мин",
            statusKind: status.map { toAppStatus($0) },
            isPro: isPro,
            tags: [],
            sectionChrome: .none,
            primaryCTA: {
                let raw = (cta ?? "").lowercased()
                if raw.contains("нач") { return .start }
                if raw.contains("продолж") { return .resume }
                if raw.contains("закреп") { return .reinforce }
                if raw.contains("повтор") { return .resume }
                return .start
            }(),
            scale: .xs,
            showFavorite: true,
            showConsole: true,
            onPrimaryTap: { onTap() },
            isFavoriteActive: isFavorite,
            isConsoleEnabled: _homeworkDone > 0,
            completionFraction: progress,
            onFavoriteTap: { onToggleFavorite() },
            showsInlineProgress: true
        )
        .frame(width: cardWidth, height: cardHeight)
    }
}

// MARK: - Sticky App Header (logo + quick actions)
@available(*, deprecated, message: "Use AppHeader (AppDS.swift) directly.")
public struct CDAppHeader: View {
    public var onTapSearch: () -> Void = {}
    public var onTapFavorites: () -> Void = {}
    public var onTapProfile: () -> Void = {}

    public init(onTapSearch: @escaping () -> Void = {},
                onTapFavorites: @escaping () -> Void = {},
                onTapProfile: @escaping () -> Void = {}) {
        self.onTapSearch = onTapSearch
        self.onTapFavorites = onTapFavorites
        self.onTapProfile = onTapProfile
    }

    public var body: some View {
        AppHeader(
            showSearch: true,
            showHeart: true,
            showProfile: true,
            onTapSearch: onTapSearch,
            onTapHeart: onTapFavorites,
            onTapProfile: onTapProfile
        )
    }
}

/// Simple blur wrapper to avoid importing extra utilities here
fileprivate struct VisualEffectBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = UIBlurEffect(style: style) }
}

// MARK: - Course Section (title + list container)
public struct CDSection<Content: View>: View {
    public var title: String
    @ViewBuilder public var content: Content
    public init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: CDLayout.sectionContentV) {
            Text(title.uppercased())
                .font(CD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(CD.ColorToken.textSecondary)
                .padding(.horizontal, CD.Spacing.screen)
            content
                .padding(.top, CDSectionTitleToContentSpacing)
        }
        .padding(.top, CDSectionTopSpacing)
    }
}

// MARK: - Section with trailing action (title on the left, action on the right)
public struct CDSectionWithAction<Action: View, Content: View>: View {
    public var title: String
    @ViewBuilder public var action: Action
    @ViewBuilder public var content: Content

    public init(_ title: String,
                @ViewBuilder action: () -> Action,
                @ViewBuilder content: () -> Content) {
        self.title = title
        self.action = action()
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CDLayout.sectionContentV) {
            HStack(alignment: .center) {
                Text(title.uppercased())
                    .font(CD.FontToken.caption(12, weight: .semibold))
                    .kerning(0.6)
                    .foregroundColor(CD.ColorToken.textSecondary)
                Spacer()
                action
            }
            .padding(.horizontal, CD.Spacing.screen)

            content
                .padding(.top, CDSectionTitleToContentSpacing)
        }
        .padding(.top, CDSectionTopSpacing)
    }
}

// MARK: - Subsection Row (title left, count+chevron right, pink divider)
public struct CDSubsectionRow: View {
    public var title: String
    public var count: Int
    @Binding public var isExpanded: Bool
    public var showDivider: Bool = false
    public var onTap: () -> Void

    public init(title: String, count: Int, isExpanded: Binding<Bool>, showDivider: Bool = false, onTap: @escaping () -> Void) {
        self.title = title
        self.count = count
        self._isExpanded = isExpanded
        self.showDivider = showDivider
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: CDLayout.sectionContentV) {
            Button(action: {
                withAnimation(.easeOut(duration: 0.25)) {
                    isExpanded.toggle()
                    onTap()
                }
            }) {
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Text(title.uppercased())
                            .font(CD.FontToken.caption(12, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showDivider {
                Rectangle()
                    .fill(ThemeManager.shared.currentAccentFill)
                    .frame(height: 1)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.vertical, CDLayout.inlineDividerGap)
    }
}


// MARK: - Marquee as Section ("TAIKA FM" style)
/// Section wrapper so the assistant stripe looks like other sections (e.g., "БАЗА", "КУРСЫ").
public struct CDMarqueeSection: View {
    public var title: String
    public var messages: [String]
    public var mascot: Image?
    public var typingDuration: TimeInterval
    public var showDuration: TimeInterval
    public var typingCharInterval: TimeInterval

    public init(
        title: String = "ТАЙКА FM",
        messages: [String],
        mascot: Image? = Image("mascot.course"),
        typingDuration: TimeInterval = 2.2,
        showDuration: TimeInterval = 3.2,
        typingCharInterval: TimeInterval = 0.045
    ) {
        self.title = title
        self.messages = messages
        self.mascot = mascot
        self.typingDuration = typingDuration
        self.showDuration = showDuration
        self.typingCharInterval = typingCharInterval
    }

    public var body: some View {
        // taika fm для экрана курсов: текст и реакции берём из taikafm.json (scope: .course),
        // а входной параметр messages используем как оверрайд, если он не пустой.
        let configMessages = TaikaFMData.shared.messages(for: .course)
        let configReactions = TaikaFMData.shared.reactionGroups(for: .course)

        let effectiveMessages = messages.isEmpty ? configMessages : messages
        let effectiveReactions = configReactions

        return CDSection(title) {
            TaikaFMBubbleTyping(
                messages: effectiveMessages,
                reactions: effectiveReactions,
                repeats: false
            )
            .padding(.top, 0)
        }
    }
}


// MARK: - Minimal Course model for CDCourseSearchSection
public struct CDCourseItem: Identifiable {
    public var id: UUID = UUID()
    public var title: String
    public var subtitle: String
    public var category: String
    public var lessons: Int
    public var durationMin: Int
    public var cta: String
    public var isPro: Bool
    public var status: CDCourseStatus?
    public var progress: Double
    public var homeworkTotal: Int
    public var homeworkDone: Int
    public var isActive: Bool = false
    public var onTap: (() -> Void)?
    public var isFavorite: Bool = false
    public var onToggleFavorite: (() -> Void)? = nil
    public var key: String? = nil // optional stable identity (e.g., courseId)
    fileprivate var stableKey: String { key ?? id.uuidString }

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        category: String = "",
        lessons: Int,
        durationMin: Int,
        cta: String,
        isPro: Bool,
        status: CDCourseStatus? = nil,
        progress: Double,
        homeworkTotal: Int = 0,
        homeworkDone: Int = 0,
        isActive: Bool = false,
        onTap: (() -> Void)? = nil,
        isFavorite: Bool = false,
        onToggleFavorite: (() -> Void)? = nil,
        key: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.lessons = lessons
        self.durationMin = durationMin
        self.cta = cta
        self.isPro = isPro
        self.status = status
        self.progress = progress
        self.homeworkTotal = homeworkTotal
        self.homeworkDone = homeworkDone
        self.isActive = isActive
        self.onTap = onTap
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
        self.key = key
    }
}

// Render wrapper so we can safely duplicate first/last for cyclic carousels
fileprivate struct _RenderedCourseItem: Identifiable {
    let id: UUID
    let origin: CDCourseItem
    init(origin: CDCourseItem) {
        self.id = UUID()
        self.origin = origin
    }
}



// MARK: - Canonical 3D depth (calendar-style) used for Base carousels
// MARK: - Canonical 3D depth (calendar-style) used for Base carousels
fileprivate struct CDDepthEffect: ViewModifier {
    let spaceName: String
    let viewportMidX: CGFloat

    private let maxScaleDrop: CGFloat = 0.32
    private let maxOpacityDrop: Double = 0.70
    private let maxYOffset: CGFloat = 16
    private let maxAngleDeg: CGFloat = 18

    private var influenceWidth: CGFloat { max(CDCardWidth + (CDCarouselSpacing * 1.0), 1) }

    @State private var itemMidX: CGFloat = .zero
    @State private var lastReportedMidX: CGFloat = .leastNormalMagnitude

    func body(content: Content) -> some View {
        // No-op depth: keep structure, remove custom transforms.
        // We preserve the type and call sites but render identity visuals.
        content
    }
}


// preference to collect item midX positions (global space)
private struct CDItemCenterKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// viewport center (midX) for a given scroll container
private struct CDViewportMidXKey: PreferenceKey {
    static var defaultValue: CGFloat = UIScreen.main.bounds.midX
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// viewport width for a given scroll container
private struct CDViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = UIScreen.main.bounds.width
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Base (БАЗА) Section — horizontal reel
public struct CDBaseSection: View {
    public var title: String = "БАЗА"
    public var items: [CDCourseItem]
    public var onTapItem: ((CDCourseItem) -> Void)?
    public var onTapStart: (() -> Void)?

    @State private var selectedId: UUID? = nil
    @State private var itemCenters: [UUID: CGFloat] = [:]
    @State private var viewportMidX: CGFloat = UIScreen.main.bounds.midX
    @State private var viewportWidth: CGFloat = UIScreen.main.bounds.width

    public init(items: [CDCourseItem], onTapItem: ((CDCourseItem) -> Void)? = nil, onTapStart: (() -> Void)? = nil) {
        self.items = items
        self.onTapItem = onTapItem
        self.onTapStart = onTapStart
    }

    private var renderedItems: [_RenderedCourseItem] {
        let base = items.map { _RenderedCourseItem(origin: $0) }
        if base.count > 1, let first = base.first, let last = base.last {
            return [last] + base + [first]
        } else {
            return base
        }
    }

    public var body: some View {
        CDSectionWithAction(title, action: {
            Button(action: { onTapStart?() }) {
                HStack(spacing: 3) {
                    Text("НАЧАТЬ")
                        .font(CD.FontToken.caption(12, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
            }
            .buttonStyle(.plain)
        }) {
            CDLessonCarousel(
                data: items,
                cardWidth: CDCardWidth,
                cardHeight: CDCardHeight,
                spacing: CDCarouselSpacing,
                initialIndex: nil,
                onTapScrollToCenter: true,
                loop: true
            ) { item in
                CourseLessonCard(
                    title: item.title,
                    subtitle: "",
                    lessonsCount: item.lessons,
                    durationText: "≈ \(item.durationMin) мин",
                    statusKind: item.status.map { toAppStatus($0) },
                    courseCategory: item.category,
                    isPro: item.isPro,
                    tags: [],
                    sectionChrome: .none,
                    primaryCTA: {
                        let t = item.cta.lowercased()
                        if t.contains("нач") { return .start }
                        if t.contains("продолж") { return .resume }
                        if t.contains("закреп") { return .reinforce }
                        if t.contains("повтор") { return .resume }
                        return .start
                    }(),
                    scale: .xs,
                    showFavorite: true,
                    showConsole: true,
                    onPrimaryTap: {
                        if let act = onTapItem {
                            DispatchQueue.main.async { act(item) }
                        } else {
                            DispatchQueue.main.async { item.onTap?() }
                        }
                    },
                    isFavoriteActive: item.isFavorite,
                    isConsoleEnabled: item.homeworkDone > 0,
                    completionFraction: item.progress,
                    onFavoriteTap: { item.onToggleFavorite?() },
                    showsInlineProgress: true
                )
            }
        }
    }
}
 
public struct CDAllCoursesSection: View {
    public var title: String = ""
    public var items: [CDCourseItem]

    public init(title: String = "", items: [CDCourseItem]) {
        self.title = title
        self.items = items
    }

    private var renderedItems: [_RenderedCourseItem] {
        let base = items.map { _RenderedCourseItem(origin: $0) }
        if base.count > 1, let first = base.first, let last = base.last {
            return [last] + base + [first]
        } else {
            return base
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CDLayout.sectionContentV) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(CD.FontToken.caption(12, weight: .semibold))
                    .kerning(0.6)
                    .foregroundColor(CD.ColorToken.textSecondary)
                    .padding(.horizontal, CD.Spacing.screen)
            }
            if items.isEmpty {
                Text("Ничего не найдено")
                    .font(CD.FontToken.body(14))
                    .foregroundColor(CD.ColorToken.textSecondary)
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.vertical, 10)
            } else {
                CDLessonCarousel(
                    data: items,
                    cardWidth: CDCardWidth,
                    cardHeight: CDCardHeight,
                    spacing: CDCarouselSpacing,
                    initialIndex: nil,
                    onTapScrollToCenter: true,
                    loop: true
                ) { item in
                    CourseLessonCard(
                        title: item.title,
                        subtitle: "",
                        lessonsCount: item.lessons,
                        durationText: "≈ \(item.durationMin) мин",
                        statusKind: item.status.map { toAppStatus($0) },
                        courseCategory: item.category,
                        isPro: item.isPro,
                        tags: [],
                        sectionChrome: .none,
                        primaryCTA: {
                            let t = item.cta.lowercased()
                            if t.contains("нач") { return .start }
                            if t.contains("продолж") { return .resume }
                            if t.contains("закреп") { return .reinforce }
                            if t.contains("повтор") { return .resume }
                            return .start
                        }(),
                        scale: .xs,
                        showFavorite: true,
                        showConsole: true,
                        onPrimaryTap: { DispatchQueue.main.async { item.onTap?() } },
                        isFavoriteActive: item.isFavorite,
                        isConsoleEnabled: item.homeworkDone > 0,
                        completionFraction: item.progress,
                        onFavoriteTap: { item.onToggleFavorite?() },
                        showsInlineProgress: true
                    )
                }
                .padding(.top, CDLayout.sectionTitleToContent)
            }
        }
        .padding(.top, CDLayout.sectionTop)
    }
}

// MARK: - Reusable calendar‑style carousel for lesson/course cards
public struct CDLessonCarousel<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    public typealias Item = Data.Element

    private let data: Data
    private let cardWidth: CGFloat
    private let cardHeight: CGFloat
    private let spacing: CGFloat
    private let initialIndex: Int?
    private let onTapScrollToCenter: Bool
    private let loop: Bool
    @ViewBuilder private let content: (Item) -> Content

    @State private var viewportWidth: CGFloat = UIScreen.main.bounds.width

    public init(
        data: Data,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        spacing: CGFloat,
        initialIndex: Int? = nil,
        onTapScrollToCenter: Bool = true,
        loop: Bool = false,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.data = data
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.spacing = spacing
        self.initialIndex = initialIndex
        self.onTapScrollToCenter = onTapScrollToCenter
        self.loop = loop
        self.content = content
    }

    public var body: some View {
        GeometryReader { outer in
            let cardW = min(cardWidth, outer.size.width - (CDCarouselPeekMin * 2)) // enforce ≥24pt peek per side
            let sideInset = max(0, (outer.size.width - cardW) / 2)
            let base = Array(data)
            let renderedIndices: [Int] = {
                guard loop, base.count > 1 else {
                    return Array(base.indices)
                }
                let indices = Array(base.indices)
                return indices + indices + indices
            }()
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: spacing) {
                        ForEach(Array(renderedIndices.enumerated()), id: \.0) { (renderIndex, baseIndex) in
                            let item = base[baseIndex]
                            GeometryReader { cellGeo in
                                let viewportCenterX: CGFloat = outer.size.width / 2
                                let cellCenterX: CGFloat = cellGeo.frame(in: .named("cdLessonCarousel")).midX
                                let dist: CGFloat = abs(cellCenterX - viewportCenterX)
                                let norm: CGFloat = min(1.0, dist / max(1.0, outer.size.width * CDDepthNormWidthFactor))
                                // мягкий календарный эффект
                                let vScale: CGFloat = CDDepthScaleSide + (CDDepthScaleCenter - CDDepthScaleSide) * (1.0 - norm)
                                let vOpacity: CGFloat = CDDepthOpacitySide + (CDDepthOpacityCenter - CDDepthOpacitySide) * (1.0 - norm)
                                let vYOffset: CGFloat = -(1.0 - norm) * CDDepthYOffsetMax

                                content(item)
                                    .scaleEffect(vScale)
                                    .opacity(vOpacity)
                                    .offset(y: vYOffset)
                                    .frame(width: cardW, height: cardHeight)
                                    .id(renderIndex)
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            guard onTapScrollToCenter else { return }
                                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                                proxy.scrollTo(renderIndex, anchor: .center)
                                            }
                                        }
                                    )
                            }
                            .frame(width: cardW, height: cardHeight)
                        }
                    }
                    .padding(.horizontal, sideInset)
                }
                .coordinateSpace(name: "cdLessonCarousel")
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { viewportWidth = g.size.width }
                            .onChange(of: g.size.width) { _, newValue in viewportWidth = newValue }
                    }
                )
                .onAppear {
                    guard !base.isEmpty else { return }

                    let baseCount = base.count
                    let targetBaseIndex: Int
                    if let idx = initialIndex, base.indices.contains(idx) {
                        targetBaseIndex = idx
                    } else {
                        targetBaseIndex = 0
                    }

                    let targetRenderIndex: Int
                    if loop, baseCount > 1 {
                        let blockSize = baseCount
                        let middleBlockStart = blockSize
                        targetRenderIndex = middleBlockStart + targetBaseIndex
                    } else {
                        targetRenderIndex = targetBaseIndex
                    }

                    withAnimation(.none) {
                        proxy.scrollTo(targetRenderIndex, anchor: .center)
                    }
                }
            }
        }
        .padding(.vertical, CDLayout.carouselVPad)
        .frame(height: cardHeight)
    }
}

struct CourseDSPreviewHost: View {
    // Filters state
    @State private var selectedPrimary: Int = -1
    @State private var selectedSecondary: Int = -1
    @State private var isSortOn: Bool = false
    @State private var showFilters: Bool = true
    @State private var showCategories: Bool = true

    // Category filter state
    @State private var selectedCategory: Int = -1 // -1 = все
    private let categoriesChips: [String] = ["Тайский для жизни", "На одной волне", "Тайский для души"]

    // Search state
    @State private var searchText: String = ""

    // Base section tap
    @State private var tappedBaseItemTitle: String? = nil

    // Local preview favorite state for demo
    @State private var favSet: Set<UUID> = []
    @State private var demoId1 = UUID()
    @State private var demoId2 = UUID()
    @State private var demoId3 = UUID()

    // Demo data for "Все курсы" карусели
    private let allCoursesDemo: [CDCourseItem] = [
        CDCourseItem(title: "Разговорный минимум", subtitle: "Практика с Taika и смешные подсказки", category: "На одной волне", lessons: 18, durationMin: 60, cta: "Продолжить", isPro: false, status: .inProgress, progress: 0.25, homeworkTotal: 6, homeworkDone: 2),
        CDCourseItem(title: "Грамматика без боли", subtitle: "3 простых шаблона речи", category: "Тайский для души", lessons: 12, durationMin: 45, cta: "Начать", isPro: true, status: .done, progress: 1.0, homeworkTotal: 12, homeworkDone: 12),
        CDCourseItem(title: "Алфавит и чтение", subtitle: "Базовые звуки и тональность", category: "База", lessons: 9, durationMin: 35, cta: "Начать", isPro: false, status: .new, progress: 0.0, homeworkTotal: 3, homeworkDone: 0),
        CDCourseItem(title: "Фразы на каждый день", subtitle: "Приветствия и вежливость", category: "Тайский для жизни", lessons: 12, durationMin: 40, cta: "Начать", isPro: false, status: .new, progress: 0.0, homeworkTotal: 5, homeworkDone: 2),
        CDCourseItem(title: "Тональные тренировки", subtitle: "Слух и произношение", category: "Тайский для души", lessons: 10, durationMin: 42, cta: "Начать", isPro: true, status: .inProgress, progress: 0.2, homeworkTotal: 4, homeworkDone: 1)
    ]

    // Фильтрация под поиск + чипы
    private var filteredAllCourses: [CDCourseItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCoursesDemo.filter { item in
            // текст
            let textOK = q.isEmpty
                || item.title.lowercased().contains(q)
                || item.subtitle.lowercased().contains(q)
            // статус
            let statusOK: Bool = {
                switch selectedPrimary {
                case 0: return item.status == .new
                case 1: return item.status == .inProgress
                case 2: return item.status == .done
                default: return true
                }
            }()
            // доступ
            let accessOK: Bool = {
                switch selectedSecondary {
                case 0: return item.isPro == false   // Free
                case 1: return item.isPro == true    // Pro
                default: return true
                }
            }()
            // категория
            let categoryOK: Bool = {
                guard selectedCategory >= 0 else { return true }
                let wanted = categoriesChips[selectedCategory]
                return item.category == wanted
            }()
            return textOK && statusOK && accessOK && categoryOK
        }
    }

    private var activeFiltersCount: Int {
        (selectedPrimary >= 0 ? 1 : 0) + (selectedSecondary >= 0 ? 1 : 0) + (isSortOn ? 1 : 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            CD.ColorToken.background.ignoresSafeArea()

            // Main scroll content sits under header; give it a small top padding so it doesn't stick to it
            ScrollView {
                VStack(spacing: CD.Spacing.inner) {

                    // БАЗА (demo reel)
                    CDBaseSection(
                        items: [
                            CDCourseItem(
                                id: demoId1,
                                title: "Алфавит и чтение",
                                subtitle: "Базовые звуки и тональность",
                                category: "База",
                                lessons: 9,
                                durationMin: 35,
                                cta: "Начать",
                                isPro: false,
                                status: .new,
                                progress: 0.0,
                                homeworkTotal: 3,
                                homeworkDone: 0,
                                onTap: { tappedBaseItemTitle = "Алфавит и чтение" },
                                isFavorite: favSet.contains(demoId1),
                                onToggleFavorite: {
                                    if favSet.contains(demoId1) { favSet.remove(demoId1) } else { favSet.insert(demoId1) }
                                }
                            ),
                            CDCourseItem(
                                id: demoId2,
                                title: "Фразы на каждый день",
                                subtitle: "Приветствия и вежливость",
                                category: "База",
                                lessons: 12,
                                durationMin: 40,
                                cta: "Начать",
                                isPro: false,
                                status: .new,
                                progress: 0.0,
                                homeworkTotal: 5,
                                homeworkDone: 2,
                                onTap: { tappedBaseItemTitle = "Фразы на каждый день" },
                                isFavorite: favSet.contains(demoId2),
                                onToggleFavorite: {
                                    if favSet.contains(demoId2) { favSet.remove(demoId2) } else { favSet.insert(demoId2) }
                                }
                            ),
                            CDCourseItem(
                                id: demoId3,
                                title: "Тональные тренировки",
                                subtitle: "Слух и произношение",
                                category: "База",
                                lessons: 10,
                                durationMin: 42,
                                cta: "Начать",
                                isPro: true,
                                status: .inProgress,
                                progress: 0.2,
                                homeworkTotal: 4,
                                homeworkDone: 1,
                                onTap: { tappedBaseItemTitle = "Тональные тренировки" },
                                isFavorite: favSet.contains(demoId3),
                                onToggleFavorite: {
                                    if favSet.contains(demoId3) { favSet.remove(demoId3) } else { favSet.insert(demoId3) }
                                }
                            )
                        ],
                        onTapItem: { item in tappedBaseItemTitle = item.title },
                        onTapStart: { print("Start base from first course") }
                    )
                    .padding(.top, 4)

                    CDMarqueeSection(
                        title: "ТАЙКА FM",
                        messages: [
                            "как выбирать курс: начни с коротких уроков, потом переходи к диалогам",
                            "фильтры помогают: отметь PRO, если хочешь больше практики"
                        ],
                        mascot: Image("mascot.course")
                    )

                    CDSectionWithAction("ФИЛЬТРЫ", action: {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.25)) { showFilters.toggle() }
                        }) {
                            Image(systemName: showFilters ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        }
                        .buttonStyle(.plain)
                    }) {
                        if showFilters {
                            // Combined single row: "Все" + статус + доступ
                            let combined: [String] = ["Все", "Новый", "В процессе", "Завершено", "Free", "Pro"]
                            let items: [AppFilterItem] = combined.enumerated().map { (i, title) in
                                if i == 0 {
                                    // "Все" активно, когда нет выбранных фильтров
                                    return AppFilterItem(title: title, isActive: selectedPrimary < 0 && selectedSecondary < 0)
                                }
                                if (1...3).contains(i) {
                                    // статус: смещение на -1
                                    return AppFilterItem(title: title, isActive: selectedPrimary == (i - 1))
                                }
                                // доступ: Free (i==4 => 0), Pro (i==5 => 1)
                                return AppFilterItem(title: title, isActive: selectedSecondary == (i - 4))
                            }

                            AppFiltersBar(items: items, scale: .s) { id in
                                guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
                                switch idx {
                                case 0:
                                    // Сбросить всё
                                    selectedPrimary = -1
                                    selectedSecondary = -1
                                case 1...3:
                                    // Переключение статуса
                                    let pick = idx - 1
                                    selectedPrimary = (selectedPrimary == pick ? -1 : pick)
                                case 4...5:
                                    // Переключение доступа
                                    let pick = idx - 4
                                    selectedSecondary = (selectedSecondary == pick ? -1 : pick)
                                default:
                                    break
                                }
                            }
                            .padding(.horizontal, CD.Spacing.screen)
                        }
                    }

                    CDSectionWithAction("КАТЕГОРИИ", action: {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.25)) { showCategories.toggle() }
                        }) {
                            Image(systemName: showCategories ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        }
                        .buttonStyle(.plain)
                    }) {
                        if showCategories {
                            let catItems: [AppFilterItem] = categoriesChips.enumerated().map { (i, label) in
                                AppFilterItem(title: label, isActive: i == selectedCategory)
                            }
                            AppFiltersBar(items: catItems, scale: .s) { id in
                                if let idx = catItems.firstIndex(where: { $0.id == id }) {
                                    selectedCategory = (selectedCategory == idx ? -1 : idx)
                                }
                            }
                            .padding(.horizontal, CD.Spacing.screen)
                        }
                    }

                    // Removed search section under "КУРСЫ"

                    let shouldAutoScroll = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPrimary < 0 && selectedSecondary < 0 && selectedCategory < 0
                    CDAllCoursesSection(
                        title: "КУРСЫ",
                        items: filteredAllCourses.map { item in
                            var m = item
                            let id = item.id
                            m.isFavorite = favSet.contains(id)
                            m.onToggleFavorite = {
                                if favSet.contains(id) { favSet.remove(id) } else { favSet.insert(id) }
                            }
                            return m
                        }
                    )

                    CDSection("КАТЕГОРИИ") {
                        VStack(spacing: 8) {
                        }
                        .padding(.top, 0)
                    }
                }
                .padding(.top, CDLayout.sectionTop)
                .padding(.vertical, CDLayout.sectionContentV)
            }

            // Sticky transparent header on top
            CDAppHeader(
                onTapSearch: { print("search tapped") },
                onTapFavorites: { print("favorites tapped") },
                onTapProfile: { print("profile tapped") }
            )
            .frame(height: 44)
        }
    }

}
#Preview("Course DS") {
    CourseDSPreviewHost()
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
}



// MARK: - DS Wrappers for Filters & Categories (exported)
public struct CDFiltersSection: View {
    @EnvironmentObject private var theme: ThemeManager
    public var title: String = "ФИЛЬТРЫ"
    @Binding public var isExpanded: Bool

    public var primary: [String]
    public var selectedPrimary: Int
    public var onTapPrimary: (Int) -> Void

    public var secondary: [String]
    public var selectedSecondary: Int
    public var onTapSecondary: (Int) -> Void

    public init(
        title: String = "ФИЛЬТРЫ",
        isExpanded: Binding<Bool>,
        primary: [String],
        selectedPrimary: Int,
        onTapPrimary: @escaping (Int) -> Void,
        secondary: [String],
        selectedSecondary: Int,
        onTapSecondary: @escaping (Int) -> Void
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.primary = primary
        self.selectedPrimary = selectedPrimary
        self.onTapPrimary = onTapPrimary
        self.secondary = secondary
        self.selectedSecondary = selectedSecondary
        self.onTapSecondary = onTapSecondary
    }

    public var body: some View {
        return CDSectionWithAction(title, action: {
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
            }
            .buttonStyle(.plain)
        }) {
            if isExpanded {
                // Combined single row: "Все" + primary + secondary
                let titles: [String] = ["Все"] + primary + secondary
                let items: [AppFilterItem] = titles.enumerated().map { (i, title) in
                    if i == 0 {
                        // "Все" активно, когда ничего не выбрано
                        return AppFilterItem(title: title, isActive: selectedPrimary < 0 && selectedSecondary < 0)
                    }
                    if i <= primary.count {
                        let pIndex = i - 1
                        return AppFilterItem(title: title, isActive: selectedPrimary == pIndex)
                    }
                    // secondary: offset by primary.count + 1 ("Все")
                    let sIndex = i - (primary.count + 1)
                    return AppFilterItem(title: title, isActive: selectedSecondary == sIndex)
                }

                AppFiltersBar(items: items, scale: .s) { id in
                    guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
                    if idx == 0 {
                        // reset all
                        onTapPrimary(-1)
                        onTapSecondary(-1)
                        return
                    }
                    if idx <= primary.count {
                        let pPick = idx - 1
                        onTapPrimary(pPick)
                        return
                    }
                    let sPick = idx - (primary.count + 1)
                    onTapSecondary(sPick)
                }
                .padding(.horizontal, CD.Spacing.screen)
            }
        }
    }
}

public struct CDCategoriesSection: View {
    @EnvironmentObject private var theme: ThemeManager
    public var title: String = "КАТЕГОРИИ"
    @Binding public var isExpanded: Bool

    public var chips: [String]
    public var selected: Int
    public var onTap: (Int) -> Void

    public init(
        title: String = "КАТЕГОРИИ",
        isExpanded: Binding<Bool>,
        chips: [String],
        selected: Int,
        onTap: @escaping (Int) -> Void
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.chips = chips
        self.selected = selected
        self.onTap = onTap
    }

    public var body: some View {
        let cItems: [AppFilterItem] = chips.enumerated().map { (i, t) in AppFilterItem(title: t, isActive: i == selected) }

        return CDSectionWithAction(title, action: {
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
            }
            .buttonStyle(.plain)
        }) {
            if isExpanded {
                AppFiltersBar(items: cItems, scale: .s) { id in
                    if let idx = cItems.firstIndex(where: { $0.id == id }) { onTap(idx) }
                }
                .padding(.horizontal, CD.Spacing.screen)
            }
        }
    }
}
