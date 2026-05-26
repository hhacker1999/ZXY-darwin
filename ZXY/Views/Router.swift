//
//  Router.swift
//
//  Created by Harsh Kumar on 31/03/26.
//

import Foundation
import SwiftUI

struct MPVViewArgs: Hashable {
    let resItems: [ResolutionItem]
    let selectedIndex: Int
    let mediaId: String
    let episodeNo: Int
    let seasonNo: Int
    let name: String
    let backdropPath: String?

    init(
        resItems: [ResolutionItem],
        selectedIndex: Int,
        mediaId: String,
        episodeNo: Int,
        seasonNo: Int,
        name: String,
        backdropPath: String? = nil
    ) {
        self.resItems = resItems
        self.selectedIndex = selectedIndex
        self.mediaId = mediaId
        self.episodeNo = episodeNo
        self.seasonNo = seasonNo
        self.name = name
        self.backdropPath = backdropPath
    }
}

enum Route: Hashable {
    case home
    case movieDetails(Int)
    case seriesDetails(Int)
    case mpvVideoView(MPVViewArgs)
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

    private init() {}

    var routerState: RouterState = .splash

    /// Backs `NavigationStack(path:)` (see `ContentView`). User-driven pops—including the
    /// interactive swipe back—and the system bar back button rewrite this array through the
    /// same `Binding` as `addToRoute` / `popRoute`, so router state stays aligned with the UI.
    var mainRouteState: [Route] = []

    func addToRoute(route: Route) {
        withAnimation(.easeInOut) {
            mainRouteState.append(route)
        }
    }

    func popRoute() {
        _ = withAnimation(.easeInOut) {
            mainRouteState.popLast()
        }
    }
}
