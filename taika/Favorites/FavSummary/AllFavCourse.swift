import SwiftUI

private typealias T = PD

// общий лэйаут, синхронизирован с AllFavCards
private enum FavGridCourses {
    static let rowSpacing: CGFloat = 12
    static let colSpacing: CGFloat = 0
    static let verticalPadding: CGFloat = 0
    static let contentMargin: CGFloat = PD.Spacing.screen
    static let cardWidth: CGFloat = 280 // подогнано под визуал курса; при необходимости скорректируем
}

struct AllFavCourseView: View {
    let courses: [FDCourseDTO]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            T.ColorToken.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Section title
                LSSectionTitle("курсы")
                    .padding(.horizontal, FavGridCourses.contentMargin)
                    .padding(.top, 6)

                // Content
                ScrollView {
                    if courses.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(T.ColorToken.textSecondary.opacity(0.65))
                            Text("Нет избранных курсов")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(T.ColorToken.textSecondary.opacity(0.85))
                            Text("Добавьте курсы в избранное — они появятся здесь.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(T.ColorToken.textSecondary.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .padding(.bottom, ToolBar.recommendedBottomInset)
                    } else {
                        VStack(spacing: FavGridCourses.rowSpacing) {
                            ForEach(Array(rowsByDiagonal.enumerated()), id: \.offset) { idx, group in
                                let dir: AutoScrollDirection = (idx % 2 == 0) ? .right : .left
                                InfiniteCourseRowView(items: group, direction: dir)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, ToolBar.recommendedBottomInset)
                    }
                }
                .padding(.horizontal, FavGridCourses.contentMargin)
                .safeAreaPadding(.top, 56)
            }
        }
        .safeAreaInset(edge: .top) {
            AppBackHeader { dismiss() }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: layout helper — диагональные ряды как в AllFavCards
    private var rowsByDiagonal: [[FDCourseDTO]] {
        let maxRows = max(2, min(4, max(1, courses.count / 2))) // 2–4 рядов в зависимости от объёма
        var rows: [[FDCourseDTO]] = Array(repeating: [], count: maxRows)
        for (i, item) in courses.enumerated() {
            rows[i % maxRows].append(item)
        }
        return rows
    }
}

// MARK: - авто-карусель ряда (курсы)
private enum AutoScrollDirection { case left, right }

private struct InfiniteCourseRowView: View {
    var items: [FDCourseDTO]
    var spacing: CGFloat = FavGridCourses.colSpacing
    var direction: AutoScrollDirection = .right

    private let hGutter: CGFloat = 0
    private let cardW: CGFloat = FavGridCourses.cardWidth

    @State private var offsetX: CGFloat = 0
    @State private var initialized: Bool = false
    @State private var isPaused: Bool = false
    @State private var resumeTask: DispatchWorkItem? = nil
    @State private var dragDX: CGFloat = 0

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
        let n = max(items.count, 1)
        let unit = cardW + spacing
        let segmentWidth = unit * CGFloat(n)

        ZStack { // container
            // triple feed to guarantee seamless wrapping
            HStack(spacing: spacing) {
                ForEach(0..<(n * 3), id: \.self) { i in
                    let dto = items[n > 0 ? (i % n) : 0]
                    FDFavCourseCard(
                        item: dto,
                        onOpen: { },
                        onUnfavorite: { }
                    )
                    .frame(width: cardW)
                }
            }
            .offset(x: offsetX + dragDX)
            .padding(.vertical, FavGridCourses.verticalPadding)
            .onAppear {
                if !initialized {
                    offsetX = -segmentWidth // start centered on the middle segment
                    initialized = true
                }
            }
            .onReceive(ticker) { _ in
                guard !isPaused, n > 1 else { return }
                let step: CGFloat = speed / 60.0 * (direction == .right ? 1 : -1)
                offsetX += step
                normalizeOffset(segmentWidth: segmentWidth)
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isPaused = true
                        dragDX = value.translation.width
                    }
                    .onEnded { value in
                        offsetX += value.translation.width
                        dragDX = 0
                        normalizeOffset(segmentWidth: segmentWidth)
                        pauseAuto(for: 2.0)
                    }
            )
        }
        .clipped()
        .padding(.horizontal, hGutter)
    }

    private func normalizeOffset(segmentWidth: CGFloat) {
        // keep offset in the middle segment [-2W, 0], so the ends never show gaps
        if direction == .right {
            if offsetX >= 0 { offsetX -= segmentWidth }
            if offsetX < -2 * segmentWidth { offsetX += segmentWidth }
        } else { // left
            if offsetX <= -2 * segmentWidth { offsetX += segmentWidth }
            if offsetX > 0 { offsetX -= segmentWidth }
        }
    }

    // NOTE: kept for reference; not used by the new seamless triple-feed implementation
    private func buildFeed(items: [FDCourseDTO], repeatCount: Int) -> [FDCourseDTO] {
        guard !items.isEmpty else { return [] }
        if items.count == 1 {
            // single item: just repeat it (auto-scroll visually stable, no adjacency issue)
            return Array(repeating: items[0], count: max(1, repeatCount))
        }
        let n = items.count
        var result: [FDCourseDTO] = []
        // Build repeated segments with rotation so boundaries don't duplicate the same item
        for r in 0..<max(1, repeatCount) {
            let shift = r % n
            for j in 0..<n {
                result.append(items[(j + shift) % n])
            }
        }
        return result
    }
}

#Preview {
    NavigationView {
        AllFavCourseView(courses: [])
    }
}
