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
                            .navigationTransition(.crossFade)
                    }
            }
        #else
            NavigationStack {
                ZStack {
                    BaseHomeview(deps: deps)
                        .allowsHitTesting(router.mainRouteState.isEmpty)

                    ForEach(router.mainRouteState, id: \.self) { route in
                        destination(for: route)
                            .transition(.opacity)
                            .allowsHitTesting(router.mainRouteState.last == route)
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: router.mainRouteState)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .automatic)
            .toolbarBackground(.hidden, for: .windowToolbar)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .windowToolbarFullScreenVisibility(.onHover)
        #endif
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case let .movieDetails(id):
            MovieView(id: id, mediaUc: deps.mediaUc, streamUc: deps.streamUc, progressUc: deps.progressUc, stremioUc: deps.streamioUc)
        case let .seriesDetails(id):
            SeriesView(id: id, mediaUc: deps.mediaUc, streamUc: deps.streamUc, progressUc: deps.progressUc)
        case let .mpvVideoView(route):
            MpvPlayerView(streamVm: route.viewModel)
        default:
            Text("Invalid route")
        }
    }
}
