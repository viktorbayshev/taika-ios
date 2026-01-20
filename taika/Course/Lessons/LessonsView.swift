// MARK: - Window Snapshot Helper
import UIKit

/// Captures a snapshot of the key window, including the status/safe-area region, for use as a full-screen background.
@MainActor
private func captureWindowSnapshot() -> Image? {
    // Only when app is active and we have a valid key window
    guard UIApplication.shared.applicationState == .active,
          let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
          let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
        return nil
    }
    let bounds = window.bounds
    guard bounds.width > 0 && bounds.height > 0 else { return nil }
    let renderer = UIGraphicsImageRenderer(size: bounds.size)
    let uiImage = renderer.image { _ in
        // drawHierarchy faster and with correct blur-ready pixels
        window.drawHierarchy(in: bounds, afterScreenUpdates: false)
    }
    return Image(uiImage: uiImage)
}
// Disables the interactive "swipe back" gesture for this screen
private struct NavSwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}



import SwiftUI

private extension LessonsData {
    func course(withID id: String) -> CourseBundle? {
        allCourses().first { $0.courseID == id }
    }
}


private extension LessonsView {
    var currentCourse: CourseBundle? {
        if let id = courseId {
            return lessonsStore.course(withID: id)
        }
        return lessonsStore.allCourses().first
    }

    var lessonsSorted: [LessonBundle] {
        (currentCourse?.lessons ?? []).sorted { $0.order < $1.order }
    }

    var currentLesson: LessonBundle? {
        if let sel = selectedLessonId, let bySel = lessonsSorted.first(where: { $0.lessonID == sel }) { return bySel }
        if let initial = lessonId, let byInit = lessonsSorted.first(where: { $0.lessonID == initial }) { return byInit }
        return lessonsSorted.first
    }

    var headerTitle: String {
        currentCourse?.courseTitle ?? "Курс: разговорный минимум"
    }

    var headerSubtitle: String {
        // Prefer CourseData description with [[...]] markers if present
        if let cid = currentCourse?.courseID,
           let cd = CourseData.shared.description(for: cid),
           !cd.isEmpty {
            return cd
        }
        // Fallback to lessons.json description
        return currentCourse?.courseDescription ?? ""
    }

    var fmMessages: [String] {
        if let tips = currentLesson?.assistantTips, !tips.isEmpty { return tips }
        return []
    }

    var totalLessonsCount: Int {
        lessonsSorted.count
    }

    var activeLessonIndex: Int {
        let ids = lessonsSorted.map { $0.lessonID }
        // 1) explicit selection wins
        if let sel = selectedLessonId, let i = ids.firstIndex(of: sel) { return i }
        // 2) fallback to last active (persisted)
        if !lastActiveLessonId.isEmpty, let i = ids.firstIndex(of: lastActiveLessonId) { return i }
        // 3) initial deep-link / provided lessonId
        if let initial = lessonId, let i = ids.firstIndex(of: initial) { return i }
        // 4) otherwise first
        return 0
    }

    var headerProgress: (completed: Int, total: Int) {
        let total = totalLessonsCount
        guard let cid = currentCourse?.courseID else { return (0, total) }
        return lessonsManager.headerCounts(for: cid, lessonsTotal: total)
    }

    /// Per-lesson completion percentage array (0...1) for the header slots
    func perLessonPercents() -> [Double] {
        guard let cid = currentCourse?.courseID else { return [] }
        // Build fractions from the same source, lesson-by-lesson.
        // This avoids relying on an optional ProgressManager API and guarantees
        // the header reflects the real state used across the app.
        return lessonsSorted.map { l in
            let p = lessonsManager.lessonProgress(courseId: cid, lessonId: l.lessonID)?.percent ?? 0
            // Clamp to [0,1] just in case
            return max(0, min(1, p))
        }
    }

    // MARK: – Adapters to DS models
    func contentItems() -> [LS.ContentItem] {
        guard let lesson = currentLesson else { return [] }
        var seen = Set<String>()
        return lesson.content.compactMap { block in
            let kind: LS.ContentKind
            switch block.kind {
            case .intro:   kind = .intro
            case .outline: kind = .outline
            case .apply:   kind = .apply
            case .outcome: kind = .outcome
            }
            let key = "\(kind)-\(block.text)"
            if seen.contains(key) {
                return nil
            } else {
                seen.insert(key)
                return LS.ContentItem(kind: kind, text: block.text, imageName: nil)
            }
        }
    }

