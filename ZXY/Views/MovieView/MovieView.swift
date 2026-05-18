import Foundation
import Inject
import SwiftUI

struct MovieView: View {
    @ObserveInjection var inject
    @State var vm: MovieViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        id: Int,
        mediaUc: MediaUsecase,
        streamUc: StreamUsecase,
        progressUc: ProgressUsecase
    ) {
        vm = MovieViewModel(
            id: id,
            mediaUc: mediaUc,
            streamUc: streamUc,
            progressUc: progressUc
        )
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
            switch vm.movieState {
            case .initial, .loading:
                AppTheme.Colors.background.ignoresSafeArea()
                MediaViewShimmer(isMobile: isMobile)
            case .error(let err):
                AppTheme.Colors.background.ignoresSafeArea()
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
            case .loaded(let details):
                MediaLoadedContent(
                    details: MediaDetails(from: details),
                    isMobile: isMobile,
                    streamState: vm.streamsState,
                    movieProgress: vm.progress,
                    movieIsWatched: vm.isWatched,
                    onMarkMovieWatched: {
                        Task { await vm.markWatched() }
                    }
                )
            }
        }
        .task {
            await vm.initialise()
        }
        .onDisappear {
            vm.streamTask?.cancel()
        }
        .onChange(of: Router.router.mainRouteState) { old, _ in
            guard let oldRoute = old.last else {
                return
            }
            if case .mpvVideoView(let args) = oldRoute {
                if args.mediaId == "\(vm.id)" {
                    Task {
                        await vm.fetchMovieProgress(loadOverlay: true)
                    }
                }
            }
        }
        #if os(macOS)
            .overlay(alignment: .top) {
                switch vm.movieState {
                case .error:
                    EmptyView()
                default:
                    MediaDetailMacTopBar(
                        showLibraryButton: {
                            if case .loaded = vm.movieState { return true }
                            return false
                        }(),
                        isInLibrary: vm.isInLibrary,
                        onBack: { Router.router.popRoute() },
                        onLibrary: { Task { await vm.updateInLibrary() } }
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .automatic)
            .toolbarBackground(.hidden, for: .windowToolbar)
        #else
            .toolbar {
                if case .loaded = vm.movieState {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await vm.updateInLibrary() }
                        } label: {
                            Label(
                                vm.isInLibrary
                                    ? "In Library" : "Add to Library",
                                systemImage: vm.isInLibrary
                                    ? "bookmark.fill" : "bookmark"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        #endif
    }
}
