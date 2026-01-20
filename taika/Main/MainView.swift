
import SwiftUI
import UIKit

@MainActor
final class _Ignore_Compile_Helper: ObservableObject {}

struct MainView: View {

    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @ObservedObject private var main = MainManager.shared
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var session = UserSession.shared
    @State private var dailyIndex: Int = 1
    @State private var doneHaptic = UINotificationFeedbackGenerator()
    @State private var learnedIds: Set<String> = []
    @State private var favoriteIds: Set<String> = []
    @State private var lessonsTick: Int = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var navPushInFlight: Bool = false

    // MARK: - Search (OverlayPresenter contract)
    @State private var didConfigureSearchIndex: Bool = false
    @State private var searchCourseById: [String: CourseBundle] = [:]
    @State private var searchLessonHitById: [String: SearchLessonHit] = [:]
    @FocusState private var isSearchFocused: Bool
    @State private var mainSearchStub: String = ""

    private struct SearchLessonHit: Identifiable, Equatable {
        let id: String
        let courseId: String
        let lessonId: String
        let courseTitle: String
        let lessonTitle: String
        let lessonSubtitle: String

        init(courseId: String, lessonId: String, courseTitle: String, lessonTitle: String, lessonSubtitle: String) {
            self.courseId = courseId
            self.lessonId = lessonId
            self.courseTitle = courseTitle
            self.lessonTitle = lessonTitle
            self.lessonSubtitle = lessonSubtitle
            self.id = "lesson|\(courseId)|\(lessonId)"
        }
    }
    private enum CalendarSheet: Equatable {
        case add(Date)
        case summary(Date)

        var day: Date {
            switch self {
            case .add(let d): return d
            case .summary(let d): return d
            }
        }
        var isAdd: Bool {
            if case .add = self { return true }
            return false
        }
    }

    @State private var calendarDayCourses: [MainManager.CourseCardModel] = []
    @State private var calendarSummaryPlannedOnly: Bool = false
    @State private var refreshWork: DispatchWorkItem? = nil
    @State private var addOverlayShuffleToken: Int = 0
    @State private var addOverlayReloadToken: Int = 0

