import SwiftUI
import UIKit

/// Docked, minimal bottom bar (Instagram‑inspired, but with Taika center action)
/// Full‑width, attached to bottom; flat background; subtle hairline divider on top.
struct ToolBar: View {
    @Binding var selectedTab: Int   // 0...4
    @State private var pulse = false
    @EnvironmentObject var theme: ThemeManager

    // MARK: Tokens
    private let barHeight: CGFloat = 36
    private let iconSize: CGFloat = 24
    private let barDrop: CGFloat = 12

    /// Host views can use this to match safeAreaInset height
    static let recommendedBottomInset: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            // content row
            HStack(alignment: .center) {
                tab(icon: "house", selectedIcon: "house.fill", index: 0)
                Spacer(minLength: 0)
                tab(icon: "magnifyingglass", index: 1)
                Spacer(minLength: 0)
                centerOrb()
                Spacer(minLength: 0)
                tab(icon: "heart", selectedIcon: "heart.fill", index: 3)
                Spacer(minLength: 0)
                tab(icon: "person", selectedIcon: "person.fill", index: 4)
            }
            .padding(.horizontal, 22)
            .frame(height: barHeight)
        }
        .offset(y: barDrop)
        .background(
            ZStack {
                // dense real blur
                BackdropBlur(style: .systemChromeMaterialDark)
                    .ignoresSafeArea(edges: .bottom)
                // subtle brand background tint so glass matches app background
                Theme.Colors.backgroundPrimary
                    .opacity(0.65)
                    .ignoresSafeArea(edges: .bottom)
            }
            .saturation(1.5)
            .contrast(1.05)
        )
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Elements
    @ViewBuilder
    private func tab(icon: String, selectedIcon: String? = nil, index: Int) -> some View {
        let isSelected = selectedTab == index
        VStack(spacing: 4) {
            Button {
                selectedTab = index
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: isSelected ? (selectedIcon ?? icon) : icon)
                    .symbolRenderingMode(.monochrome)
                    .renderingMode(.template)
                    .font(.system(size: iconSize, weight: .regular))
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(theme.currentAccentFill)
                        : AnyShapeStyle(Color.white.opacity(0.72))
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.9), value: isSelected)
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier("toolbar_tab_\(index)")
    }

    @ViewBuilder
    private func centerOrb() -> some View {
        let isSelected = selectedTab == 2
        VStack(spacing: 4) {
            Button {
                selectedTab = 2
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .fill(theme.currentAccentFill.opacity(0.28))
                        .frame(width: 34, height: 34)
                        .shadow(radius: 12)
                    Circle()
                        .fill(theme.currentAccentFill)
                        .frame(width: 24, height: 24)
                        .shadow(radius: 6)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onAppear { pulse = true }
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier("toolbar_center_orb")
    }
}

// MARK: - Preview
struct ToolBar_Previews: PreviewProvider {
    @State static var selectedTab = 2
    static var previews: some View {
        ZStack {
            // Simulate host background
            PD.ColorToken.background.ignoresSafeArea()
            VStack { Spacer() }
                .safeAreaInset(edge: .bottom) {
                    ToolBar(selectedTab: $selectedTab)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Tool Bar — docked, minimal")
        .environmentObject(ThemeManager.shared)
    }
}

// MARK: - UIKit-backed dense blur (captures real background)
struct BackdropBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
