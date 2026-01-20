//
//  FavoriteDS.swift (simplified)
//

import SwiftUI
import Combine
import UIKit
import UniformTypeIdentifiers


#if canImport(AppDS)
import AppDS
public typealias FDAppFilterItem = AppFilterItem
public typealias FDAppFiltersBar = AppFiltersBar
#else
// Fallback (when AppDS module is not linked in the current target)
public struct FDAppFilterItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let isSelected: Bool
    public let onTap: () -> Void

    public init(
        id: String,
        title: String,
        systemImage: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.onTap = onTap
    }
}

public struct FDAppFiltersBar: View {
    public let items: [FDAppFilterItem]

    public init(items: [FDAppFilterItem]) {
        self.items = items
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            item.onTap()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                item.isSelected
                                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                : AnyShapeStyle(Color.white.opacity(0.10))
                            )
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(item.isSelected ? 0.00 : 0.12), lineWidth: 1)
                        )
                        .foregroundStyle(item.isSelected ? Color.black.opacity(0.9) : Color.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
            }
        }
    }
}
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif


// MARK: - Data

enum FDK: String, CaseIterable, Identifiable {
    case all = "Все"
    case courses = "Курсы"
    case hacks = "Лайфхаки"
    case cards = "Карточки"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "star"
        case .courses: return "graduationcap"
        case .hacks: return "lightbulb"
        case .cards: return "rectangle.on.rectangle"
        }
    }
}

struct FDFavItem: Identifiable {
    let id = UUID()
    let sourceId: String   // FavoriteItem.id from FavoriteManager
    let kind: FDK
    let title: String
    let subtitle: String
    let meta: String       // e.g. "7 мин • 6 уроков" / "урок 2 из 6 • ~7 мин" / "карточек: 12"
    let lessonTitle: String?   // <— НОВОЕ
    let tagText: String?       // <— НОВОЕ
    let isPro: Bool
    let addedAt: Date
}


// MARK: - Reusable views


struct FDSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PD.Spacing.screen)
    }
}

struct FDSectionHeaderBar: View {
    let title: String
    var count: Int? = nil
    var onShowAll: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .kerning(0.8)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onShowAll?()
            }) {
                HStack(spacing: 6) {
                    Text(count != nil ? "Показать все (\(count!))" : "Показать все")
                        .font(.caption2.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                // цвет текста — фирменный градиент, без подложки
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
            }
            .buttonStyle(.plain) // без системной подложки
            .contentShape(Capsule()) // большая зона тапа
        }
        .padding(.horizontal, PD.Spacing.screen)
    }
}

struct FDChipPill: View {
    let title: String
    let isOn: Bool
    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isOn ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.10)))
            )
            .foregroundStyle(isOn ? Color.black.opacity(0.9) : Color.white.opacity(0.85))
    }
}

enum FDChipSize { case regular, large }

struct FDFiltersBar: View {
    @Binding var selected: FDK
    var size: FDChipSize = .regular
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FDK.allCases) { kind in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { selected = kind }
                    }) {
                        let hPad: CGFloat = (size == .large) ? 16 : 12
                        let vPad: CGFloat = (size == .large) ? 8 : 6
                        let iconSize: CGFloat = (size == .large) ? 14 : 12
                        let titleFont: Font = (size == .large) ? .callout.weight(.semibold) : .subheadline.weight(.semibold)

                        HStack(spacing: 6) {
                            Image(systemName: kind.icon)
                                .font(.system(size: iconSize, weight: .semibold))
                            Text(kind.rawValue)
                                .font(titleFont)
                        }
                        .padding(.horizontal, hPad)
                        .padding(.vertical, vPad)
                        .background(
                            Capsule().fill(kind == selected ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.10)))
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(kind == selected ? 0.00 : 0.12), lineWidth: 1)
                        )
                        .foregroundStyle(kind == selected ? Color.black.opacity(0.9) : Color.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
            }
            .padding(.horizontal, PD.Spacing.screen)
        }
    }
}

struct FDSearchField: View {
    @Binding var query: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField("Поиск в избранном", text: $query)
                .textInputAutocapitalization(.never)
        }
        .font(.body)
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    .clear,
                                    .black.opacity(0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, PD.Spacing.screen)
    }
}

