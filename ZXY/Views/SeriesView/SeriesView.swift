import Foundation
import Inject
import SwiftUI

struct SeriesView: View {
    @ObserveInjection var inject
    @State var vm: SeriesViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(id: Int, mediaUc: MediaUsecase, streamUc: StreamUsecase, progressUc: ProgressUsecase) {
        vm = SeriesViewModel(id: id, mediaUc: mediaUc, streamUc: streamUc, progressUc: progressUc)
    }

    private var isMobile: Bool {
        #if os(iOS)
            return horizontalSizeClass == .compact
        #else
            return false
        #endif
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            switch vm.seriesState {
            case .initial, .loading:
                MediaViewShimmer(isMobile: isMobile)
            case let .error(err):
                VStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        Router.router.popRoute()
                    } label: {
                        Text("Go Back")
                            .font(AppTheme.Typography.labelLarge)
                            .foregroundStyle(AppTheme.Colors.buttonPrimaryLabel)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: AppTheme.Radius.sm,
                                    style: .continuous
                                )
                                .fill(AppTheme.Colors.buttonPrimary)
                            )
                    }
                    .buttonStyle(.plain)
                    Text(err)
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                }
            case let .loaded(details):
                MediaLoadedContent(
                    details: MediaDetails(from: details),
                    isMobile: isMobile,
                    seriesVm: vm
                )
            }
        }
        .task {
            await vm.initialise()
        }
        .navigationBarBackButtonHidden(true)
        .enableInjection()
    }
}


