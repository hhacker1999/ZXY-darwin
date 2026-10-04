//
//  Router.swift
//
//  Created by Harsh Kumar on 31/03/26.
//

import Foundation
import SwiftUI

final class StreamPlaybackRoute: Hashable {
    let viewModel: any StreamViewModel

    init(viewModel: any StreamViewModel) {
        self.viewModel = viewModel
    }

    static func == (lhs: StreamPlaybackRoute, rhs: StreamPlaybackRoute) -> Bool {
        lhs.viewModel === rhs.viewModel
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(viewModel))
    }
}

enum Route: Hashable {
    case home
    case movieDetails(Int)
    case seriesDetails(Int)
    case mpvVideoView(StreamPlaybackRoute)

    var isMpvPlayback: Bool {
        if case .mpvVideoView = self { return true }
        return false
    }
}

enum RouterState: Hashable, Equatable {
    case splash
    case logIn
    case profileLogIn([Profile])
    case home
}

@MainActor
@Observable
class Router {
    static let router = Router()

    /// Matches `addToRoute` / `popRoute` and home-route push animations.
    static let navigationTransitionDuration: TimeInterval = 0.28

    private init() {}

    var routerState: RouterState = .splash

    /// Backs `NavigationStack(path:)` (see `ContentView`). User-driven pops—including the
    /// interactive swipe back—and the system bar back button rewrite this array through the
    /// same `Binding` as `addToRoute` / `popRoute`, so router state stays aligned with the UI.
    var mainRouteState: [Route] = []

    func addToRoute(route: Route) {
        withAnimation(.easeInOut(duration: Self.navigationTransitionDuration)) {
            mainRouteState.append(route)
        }
    }

    func popRoute() {
        _ = withAnimation(.easeInOut(duration: Self.navigationTransitionDuration)) {
            mainRouteState.popLast()
        }
    }
}