struct FDFavRow: View {
    let item: FDFavItem

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PD.ColorToken.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), .clear, .black.opacity(0.10)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                Image(systemName: item.kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isPro {
                        Text("PRO")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(PD.ColorToken.accent)
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !item.meta.isEmpty {
                    Text(item.meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, PD.Spacing.screen)
        .padding(.vertical, 12)
        .background(
            round.fill(PD.ColorToken.card)
                .overlay(
                    round.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), .clear, .black.opacity(0.10)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                )
        )
        .overlay(round.stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}


// MARK: - Mini card for favorites (compact)
struct FDMiniCardV: View {
    let item: FDCardDTO
    var onSpeak: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Binding var isEditing: Bool
    @State private var isJiggling = false
    private var cleanMeta: String {
        if item.meta.hasPrefix("card:") { return String(item.meta.dropFirst("card:".count)) }
        return item.meta
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            Text("taikA")
                .font(Font.custom("ONMARK Trial", size: 14))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
        }
    }

    private var centerBlock: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(item.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            if !cleanMeta.isEmpty {
                Text(cleanMeta)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }

            Text(item.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomBar: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSpeak?()
            }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(PD.ColorToken.card)
                            .overlay(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.06),
                                            .clear,
                                            .black.opacity(0.10)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            )
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            Spacer(minLength: 10)
            if !item.lessonTitle.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(item.lessonTitle)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .allowsHitTesting(false) // badge only, не кликается (удаление через long‑press)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func deleteButtonOverlay(_ round: RoundedRectangle) -> some View {
        Group {
            if isEditing {
                Button(action: { onDelete?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.95))
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }
                .buttonStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)),
                        removal: .opacity
                    )
                )
            }
        }
    }

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            topRow
            Spacer(minLength: 0)
            centerBlock
            Spacer(minLength: 0)
            bottomBar
        }
        .padding(16)
        .frame(width: 268, height: 196, alignment: .topLeading)
        .background(
            Theme.Surfaces.card(round)
        )
        .overlay(deleteButtonOverlay(round))
        .rotationEffect(isJiggling ? .degrees(2) : .degrees(0), anchor: .center)
        .animation(
            isEditing
            ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
            : .default,
            value: isJiggling
        )
        .contentShape(round)
        .onTapGesture {
            if isEditing {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isEditing = false
                }
            } else {
                onOpen?()
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) {
                isEditing.toggle()
            }
        }
        .onChange(of: isEditing) { newValue in
            withAnimation(.easeInOut(duration: 0.15)) {
                isJiggling = newValue
            }
        }
    }
}

// MARK: - Mini lifehack card (text-first)
struct FDMiniHackCard: View {
    let item: FDHackDTO
    var onOpen: (() -> Void)? = nil
    var onUnfavorite: (() -> Void)? = nil
    @Binding var isEditing: Bool
    @State private var isJiggling: Bool = false

    @ViewBuilder
    private func deleteButtonOverlay(_ round: RoundedRectangle) -> some View {
        Group {
            if isEditing {
                Button(action: { onUnfavorite?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.95))
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }
                .buttonStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)),
                        removal: .opacity
                    )
                )
            }
        }
    }

    var body: some View {
        // prefer body text passed via `meta`; fallback to `title`. Strip possible "hack:" prefix.
        let raw0 = item.meta.isEmpty ? item.title : item.meta
        let raw1 = raw0.hasPrefix("hack:") ? String(raw0.dropFirst("hack:".count)) : raw0
        let hackText: String = raw1.trimmingCharacters(in: .whitespacesAndNewlines)
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)

        VStack(alignment: .leading, spacing: 14) {
            // brand
            Text("taikA")
                .font(Font.custom("ONMARK Trial", size: 14))
                .foregroundStyle(.secondary)

            // push content to vertical center between brand and bottom bar
            Spacer(minLength: 0)

            // main text — строго тело лайфхака
            VStack(alignment: .center, spacing: 8) {
                Text(hackText)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 6)

            // bottom: heart pill with lesson title (открывает лайфхак, не удаляет)
            HStack {
                Spacer(minLength: 10)
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onOpen?() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill").font(.system(size: 13, weight: .semibold))
                        if !item.lessonTitle.isEmpty {
                            Text(item.lessonTitle)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .frame(width: 200, height: 286, alignment: .topLeading)
        .background(
            Theme.Surfaces.card(round)
        )
        .overlay(deleteButtonOverlay(round))
        .rotationEffect(isJiggling ? .degrees(2) : .degrees(0), anchor: .center)
        .animation(
            isEditing
            ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
            : .default,
            value: isJiggling
        )
        .contentShape(round)
        .onTapGesture {
            if isEditing {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isEditing = false
                }
            } else {
                onOpen?()
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) {
                isEditing.toggle()
            }
        }
        .onChange(of: isEditing) { newValue in
            withAnimation(.easeInOut(duration: 0.15)) {
                isJiggling = newValue
            }
        }
    }
}

