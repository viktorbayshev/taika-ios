import SwiftUI

struct PROView: View {
    let courseId: String?
    let onClose: () -> Void

    private struct Benefit: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let systemImage: String
    }

    private let benefits: [Benefit] = [
        .init(title: "планы без лимита", subtitle: "в pro можно запланировать сколько угодно курсов на один день", systemImage: "calendar.badge.plus"),
        .init(title: "умный календарь", subtitle: "планируй наперёд и возвращайся к курсам без потери контекста", systemImage: "sparkles"),
        .init(title: "прогресс и мотивация", subtitle: "видишь, где ты молодец, и где план проспан — без боли и путаницы", systemImage: "chart.line.uptrend.xyaxis"),
        .init(title: "поддержка проекта", subtitle: "pro помогает нам быстрее пилить taika и делать его красивее", systemImage: "heart.fill")
    ]

    @State private var page: Int = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 14) {
                header

                TabView(selection: $page) {
                    ForEach(Array(benefits.enumerated()), id: \ .offset) { idx, item in
                        benefitCard(item)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 210)

                ctaRow
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 22, y: 10)
            .frame(maxWidth: 420)
            .padding(.horizontal, 16)
            .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("pro")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))

            Spacer(minLength: 12)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func benefitCard(_ item: Benefit) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))

                Spacer(minLength: 0)
            }

            Text(item.subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.12))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 2)
    }

    private var ctaRow: some View {
        HStack(spacing: 10) {
            Button {
                NotificationCenter.default.post(
                    name: Notification.Name("OpenProPurchaseRequested"),
                    object: nil,
                    userInfo: ["courseId": courseId ?? ""]
                )
                onClose()
            } label: {
                Text("перейти на pro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ThemeManager.shared.currentAccentFill)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Text("позже")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.18))
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        PROView(courseId: "course_test") {}
    }
}