    /// Resolve DS status for a lesson using LessonsManager, with sensible fallback
    func statusForLesson(_ l: LessonBundle) -> LS.Status {
        guard let cid = currentCourse?.courseID,
              let p = lessonsManager.lessonProgress(courseId: cid, lessonId: l.lessonID) else {
            return .locked
        }
        switch p.status {
        case .completed: return .completed
        case .inProgress: return .inProgress
        case .locked: return l.isFree ? .inProgress : .locked
        }
    }

    func lessonItems() -> [LS.Item] {
        guard let cid = currentCourse?.courseID else { return [] }
        return lessonsSorted.enumerated().map { (i, l) in
            {
                let lp = lessonsManager.lessonProgress(courseId: cid, lessonId: l.lessonID)
                let percent = lp?.percent // Double 0...1 or nil
                return LS.Item(
                    id: l.lessonID,
                    index: i, // zero-based position to match header slots order
                    title: l.title,
                    subtitle: l.subtitle,
                    durationMinutes: l.durationMinutes,
                    isPro: !l.isFree,
                    status: statusForLesson(l),
                    tags: l.tags,
                    progress: percent,
                    cardCount: l.cardCount,
                    favoriteCount: FavoriteManager.shared.countCardsForLesson(courseId: cid, lessonId: l.lessonID)
                )
            }()
        }
    }

    var homeTaskProgress: (done: Int, total: Int) {
        guard let cid = currentCourse?.courseID else { return (0, 0) }
        let p = homeTaskManager.progress(for: cid)
        return (p.done, p.total)
    }

    func hometaskItems() -> [HT.Item] {
        let cid = currentCourse?.courseID ?? ""
        let lessonIDs = lessonsSorted.map { $0.lessonID }

        // 1) Try real tasks from the manager
        let rows: [(task: HTask, locked: Bool, minutes: Int?)] =
            homeTaskManager.hometasksFor(courseId: cid) { t, locked, minutes, _ in
                (t, locked, minutes)
            }
        if !rows.isEmpty {
            return rows.enumerated().map { idx, row in
                HT.Item(
                    id: row.task.id,
                    index: idx,
                    title: row.task.title,
                    subtitle: nil,
                    durationMinutes: row.minutes,
                    isLocked: row.locked
                )
            }
        }

        // 2) No concrete tasks yet → use availability (status + game kind) for richer placeholders
        let annotated = homeTaskManager.availability(
            for: cid,
            lessonIds: lessonIDs,
            rule: .everyNLessons(3),
            samplePerTask: 6,
            minTriples: 6
        )
        if !annotated.isEmpty {
            return annotated.enumerated().map { idx, a in
                let p = a.descriptor
                // rough duration estimate from pool size to avoid empty look
                let est = max(6, min(18, p.triples.count))
                let locked = (a.status == .locked)
                let gameSubtitle = "игра: \(a.game)"
                return HT.Item(
                    id: p.id,
                    index: idx,
                    title: p.title,
                    subtitle: gameSubtitle,
                    durationMinutes: est,
                    isLocked: locked
                )
            }
        }

        // 3) Absolute fallback — structural placeholders by grouping lessons (3 per task) + final
        let total = lessonsSorted.count
        let groupCount = max(1, total > 0 ? Int(ceil(Double(total) / 3.0)) : 1)
        var items: [HT.Item] = []
        for i in 0..<groupCount {
            items.append(
                HT.Item(
                    id: "ht-placeholder-\(i+1)",
                    index: i,
                    title: "Практика #\(i+1)",
                    subtitle: "мини‑игры: пары • викторина • аудио",
                    durationMinutes: 8,
                    isLocked: true
                )
            )
        }
        items.append(
            HT.Item(
                id: "ht-placeholder-final",
                index: groupCount,
                title: "Итоговая практика",
                subtitle: "мини‑игры: пары • викторина • аудио",
                durationMinutes: 10,
                isLocked: true
            )
        )
        return items
    }

}

