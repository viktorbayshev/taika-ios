import SwiftUI

// MARK: - shell header visibility
/// Preference used by child screens to request the AppShell top header to be hidden.
public struct ShellHeaderHiddenPreferenceKey: PreferenceKey {
    public static var defaultValue: Bool = false
    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        // last writer wins (allows deeper screens to override parent preferences)
        value = nextValue()
    }
}

// Back-compat aliases (some screens still reference these names)
public typealias GlobalHeaderHiddenPreferenceKey = ShellHeaderHiddenPreferenceKey
public typealias ShellHideHeaderPreferenceKey = ShellHeaderHiddenPreferenceKey

extension View {
    /// Requests AppShell to hide its top header for this subtree.
    public func shellHeaderHidden(_ hidden: Bool = true) -> some View {
        preference(key: ShellHeaderHiddenPreferenceKey.self, value: hidden)
    }
}

struct AppShell: View {
    @State private var selectedTab: Int = 0
    @State private var showSplash: Bool = true
    @State private var hideShellHeader: Bool = false

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                // switching tabs must always reset pushed routes so the toolbar behaves like a real root tab bar
                if selectedTab != newValue {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        selectedTab = newValue
                        if !nav.path.isEmpty { nav.path.removeAll() }
                    }
                }
            }
        )
    }

    @StateObject private var favorites = FavoriteManager.shared
    @StateObject private var overlay = OverlayPresenter.shared
    @StateObject private var nav = NavigationIntent()
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var pro = ProManager.shared

    private var shouldShowShellHeader: Bool {
        // Child screens can request the shell header to be hidden via .shellHeaderHidden(true).
        // This must apply for both root tabs and pushed routes.
        return !hideShellHeader
    }

    var body: some View {
        ZStack {
            if showSplash {
                SplashTaikaView {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                        showSplash = false
                        selectedTab = 0
                    }
                }
                .background(PD.ColorToken.background.ignoresSafeArea())
            } else {
                VStack(spacing: 0) {
                    NavigationStack(path: $nav.path) {
                        tabContent
                        .navigationDestination(for: NavigationIntent.Route.self) { route in
                            switch route {
                            case .lessons(let courseId):
                                if courseId.isEmpty {
                                    VStack(spacing: 12) {
                                        Text("navigation error")
                                            .font(.headline)
                                        Text("missing courseId")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(PD.ColorToken.background.ignoresSafeArea())
                                } else {
                                    LessonsView(courseId: courseId)
                                }
                            default:
                                VStack(spacing: 12) {
                                    Text("navigation destination is missing")
                                        .font(.headline)
                                    Text(String(describing: route))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(PD.ColorToken.background.ignoresSafeArea())
                            }
                        }
                    }
                    // child screens can request shell header hide via .shellHeaderHidden(true)
                    .onPreferenceChange(ShellHeaderHiddenPreferenceKey.self) { hideShellHeader = $0 }
                    // use a real top inset so content never renders under the header (toolbar-like behavior)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if shouldShowShellHeader {
                            headerLayer
                                .frame(maxWidth: .infinity)
                                .frame(height: headerBarHeight)
                                .background(PD.ColorToken.background)
                                .zIndex(10)
                        } else {
                            EmptyView()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ToolBar(selectedTab: tabSelection)
                        .background(PD.ColorToken.background.ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(theme.preferredScheme)
        .environmentObject(theme)
        .environmentObject(favorites)
        .environmentObject(overlay)
        .environmentObject(nav)
        .environmentObject(pro)
        .onAppear {
            Task.detached {
                StepData.shared.preload()
                LessonsData.shared.preload()
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            MainView()
        case 1:
            CourseView()
        case 2:
            if pro.isPro {
                SpeakerView()
            } else {
                PROView(courseId: "__speaker__") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        selectedTab = 0
                    }
                }
            }
        case 3:
            FavoriteView()
        case 4:
            ProfileView()
        default:
            MainView()
        }
    }

    private var headerBarHeight: CGFloat { 56 }

    @ViewBuilder
    private var headerLayer: some View {
        if nav.path.isEmpty {
            AppHeader(
                showSearch: false,
                showHeart: true,
                showProfile: true,
                showPro: true,
                onTapHeart: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        overlay.presentAccentPicker()
                    }
                },
                onTapProfile: {
                    theme.toggleTheme()
                },
                onTapPro: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        overlay.present(.proCoursePaywall(courseId: "__pro__"))
                    }
                },
                isPro: pro.isPro
            )
        } else {
            AppBackHeader(variant: .solid) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                    if !nav.path.isEmpty {
                        nav.path.removeLast()
                    }
                }
            }
        }
    }
}

#Preview {
    AppShell()
}
