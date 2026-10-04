//
//  ContentView.swift
//
//  Created by Harsh Kumar on 28/03/26.
//

import SwiftUI

struct ContentView: View {
    @Bindable private var router = Router.router
    let deps: AppDependencies

    var body: some View {
        rootRoute
            .withGlobalOverlays()
            #if os(macOS)
            .onChange(of: router.mainRouteState) { _, routes in
                DiscordRichPresenceBloc.bloc.handleNavigationStack(routes)
            }
            #endif
    }

    @ViewBuilder
    private var rootRoute: some View {
        switch router.routerState {
        case .splash:
            SplashView(mediaUc: deps.mediaUc, authUc: deps.authUc, stremioUc: deps.streamioUc)
        case .logIn:
            LoginView(authUc: deps.authUc)
        case let .profileLogIn(profiles):
            ProfileSelectView(profiles: profiles, authUc: deps.authUc, stremioUc: deps.streamioUc)
        case .home:
            homeRoute
        }
    }

    @ViewBuilder
    private var homeRoute: some View {
        #if os(iOS)
            NavigationStack(path: $router.mainRouteState) {
                BaseHomeview(deps: deps)
                    .navigationTransition(.crossFade)
                    .navigationDestination(for: Route.self) { route in
                        destination(for: route)
                            .navigationTransition(
                                route.isMpvPlayback
                                    ? .automatic
                                    : .crossFade
                            )
                    }
            }
        #else
            NavigationStack {
                ZStack {
                    BaseHomeview(deps: deps)
                        .allowsHitTesting(router.mainRouteState.isEmpty)

                    ForEach(router.mainRouteState, id: \.self) { route in
                        destination(for: route)
                            .transition(navigationTransition(for: route))
                            .allowsHitTesting(router.mainRouteState.last == route)
                    }
                }
                .animation(.easeInOut(duration: Router.navigationTransitionDuration), value: router.mainRouteState)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .automatic)
            .toolbarBackground(.hidden, for: .windowToolbar)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .windowToolbarFullScreenVisibility(.onHover)
        #endif
    }

    private func navigationTransition(for route: Route) -> AnyTransition {
        if case .mpvVideoView = route {
            // Opacity push animates the layer mpv binds to; VO can stay black while audio plays.
            return .identity
        }
        return .opacity
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case let .movieDetails(id):
            MovieView(id: id, mediaUc: deps.mediaUc, streamUc: deps.streamUc, progressUc: deps.progressUc, stremioUc: deps.streamioUc)
        case let .seriesDetails(id):
            SeriesView(
                id: id,
                mediaUc: deps.mediaUc,
                streamUc: deps.streamUc,
                progressUc: deps.progressUc,
                stremioUc: deps.streamioUc
            )
        case let .mpvVideoView(route):
            MpvPlayerView(streamVm: route.viewModel)
        default:
            Text("Invalid route")
        }
    }
}