public struct LessonsView: View {
    // Keep user on the Courses tab while viewing lessons
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lessonsStore = LessonsData.shared
    @ObservedObject private var lessonsManager = LessonsManager.shared
    @StateObject private var homeTaskManager = HomeTaskManager()
    @State private var htVersion = UUID()
    @State private var goHomeTask: Bool = false
    @State private var goToStep: Bool = false
    @State private var selectedLessonId: String? = nil
    @State private var headerChipResolved: String? = nil
    @State private var headerSubtitleResolved: String = ""
    @State private var stepSessionKey = UUID()
    @State private var itemsVersion = UUID()
    // forces full rebuild of lesson progress UI on reset / progress changes
    @State private var progressReloadToken: UUID = UUID()
    // Debounce work item for header refreshes
    @State private var headerRefreshWork: DispatchWorkItem? = nil
    // instagram-like interactive overlay
    @GestureState private var stepDragY: CGFloat = 0
    private let stepDismissThreshold: CGFloat = 140
    @AppStorage("LSLessonActivity.lastActiveLessonId") private var lastActiveLessonId: String = ""

    private let courseId: String?
    private let lessonId: String?

    // Snapshot for step overlay
    @State private var frozenSnapshot: Image? = nil

    public init(courseId: String? = nil, lessonId: String? = nil) {
        self.courseId = courseId
        self.lessonId = lessonId
    }

    private func resolveHeaderMeta() {
        // Ensure CourseData is loaded
        CourseData.shared.load()
        guard let course = currentCourse else {
            headerChipResolved = nil
            headerSubtitleResolved = ""
            return
        }
        let cid = course.courseID
        let cat = CourseData.shared.category(for: cid)
        let desc = CourseData.shared.description(for: cid)
        headerChipResolved = (cat?.isEmpty == false) ? cat : nil
        headerSubtitleResolved = (desc?.isEmpty == false) ? desc! : (course.courseDescription ?? "")
    }