// MARK: - Compact course card
struct FDFavCourseCard: View {
    let item: FDCourseDTO
    var onOpen: (() -> Void)? = nil
    var onUnfavorite: (() -> Void)? = nil

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            // top row: brand + pro badge
            HStack(spacing: 8) {
                Text("taikA")
                    .font(Font.custom("ONMARK Trial", size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
                // No isPro in DTO for now
            }

            // centered title & meta block
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle) // here we will pass "карточек: N • ~M мин" from FavoriteData
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)

            HStack {
                Button(action: { onOpen?() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 13, weight: .semibold))
                        Text("Открыть").font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                Spacer(minLength: 10)
                Button(action: { onUnfavorite?() }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .frame(width: 268, height: 196, alignment: .topLeading)
        .background(
            Theme.Surfaces.card(round)
        )
        .contentShape(round)
    }
}

// MARK: - Horizontal reel for courses
struct FDFavCoursesReel: View {
    let title: String
    let items: [FDCourseDTO]
    var onOpen: ((FDCourseDTO) -> Void)? = nil
    var onUnfavorite: ((FDCourseDTO) -> Void)? = nil
    var onShowAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FDSectionHeaderBar(title: title, count: items.count, onShowAll: { onShowAll?() })

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("добавьте курс в избранное")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = 268
                    let cardHeight: CGFloat = 196
                    let spacing: CGFloat = 14
                    let sideInset: CGFloat = PD.Spacing.screen

                    let reelItems: [FDCourseDTO] = {
                        guard !items.isEmpty else { return [] }
                        return items + items + items
                    }()
                    let centerIndex = items.count

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: spacing) {
                                ForEach(reelItems.indices, id: \.self) { idx in
                                    let it = reelItems[idx]
                                    GeometryReader { itemGeo in
                                        let midX = itemGeo.frame(in: .global).midX
                                        let containerMidX = geo.frame(in: .global).midX
                                        let distance = abs(midX - containerMidX)
                                        let maxDistance = cardWidth + spacing
                                        let t = min(distance / maxDistance, 1)
                                        let scale: CGFloat = 0.9 + (1 - t) * 0.12
                                        let opacity: Double = 0.45 + (1 - t) * 0.55
                                        let yOffset: CGFloat = t * 18

                                        FDFavCourseCard(
                                            item: it,
                                            onOpen: { onOpen?(it) },
                                            onUnfavorite: { onUnfavorite?(it) }
                                        )
                                        .scaleEffect(scale)
                                        .opacity(opacity)
                                        .offset(y: yOffset)
                                    }
                                    .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                            .padding(.horizontal, sideInset)
                            .padding(.vertical, 4)
                            .frame(height: cardHeight + 36)
                        }
                        .onAppear {
                            if !reelItems.isEmpty {
                                proxy.scrollTo(centerIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 196 + 36)
            }
        }
    }
}

// MARK: - Horizontal reel for lifehacks
struct FDFavHacksReel: View {
    let title: String
    let items: [FDHackDTO]
    @Binding var isEditing: Bool
    var onUnfavorite: ((FDHackDTO) -> Void)? = nil
    var onOpen: ((FDHackDTO) -> Void)? = nil
    var onShowAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FDSectionHeaderBar(title: title, count: items.count, onShowAll: { onShowAll?() })

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("здесь появятся ваши лайфхаки")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = 200
                    let cardHeight: CGFloat = 286
                    let spacing: CGFloat = 14
                    let sideInset: CGFloat = PD.Spacing.screen

