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
        #if os(tvOS)
        SeriesViewTVOS(vm: vm)
        #else
        ZStack {
            switch vm.seriesState {
            case .initial, .loading:
                HomePageAmbientBackground(gradient: .default)
                    .ignoresSafeArea()
                MediaViewShimmer(isMobile: isMobile)
            case let .error(err):
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
        .onDisappear {
            vm.streamsTask?.cancel()
        }
        .onChange(of: Router.router.mainRouteState) { old, _ in
            guard let oldRoute = old.last else {
                return
            }
            if case let .mpvVideoView(args) = oldRoute {
                if args.mediaId == "\(vm.id)" {
                    Task {
                        await vm.fetchShowProgress(loadOverlay: true, afterVideoEnds: true)
                    }
                }
            }
        }
        #if os(macOS)
            .onAppear {
                vm.syncDiscordPresenceIfLoaded()
            }
            .overlay(alignment: .top) {
                switch vm.seriesState {
                case .error:
                    EmptyView()
                default:
                    MediaDetailMacTopBar(
                        showLibraryButton: {
                            if case .loaded = vm.seriesState { return true }
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
        #elseif os(iOS)
            .toolbar {
                if case .loaded = vm.seriesState {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await vm.updateInLibrary() }
                        } label: {
                            Label(
                                vm.isInLibrary ? "In Library" : "Add to Library",
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
        .enableInjection()
        #endif
    }
}

