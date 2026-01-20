//
//  ProfileView.swift
//  taika
//
//  Created by product on 23.08.2025.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject private var pro = ProManager.shared
    @StateObject private var profile = ProfileManager.shared

    @State private var showResetAllConfirm = false
    @State private var viewReloadToken = UUID()

    // MARK: - ui bindings (ProfileManager is the single source of truth)
    private var studySelectedBinding: Binding<PDStudyPanel?> {
        Binding(
            get: { profile.studySelected },
            set: { profile.studySelected = $0 }
        )
    }

    private var studySelected: PDStudyPanel? { profile.studySelected }

    private var progressScopeBinding: Binding<PDProgressScope> {
        Binding(
            get: {
                let key = profile.progressScopeKey ?? "courses"
                return key == "lessons" ? .lessons : .courses
            },
            set: { profile.progressScopeKey = ($0 == .lessons ? "lessons" : "courses") }
        )
    }

    private var selectedCourseMetricKeyBinding: Binding<String> {
        Binding(
            get: { profile.selectedCourseMetricKey ?? "courses_completed" },
            set: { profile.selectedCourseMetricKey = $0 }
        )
    }

    private var selectedLessonMetricKeyBinding: Binding<String> {
        Binding(
            get: { profile.selectedLessonMetricKey ?? "lessons_completed" },
            set: { profile.selectedLessonMetricKey = $0 }
        )
    }

    private var activitySelectedDayIndexBinding: Binding<Int?> {
        Binding(get: { profile.activitySelectedDayIndex }, set: { profile.activitySelectedDayIndex = $0 })
    }

    // reset per-panel state when switching accordion section
    private func resetStudyPanelStateIfNeeded(_ newSelection: PDStudyPanel?) {
        guard newSelection != studySelected else { return }
        profile.activitySelectedDayIndex = nil
        profile.selectedCourseMetricKey = "courses_completed"
        profile.selectedLessonMetricKey = "lessons_completed"
        profile.progressScopeKey = "courses"
    }

    private var coursesMetricsSignature: String {
        coursesMetrics.map { $0.key }.joined(separator: "|")
    }

    private var lessonsMetricsSignature: String {
        lessonsMetrics.map { $0.key }.joined(separator: "|")
    }

    // MARK: - data sources (ProfileManager only, no fallback)
    private var coursesMetrics: [PDMetric] { profile.coursesMetrics }

    private var lessonsMetrics: [PDMetric] { profile.lessonsMetrics }

    private var weeklyByCourseMetric: [String: [Double]] { profile.weeklyByCourseMetric }

    private var last7ByCourseMetric: [String: [Double]] { profile.last7ByCourseMetric }

    private var weeklyByLessonMetric: [String: [Double]] { profile.weeklyByLessonMetric }

    private var last7ByLessonMetric: [String: [Double]] { profile.last7ByLessonMetric }

    private var activityWeekDays: [PDActivityDay] { profile.activityWeekDays }


    private var studyEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("пока нет данных")
                .font(PD.FontToken.body(17, weight: .semibold))
                .foregroundColor(PD.ColorToken.text)

            Text("начни урок — и тут появятся прогресс, графики и активность")
                .font(PD.FontToken.caption(13, weight: .medium))
                .foregroundColor(PD.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PD.Spacing.inner)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .fill(PD.ColorToken.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .stroke(PD.ColorToken.stroke, lineWidth: 1)
        )
    }


    private func performFullReset() {
        // 1) explicit manager resets (authoritative)
        ProgressManager.shared.resetAll()
        FavoriteManager.shared.resetAll()
        StepData.shared.resetDailyPicksCache()

        // 2) broadcast changes so views/managers refresh
        NotificationCenter.default.post(name: .init("ProgressDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("FavoritesDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("DailyPicksDidReset"), object: nil)
        NotificationCenter.default.post(name: .init("AppResetAll"), object: nil)

        // 3) light UI reload
        viewReloadToken = UUID()

        // 4) success haptic
        let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
    }

    var body: some View {
        ZStack {
            // App background from Design System
            PD.ColorToken.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: Theme.Layout.sectionGap) {
                        // DS contract: TAIKA FM (marquee) from Profile DS
                        PDFMSection()

                        // === учёба ===
                        PDSection("учёба") {
                            let hasAnyProgressData = !coursesMetrics.isEmpty || !lessonsMetrics.isEmpty
                            let hasAnySeries = !weeklyByCourseMetric.isEmpty || !last7ByCourseMetric.isEmpty || !weeklyByLessonMetric.isEmpty || !last7ByLessonMetric.isEmpty
                            let hasAnyActivity = !activityWeekDays.isEmpty

                            if !(hasAnyProgressData || hasAnySeries || hasAnyActivity) {
                                studyEmptyStateCard
                            } else {
                                let progressPanel = PDProgressPanel(
                                    scope: progressScopeBinding.wrappedValue,
                                    onScopeChange: { progressScopeBinding.wrappedValue = $0 },
                                    coursesMetrics: coursesMetrics,
                                    lessonsMetrics: lessonsMetrics,
                                    selectedCourseMetricKey: selectedCourseMetricKeyBinding,
                                    selectedLessonMetricKey: selectedLessonMetricKeyBinding,
                                    onSelectCourseMetric: { selectedCourseMetricKeyBinding.wrappedValue = $0 },
                                    onSelectLessonMetric: { selectedLessonMetricKeyBinding.wrappedValue = $0 },
                                    weeklyByCourseMetric: weeklyByCourseMetric,
                                    last7ByCourseMetric: last7ByCourseMetric,
                                    weeklyByLessonMetric: weeklyByLessonMetric,
                                    last7ByLessonMetric: last7ByLessonMetric,
                                    style: .appDS
                                )

                                let activityPanel = PDActivityPanel(
                                    days: activityWeekDays,
                                    selectedIndex: activitySelectedDayIndexBinding,
                                    onSelect: { activitySelectedDayIndexBinding.wrappedValue = $0 },
                                    style: .appDS
                                )

                                PDStudyAccordion(
                                    selected: studySelected,
                                    onSelect: {
                                        resetStudyPanelStateIfNeeded($0)
                                        studySelectedBinding.wrappedValue = $0
                                        let gen = UIImpactFeedbackGenerator(style: .soft); gen.impactOccurred()
                                    },
                                    progressContent: { progressPanel },
                                    activityContent: { activityPanel },
                                    style: .appDS
                                )
                            }
                        }
                        PDSection("аккаунт") {
                            PDListGroup([
                                .init(icon: "creditcard", title: "оплата и подписка", action: { print("Payments tapped") }),
                                .init(icon: "rectangle.and.pencil.and.ellipsis", title: "личная информация", action: { print("Personal info tapped") })
                            ])
                        }

                        // === служба ===
                        PDSection("служба") {
                            PDListGroup([
                                .init(icon: "questionmark.circle", title: "помощь и поддержка", action: { print("Help tapped") })
                            ])
                        }

                        // === админ ===
                        PDSection("админ") {
                            VStack(spacing: 0) {
                                // iOS-like switch row: obvious free/pro mode
                                AdminToggleRow(
                                    icon: "crown.fill",
                                    title: "pro режим",
                                    subtitle: "тест: free ↔ pro",
                                    isOn: Binding(
                                        get: { pro.isPro },
                                        set: { newValue in
                                            pro.setDebugPro(newValue)
                                            let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                                        }
                                    )
                                )

                                AdminDivider()

                                AdminActionRow(
                                    icon: "trash",
                                    title: "сбросить всё",
                                    subtitle: "прогресс, лайки, daily picks",
                                    onTap: { showResetAllConfirm = true }
                                )

                                AdminDivider()

                                AdminActionRow(
                                    icon: "clock.arrow.circlepath",
                                    title: "сбросить подборку дня",
                                    subtitle: "очистить кэш daily picks",
                                    onTap: {
                                        StepData.shared.resetDailyPicksCache()
                                        let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                                    }
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                                    .fill(PD.ColorToken.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                                    .stroke(PD.ColorToken.stroke, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, Theme.Layout.pageTopAfterHeader)
                    .padding(.bottom, Theme.Layout.sectionGap)
                    .safeAreaPadding(.bottom, ToolBar.recommendedBottomInset)
                }
            }
            .id(viewReloadToken)
            .alert("сбросить всё?", isPresented: $showResetAllConfirm) {
                Button("отмена", role: .cancel) {}
                Button("сбросить", role: .destructive) { performFullReset() }
            } message: {
                Text("удалим прогресс, лайки, кэш подбора дня и перезапустим ui")
            }
        }
        .task {
            pro.start(session: UserSession.shared)
            profile.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ProgressDidChange"))) { _ in
            profile.refresh()
            viewReloadToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("FavoritesDidChange"))) { _ in
            profile.refresh()
            viewReloadToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("UserSessionActivityDidChange"))) { _ in
            profile.refresh()
            viewReloadToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DailyPicksDidReset"))) { _ in
            profile.refresh()
            viewReloadToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AppResetAll"))) { _ in
            profile.refresh()
            viewReloadToken = UUID()
        }
        .onChange(of: coursesMetricsSignature) { _ in
            let newValue = coursesMetrics
            guard !newValue.isEmpty else { return }
            if !newValue.contains(where: { $0.key == profile.selectedCourseMetricKey }) {
                profile.selectedCourseMetricKey = newValue.first?.key ?? profile.selectedCourseMetricKey
            }
        }
        .onChange(of: lessonsMetricsSignature) { _ in
            let newValue = lessonsMetrics
            guard !newValue.isEmpty else { return }
            if !newValue.contains(where: { $0.key == profile.selectedLessonMetricKey }) {
                profile.selectedLessonMetricKey = newValue.first?.key ?? profile.selectedLessonMetricKey
            }
        }
    }
}


