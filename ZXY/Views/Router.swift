//
//  Router.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 31/03/26.
//

import Foundation
import SwiftUI

enum Route: Hashable {
    case home
    case movieDetails(Int)
    case seriesDetails(Int)
    case mpvVideoView([ResolutionItem], Int)
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
