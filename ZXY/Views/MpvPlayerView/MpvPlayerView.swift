import Foundation
import SwiftUI

enum FocusElement {
    case video
}

/// `@State` initializers run on every `View` init, and SwiftUI drops the extras.
/// This box is the cheap discarded object; `MpvViewModel` is created once, on first use.
@MainActor
private final class MpvPlayerSession {
    private let streamVm: any StreamViewModel
    private var viewModel: MpvViewModel?

    init(streamVm: any StreamViewModel) {
        self.streamVm = streamVm
    }

    func resolve() -> MpvViewModel {
        if let viewModel {
            return viewModel
        }
        let created = MpvViewModel(streamVm: streamVm)
        viewModel = created
        return created
    }
}

struct MpvPlayerView: View {
    @State private var session: MpvPlayerSession
    @FocusState var currentFocus: FocusElement?

    #if os(iOS)
        @State private var showVideoStatsSheet = false
    #endif

    init(streamVm: any StreamViewModel) {
        _session = State(initialValue: MpvPlayerSession(streamVm: streamVm))
    }

    var body: some View {
        let vm = session.resolve()
        VStack {
            MPVMetalPlayerView(coordinator: vm)
                .onChange(of: vm.videoInFocus) {
                    if vm.videoInFocus {
                        currentFocus = .video
                    }
                }
                .onAppear {
                    currentFocus = .video
                }
                .focusable()
                .focused($currentFocus, equals: .video)
                .focusEffectDisabled()
                .overlay {
                    Group {
                        #if os(iOS)
                            OverlayView(
                                title:
                                "\(vm.name)\(vm.seasonNo != -1 ? "(S\(String(format: "%02d", vm.seasonNo))" : "")\(vm.episodeNo != -1 ? ":E\(String(format: "%02d", vm.episodeNo)))" : "")",
                                vm: vm,
                                onBack: {
                                    Router.router.popRoute()
                                },
                                onShowVideoStatsSheet: {
                                    vm.onUserInteraction()
                                    showVideoStatsSheet = true
                                }
                            )
                        #else
                            OverlayView(
                                title:
                                "\(vm.name)\(vm.seasonNo != -1 ? "(S\(String(format: "%02d", vm.seasonNo))" : "")\(vm.episodeNo != -1 ? ":E\(String(format: "%02d", vm.episodeNo)))" : "")",
                                vm: vm,
                                onBack: {
                                    Router.router.popRoute()
                                }
                            )
                        #endif
                    }
                    .opacity(vm.overlayVisible ? 1 : 0)
                }
            #if os(macOS)
                .overlay(alignment: .topLeading) {
                    VideoInfoOverlayView(vm: vm)
                        .padding(.top, 70)
                        .padding(.leading, 24)
                        .opacity(vm.showVideoInfoOverlay ? 1 : 0)
                }
            #endif
                .overlay(alignment: .center) {
                    LoadingOverlayView(vm: vm)
                }
                .onTapGesture { [weak vm] in
                    currentFocus = .video
                    if let vm = vm {
                        vm.onUserInteraction()
                    }
                }
                #if os(macOS)
                .onContinuousHover { [weak vm] phase in
                    if case .active = phase {
                        if let vm = vm {
                            vm.onUserInteraction()
                        }
                    }
                }
                #endif
                .onKeyPress(action: { key in
                    debugPrint("key: \(key.characters)")
                    return .handled
                })
                .onKeyPress(
                    .upArrow,
                    action: {
                        vm.setVolume(vm.volume + 5)
                        return .handled
                    }
                )
                .onKeyPress(
                    .downArrow,
                    action: {
                        vm.setVolume(vm.volume - 5)
                        return .handled
                    }
                )
                .onKeyPress(
                    .leftArrow,
                    action: {
                        let skipDuration = SettingsBloc.bloc.skipDuration
                        vm.seek(relative: TimeInterval(-skipDuration))
                        return .handled
                    }
                )
                .onKeyPress(
                    .rightArrow,
                    action: {
                        let skipDuration = SettingsBloc.bloc.skipDuration
                        vm.seek(relative: TimeInterval(skipDuration))
                        return .handled
                    }
                )
                .onKeyPress(
                    .space,
                    action: {
                        vm.togglePause()
                        return .handled
                    }
                )
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
                #if os(macOS)
                .onAppear {
                    let season = vm.seasonNo >= 0 ? vm.seasonNo : nil
                    let episode = vm.episodeNo >= 0 ? vm.episodeNo : nil
                    DiscordRichPresenceBloc.bloc.setWatching(
                        title: vm.name,
                        season: season,
                        episode: episode,
                        backdropPath: vm.backdropPath
                    )
                }
                #endif
            #if os(iOS)
                .navigationBarBackButtonHidden(true)
                .navigationTitle("")
                .toolbarBackground(.hidden, for: .navigationBar)
            #endif
                .onDisappear {
                    vm.cleanUp()
                }
        }
        #if os(iOS)
        .sheet(isPresented: $showVideoStatsSheet) {
            NavigationStack {
                ScrollView {
                    VideoInfoOverlayView(vm: vm, style: .sheetContent)
                        .padding(.horizontal, 8)
                }
                .navigationTitle("Video Stats")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        #endif
    }
}

struct LoadingOverlayView: View {
    let vm: MpvViewModel

    var body: some View {
        return Group {
            if vm.loading || vm.fetchingStreams {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.2)
                        .tint(.white.opacity(0.8))
                    Text(
                        vm.loading
                            ? vm.downloadSpeed != 0
                            ? String(format: "%.2f Mbps", vm.downloadSpeed)
                            : "Loading"
                            : "Fetching Streams"
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .infoOverlayGlass()
                .transition(.opacity)
            } else {
                EmptyView().opacity(0)
            }
        }
    }
}
