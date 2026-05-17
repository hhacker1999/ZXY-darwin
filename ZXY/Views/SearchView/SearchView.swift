import Foundation
import Inject
import SwiftUI

struct SearchView: View {
    @ObserveInjection var inject
    @State var vm: SearchViewModel
    @State private var searchText: String = ""

    init(mediaUc: MediaUsecase) {
        vm = SearchViewModel(mediaUc: mediaUc)
    }

    /// iOS: title + field don’t fit one row; macOS keeps title beside a fixed-width field.
    private var useCompactSearchHeader: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if useCompactSearchHeader {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Search")
                            .font(AppTheme.Typography.headingLarge)
                            .foregroundColor(AppTheme.Colors.elementWhite)

                        searchFieldChrome
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(alignment: .center) {
                        Text("Search")
                            .font(AppTheme.Typography.headingLarge)
                            .foregroundColor(AppTheme.Colors.elementWhite)

                        Spacer()

                        searchFieldChrome
                            .frame(width: 320)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Layout.tabScreenHorizontalPadding)
            .padding(.top, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.md)

            MediaGrid(
                itemState: vm.itemsState,
                initialText: "Search movie or show by name",
                showType: true,
                onScrollNearEnd: {
                    Task {
                        await vm.loadMoreResults()
                    }
                },
                id: vm.keyword,
                onItemTapped: { item in
                    if item.type == "movie" {
                        Router.router.addToRoute(route: .movieDetails(item.id))
                    } else {
                        Router.router.addToRoute(route: .seriesDetails(item.id))
                    }
                }
            )
            .padding(.horizontal, AppTheme.Layout.mediaGridOuterAlignmentPadding)
        }
        .enableInjection()
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private var searchFieldChrome: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.elementMuted)

            TextField("Movies or Shows", text: $searchText)
                .textFieldStyle(.plain)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.Colors.elementWhite)
                .onChange(of: searchText) { _, newvalue in
                    if newvalue.isEmpty {
                        vm.reset()
                    }
                }
                .onSubmit {
                    Task {
                        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                            await vm.loadResults(keyword: searchText)
                        }
                    }
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    vm.reset()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.elementMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}
