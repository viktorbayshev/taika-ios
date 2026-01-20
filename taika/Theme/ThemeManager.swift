//
//  ThemeManager.swift
//  taika
//
//  Created by product on 19.10.2025.
//

import SwiftUI

/// Central place to manage runtime-selected accent for the app.
/// Step 1: state + persistence (no UI here).
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    /// Available accent variants (extend as needed)
    public enum Accent: String, CaseIterable, Identifiable {
        case pink    // default brand (current app default)
        case azure   // blue → teal
        case sun     // light yellow → ember
        case thai    // Thai tricolor (horizontal bands)

        public var id: String { rawValue }
    }

    // Persist selected accent between launches (AppStorage keeps it in UserDefaults)
    @AppStorage("accentKey") private var storedAccentKey: String = Accent.pink.rawValue

    /// Published runtime value for SwiftUI to react to
    @Published public var accent: Accent {
        didSet {
            storedAccentKey = accent.rawValue
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // app-wide preferred scheme. nil = follow system
    @Published public var preferredScheme: ColorScheme? = .dark

    public func toggleTheme() {
        switch preferredScheme {
        case .dark:
            preferredScheme = .light
        case .light:
            preferredScheme = .dark
        default:
            preferredScheme = .dark
        }
    }

    private init() {
        // bootstrap from storage
        let key = UserDefaults.standard.string(forKey: "accentKey") ?? Accent.pink.rawValue
        self.accent = Accent(rawValue: key) ?? .pink
        self.storedAccentKey = self.accent.rawValue
    }
}

/// Convenience computed values to access the current accent tokens
extension ThemeManager {
    /// Gradient used for text/icon foregrounds (matches existing usage of Theme.Gradients.accentText)
    public var currentAccentGradient: LinearGradient {
        switch accent {
        case .pink:
            return Theme.Gradients.accentText
        case .azure:
            return Theme.Gradients.accentAzure
        case .sun:
            return Theme.Gradients.accentSun
        case .thai:
            return Theme.Gradients.accentThaiTricolor
        }
    }

    /// Color/gradient to fill controls. For now we reuse the gradient; if a solid color is needed, map here.
    public var currentAccentFill: LinearGradient { currentAccentGradient }
}

// MARK: - Accent Picker (inline panel)
struct AccentPickerPanel: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 6)
                .accessibilityHidden(true)

            HStack(spacing: 4) {
                Text("tai") // 'Thai' in Thai script
                    .font(.custom("ONMARK Trial", size: 48))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("kAAA")
                    .font(.custom("ONMARK Trial", size: 48))
                    .fontWeight(.bold)
                    .foregroundStyle(theme.currentAccentFill)
            }
            .padding(.top, 8)
            .accessibilityHidden(true)

            HStack(spacing: 16) {
                ForEach(ThemeManager.Accent.allCases) { option in
                    AccentDot(gradient: option.previewGradient,
                              selected: option == theme.accent) {
                        theme.accent = option
                    }
                    .accessibilityLabel(option.title)
                }
            }
            .padding(.vertical, 6)

            // current name (subtle)
            Text(theme.accent.title)
                .font(.caption)
                .opacity(0.6)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding()
    }
}

private struct AccentDot: View {
    let gradient: LinearGradient
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(gradient)
                .frame(width: 34, height: 34)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .strokeBorder(selected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 2)
                        .blur(radius: selected ? 0 : 0)
                )
                .shadow(color: selected ? Color.white.opacity(0.35) : .clear, radius: 8, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

// MARK: - Accent metadata
extension ThemeManager.Accent {
    var title: String {
        switch self {
        case .pink:  return "Пинки милки"
        case .azure: return "Джангл"
        case .sun:   return "Пляжный"
        case .thai:  return "Закатный"
        }
    }
    var subtitle: String {
        switch self {
        case .pink:  return "розовый акцент"
        case .azure: return "голубой → бирюза"
        case .sun:   return "жёлтый → янтарь"
        case .thai:  return "красн‑бел‑син‑бел‑красн"
        }
    }
    var previewGradient: LinearGradient {
        switch self {
        case .pink:  return Theme.Gradients.accentText
        case .azure: return Theme.Gradients.accentAzure
        case .sun:   return Theme.Gradients.accentSun
        case .thai:  return Theme.Gradients.accentThaiTricolor
        }
    }
}

// MARK: - Preview
#Preview("Accent Picker Panel") {
    ZStack {
        Theme.Colors.backgroundPrimary.ignoresSafeArea()
        AccentPickerPanel()
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(.dark)
    }
}
