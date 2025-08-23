//
//  ToolBar.swift
//  taika
//
//  Taika custom 5-tab glass toolbar with a glowing center action.
//

import SwiftUI

struct ToolBar: View {
    @Binding var selectedTab: Int   // 0...4

    private let barHeight: CGFloat = 84
    private let itemSize: CGFloat = 28
    private let centerSize: CGFloat = 56

    var body: some View {
        ZStack {
            // Glassy rounded container
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.32))
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .frame(height: barHeight)
                .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)

            HStack(spacing: 26) {
                barItem(icon: "hands.clap", selectedIcon: "hands.clap.fill", index: 0)
                barItem(icon: "graduationcap", index: 1)

                // Center action — larger, glowing
                Button {
                    selectedTab = 2
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(hue: 0.74, saturation: 0.55, brightness: 0.95), Color(hue: 0.74, saturation: 0.45, brightness: 0.80)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: centerSize, height: centerSize)
                            .shadow(color: Color(hue: 0.74, saturation: 0.55, brightness: 0.95).opacity(0.7), radius: 18, x: 0, y: 8)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                barItem(icon: "heart", selectedIcon: "heart.fill", index: 3)
                barItem(icon: "face.smiling", index: 4)
            }
            .padding(.horizontal, 22)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func barItem(icon: String, selectedIcon: String? = nil, index: Int) -> some View {
        Button {
            selectedTab = index
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            Image(systemName: (selectedTab == index ? (selectedIcon ?? icon) : icon))
                .font(.system(size: itemSize, weight: .regular))
                .frame(width: 48, height: 48)
                .foregroundStyle(selectedTab == index ? .white : Color.white.opacity(0.55))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selectedTab == index ? Color.white.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(selectedTab == index ? 0.12 : 0.0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ToolBar_Previews: PreviewProvider {
    @State static var selectedTab = 2
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack { Spacer(); ToolBar(selectedTab: $selectedTab) }
        }
        .preferredColorScheme(.dark)
    }
}