    /// Debounced header and tasks refresh, to avoid redundant rebuilds.
    private func scheduleHeaderRefresh() {
        headerRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak lessonsStore = self.lessonsStore, weak lessonsManager = self.lessonsManager] in
            // Recompute header and lightweight IDs
            resolveHeaderMeta()
            if let cid = currentCourse?.courseID {
                let ids = lessonsSorted.map { $0.lessonID }
                homeTaskManager.regenerateTasks(for: cid, lessonIds: ids)
            }
            itemsVersion = UUID()
            htVersion = UUID()
        }
        headerRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    @ViewBuilder
    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Layout.sectionGap) {
                headerSection
                    .id(itemsVersion) // force re-render when progress changes
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
                    .padding(.top, Theme.Layout.pageTopAfterHeader)
                contentReelsSection
                    .padding(.horizontal, Theme.Layout.pageHorizontal)

                lessonsReelsSection
                    .id(itemsVersion)
                    .padding(.horizontal, Theme.Layout.pageHorizontal)

                LSProgressSection(
                    lessonsDone: headerProgress.completed,
                    lessonsTotal: headerProgress.total
                )
                .padding(.horizontal, Theme.Layout.pageHorizontal)

                LSSectionTitle("ИТОГИ КУРСА")
                    .padding(.horizontal, Theme.Layout.pageHorizontal)

                LSCourseOverview(
                    stats: LSCourseStats(
                        completedLessons: headerProgress.completed,
                        totalLessons: headerProgress.total,
                        learnedWords: 0,
                        favorites: 0,
                        streakDays: 0,
                        timeMinutes: 0
                    ),
                    category: headerChipResolved ?? "",
                    onCTA: {
                        if let first = lessonsSorted.first {
                            selectedLessonId = first.lessonID
                            goToStep = true
                        }
                    },
                    onReset: {
                        if let cid = currentCourse?.courseID {
                            lessonsManager.resetCourseProgress(courseId: cid)
                            resolveHeaderMeta()
                            stepSessionKey = UUID()
                        }
                    }
                )
                .padding(.horizontal, Theme.Layout.pageHorizontal)

                if currentCourse == nil {
                    Text("Не удалось загрузить курс из lessons.json")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, Theme.Layout.pageBottomSafeGap)
        }
        .preferredColorScheme(.dark)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .id(progressReloadToken)
        .opacity(goToStep ? 0 : 1)
        .allowsHitTesting(!(goToStep || goHomeTask))
    }

    public var body: some View {
        buildBody()
    }

    @ViewBuilder
    private var overlayStackView: some View {
        ZStack(alignment: .bottom) {
            if goToStep {
                // When step overlay is open, let stepOverlay manage the glass background.
                // Keep mainContent in the tree but hidden, so layouts stay consistent.
                Color.clear.ignoresSafeArea()
                mainContent.hidden()
            } else {
                // Normal screen background + content when overlay is closed
                PD.ColorToken.background.ignoresSafeArea()
                mainContent
            }
            // Inline overlay above content (IG-style)
            stepOverlay
            homeTaskOverlay
        }
    }

    @ViewBuilder
    private func buildBody() -> some View {
        let stepPub = NotificationCenter.default.publisher(for: .stepProgressDidChange)
        let courseResetPub = NotificationCenter.default.publisher(for: Notification.Name("progressCourseDidReset"))
        let courseResetLegacyPub = NotificationCenter.default.publisher(for: Notification.Name("courseProgressDidReset"))
        let lessonResetPub = NotificationCenter.default.publisher(for: Notification.Name("progressLessonDidReset"))
        let lessonResetLegacyPub = NotificationCenter.default.publisher(for: Notification.Name("lessonProgressDidReset"))
        let hometaskRegeneratePub = NotificationCenter.default.publisher(for: Notification.Name("hometaskShouldRegenerate"))
        let favoritesDidChangePub = NotificationCenter.default.publisher(for: .favoritesDidChange)
        let favoritesDidUpdatePub = NotificationCenter.default.publisher(for: .favoritesDidUpdate)
        let favoritesDidChangeLegacyPub = NotificationCenter.default.publisher(for: .FavoritesDidChange)


// Base content

let base = overlayStackView


// Data loading / refresh hooks

let withTasks = base

    // Use the global AppShell header (back header for this screen).
    .shellHeaderHidden(goToStep || goHomeTask)

    .task {

        CourseData.shared.load()

        lessonsStore.preload()

        resolveHeaderMeta()

        if let cid = currentCourse?.courseID {

            let ids = lessonsSorted.map { $0.lessonID }

            homeTaskManager.regenerateTasks(for: cid, lessonIds: ids)

        }

        DispatchQueue.main.async { resolveHeaderMeta() }

    }

    .onChange(of: currentCourse?.courseID) { _, _ in

        resolveHeaderMeta()

        if let cid = currentCourse?.courseID {

            let ids = lessonsSorted.map { $0.lessonID }

            homeTaskManager.regenerateTasks(for: cid, lessonIds: ids)

        }

    }

    .onChange(of: selectedLessonId) { _, _ in

        itemsVersion = UUID()

    }

    .onReceive(lessonsManager.$progress) { _ in

        scheduleHeaderRefresh()

    }

    .onReceive(NotificationCenter.default.publisher(for: .init("ProgressDidChange"))) { _ in

        progressReloadToken = UUID()

        scheduleHeaderRefresh()

    }

    .onReceive(NotificationCenter.default.publisher(for: .init("AppResetAll"))) { _ in

        progressReloadToken = UUID()

        scheduleHeaderRefresh()

    }

    .onReceive(courseResetPub) { _ in scheduleHeaderRefresh() }

    .onReceive(courseResetLegacyPub) { _ in scheduleHeaderRefresh() }

    .onReceive(lessonResetPub) { _ in scheduleHeaderRefresh() }

    .onReceive(lessonResetLegacyPub) { _ in scheduleHeaderRefresh() }

    .onReceive(stepPub) { _ in

        itemsVersion = UUID()

        scheduleHeaderRefresh()

    }
    .onReceive(favoritesDidChangePub) { _ in
        itemsVersion = UUID()
        scheduleHeaderRefresh()
    }
    .onReceive(favoritesDidUpdatePub) { _ in
        itemsVersion = UUID()
        scheduleHeaderRefresh()
    }
    .onReceive(favoritesDidChangeLegacyPub) { _ in
        itemsVersion = UUID()
        scheduleHeaderRefresh()
    }

    .onReceive(homeTaskManager.objectWillChange) { _ in

        htVersion = UUID()

    }

    .onReceive(hometaskRegeneratePub) { _ in

        htVersion = UUID()

    }

    .onReceive(lessonsStore.objectWillChange) { _ in

        scheduleHeaderRefresh()

    }


// Navigation / chrome

        let withChrome = withTasks
            .navigationBarBackButtonHidden(true)
            .background(NavSwipeBackDisabler())

// Animation (explicit type to reduce inference load)

let withAnim = withChrome

    .animation(Animation.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.2), value: goHomeTask)


