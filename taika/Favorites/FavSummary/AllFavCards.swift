//
//  AllFavCards.swift
//  taika
//
//  Created by product on 16.09.2025.
//

//
//  AllFavCards.swift
//  taika
//
//  full-screen "all favorites" cards page
//  layout: appDS header → bidirectional grid (rubik-like pan) → safe bottom inset
//  NOTE: card view is a drop-in placeholder — swap to FDMiniCardV(model: ...) where marked

import SwiftUI

private typealias T = PD

private enum FavGrid {
    static let rowSpacing: CGFloat = 12   // unified spacing between rows and columns
    static let colSpacing: CGFloat = 0  // exactly match row spacing for identical gaps
    static let verticalPadding: CGFloat = 0  // remove extra vertical padding inside rows
    static let contentMargin: CGFloat = 12   // consistent horizontal content margins
    static let cardWidth: CGFloat = 280      // align to FavoriteDS mini-card width
}

// TEMP: central brand gradient alias (matches app identity)
private let TaikaAccentGradient = LinearGradient(
    gradient: Gradient(colors: [
        Color(red: 0.98, green: 0.52, blue: 0.80), // #FA85CC
        Color(red: 0.91, green: 0.62, blue: 0.98)  // #E89EFA
    ]),
    startPoint: .leading,
    endPoint: .trailing
)

private let favManager = FavoriteManager.shared

private struct AppToolbarWrapper<Content: View, TopBar: View, BackBar: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var topBar: () -> TopBar
    @ViewBuilder var backBar: () -> BackBar

    var body: some View {
        ZStack {
            T.ColorToken.background.ignoresSafeArea()
            content()
        }
        // top filters / controls (first bar)
        .safeAreaInset(edge: .top) {
            topBar()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(T.ColorToken.background)
                .overlay(Divider().opacity(0.08), alignment: .bottom)
        }
        // back nav (second bar stacked above)
        .safeAreaInset(edge: .top) {
            backBar()
        }
    }
}

struct AllFavCardsView: View {
    @State private var cards: [FDCardDTO] = []
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CardTypeFilter = .all

    private var displayedCards: [FDCardDTO] {
        switch selectedType {
        case .all:
            return cards
        case .word, .phrase, .informal:
            return cards.filter { $0.matches(selectedType) }
        }
    }

    /// Cantor diagonal mapping: index = T(r+c) + r, T(n)=n(n+1)/2
    private func cantorIndex(row r: Int, col c: Int) -> Int {
        let s = r + c
        return (s * (s + 1)) / 2 + r
    }

    private func rowSlice(_ r: Int, from items: [FDCardDTO]) -> [FDCardDTO] {
        guard !items.isEmpty else { return [] }
        var result: [FDCardDTO] = []
        var c = 0
        while true {
            let idx = cantorIndex(row: r, col: c)
            if idx >= items.count { break }
            result.append(items[idx])
            c += 1
        }
        return result
    }

    private var rowsByDiagonal: [[FDCardDTO]] {
        var rows: [[FDCardDTO]] = []
        var r = 0
        while true {
            let slice = rowSlice(r, from: displayedCards)
            if slice.isEmpty { break }
            rows.append(slice)
            r += 1
        }
        return rows
    }
    
    private func resolve(_ items: [FavoriteItem]) {
        let r = FavoriteData.shared.resolve(items)
        self.cards = r.cards
    }

    var body: some View {
        AppToolbarWrapper {
            ScrollView {
                VStack(spacing: FavGrid.rowSpacing) {
                    ForEach(Array(rowsByDiagonal.enumerated()), id: \.offset) { idx, group in
                        // чётные ряды: слева→вправо, нечётные: справа→влево
                        let dir: AutoScrollDirection = (idx % 2 == 0) ? .right : .left
                        InfiniteRowView(items: group, direction: dir)
                    }
                }
                .padding(.bottom, ToolBar.recommendedBottomInset)
            }
        } topBar: {
            HStack(spacing: 12) {
                CardsFiltersBar(selected: $selectedType)
                Spacer()
            }
        } backBar: {
            AppBackHeader {
                dismiss()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { DispatchQueue.main.async { resolve(favManager.items) } }
        .onReceive(favManager.$items) { items in
            DispatchQueue.main.async { resolve(items) }
        }
    }
}


private struct CardsFiltersBar: View {
    @Binding var selected: CardTypeFilter
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardTypeFilter.allCases) { f in
                    let isActive = (selected == f)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { selected = f }
                    }) {
                        HStack(spacing: 6) {
                            // optional icon mapping if needed in future
                            Text(f.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isActive ? AnyShapeStyle(CD.GradientToken.pro) : AnyShapeStyle(Color.white.opacity(0.10)))
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(isActive ? 0.00 : 0.12), lineWidth: 1)
                        )
                        .foregroundStyle(isActive ? Color.black.opacity(0.9) : Color.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - filter enum
private enum CardTypeFilter: String, CaseIterable, Identifiable {
    case all = "все"
    case word = "слово"
    case phrase = "фраза"
    case informal = "неформально"
    var id: String { rawValue }
}

private enum AutoScrollDirection { case left, right }

// MARK: - filtering helper (robust to different DTO field names)
private enum CardKind { case word, phrase, informal, unknown }

private extension FDCardDTO {
    func matches(_ filter: CardTypeFilter) -> Bool {
        switch filter {
        case .all: return true
        case .word: return inferredKind() == .word
        case .phrase: return inferredKind() == .phrase
        case .informal: return inferredKind() == .informal
        }
    }

    func inferredKind() -> CardKind {
        // try common string fields first
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            let label = child.label?.lowercased() ?? ""
            if label == "type" || label == "kind" || label == "category" || label == "tag" || label == "group" {
                if let s = child.value as? String {
                    let v = s.lowercased()
                    if v.contains("word") || v == "слово" { return .word }
                    if v.contains("phrase") || v == "фраза" { return .phrase }
                    if v.contains("informal") || v == "неформально" || v == "slang" { return .informal }
                }
            }
            // try boolean flags
            if label == "isword", let b = child.value as? Bool, b { return .word }
            if label == "isphrase", let b = child.value as? Bool, b { return .phrase }
            if label == "isinformal" || label == "isslang", let b = child.value as? Bool, b { return .informal }
        }
        return .unknown
    }
}

// MARK: - card cell (swap to FDMiniCardV)
// Removed AllFavCardCellDTO as unused

private struct InfiniteRowView: View {
    var items: [FDCardDTO] // expected up to 5 items
    var spacing: CGFloat = FavGrid.colSpacing
    var direction: AutoScrollDirection = .right

    private let hGutter: CGFloat = FavGrid.contentMargin
    private let cardW: CGFloat = FavGrid.cardWidth

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(items, id: \.sourceId) { dto in
                    FDMiniCardV(
                        item: dto,
                        isEditing: .constant(false)
                    )
                    .frame(width: cardW)
                }
            }
            .padding(.horizontal, hGutter)
            .padding(.vertical, FavGrid.verticalPadding)
        }
    }

    private func buildFeed(items: [FDCardDTO], repeatCount: Int) -> [FDCardDTO] {
        guard !items.isEmpty, repeatCount > 0 else { return [] }
        var out: [FDCardDTO] = []
        out.reserveCapacity(items.count * repeatCount)
        for _ in 0..<repeatCount { out.append(contentsOf: items) }
        return out
    }
}

#Preview {
    AllFavCardsView()
        .preferredColorScheme(.dark)
}