                    let reelItems: [FDHackDTO] = {
                        guard !items.isEmpty else { return [] }
                        return items + items + items
                    }()
                    let centerIndex = items.count

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: spacing) {
                                ForEach(reelItems.indices, id: \.self) { idx in
                                    let it = reelItems[idx]
                                    GeometryReader { itemGeo in
                                        let midX = itemGeo.frame(in: .global).midX
                                        let containerMidX = geo.frame(in: .global).midX
                                        let distance = abs(midX - containerMidX)
                                        let maxDistance = cardWidth + spacing
                                        let t = min(distance / maxDistance, 1)
                                        let scale: CGFloat = 0.9 + (1 - t) * 0.12
                                        let opacity: Double = 0.45 + (1 - t) * 0.55
                                        let yOffset: CGFloat = t * 18

                                        FDMiniHackCard(
                                            item: it,
                                            onOpen: { onOpen?(it) },
                                            onUnfavorite: { onUnfavorite?(it) },
                                            isEditing: $isEditing
                                        )
                                        .scaleEffect(scale)
                                        .opacity(opacity)
                                        .offset(y: yOffset)
                                    }
                                    .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                            .padding(.horizontal, sideInset)
                            .padding(.vertical, 4)
                            .frame(height: cardHeight + 36)
                        }
                        .onAppear {
                            if !reelItems.isEmpty {
                                proxy.scrollTo(centerIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 286 + 36)
            }
        }
    }
}

// MARK: - Horizontal reels section for favorites
struct FDFavReels: View {
    let title: String
    let items: [FDCardDTO]
    @Binding var order: [String]   // sourceId order for reordering
    @Binding var isEditing: Bool
    var onUnfavorite: ((FDCardDTO) -> Void)? = nil
    var onShowAll: (() -> Void)? = nil
    var onOpen: ((FDCardDTO) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FDSectionHeaderBar(title: title, count: items.count, onShowAll: { onShowAll?() })

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("здесь появятся ваши избранные карточки")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = 268
                    let cardHeight: CGFloat = 196
                    let spacing: CGFloat = 14
                    let sideInset: CGFloat = PD.Spacing.screen

                    let reelItems: [FDCardDTO] = {
                        guard !items.isEmpty else { return [] }
                        return items + items + items
                    }()
                    let centerIndex = items.count

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: spacing) {
                                ForEach(reelItems.indices, id: \.self) { idx in
                                    let it = reelItems[idx]
                                    GeometryReader { itemGeo in
                                        let midX = itemGeo.frame(in: .global).midX
                                        let containerMidX = geo.frame(in: .global).midX
                                        let distance = abs(midX - containerMidX)
                                        let maxDistance = cardWidth + spacing
                                        let t = min(distance / maxDistance, 1)
                                        let scale: CGFloat = 0.9 + (1 - t) * 0.12
                                        let opacity: Double = 0.45 + (1 - t) * 0.55
                                        let yOffset: CGFloat = t * 18

                                        FDMiniCardV(
                                            item: it,
                                            onSpeak: {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                StepAudio.shared.speakThai(it.subtitle)
                                            },
                                            onOpen: { onOpen?(it) },
                                            onDelete: { onUnfavorite?(it) },
                                            isEditing: $isEditing
                                        )
                                        .scaleEffect(scale)
                                        .opacity(opacity)
                                        .offset(y: yOffset)
                                    }
                                    .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                            .padding(.horizontal, sideInset)
                            .padding(.vertical, 4)
                            .frame(height: cardHeight + 36)
                        }
                        .onAppear {
                            if !reelItems.isEmpty {
                                proxy.scrollTo(centerIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 196 + 36)
            }
        }
    }
}



// MARK: - Tiny pulsing dots (for pre-roll)
struct FDDotsIndicator: View {
    private let tick: Double = 0.35

    var body: some View {
        TimelineView(.animation) { context in
            // derive phase from current time, no timers
            let t = context.date.timeIntervalSinceReferenceDate / tick
            let phase = Int(floor(t).truncatingRemainder(dividingBy: 3))

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 5, height: 5)
                        .opacity(phase == i ? 1.0 : 0.35)
                        .scaleEffect(phase == i ? 1.0 : 0.85)
                }
            }
            .animation(.easeInOut(duration: tick), value: phase)
        }
    }
}

