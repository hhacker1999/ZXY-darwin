//
//  SplashViewModel.swift
//
//  Created by Harsh Kumar on 03/04/26.
//

import Foundation

@MainActor
@Observable
class SplashViewModel {
    let mediaUc: MediaUsecase
    let authUc: AuthUsecase
    let httpService: HttpService = .service
    let router: Router = .router

    var err: String?

    init(mediaUc: MediaUsecase, authUc: AuthUsecase) {
        self.mediaUc = mediaUc
        self.authUc = authUc
    }

    func initialise() async {
        do {
            // Public `/genre` endpoint — same as Flutter `HomeViewModel.initialiseGenre()` run from splash.
            try await initialiseGenre()
            let haveCookies = httpService.loadCookiesIfPresent()
            if !haveCookies {
                router.routerState = .logIn
                return
            }
            try await initialiseUserAndProfile()
        } catch let error as HttpError {
            err = error.error()
        } catch {
            err = error.localizedDescription
        }
    }

    /// Loads TMDB genre maps into `MediaConfig` (public API, no auth). Parity with Flutter `initialiseGenre()`.
    private func initialiseGenre() async throws {
        var moviesGenre: [Int: Genre] = [:]
        var showsGenre: [Int: Genre] = [:]
        let genreRes = try await mediaUc.getGenre()
        for genre in genreRes.movieGenre {
            moviesGenre[genre.id] = genre
        }
        for genre in genreRes.showGenre {
            showsGenre[genre.id] = genre
        }
        MediaConfig.instance.movieGenres = moviesGenre
        MediaConfig.instance.showGenres = showsGenre
    }

    private func initialiseUserAndProfile() async throws {
        var profiles: [Profile]?
        do {
            let user = try await authUc.getUser()
            profiles = user.profiles
            UserBloc.bloc.user = user
            let profile = try await authUc.getProfile()
            UserBloc.bloc.profile = profile
            Router.router.routerState = .home([])
        } catch _ as UnAuthorised {
            if let profiles = profiles {
                Router.router.routerState = .profileLogIn(profiles)
            } else {
                Router.router.routerState = .logIn
            }
        }
    }
}
