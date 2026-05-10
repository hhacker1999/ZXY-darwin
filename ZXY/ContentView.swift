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
                        MovieView(id: id, mediaUc: deps.mediaUc, streamUc: deps.streamUc)
                    case let .seriesDetails(id):
                        SeriesView(id: id, mediaUc: deps.mediaUc, streamUc: deps.streamUc, progressUc: deps.progressUc)
                    case let .mpvVideoView(streams, index):
                        MpvPlayerView(streams: streams, selectedStreamIndex: index, streamUc: deps.streamUc)
                    default:
                        Text("Invalid route")
                    }
                }
            }
        }
    }
}