// MARK: - Typewriter marquee used in "тайка фм"
struct FDTypewriterMarquee: View {
    let messages: [String]
    let typingSpeed: Double = 0.05   // seconds per char
    let pauseBetween: Double = 1.2   // seconds between messages
    let dotsDuration: Double = 1.2   // total time to show animated dots before text
    let dotTick: Double = 0.35       // dot animation tick
    // dynamic hold after the line is fully printed
    let minHold: Double = 2.0   // minimum seconds to display
    let perCharHold: Double = 0.065 // extra seconds per character
    let maxHold: Double = 6.0   // cap so it doesn’t get too long
    private let isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    @State private var messageIndex: Int = 0
    @State private var charCount: Int = 0
    @State private var isPaused: Bool = false
    @State private var showDots: Bool = true
    @State private var dotCount: Int = 1
    @State private var typingTimer: Timer?

    private var current: String { messages.isEmpty ? "" : messages[messageIndex % messages.count] }

    private func holdDuration() -> Double {
        let seconds = minHold + Double(current.count) * perCharHold
        return min(maxHold, seconds)
    }

    var body: some View {
        Group {
            if isPreview {
                // In previews: render one line statically (no timers)
                Text(messages.first ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } else if showDots {
                FDDotsIndicator()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(String(current.prefix(charCount)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { startCycle() }
        .onDisappear { cancelTimers() }
    }

    private func startCycle() {
        if isPreview {
            showDots = false
            charCount = current.count
            return
        }
        cancelTimers()
        showDots = true
        dotCount = 1
        // show dots for the configured duration, then start typing
        DispatchQueue.main.asyncAfter(deadline: .now() + dotsDuration) {
            showDots = false
            startTyping()
        }
    }

    private func startTyping() {
        if isPreview { return }
        guard !messages.isEmpty else { return }
        charCount = 0
        isPaused = false
        typingTimer = Timer.scheduledTimer(withTimeInterval: typingSpeed, repeats: true) { t in
            if charCount < current.count {
                charCount += 1
            } else {
                t.invalidate()
                typingTimer = nil
                // pause dynamically based on text length, then go to next message and start dots again
                let delay = holdDuration()
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    messageIndex = (messageIndex + 1) % max(1, messages.count)
                    startCycle()
                }
            }
        }
    }

    private func cancelTimers() {
        typingTimer?.invalidate(); typingTimer = nil
    }
}

// MARK: - Taika FM section (marquee card)
struct FDTaikaFMSection: View {
    let title: String = "тайка фм"
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FDSectionHeader(title: title)

            HStack(alignment: .center, spacing: 12) {
                // Mascot outside the card
                Image("mascot.favorite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .padding(.leading, PD.Spacing.screen)

                // Card only for text
                let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                FDTypewriterMarquee(messages: messages)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 68, alignment: .leading)
                    .background(
                        round.fill(PD.ColorToken.card)
                            .overlay(
                                round.fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), .clear, .black.opacity(0.10)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                            )
                    )
                    .overlay(round.stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.trailing, PD.Spacing.screen)
            }
        }
    }
}

// MARK: - Screen

public struct FavoriteDS: View {
    // inbound data (already resolved by FavoriteData)
    public let courses: [FDCourseDTO]
    public let cards:   [FDCardDTO]
    public let hacks:   [FDHackDTO]

    @Binding public var isEditing: Bool

    // callbacks to parent view
    public var onUnfavorite: ((String) -> Void)? = nil   // id to remove
    public var onReorder: (([String]) -> Void)? = nil    // ordered ids for cards
    public var onShowAllCards:   (() -> Void)? = nil
    public var onShowAllCourses: (() -> Void)? = nil
    public var onShowAllHacks:   (() -> Void)? = nil
    public var onOpenCard: ((FDCardDTO) -> Void)? = nil
    public var onOpenCourse: ((FDCourseDTO) -> Void)? = nil

    @State private var cardOrder: [String] = []
    @State private var isHacksEditing: Bool = false
    @State private var selectedFilter: FDK = .all