return withAnim
}
}


extension HomeTaskManager {
    /// Convenience shim for views: regenerate with default rule and sampling.
    /// If a more specific API exists elsewhere, this overload keeps call sites simple.
    @MainActor
    func regenerateTasks(for courseId: String, lessonIds: [String]) {
        // If your manager requires a more detailed regenerate, you can
        // implement sensible defaults there. For now we trigger observers
        // to refresh UI; the manager may lazily prepare tasks on access.
        NotificationCenter.default.post(name: Notification.Name("hometaskShouldRegenerate"), object: nil)
    }
}

extension LessonsView {
    // MARK: - Extracted Sections
    private var headerSection: some View {
        let slots = perLessonPercents()
        let count = totalLessonsCount
        let baseSlots = !slots.isEmpty ? slots : Array(repeating: 0.0, count: count)
        let slotsResolved: [Double] = baseSlots.isEmpty ? [0.0] : baseSlots
        let subtitleResolved = headerSubtitleResolved.isEmpty ? headerSubtitle : headerSubtitleResolved
        return LSLessonHeader(
            title: headerTitle,
            subtitle: subtitleResolved,
            progressSlots: slotsResolved,
            selectedIndex: activeLessonIndex,
            onTapSlot: { idx in
                let arr = lessonsSorted
                if idx >= 0 && idx < arr.count {
                    let lid = arr[idx].lessonID
                    LSLessonActivity.mark(lid)
                    if let cid = currentCourse?.courseID {
                        UserSession.shared.markActive(courseId: cid, lessonId: lid)
                    }
                    DispatchQueue.main.async {
                        selectedLessonId = lid
                        if !goToStep {
                            // freeze current screen for the overlay background (prevents black screen)
                            frozenSnapshot = captureWindowSnapshot()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                goToStep = true
                            }
                        }
                    }
                }
            }
        )
    }

    private var contentReelsSection: some View {
        VStack(spacing: Theme.Layout.sectionContentV) {
            LSContentReels("СОДЕРЖАНИЕ", items: contentItems())
            LSMarqueeSection(
                title: "ТАЙКА FM",
                messages: fmMessages
            )
        }
    }

    private var lessonsReelsSection: some View {
        LSLessonReels(
            "УРОКИ",
            items: lessonItems(),
            onTap: { item in
                let arr = lessonsSorted
                if item.index >= 0 && item.index < arr.count {
                    let lid = arr[item.index].lessonID
                    LSLessonActivity.mark(lid)
                    if let cid = currentCourse?.courseID {
                        UserSession.shared.markActive(courseId: cid, lessonId: lid)
                    }
                    DispatchQueue.main.async {
                        selectedLessonId = lid
                        if !goToStep {
                            // freeze current screen for the overlay background (prevents black screen)
                            frozenSnapshot = captureWindowSnapshot()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                goToStep = true
                            }
                        }
                    }
                }
            },
            onTapAccessory: { item in
                let arr = lessonsSorted
                guard item.index >= 0 && item.index < arr.count else { return }
                let lid = arr[item.index].lessonID
                if let cid = currentCourse?.courseID,
                   let p = lessonsManager.lessonProgress(courseId: cid, lessonId: lid),
                   p.percent >= 1.0 {
                    DispatchQueue.main.async {
                        selectedLessonId = lid
                        goHomeTask = true
                    }
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            },
            selectedIndex: activeLessonIndex
        )
    }
}
#Preview("LessonsView – screen") {
  NavigationStack {
    LessonsView()
      .task { CourseData.shared.load() } // прогрузи курсовый JSON
  }
}


