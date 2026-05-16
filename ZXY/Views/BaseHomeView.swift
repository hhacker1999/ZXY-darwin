import Foundation
import SwiftUI

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
}

struct BaseHomeview: View {
    @State var selectedPage: BaseHomeViewPages = .home
    let deps: AppDependencies

    var body: some View {
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
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ZXY")
            // .navigationBarBackButtonHidden(true)
            .navigationSplitViewColumnWidth(min: 232, ideal: 256, max: 296)

        } detail: {
            switch selectedPage {
            case .home:
                HomeView(mediaUc: deps.mediaUc, progressUc: deps.progressUc)
            case .discover:
                DiscoverView(mediaUc: deps.mediaUc, authUc: deps.authUc)
            case .search:
                SearchView(mediaUc: deps.mediaUc)
            case .library:
                LibraryView(mediaUc: deps.mediaUc)
            case .settings:
                SettingsView(authUc: deps.authUc)
            }
        }
        // .toolbar(removing: .sidebarToggle)
        // .toolbar(.hidden, for: .windowToolbar)
        .accentColor(.white)
    }
}