    public init(
        courses: [FDCourseDTO] = [],
        cards: [FDCardDTO] = [],
        hacks: [FDHackDTO] = [],
        isEditing: Binding<Bool> = .constant(false),
        onUnfavorite: ((String) -> Void)? = nil,
        onReorder: (([String]) -> Void)? = nil,
        onShowAllCards:   (() -> Void)? = nil,
        onShowAllCourses: (() -> Void)? = nil,
        onShowAllHacks:   (() -> Void)? = nil,
        onOpenCard: ((FDCardDTO) -> Void)? = nil,
        onOpenCourse: ((FDCourseDTO) -> Void)? = nil
    ) {
        self.courses = courses
        self.cards = cards
        self.hacks = hacks
        self._isEditing = isEditing
        self.onUnfavorite = onUnfavorite
        self.onReorder = onReorder
        self.onShowAllCards = onShowAllCards
        self.onShowAllCourses = onShowAllCourses
        self.onShowAllHacks = onShowAllHacks
        self.onOpenCard = onOpenCard
        self.onOpenCourse = onOpenCourse
    }

    // Split cards into hacks and normal cards based on meta/sourceId prefix
    private var hackCards: [FDCardDTO] {
        cards.filter { $0.meta.hasPrefix("hack:") || $0.sourceId.hasPrefix("hack:") }
    }

    private var normalCards: [FDCardDTO] {
        cards.filter { !$0.meta.hasPrefix("hack:") && !$0.sourceId.hasPrefix("hack:") }
    }

    // Filtered cards for the "карточки" section (excluding hacks)
    private var filtered: [FDCardDTO] {
        if selectedFilter != .all {
            // Favorites currently exposes cards only for this section; leave the filter hook in place for future expansion.
        }
        // 0) Sort newest → first
        let sorted = normalCards.sorted { $0.addedAt > $1.addedAt }

        let scopeSorted: [FDCardDTO] = {
            switch selectedFilter {
            case .all:
                return sorted
            case .cards:
                return sorted
            case .courses, .hacks:
                // Not applicable for this list; return empty to avoid confusing results.
                return []
            }
        }()

        // 1) De-duplicate by sourceId, preserving the NEW (sorted) order
        var seen = Set<String>()
        let deduped = scopeSorted.filter { seen.insert($0.sourceId).inserted }

        // 2) Build a safe dictionary; if duplicates still sneak in, prefer the first (newest)
        let dict: [String: FDCardDTO] = Dictionary(deduped.map { ($0.sourceId, $0) },
                                                   uniquingKeysWith: { (first: FDCardDTO, _ : FDCardDTO) in first })

        // 3) Respect persisted order where possible; then prepend the rest (so new ones go to the front)
        let ordered = cardOrder.compactMap { dict[$0] }
        let orderSet = Set(cardOrder)
        let extras = deduped.filter { !orderSet.contains($0.sourceId) }

        // New cards (extras) first, then the persisted order
        return extras + ordered
    }


