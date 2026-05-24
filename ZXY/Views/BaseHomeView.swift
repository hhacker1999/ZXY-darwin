import Foundation
import SwiftUI
#if os(iOS)
    import UIKit
#endif

enum BaseHomeViewPages: String, CaseIterable, Identifiable {
    case home = "Home"
    case discover = "Discover"
    case search = "Search"
    case library = "Library"
    case settings = "Settings"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .discover: return "sparkles.rectangle.stack"
        case .search: return "magnifyingglass"
        case .library: return "film.stack"
        case .settings: return "gearshape.fill"
        }
    }

    /// Pages shown in the tvOS top tab bar.
    static var tvOSTabs: [BaseHomeViewPages] {
        [.home, .search, .library, .settings]
    }
}

struct BaseHomeview: View {
    @State var selectedPage: BaseHomeViewPages = .home
    @State private var ambientGradient: HomeAmbientGradient = .default
    @State private var vm: HomeViewModel
    let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
        vm =
            HomeViewModel(
                mediaUc: deps.mediaUc,
                progressUc: deps.progressUc
            )
    }

    var body: some View {
        Group {
            #if os(tvOS)
                tvosTabChrome
            #elseif os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    iosTabChrome
                } else {
                    macSidebarSplitChrome
                }
            #else
                macSidebarSplitChrome
            #endif
        }
        .accentColor(.white)
    }

    // MARK: - tvOS

    #if os(tvOS)
        private var tvosTabChrome: some View {
            TabView(selection: $selectedPage) {
                ForEach(BaseHomeViewPages.tvOSTabs) { page in
                    detailContent(for: page)
                        .tabItem {
                            Label(page.rawValue, systemImage: page.icon)
                        }
                        .tag(page)
                }
            }
            .background {
                if selectedPage != .home {
                    HomePageAmbientBackground(gradient: ImageGradientAndStoreBloc.bloc.currentGradient)
                }
            }
        }
    #endif

    // MARK: - iOS

    #if os(iOS)
        private var iosTabChrome: some View {
            ZStack {
                HomePageAmbientBackground(gradient: ambientGradient)

                TabView(selection: $selectedPage) {
                    ForEach(BaseHomeViewPages.allCases) { page in
                        detailContent(for: page)
                            .tabItem {
                                Label(page.rawValue, systemImage: page.icon)
                            }
                            .tag(page)
                    }
                }
            }
        }
    #endif

    // MARK: - macOS / iPad sidebar

    #if !os(tvOS)
    private var macSidebarSplitChrome: some View {
        NavigationSplitView {
            List {
                Spacer().frame(height: AppTheme.Spacing.lg)

                ForEach(BaseHomeViewPages.allCases) { item in
                    let isSelected = selectedPage == item
                    Button {
                        selectedPage = item
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 24, alignment: .center)

                            Text(item.rawValue)
                                .font(AppTheme.Typography.bodyLarge.weight(.medium))

                            Spacer()
                        }
                        .foregroundStyle(isSelected ? AppTheme.Colors.buttonPrimaryLabel : AppTheme.Colors.elementSubtle)
                        .padding(.vertical, 10)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(
                        EdgeInsets(
                            top: 4,
                            leading: AppTheme.Spacing.md,
                            bottom: 4,
                            trailing: AppTheme.Spacing.md
                        )
                    )
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .fill(isSelected ? AppTheme.Colors.buttonPrimary : Color.clear)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                    )
                    .hideListRowSeparator()
                }
            }
            .sidebarNavigationListStyle()
            .sidebarColumnWidth(min: 232, ideal: 256, max: 296)

        } detail: {
            ZStack {
                HomePageAmbientBackground(gradient: ImageGradientAndStoreBloc.bloc.currentGradient)
                detailContent(for: selectedPage)
            }
        }
        #if os(macOS)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .automatic)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .windowToolbarFullScreenVisibility(.onHover)
        #endif
    }
    #endif

    @ViewBuilder
    private func detailContent(for page: BaseHomeViewPages) -> some View {
        switch page {
        case .home:
            #if os(tvOS)
                HomeViewTVOS(vm: vm)
            #else
                HomeView(
                    vm: $vm,
                    ambientGradient: $ambientGradient
                )
            #endif
        case .discover:
            DiscoverView(mediaUc: deps.mediaUc, authUc: deps.authUc)
        case .search:
            #if os(tvOS)
                SearchViewTVOS(mediaUc: deps.mediaUc)
            #else
                SearchView(mediaUc: deps.mediaUc)
            #endif
        case .library:
            #if os(tvOS)
                LibraryViewTVOS(mediaUc: deps.mediaUc)
            #else
                LibraryView(mediaUc: deps.mediaUc)
            #endif
        case .settings:
            #if os(tvOS)
                SettingsViewTVOS(authUc: deps.authUc)
            #else
                SettingsView(authUc: deps.authUc)
            #endif
        }
    }
}
