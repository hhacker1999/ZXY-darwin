import Foundation
import Inject
import SwiftUI

struct LibraryView: View {
    @ObserveInjection var inject
    @State var vm: LibraryViewModel

    init(mediaUc: MediaUsecase) {
        vm = LibraryViewModel(mediaUc: mediaUc)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Library")
                    .font(AppTheme.Typography.headingLarge)
                    .foregroundColor(AppTheme.Colors.elementWhite)

                Spacer()
            }
            .padding(.horizontal, AppTheme.Layout.tabScreenHorizontalPadding)
            .padding(.top, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.md)

            MediaGrid(
                itemState: vm.itemsState,
                initialText: "Your library is empty",
                showType: true,
                onScrollNearEnd: {
                    Task {
                        await vm.loadMore()
                    }
                },
                id: "library",
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
        .task {
            await vm.initialLoad()
        }
        .enableInjection()
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }
}