    public var body: some View {
        // Prepare hacks section: combine original hacks plus hackCards from cards
        let allHacks: [FDHackDTO] = {
            // Convert hackCards (FDCardDTO) to FDHackDTO for the hacks reel
            let hackCardDTOs: [FDHackDTO] = hackCards.map { card in
                let sid = card.sourceId.hasPrefix("hack:") ? card.sourceId : ("hack:" + card.sourceId)
                return FDHackDTO(
                    sourceId: sid,
                    title: card.title,
                    meta: card.meta,
                    lessonTitle: card.lessonTitle,
                    addedAt: card.addedAt
                )
            }
            let combined = hacks + hackCardDTOs
            var seen = Set<String>()
            return combined.filter { if seen.insert($0.sourceId).inserted { return true } else { return false } }
        }()
        let fmMessages = TaikaFMData.shared.messages(for: .fav)
        let fmReactions = TaikaFMData.shared.reactionGroups(for: .fav)
        ScrollView {
            VStack(spacing: 24) {
                // filters
                FDSectionHeader(title: "фильтры")
                FDAppFiltersBar(
                    items: FDK.allCases.map { kind in
                        FDAppFilterItem(
                            id: kind.id,
                            title: kind.rawValue,
                            systemImage: kind.icon,
                            isSelected: kind == selectedFilter,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedFilter = kind
                                }
                            }
                        )
                    }
                )
                .padding(.horizontal, PD.Spacing.screen)
                VStack(alignment: .leading, spacing: 12) {
                    FDSectionHeader(title: "тайка фм")
                    TaikaFMBubbleTyping(
                        messages: fmMessages,
                        reactions: fmReactions,
                        repeats: false
                    )
                }


                if (selectedFilter == .all || selectedFilter == .cards), !filtered.isEmpty {
                    FDFavReels(
                        title: "карточки",
                        items: filtered,
                        order: $cardOrder,
                        isEditing: $isEditing,
                        onUnfavorite: { onUnfavorite?($0.sourceId) },
                        onShowAll: { onShowAllCards?() },
                        onOpen: { onOpenCard?($0) }
                    )
                }

                if (selectedFilter == .all || selectedFilter == .hacks), !allHacks.isEmpty {
                    FDFavHacksReel(
                        title: "лайфхаки",
                        items: allHacks,
                        isEditing: $isHacksEditing,
                        onUnfavorite: { onUnfavorite?($0.sourceId) },
                        onOpen: { it in
                            let text = it.meta.isEmpty ? it.title : it.meta
                            let clean = text.hasPrefix("hack:") ? String(text.dropFirst("hack:".count)) : text
                            let hackId = it.sourceId.hasPrefix("hack:") ? it.sourceId : ("hack:" + it.sourceId)
                            let dto = FDCardDTO(
                                sourceId: hackId,
                                title: "Лайфхак",
                                subtitle: clean,
                                meta: "hack:" + clean,
                                lessonTitle: it.lessonTitle,
                                tagText: nil,
                                addedAt: it.addedAt
                            )
                            onOpenCard?(dto)
                        },
                        onShowAll: { onShowAllHacks?() }
                    )
                }

                if (selectedFilter == .all || selectedFilter == .courses), !courses.isEmpty {
                    FDFavCoursesReel(
                        title: "курсы",
                        items: courses,
                        onOpen: { onOpenCourse?($0) },
                        onUnfavorite: { c in onUnfavorite?("course:\(c.courseId)") },
                        onShowAll: { onShowAllCourses?() }
                    )
                }
                Spacer(minLength: 8)
            }
            .padding(.top, 16)
            .padding(.vertical, 16)
            .onAppear { syncCardOrder() }
            .onChange(of: cards) { _, _ in syncCardOrder() }
        }
    }

    private func syncCardOrder() {
        // Newest-first ids from normalCards
        let currentIds = normalCards
            .sorted { $0.addedAt > $1.addedAt }
            .reduce(into: [String]()) { arr, item in if !arr.contains(item.sourceId) { arr.append(item.sourceId) } }

        // keep only those ids that still exist and make them unique
        var newOrder: [String] = []
        for id in cardOrder where currentIds.contains(id) {
            if !newOrder.contains(id) { newOrder.append(id) }
        }
        // append missing ids in the currentIds order (already newest-first)
        for id in currentIds where !newOrder.contains(id) {
            newOrder.append(id)
        }
        cardOrder = newOrder
        onReorder?(cardOrder)
    }
}

#Preview {
    struct FavoriteDS_PreviewWrapper: View {
        @State private var isEditing: Bool = false

        var body: some View {
            let sampleCards: [FDCardDTO] = [
                .init(
                    sourceId: "s1",
                    title: "заказ кофе",
                    subtitle: "กาแฟเย็นหนึ่งแก้วครับ",
                    meta: "ка-фае йен нунг гэо кхрап",
                    lessonTitle: "кафе",
                    tagText: "фраза",
                    addedAt: Date()
                ),
                .init(
                    sourceId: "s2",
                    title: "куда едем",
                    subtitle: "ไปที่นี่ได้ไหม",
                    meta: "пай тхии нии дай май?",
                    lessonTitle: "такси",
                    tagText: "фраза",
                    addedAt: Date().addingTimeInterval(-3600)
                )
            ]

            let sampleHacks: [FDHackDTO] = [
                .init(
                    sourceId: "h1",
                    title: "Не перегружай карточку текстом — оставь смысл",
                    meta: "мини-правило UI",
                    lessonTitle: "интерфейс",
                    addedAt: Date()
                )
            ]

            let sampleCourses: [FDCourseDTO] = [
                .init(
                    courseId: "c1",
                    title: "Таиланд: базовые фразы",
                    subtitle: "путешествия и быт",
                    addedAt: Date()
                )
            ]

            return ZStack {
                PD.ColorToken.background.ignoresSafeArea()
                FavoriteDS(
                    courses: sampleCourses,
                    cards: sampleCards,
                    hacks: sampleHacks,
                    isEditing: $isEditing
                )
            }
            .preferredColorScheme(.dark)
        }
    }

    return FavoriteDS_PreviewWrapper()
}