// MARK: - Admin rows (ProfileView local)
private struct AdminToggleRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: PD.Spacing.inner) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PD.ColorToken.chip)
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(PD.ColorToken.stroke, lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(PD.ColorToken.text)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PD.FontToken.body(17, weight: .regular))
                    .foregroundColor(PD.ColorToken.text)
                Text(subtitle)
                    .font(PD.FontToken.caption(13, weight: .medium))
                    .foregroundColor(PD.ColorToken.textSecondary)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, PD.Spacing.inner)
        .padding(.vertical, 14)
    }
}

private struct AdminActionRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PD.Spacing.inner) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PD.ColorToken.chip)
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PD.ColorToken.stroke, lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PD.ColorToken.text)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PD.FontToken.body(17, weight: .regular))
                        .foregroundColor(PD.ColorToken.text)
                    Text(subtitle)
                        .font(PD.FontToken.caption(13, weight: .medium))
                        .foregroundColor(PD.ColorToken.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PD.ColorToken.textSecondary)
            }
            .padding(.horizontal, PD.Spacing.inner)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

private struct AdminDivider: View {
    var body: some View {
        Rectangle()
            .fill(PD.ColorToken.stroke)
            .frame(height: 1)
            .padding(.leading, 68)
    }
}


// MARK: - Preview
#Preview("Profile View") {
    NavigationStack {
        ProfileView()
            .environmentObject(ThemeManager.shared)
    }
    .preferredColorScheme(.dark)
}