    // MARK: - Thailand canonical calendar (match MainManager)
    private static let bangkokTZ: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    private static var bangkokCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = bangkokTZ
        return cal
    }()

    // MARK: - Extracted blocks to help the type-checker
    @State private var continueSelectedIndex: Int = 3
    @State private var weekRenderToken: Int = 0
    private var dailyPicksBlock: some View {
        let picks = main.dailyPicks
        let items = picks.items
        let refs  = picks.refs

        let refCourseIds = refs.map { $0.courseId }
        let refLessonIds = refs.map { $0.lessonId }
        let refIndices   = refs.map { $0.index }

        let learnedIdx = computeLearnedIdx(
            itemsCount: items.count,
            courseIds: refCourseIds,
            lessonIds: refLessonIds,
            indices: refIndices
        )
        let favoriteIdx = computeFavoriteIdx(
            itemsCount: items.count,
            courseIds: refCourseIds,
            lessonIds: refLessonIds,
            indices: refIndices
        )

        return VStack(spacing: Theme.Layout.sectionGap) {
            MDDailyPicksComposite(
                title: "ПОДБОРКА ДНЯ",
                items: items,
                courseShortNames: picks.courseShort,
                lessonShortNames: picks.lessonShort,
                learned: learnedIdx,
                favorites: favoriteIdx,
                activeIndex: $dailyIndex,
                onTapCourse: { i in
                    guard i >= 0, i < refs.count else { return }
                    openCourse(refs[i].courseId)
                },
                onTapLesson: { i in
                    guard i >= 0, i < refs.count else { return }
                    let ref = refs[i]
                    openLesson(courseId: ref.courseId, lessonId: ref.lessonId)
                },
                onOpenCourse: { i in
                    guard i >= 0, i < refs.count else { return }
                    openCourse(refs[i].courseId)
                },
                onPlay: { i in
                    guard i >= 0, i < items.count else { return }
                    handlePlayItem(items[i])
                },
                onDone: { i in
                    guard i >= 0, i < items.count else { return false }
                    return handleDoneItem(items[i])
                },
                onFav: { i in
                    guard i >= 0, i < items.count, i < refs.count else { return false }
                    let item = items[i]
                    let ref  = refs[i]

                    // was it liked before?
                    let was = FavoriteManager.shared.isLiked(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)

                    // toggle like
                    FavoriteManager.shared.toggle(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)

                    // refresh local DS highlight state
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        rebuildFavoritesState()
                    }

                    // return true only when we ADDED like (so DS will advance). On unlike — return false (no scroll).
                    return !was
                },
                onIndexChange: { i in
                    dailyIndex = i
                    // keep DS highlights in sync for the newly active card
                    rebuildLearnedState()
                    rebuildFavoritesState()
                }
            )
        }
    }

    @ViewBuilder
    private var continueBlock: some View {
        if main.weekSummary.isEmpty {
            // lightweight placeholder to keep layout stable
            Color.clear
                .frame(height: 260)
                .onAppear {
                    // best-effort: kick a rebuild if needed
                    Task { @MainActor in
                        if main.weekSummary.isEmpty {
                            await main.rebuildWeekSummary()
                        }
                    }
                }
        } else {
            let continueItems: [(String, Double)] = Array(main.resumeItems).map { it in
                (it.title, Double(it.progress))
            }

            MDContinueSection(
                "ПРОДОЛЖИТЬ",
                items: continueItems,
                bannerProvider: bannerFor(date:),
                weekProvider: weekFor(offset:),
                onTapEmptyDay: { item in
                    handleTapDayCard(item)
                },
                onTapDaySummary: { item in
                    handleTapDayCard(item)
                },
                selectedIndex: $continueSelectedIndex
            ) { _ in }
            .id(weekRenderToken)
            .onAppear {
                // post-render centering (avoids internal clamping on first mount)
                let cal = Self.bangkokCal
                let today = cal.startOfDay(for: Date())
                if let idx = main.weekSummary.firstIndex(where: { cal.isDate(cal.startOfDay(for: $0.date), inSameDayAs: today) }) {
                    DispatchQueue.main.async { continueSelectedIndex = idx }
                } else {
                    DispatchQueue.main.async { continueSelectedIndex = 3 }
                }
            }
        }
    }
    private func startRandomCourseQuickstart() {
        // avoid stacking overlays
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.present(.randomCourseLoading)
        }

        Task { @MainActor in
            // a tiny delay for the loading animation
            try? await Task.sleep(nanoseconds: 950_000_000)

            // pick a random course according to current business rules
            // (pro: any; free: only free courses)
            let pick = await main.randomCourseForToday(isProUser: pro.isPro)
            let courseId = pick?.id

            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                overlay.dismiss()
            }

            guard let courseId else {
                // no available courses under current rules → open add overlay instead
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.present(.calendarAdd(Self.bangkokCal.startOfDay(for: Date())))
                }
                return
            }
            openCourse(courseId)
        }
    }

    private func handleTapDayCard(_ item: WeeklyResumeItem) {
        let cal = Self.bangkokCal
        let today = cal.startOfDay(for: Date())
        let tapped = cal.startOfDay(for: item.date)

        Task { @MainActor in
            let resolved = await main.dayState(for: tapped)

            switch resolved.state {
            case .active:
                calendarSummaryPlannedOnly = false
                overlay.present(.calendarSummary(resolved.dayStart))

            case .plannedOnly:
                // planned-only day:
                // - future/today: open plan editor (add/remove)
                // - past: treat as "missed" → open summary (read-only)
                if resolved.dayStart < today {
                    calendarSummaryPlannedOnly = true
                    overlay.present(.calendarSummary(resolved.dayStart))
                } else {
                    calendarSummaryPlannedOnly = false
                    overlay.present(.calendarAdd(resolved.dayStart))
                }

            case .empty:
                // past empty day: do nothing
                if resolved.dayStart < today { return }

                // today empty: random
                if cal.isDateInToday(resolved.dayStart) {
                    startRandomCourseQuickstart()
                    return
                }

                // future empty: add
                calendarSummaryPlannedOnly = false
                overlay.present(.calendarAdd(resolved.dayStart))
            }
        }
    }


    private func bannerFor(date: Date) -> MDContinueSection.BannerInfo {
        let cal = Self.bangkokCal
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let idx = max(0, min(6, cal.dateComponents([.day], from: weekStart, to: date).day ?? 0))
        if idx < main.resumeItems.count {
            let it = main.resumeItems[idx]
            let category = (it.kind == .course ? "Курс" : "Урок")
            return (it.title, Double(it.progress), category)
        }
        let f = main.resumeItems.first
        return (f?.title ?? "", Double(f?.progress ?? 0), (f?.kind == .course ? "Курс" : "Урок"))
    }

    private func daySummary(for date: Date) -> CardDS_DaySummary? {
        return main.daySummary(for: date)
    }

    private func weekFor(offset: Int) -> [WeeklyResumeItem] {
        let cal = Self.bangkokCal
        let today = cal.startOfDay(for: Date())

        // source of truth: published weekSummary from MainManager
        // (offset is currently unused; the weekSummary itself is already aligned to today -3...+3)
        let days = main.weekSummary

        return days.map { ds in
            let dayStart = cal.startOfDay(for: ds.date)
            let weekdayIndex = max(1, min(7, cal.component(.weekday, from: dayStart)))
            let wd = cal.shortWeekdaySymbols[weekdayIndex - 1].lowercased()

            let raw1 = ds.courses.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            let raw2 = ds.courses.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines)

            let isPast = (dayStart < today)
            let hasPlannedCourses = (ds.totalCourses > 0)
            let isPlannedOnly = ds.isPlanned
            let isMissed = isPast && isPlannedOnly && hasPlannedCourses && (ds.progress <= 0.0001)

            // titles: for missed plan we show a dedicated placeholder card (no titles)
            let t1: String? = isMissed ? nil : ((raw1?.isEmpty == false) ? raw1 : nil)
            let t2: String? = isMissed ? nil : ((raw2?.isEmpty == false) ? raw2 : nil)

            // Strictly render from DaySummary: isEmpty, p1, p2
            // - empty past planned day => render as "missed" (isEmpty=true, coursesCount>0)
            // - empty non-planned day => render as empty
            let isEmpty = isMissed || (!isPlannedOnly && ds.totalCourses == 0)

            let p1: Double? = {
                if isEmpty { return nil }
                if isPlannedOnly { return 0.0 }
                return max(0.02, min(1.0, ds.progress))
            }()

            let p2: Double? = (t2 != nil) ? p1 : nil

            return WeeklyResumeItem(
                weekdayShort: wd,
                date: dayStart,
                title: t1,
                progress: p1,
                secondaryTitle: t2,
                secondaryProgress: p2,
                coursesCount: ds.totalCourses,
                isToday: cal.isDateInToday(dayStart),
                isEmpty: isEmpty
            )
        }
    }

    private func courseTitle(_ courseId: String) -> String {
        let t = LessonsManager.shared.courseTitle(for: courseId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? courseId : t
    }

    private func courseProgress(_ courseId: String, isActive: Bool) -> Double? {
        // canonical source of truth: ProgressManager
        let v = ProgressManager.shared.progress(for: courseId, lessonId: nil)
        let clamped = max(0.0, min(1.0, v))

        if isActive {
            return max(0.02, clamped)
        }
        return clamped
    }

    private func stepKey(for idx: Int) -> String? {
        guard idx >= 0, idx < main.dailyPicks.refs.count else { return nil }
        let r = main.dailyPicks.refs[idx]
        guard r.index >= 0, r.courseId != "__pro__", r.lessonId != "__pro__" else { return nil }
        return "step:\(r.courseId):\(r.lessonId):idx\(r.index)"
    }

    private func computeLearnedIdx(
        itemsCount: Int,
        courseIds: [String],
        lessonIds: [String],
        indices: [Int]
    ) -> Set<Int> {
        var out: Set<Int> = []
        let n = min(itemsCount, courseIds.count, lessonIds.count, indices.count)
        guard n > 0 else { return out }

        for i in 0..<n {
            let c = courseIds[i]
            let l = lessonIds[i]
            let idx = indices[i]
            guard idx >= 0, c != "__pro__", l != "__pro__" else { continue }
            let key = "step:\(c):\(l):idx\(idx)"
            if learnedIds.contains(key) {
                out.insert(i)
            }
        }
        return out
    }

    private func computeFavoriteIdx(
        itemsCount: Int,
        courseIds: [String],
        lessonIds: [String],
        indices: [Int]
    ) -> Set<Int> {
        var out: Set<Int> = []
        let n = min(itemsCount, courseIds.count, lessonIds.count, indices.count)
        guard n > 0 else { return out }

        for i in 0..<n {
            let c = courseIds[i]
            let l = lessonIds[i]
            let idx = indices[i]
            guard idx >= 0, c != "__pro__", l != "__pro__" else { continue }
            let key = "step:\(c):\(l):idx\(idx)"
            if favoriteIds.contains(key) {
                out.insert(i)
            }
        }
        return out
    }

    private var mainScrollBlock: some View {
        let isModalPresented = overlay.isPresented

        return ScrollView {
            VStack(spacing: Theme.Layout.sectionGap) {
                fmSection

                dailyPicksBlock

                searchSection

                continueBlock
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .modifier(_ContentMarginsCompat(horizontal: PD.Spacing.screen))
            .scaleEffect(isModalPresented ? 0.985 : 1)
            .opacity(isModalPresented ? 0.88 : 1)
            .overlay(
                Color.black
                    .opacity(isModalPresented ? 0.18 : 0)
                    .allowsHitTesting(false)
            )
            .allowsHitTesting(!isModalPresented)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProgressDidChange"))) { _ in
            rebuildLearnedState()
            scheduleMainRefresh(delay: 0.45)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FavoritesDidChange"))) { _ in
            Task { @MainActor in
                rebuildFavoritesState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LessonsDidChange"))) { _ in
            Task { @MainActor in
                lessonsTick &+= 1
                scheduleMainRefresh(delay: 0.45)
                rebuildLearnedState()
                rebuildFavoritesState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CoursePlanDidChange"))) { _ in
            // realtime calendar updates come from MainManager.weekSummary (@Published) via quick update;
            // do NOT force a full refresh here.
            lessonsTick &+= 1
        }
        .onReceive(session.objectWillChange) { _ in
            // avoid full refresh storms; calendar will update via weekSummary publishes
            lessonsTick &+= 1
        }
        .onChange(of: main.dailyPicks.refs) { _ in
            rebuildLearnedState()
            rebuildFavoritesState()
        }
        .onChange(of: main.weekSummary) { _ in
            weekRenderToken &+= 1
            let cal = Self.bangkokCal
            let today = cal.startOfDay(for: Date())
            if let idx = main.weekSummary.firstIndex(where: { cal.isDate(cal.startOfDay(for: $0.date), inSameDayAs: today) }) {
                continueSelectedIndex = idx
            } else {
                continueSelectedIndex = 3
            }
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.top, Theme.Layout.pageTopAfterHeader)
        .safeAreaPadding(.bottom, Theme.Layout.pageBottomSafeGap)
        .task {
            StepData.shared.preload()
            await main.refresh()
            await main.reloadDailyPicks()
            if main.weekSummary.isEmpty {
                await main.rebuildWeekSummary()
            }
            let cal = Self.bangkokCal
            let today = cal.startOfDay(for: Date())
            if let idx = main.weekSummary.firstIndex(where: { cal.isDate(cal.startOfDay(for: $0.date), inSameDayAs: today) }) {
                continueSelectedIndex = idx
            } else {
                continueSelectedIndex = 3
            }

            let targetIndex: Int = (main.dailyPicks.items.first?.isPro == true && main.dailyPicks.items.count > 1) ? 1 : 0
            dailyIndex = targetIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                dailyIndex = targetIndex
            }

            rebuildLearnedState()
            rebuildFavoritesState()
        }
    }

    var body: some View {
        ZStack {
            let isModalPresented = overlay.isPresented
            // themed background from DS
            PD.ColorToken.background.ignoresSafeArea()

            mainScrollBlock

            if let o = overlay.overlay {
                switch o {
                case .search:
                    searchOverlay
                case .calendarAdd(let d):
                    calendarOverlay(sheet: CalendarSheet.add(d))
                case .calendarSummary(let d):
                    calendarOverlay(sheet: CalendarSheet.summary(d))
                case .randomCourseLoading:
                    randomCourseLoadingOverlay
                case .proCoursePaywall(let courseId):
                    PROView(courseId: courseId) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                        }
                    }
                case .accentPicker:
                    Color.clear
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarTitleDisplayMode(.inline)
    }
    // MARK: - Search overlay

    private var searchOverlay: some View {
        ZStack {
            searchOverlayBackdrop
            searchOverlayCard
        }
    }

    private var searchOverlayBackdrop: some View {
        Color.black.opacity(0.28)
            .ignoresSafeArea()
            .onTapGesture {
                dismissSearchOverlay()
            }
    }

    private var searchOverlayCard: some View {
        VStack(spacing: 12) {
            searchOverlayHeader
            searchOverlayField
            searchOverlayResults
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        // avoid double keyboard-avoidance (we ignore keyboard safe area globally)
        // lift the card slightly, but keep enough space for a full-size course card
        .padding(.bottom, keyboardHeight > 0 ? max(18, min(180, keyboardHeight * 0.45)) : 0)
        .transition(.scale(scale: 0.98).combined(with: .opacity))
        .onAppear {
            // best-effort ensure index is configured; results are produced by OverlayPresenter
            Task { @MainActor in
                await ensureOverlaySearchIndexConfigured()
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard overlay.overlay == .search else { return }
            guard let endFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

            let screenH = UIScreen.main.bounds.height
            let h = max(0, screenH - endFrame.minY)

            withAnimation(.easeOut(duration: 0.22)) {
                keyboardHeight = h
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            guard overlay.overlay == .search else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                keyboardHeight = 0
            }
        }
    }

    private var searchOverlayHeader: some View {
        HStack(spacing: 10) {
            Text("поиск")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 12)

            Button {
                dismissSearchOverlay()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }

    private var searchOverlayField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))

            TextField("введи слово", text: $overlay.searchQuery)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.92))
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)

            if !overlay.searchQuery.isEmpty {
                Button {
                    overlay.searchQuery = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isSearchFocused = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            Theme.Surfaces.card(Capsule(style: .continuous))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(ThemeManager.shared.currentAccentFill.opacity(isSearchFocused ? 0.95 : 0.0), lineWidth: 1.2)
        )
    }

    @ViewBuilder
    private var searchOverlayResults: some View {
        let q = overlay.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmptyQuery = q.isEmpty

        if isEmptyQuery {
            // keep it minimal; do not reserve large vertical space when keyboard is hidden
            Color.clear
                .frame(height: 10)
        } else {
            searchCoursesUnifiedSection()
        }
    }

    private func searchCoursesUnifiedSection() -> some View {
        let directCourseIds = overlay.searchCourseIds
        let lessonHitIds = overlay.searchLessonIds

        // courses that matched via lessons
        var viaLessonCourseIds: [String] = []
        viaLessonCourseIds.reserveCapacity(min(12, lessonHitIds.count))
        for hitId in lessonHitIds {
            if let hit = searchLessonHitById[hitId] {
                viaLessonCourseIds.append(hit.courseId)
            }
        }

        // stable unique order: direct matches first, then courses with lesson matches
        var seen: Set<String> = []
        var combined: [String] = []
        combined.reserveCapacity(min(12, directCourseIds.count + viaLessonCourseIds.count))

        for id in directCourseIds {
            if seen.insert(id).inserted {
                combined.append(id)
            }
        }
        for id in viaLessonCourseIds {
            if seen.insert(id).inserted {
                combined.append(id)
            }
        }

        // cap results for UI
        let ids = Array(combined.prefix(8))

        if ids.isEmpty {
            return AnyView(
                Text("ничего не найдено")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(ids, id: \.self) { courseId in
                        if let c = searchCourseById[courseId] {
                            let p = courseProgress(c.courseID, isActive: true) ?? 0.0

                            // if the course did not match directly, it came from a lesson hit → show a subtle hint
                            let isDirect = directCourseIds.contains(courseId)
                            let hint: String? = {
                                guard !isDirect else { return nil }
                                // pick the first lesson hit inside this course
                                if let first = lessonHitIds
                                    .compactMap({ searchLessonHitById[$0] })
                                    .first(where: { $0.courseId == courseId }) {
                                    let t = first.lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    return t.isEmpty ? nil : ("в уроке: " + t)
                                }
                                return nil
                            }()

                            _SearchCourseCard(
                                course: c,
                                progress: p,
                                subtitleOverride: hint,
                                onTap: {
                                    openCourse(c.courseID)
                                    dismissSearchOverlay()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            // fixed carousel height = stable layout; no "bottomless" empty area when keyboard is hidden
            .frame(height: 340)
        )
    }


    private func dismissSearchOverlay() {
        isSearchFocused = false
        keyboardHeight = 0
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.dismiss()
        }
    }

    private struct _SearchCourseCard: View {
        let course: CourseBundle
        let progress: Double
        let subtitleOverride: String?
        let onTap: () -> Void

        var body: some View {
            let base = (course.courseDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = (subtitleOverride?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? base

            CardDS.NoteCourseCardV(
                label: "курс",
                categoryChip: nil,
                title: course.courseTitle,
                subtitle: subtitle,
                progress: progress,
                ctaTitle: "открыть",
                onTap: onTap,
                topRightChip: nil
            )
        }
    }


    @MainActor
    private func ensureOverlaySearchIndexConfigured() async {
        if didConfigureSearchIndex, !searchCourseById.isEmpty { return }

        // load JSON
        LessonsData.shared.preload()
        let allCourses = LessonsData.shared.allCourses()

        let built = await Task.detached(priority: .userInitiated) { () -> (byCourse: [String: CourseBundle], byLessonHit: [String: SearchLessonHit], courseEntries: [OverlayPresenter.SearchIndex.Entry], lessonEntries: [OverlayPresenter.SearchIndex.Entry]) in
            // build id->model maps (fast lookup for UI)
            var byCourse: [String: CourseBundle] = [:]
            byCourse.reserveCapacity(allCourses.count)

            var byLessonHit: [String: SearchLessonHit] = [:]
            byLessonHit.reserveCapacity(allCourses.count * 6)

            // build normalized haystacks for index
            func norm(_ s: String) -> String {
                s.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var courseEntries: [OverlayPresenter.SearchIndex.Entry] = []
            courseEntries.reserveCapacity(allCourses.count)

            var lessonEntries: [OverlayPresenter.SearchIndex.Entry] = []
            lessonEntries.reserveCapacity(allCourses.count * 6)

            for c in allCourses {
                byCourse[c.courseID] = c

                let courseHay = [
                    norm(c.courseTitle),
                    norm(c.courseDescription ?? "")
                ].joined(separator: " | ")

                courseEntries.append(.init(id: c.courseID, haystack: courseHay))

                for l in c.lessons {
                    let contentText = l.content.map { $0.text }.joined(separator: " ")
                    let hay = [
                        norm(l.title),
                        norm(l.subtitle),
                        norm(contentText),
                        norm(c.courseTitle)
                    ].joined(separator: " | ")

                    let hit = SearchLessonHit(
                        courseId: c.courseID,
                        lessonId: l.lessonID,
                        courseTitle: c.courseTitle,
                        lessonTitle: l.title,
                        lessonSubtitle: l.subtitle
                    )

                    byLessonHit[hit.id] = hit
                    lessonEntries.append(.init(id: hit.id, haystack: hay))
                }
            }

            return (byCourse, byLessonHit, courseEntries, lessonEntries)
        }.value

        // publish caches
        searchCourseById = built.byCourse
        searchLessonHitById = built.byLessonHit
        didConfigureSearchIndex = true

        // configure overlay index (it will debounce + search on its own)
        overlay.configureSearchIndex(courses: built.courseEntries, lessons: built.lessonEntries)
    }

    private var searchSection: some View {
        MDSearchSection(
            query: $mainSearchStub,
            placeholder: "поиск"
        )
        .disabled(true)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                overlay.presentSearch()
            }
            Task { @MainActor in
                await ensureOverlaySearchIndexConfigured()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFocused = true
                }
            }
        }
    }

    private var fmSection: some View {
        // DS-driven section (title from DS, no mascot param)
        MDFMSection(
            "ТАЙКА FM",
            messages: TaikaFMData.shared.messages(for: .main)
        )
    }

    private func scheduleMainRefresh(delay: Double = 0.35) {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak main] in
            Task { @MainActor in
                await main?.refresh()
            }
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    // MARK: - Random course loading overlay (scoped to MainView)

    private var randomCourseLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                _DiceLoadingV()
                Text("случайный курс…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
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
            .frame(maxWidth: 280)
            .padding(.horizontal, 16)
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }

    private struct _DiceLoadingV: View {
        @State private var spin: Double = 0
        @State private var pulse: CGFloat = 1

        var body: some View {
            ZStack {
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotation3DEffect(
                        .degrees(spin),
                        axis: (x: 0.7, y: 0.4, z: 0.2)
                    )
                    .scaleEffect(pulse)
                    .shadow(color: Color.black.opacity(0.35), radius: 12, y: 6)
            }
            .frame(width: 56, height: 56)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    spin = 360
                }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse = 1.08
                }
            }
        }
    }

    // MARK: - Step handlers (mirror StepView)

    private func rebuildLearnedState() {
        var next: Set<String> = []
        for (i, ref) in main.dailyPicks.refs.enumerated() {
            guard ref.index >= 0 else { continue }
            if ProgressManager.shared.learnedSet(courseId: ref.courseId, lessonId: ref.lessonId).contains(ref.index),
               let key = stepKey(for: i) {
                next.insert(key)
            }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            self.learnedIds = next
        }
    }

    private func rebuildFavoritesState() {
        var next: Set<String> = []
        for (i, item) in main.dailyPicks.items.enumerated() {
            let ref = main.dailyPicks.refs[i]
            guard ref.index >= 0, !item.isPro else { continue }
            if FavoriteManager.shared.isLiked(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index),
               let key = stepKey(for: i) {
                next.insert(key)
            }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            self.favoriteIds = next
        }
    }

    private func handlePlayItem(_ item: SDStepItem) {
        StepAudio.shared.speakThai(item.subtitleTH)
    }
    private func handleFavItem(_ item: SDStepItem) {
        guard !item.isPro else { return }
        guard let idx = main.dailyPicks.items.firstIndex(where: { $0.id == item.id }) else { return }
        guard idx >= 0, idx < main.dailyPicks.refs.count else { return }
        let ref = main.dailyPicks.refs[idx]
        guard ref.index >= 0 else { return }

        FavoriteManager.shared.toggle(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            rebuildFavoritesState()
        }
    }
    private func handleDoneItem(_ item: SDStepItem) -> Bool {
        guard let idx = main.dailyPicks.items.firstIndex(where: { $0.id == item.id }) else { return false }
        guard idx >= 0, idx < main.dailyPicks.refs.count else { return false }
        let ref = main.dailyPicks.refs[idx]
        guard ref.index >= 0, !item.isPro else { return false }

        // toggle learned
        let wasLearned = ProgressManager.shared
            .learnedSet(courseId: ref.courseId, lessonId: ref.lessonId)
            .contains(ref.index)

        // 1) local UI update immediately
        if let key = stepKey(for: idx) {
            if wasLearned {
                learnedIds.remove(key)
            } else {
                learnedIds.insert(key)
            }
        }

        if wasLearned {
            doneHaptic.notificationOccurred(.warning)
        } else {
            doneHaptic.notificationOccurred(.success)
        }

        // 2) commit progress (slightly deferred to match StepView feel)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            ProgressManager.shared.setStepLearned(
                courseId: ref.courseId,
                lessonId: ref.lessonId,
                index: ref.index,
                isLearned: !wasLearned
            )
        }

        // advance only when we mark as learned; on unlearn do not advance
        return !wasLearned
    }
    // MARK: - Calendar overlay (scoped to MainView)

    private func calendarCourseCard(_ model: MainManager.CourseCardModel, sheetDay: Date) -> some View {
        CardDS.NoteCourseCardV(
            label: (model.cta == .add ? "добавить" : "курс"),
            categoryChip: nil,
            title: model.title,
            subtitle: model.subtitle,
            progress: (courseProgress(model.courseId, isActive: model.cta != .add) ?? 0.0),
            ctaTitle: (calendarSummaryPlannedOnly ? "открыть" : model.cta.title),
            onTap: {
                if calendarSummaryPlannedOnly {
                    openCourse(model.courseId)
                    calendarDayCourses = []
                    return
                }
                switch model.cta {
                case .add:
                    // 1) request add for the currently opened day
                    NotificationCenter.default.post(
                        name: Notification.Name("AddCourseToDayRequested"),
                        object: nil,
                        userInfo: [
                            "courseId": model.courseId,
                            "day": Self.bangkokCal.startOfDay(for: sheetDay)
                        ]
                    )
                    lessonsTick &+= 1
                    addOverlayReloadToken &+= 1
                case .continue:
                    openCourse(model.courseId)
                }

                if case .continue = model.cta {
            // overlay.dismiss() handled in openCourse(courseId)
                    calendarDayCourses = []
                }
            },
            topRightChip: model.categoryChip
        )
    }

    @ViewBuilder
    private func calendarOverlay(sheet: CalendarSheet) -> some View {
        let day = sheet.day
        let taskId = calendarOverlayTaskId(day: day, isAdd: sheet.isAdd, shuffle: addOverlayShuffleToken, reload: addOverlayReloadToken)

        Color.black.opacity(0.28)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.dismiss()
                    calendarDayCourses = []
                }
            }

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                calendarOverlayHeader(sheet: sheet)

                Text(day.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))

                Text(sheet.isAdd
                     ? "выбери курс, чтобы добавить его в план на этот день"
                     : (calendarSummaryPlannedOnly
                        ? "выбери курс и открой его, чтобы начать занятия"
                        : "выбери курс и продолжай с того места, где остановился"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.82))

                calendarOverlayCarousel(sheet: sheet, day: day)
                    .padding(.top, 6)

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: taskId) {
            if sheet.isAdd {
                let isProUser = pro.isPro
                let fetched = await main.availableCoursesForAdd(isProUser: isProUser, proShowcaseLimit: 8)

                let dayStart = Self.bangkokCal.startOfDay(for: day)
                let lastId = session.lastPlannedCourseId(on: dayStart)

                // stable sort:
                // 1) last planned for this day (if any) goes first
                // 2) other planned courses for this day
                // 3) the rest, keeping original order
                let indexed = fetched.enumerated().map { (idx: $0.offset, model: $0.element) }
                let sorted = indexed.sorted { a, b in
                    let aSelected = session.isCoursePlanned(courseId: a.model.courseId, on: dayStart)
                    let bSelected = session.isCoursePlanned(courseId: b.model.courseId, on: dayStart)

                    let aIsLast = (lastId != nil && a.model.courseId == lastId)
                    let bIsLast = (lastId != nil && b.model.courseId == lastId)

                    if aIsLast != bIsLast { return aIsLast && !bIsLast }
                    if aSelected != bSelected { return aSelected && !bSelected }
                    return a.idx < b.idx
                }.map { $0.model }

                calendarDayCourses = sorted
            } else {
                calendarDayCourses = await main.activeCoursesForDay(day, limit: 10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CoursePlanDidChange"))) { _ in
            guard sheet.isAdd else { return }
            // force overlay content refresh (CTA/selected state) without leaving MainView
            addOverlayReloadToken &+= 1
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }

    private func calendarOverlayTaskId(day: Date, isAdd: Bool, shuffle: Int, reload: Int) -> String {
        "\(Self.bangkokCal.startOfDay(for: day).timeIntervalSinceReferenceDate)|\(isAdd ? 1 : 0)|\(shuffle)|\(reload)"
    }

    private func calendarOverlayHeader(sheet: CalendarSheet) -> some View {
        HStack(spacing: 10) {
            Text(sheet.isAdd ? "добавить курс" : "активность за день")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 12)

            if sheet.isAdd {
                Button {
                    addOverlayShuffleToken &+= 1
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.dismiss()
                    calendarDayCourses = []
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }


    private func addOverlayCourseCard(_ model: MainManager.CourseCardModel, day: Date) -> some View {
        let cal = Self.bangkokCal
        let dayStart = cal.startOfDay(for: day)
        let isToday = cal.isDateInToday(dayStart)
        let selected = session.isCoursePlanned(courseId: model.courseId, on: dayStart)

        // variant a hint: already planned on other visible days (today -3 ... today +3), excluding current day
        let today = cal.startOfDay(for: Date())
        var elsewhereDays: [Date] = []
        for off in -3...3 {
            guard let d = cal.date(byAdding: .day, value: off, to: today) else { continue }
            let d0 = cal.startOfDay(for: d)
            if cal.isDate(d0, inSameDayAs: dayStart) { continue }
            if session.isCoursePlanned(courseId: model.courseId, on: d0) {
                elsewhereDays.append(d0)
            }
        }

        let plannedElsewhereHint: String? = {
            guard !elsewhereDays.isEmpty else { return nil }
            if elsewhereDays.count >= 3 {
                return "уже в плане: \(elsewhereDays.count) дня"
            }
            let names: [String] = elsewhereDays.map { d in
                let wd = cal.component(.weekday, from: d)
                return cal.shortWeekdaySymbols[max(0, min(cal.shortWeekdaySymbols.count - 1, wd - 1))].lowercased()
            }
            return "уже в плане: " + names.joined(separator: ", ")
        }()

        let subtitleText: String = {
            let base = model.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let hint = plannedElsewhereHint else { return base }
            if base.isEmpty { return hint }
            return base + " • " + hint
        }()

        let ctaText: String = {
            if selected {
                return isToday ? "продолжить" : "добавлено"
            } else {
                return "добавить"
            }
        }()

        return CardDS.NoteCourseCardV(
            label: selected ? "выбрано" : "добавить",
            categoryChip: nil,
            title: model.title,
            subtitle: subtitleText,
            progress: (courseProgress(model.courseId, isActive: true) ?? 0.0),
            ctaTitle: ctaText,
            onTap: {
                // --- REPLACEMENT LOGIC START ---
                if selected {
                    // already planned for this exact day
                    if isToday {
                        openCourse(model.courseId)
                        return
                    }
                    // toggle off for non-today
                    NotificationCenter.default.post(
                        name: Notification.Name("RemoveCourseFromDayRequested"),
                        object: nil,
                        userInfo: [
                            "courseId": model.courseId,
                            "day": dayStart
                        ]
                    )
                } else {
                    // free-tier: only 1 planned course per day
                    if !pro.isPro {
                        let existing = session.plannedCourseIds(on: dayStart)
                        if !existing.isEmpty {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                overlay.present(.proCoursePaywall(courseId: model.courseId))
                            }
                            return
                        }
                    }

                    // add strictly to the currently opened calendar day
                    NotificationCenter.default.post(
                        name: Notification.Name("AddCourseToDayRequested"),
                        object: nil,
                        userInfo: [
                            "courseId": model.courseId,
                            "day": dayStart
                        ]
                    )
                }

                lessonsTick &+= 1
                addOverlayReloadToken &+= 1
                // --- REPLACEMENT LOGIC END ---
            },
            topRightChip: model.categoryChip
        )
    }

    private func calendarOverlayCarousel(sheet: CalendarSheet, day: Date) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(calendarDayCourses, id: \.id) { model in
                    if sheet.isAdd {
                        addOverlayCourseCard(model, day: day)
                    } else {
                        calendarCourseCard(model, sheetDay: day)
                    }
                }

                if calendarDayCourses.isEmpty {
                    CardDS.NoteCourseCardV(
                        label: "заметка",
                        categoryChip: nil,
                        title: sheet.isAdd ? "выбери курс" : "нет активности",
                        subtitle: sheet.isAdd ? "добавь курс в план" : "в этот день занятий не было",
                        progress: 0,
                        ctaTitle: nil,
                        onTap: { },
                        topRightChip: nil
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }
}


// MARK: - Navigation intents (scoped to MainView)
extension MainView {
    private func openCourse(_ courseId: String) {
        // prevent double pushes in the same frame (DailyPicks can fire multiple callbacks)
        guard !navPushInFlight else { return }
        navPushInFlight = true

        // always dismiss overlays before navigating
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.dismiss()
        }

        DispatchQueue.main.async {
            // treat this as a top-level navigation from main
            nav.reset()
            nav.go(.lessons(courseId: courseId))

            // release throttle after the next runloop (and a tiny buffer)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                navPushInFlight = false
            }
        }
    }

    private func openLesson(courseId: String, lessonId: String) {
        // prevent double pushes in the same frame
        guard !navPushInFlight else { return }
        navPushInFlight = true

        // we don't have a dedicated lesson route in NavigationIntent.Route.
        // Navigate to the course screen; lesson deep-linking is handled inside LessonsView (or later).
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.dismiss()
        }

        DispatchQueue.main.async {
            // treat this as a top-level navigation from main
            nav.reset()
            nav.go(.lessons(courseId: courseId))

            // optional: broadcast the intended lesson so LessonsView can react if it listens
            NotificationCenter.default.post(
                name: Notification.Name("OpenLessonRequested"),
                object: nil,
                userInfo: ["courseId": courseId, "lessonId": lessonId]
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                navPushInFlight = false
            }
        }
    }
}


private struct _ContentMarginsCompat: ViewModifier {
    let horizontal: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.horizontal, horizontal)
        } else {
            content
                .padding(.horizontal, horizontal)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(MainManager.shared)
        .environmentObject(OverlayPresenter.shared)
        .environmentObject(NavigationIntent())
}
