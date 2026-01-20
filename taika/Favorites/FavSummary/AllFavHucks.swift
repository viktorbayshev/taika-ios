//
//  AllFavHucks.swift
//  taika
//
//  Created by product on 16.09.2025.
//

import SwiftUI

private typealias T = PD

// общий лэйаут — синхронизация с all fav cards/courses
private enum FavGridHacks {
    static let rowSpacing: CGFloat = 12
    static let colSpacing: CGFloat = 12
    static let verticalPadding: CGFloat = 0
    static let contentMargin: CGFloat = PD.Spacing.screen
    static let cardWidth: CGFloat = 240   // ширина мини-хака; при необходимости подгоним
}

struct AllFavHucksView: View {
    @Environment(\.dismiss) private var dismiss
    let hacks: [FDHackDTO]

    var body: some View {
        ZStack(alignment: .bottom) {
            T.ColorToken.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky custom back header
                AppBackHeader { dismiss() }

                // Section header
                HStack {
                    Text("Лайфхаки")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, FavGridHacks.contentMargin)
                .padding(.top, 12)

                // Content
                ScrollView {
                    VStack(spacing: FavGridHacks.rowSpacing) {
                        ForEach(Array(rowsByDiagonal.enumerated()), id: \.offset) { idx, group in
                            let dir: AutoScrollDirection = (idx % 2 == 0) ? .right : .left
                            InfiniteHackRowView(items: group, direction: dir)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, ToolBar.recommendedBottomInset)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: раскладка по диагональным рядам (как в AllFavCards)
    private var rowsByDiagonal: [[FDHackDTO]] {
        let maxRows = max(2, min(4, max(1, hacks.count / 2))) // 2–4 рядов динамически
        var rows: [[FDHackDTO]] = Array(repeating: [], count: maxRows)
        for (i, item) in hacks.enumerated() {
            rows[i % maxRows].append(item)
        }
        return rows
    }
}

// MARK: - авто-карусель ряда лайфхаков
private enum AutoScrollDirection { case left, right }

private struct InfiniteHackRowView: View {
    var items: [FDHackDTO]
    var spacing: CGFloat = FavGridHacks.colSpacing
    var direction: AutoScrollDirection = .right

    private let hGutter: CGFloat = FavGridHacks.contentMargin
    private let cardW: CGFloat = FavGridHacks.cardWidth

    @State private var offsetX: CGFloat = 0
    @State private var initialized: Bool = false
    @State private var isPaused: Bool = false
    @State private var resumeTask: DispatchWorkItem? = nil

    private func pauseAuto(for seconds: Double = 3.0) {
        isPaused = true
        resumeTask?.cancel()
        let task = DispatchWorkItem {
            isPaused = false
        }
        resumeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }

    private let speed: CGFloat = 20 // pts/sec
    private let ticker = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            let baseCount = max(items.count, 1)
            let segmentWidth = (cardW * CGFloat(baseCount)) + (spacing * CGFloat(max(baseCount-1 , 0)))
            let viewport = UIScreen.main.bounds.width - (hGutter * 2)
            let reps = max(3, Int(ceil((viewport / max(segmentWidth, 1)) + 2)))
            let feed = buildFeed(items: items, repeatCount: reps)

            LazyHStack(spacing: spacing) {
                ForEach(Array(feed.enumerated()), id: \.offset) { _, dto in
                    FDMiniHackCard(
                        item: dto,
                        onOpen: nil,
                        onUnfavorite: { },
                        isEditing: .constant(false)
                    )
                    .frame(width: cardW)
                    .clipped(antialiased: false)
                }
            }
            .offset(x: offsetX)
            .scrollTargetLayout()
            .padding(.leading, hGutter)
            .padding(.trailing, hGutter)
            .padding(.vertical, FavGridHacks.verticalPadding)
            .onAppear {
                if !initialized {
                    offsetX = -segmentWidth // старт из центрального сегмента
                    initialized = true
                }
            }
            .onReceive(ticker) { _ in
                guard !isPaused, baseCount > 1 else { return }
                let step: CGFloat = speed / 60.0 * (direction == .right ? 1 : -1)
                var next = offsetX + step
                if direction == .right {
                    if next >= 0 { next -= segmentWidth }
                } else {
                    if next <= -2 * segmentWidth { next += segmentWidth }
                }
                offsetX = next
            }
        }
        .scrollDisabled(false)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in pauseAuto(for: 3) }
                .onEnded { _ in pauseAuto(for: 3) }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded { pauseAuto(for: 3) }
        )
        .scrollTargetBehavior(.viewAligned)
    }

    private func buildFeed(items: [FDHackDTO], repeatCount: Int) -> [FDHackDTO] {
        guard !items.isEmpty else { return [] }
        return Array(repeating: items, count: max(1, repeatCount)).flatMap { $0 }
    }
}

#Preview {
    NavigationView {
        AllFavHucksView(hacks: [])
    }
}