extension LessonsView {
    // MARK: - Step Overlay Helpers
    @ViewBuilder
    private var stepOverlay: some View {
        if goToStep {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Фон: размазанный снапшот Lessons (как "стекло" под каноничным степом)
                    Group {
                        if let frozenSnapshot {
                            frozenSnapshot
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 22)
                                .overlay(Color.black.opacity(0.24))
                                .ignoresSafeArea()
                        } else {
                            // fallback: stable background (avoid depending on hidden/opacity content)
                            ZStack {
                                PD.ColorToken.background
                                    .ignoresSafeArea()
                                Color.black.opacity(0.24)
                                    .ignoresSafeArea()
                            }
                        }
                    }
                    .allowsHitTesting(false)

                    // Прозрачный блокер, чтобы клики не шли в Lessons
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .allowsHitTesting(true)

                    // Контейнер с каноничным StepView в виде полноэкранного overlay
                    StepView(
                        courseId: currentCourse?.courseID ?? "",
                        lessonId: resolvedOverlayLessonId(),
                        lessonTitle: nil,
                        startIndex: 0,
                        scope: .full,
                        layoutCardsOnly: false,
                        showInternalHeader: false
                    )
                    .id("\(resolvedOverlayLessonId())-\(stepSessionKey)-start0")
                    .environmentObject(StepManager.shared)
                    .environmentObject(ProgressManager.shared)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    // keep Step content below the header area (same feel as other screens)
                    .padding(.top, geo.safeAreaInsets.top + 84)
                    .zIndex(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.32, dampingFraction: 0.9), value: goToStep)
                    .overlay(alignment: .top) {
                        AppBackHeader(variant: .transparent) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                goToStep = false
                            }
                            // release snapshot when closing
                            frozenSnapshot = nil
                        }
                        .padding(.top, geo.safeAreaInsets.top + 6)
                        .padding(.horizontal, 12)
                    }
                }
                .ignoresSafeArea(edges: .all)
            }
        }
    }

    private var isCurrentLessonComplete: Bool {
        guard let cid = currentCourse?.courseID, !resolvedOverlayLessonId().isEmpty else { return false }
        if let p = lessonsManager.lessonProgress(courseId: cid, lessonId: resolvedOverlayLessonId())?.percent {
            return p >= 1.0
        }
        return false
    }

    private func resolvedOverlayLessonId() -> String {
        return selectedLessonId ?? currentLesson?.lessonID ?? lessonId ?? ""
    }

    private func stepOverlayId() -> String {
        let lid = resolvedOverlayLessonId()
        return "step-\(lid)-\(stepSessionKey)"
    }
}


extension LessonsView {
    // MARK: - HomeTask Overlay (matches stepOverlay style)
    @ViewBuilder
    private var homeTaskOverlay: some View {
        if goHomeTask {
            GeometryReader { geo in
                let h = geo.size.height
                let sheetH = min(h - 64, h * 0.94) // Keep HomeTask overlay at the same higher position as Step overlay.
                ZStack(alignment: .bottom) {
                    // Background blur + dim (same as stepOverlay)
                    Group {
                        if UIAccessibility.isReduceTransparencyEnabled {
                            Color.black.opacity(0.06).ignoresSafeArea()
                        } else {
                            ZStack {
                                BlurView(style: .systemChromeMaterialDark)
                                    .ignoresSafeArea()
                                    .saturation(1.0)
                                    .contrast(1.15)
                                Color.black.opacity(0.10).ignoresSafeArea()
                            }
                        }
                    }
                    .allowsHitTesting(false)

                    // Transparent blocker to swallow gestures on the backdrop
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .allowsHitTesting(true)

                    // Bottom sheet container
                    VStack(spacing: 0) {
                        let cid = currentCourse?.courseID ?? ""
                        let lid = selectedLessonId ?? currentLesson?.lessonID ?? lessonId ?? lessonsSorted.first?.lessonID ?? ""
                        HomeTaskView(
                            courseId: cid,
                            lessonId: lid,
                            embedBackground: false,
                            onClose: {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { goHomeTask = false }
                            },
                            onNextGame: {
                                // Notify host to present next game / paywall
                                NotificationCenter.default.post(name: Notification.Name("hometaskNextGameRequested"), object: nil)
                            },
                            isProUser: true // TODO: wire to real user state, e.g. UserSession.shared.isPro
                        )
                        .id("hometask-\(lid)-\(htVersion)")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: sheetH)
                    .background(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))
                    .zIndex(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.32, dampingFraction: 0.9), value: goHomeTask)

                }
                .ignoresSafeArea(edges: .all)
            }
        }
    }
}
 
