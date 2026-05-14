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
    case home([Route])
}

@MainActor
@Observable
class Router {
    static let router = Router()

    private init() {}

    var routerState: RouterState = .splash

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
