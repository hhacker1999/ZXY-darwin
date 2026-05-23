//
//  ContentView.swift
//
//  Created by Harsh Kumar on 28/03/26.
//

import Inject
import SwiftUI

struct ContentView: View {
    @Bindable private var router = Router.router
    let deps: AppDependencies

    var body: some View {
        rootRoute
            .withGlobalOverlays()
    }

    @ViewBuilder
    private var rootRoute: some View {
        switch router.routerState {
        case .splash:
            SplashView(mediaUc: deps.mediaUc, authUc: deps.authUc)
        case .logIn:
            LoginView(authUc: deps.authUc)
        case let .profileLogIn(profiles):
            ProfileSelectView(profiles: profiles, authUc: deps.authUc)
        case .home:
            NavigationStack(path: $router.mainRouteState) {
                BaseHomeview(deps: deps).navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .movieDetails(id):
                        MovieView(id: id, mediaUc: deps.mediaUc, streamUc: deps.streamUc, progressUc: deps.progressUc)
                    case let .seriesDetails(id):
                        SeriesView(id: id, mediaUc: deps.mediaUc, streamUc: deps.streamUc, progressUc: deps.progressUc)
                    case let .mpvVideoView(args):
                        if args.seasonNo != -1 && args.episodeNo != -1 {
                            MpvPlayerView(streams: args.resItems, selectedStreamIndex: args.selectedIndex, streamUc: deps.streamUc, progressUc: deps.progressUc, mediaId: args.mediaId, seasonNo: args.seasonNo, episodeNo: args.episodeNo, name: args.name)
                        } else {
                            MpvPlayerView(streams: args.resItems, selectedStreamIndex: args.selectedIndex, streamUc: deps.streamUc, progressUc: deps.progressUc, mediaId: args.mediaId, name: args.name)
                        }
                    default:
                        Text("Invalid route")
                    }
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
    }
}
