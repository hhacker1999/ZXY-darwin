import Foundation
import SwiftUI

@MainActor
@Observable
class MovieViewModel {
    let mediaUc: MediaUsecase
    let streamUc: StreamUsecase
    let progressUc: ProgressUsecase
    let userBloc: UserBloc = .bloc
    let id: Int
    init(id: Int, mediaUc: MediaUsecase, streamUc: StreamUsecase, progressUc: ProgressUsecase) {
        self.id = id
        self.mediaUc = mediaUc
        self.streamUc = streamUc
        self.progressUc = progressUc
    }

    var movieState: ViewItemState<MovieDetails> = .initial
    var streamsState: ViewItemState<[ResolutionItem]> = .initial
    var progress: Double = 0
    var isWatched: Bool = false
    var isInLibrary: Bool = false

    @ObservationIgnored
    var streamTask: Task<Void, Never>?

    func initialise() async {
        // Avoid shredding loaded UI when NavigationStack restores this screen after popping
        // a stacked detail—the view's `.task` runs again on reappear on compact iPhone.
        if case .loaded = movieState {
            syncDiscordPresenceIfLoaded()
            return
        }
        movieState = .loading
        do {
            // `async let` schedules each request right away; nothing is awaited
            // until the lines below, so all three are in flight together.
            async let detailsTask = mediaUc.getMovieDetails(id: id)
            async let progressTask = progressUc.getMovieProgress(movieId: id)
            async let libraryTask = mediaUc.isInLibrary(tmdbId: id, tp: "movie")

            let d = try await detailsTask

            do {
                let wp = try await progressTask
                progress = wp?.progress ?? 0
                isWatched = wp?.isWatched ?? false
            } catch let err as HttpError {
                ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
            } catch {
                ToastProgressBloc.bloc.showToast(
                    message: error.localizedDescription,
                    isError: true
                )
            }

            do {
                isInLibrary = try await libraryTask
            } catch let err as HttpError {
                ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
            } catch {
                ToastProgressBloc.bloc.showToast(
                    message: error.localizedDescription,
                    isError: true
                )
            }

            movieState = .loaded(d)
            syncDiscordPresenceIfLoaded()
            streamTask = Task {
                await getStreams(imdbId: d.imdbId)
            }
        } catch let err as HttpError {
            movieState = .error(err.error())
        } catch {
            movieState = .error(error.localizedDescription)
        }
    }

    func syncDiscordPresenceIfLoaded() {
        #if os(macOS)
            guard case let .loaded(details) = movieState else { return }
            DiscordRichPresenceBloc.bloc.setViewingMovie(
                title: details.title,
                backdropPath: details.backdropPath
            )
        #endif
    }

    func markWatched() async {
        ToastProgressBloc.bloc.enableLoading()
        defer {
            ToastProgressBloc.bloc.disableLoading()
        }
        do {
            try await progressUc.updateMovieToWatched(movieId: "\(id)")
            isWatched = true
        } catch let err as HttpError {
            ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
        } catch {
            ToastProgressBloc.bloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func updateInLibrary() async {
        ToastProgressBloc.bloc.enableLoading()
        defer {
            ToastProgressBloc.bloc.disableLoading()
        }
        do {
            if isInLibrary {
                try await mediaUc.removeFromLibrary(tmdbId: id, tp: "movie")
            } else {
                try await mediaUc.addToLibrary(tmdbId: id, tp: "movie")
            }
            isInLibrary.toggle()
        } catch let err as HttpError {
            ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
        } catch {
            ToastProgressBloc.bloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func fetchMovieProgress(loadOverlay: Bool = false) async {
        if loadOverlay {
            ToastProgressBloc.bloc.enableLoading()
        }
        defer {
            if loadOverlay {
                ToastProgressBloc.bloc.disableLoading()
            }
        }
        do {
            let serverProgress = try await progressUc.getMovieProgress(movieId: id)
            progress = serverProgress?.progress ?? 0
            isWatched = serverProgress?.isWatched ?? false
        } catch let err as HttpError {
            ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
        } catch {
            ToastProgressBloc.bloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    private func getStreams(imdbId: String) async {
        streamsState = .loading
        do {
            let streams = try await streamUc.getMovieStreams(id: imdbId)
            if Task.isCancelled {
                return
            }
            streamsState = .loaded(streams)
        } catch let err as HttpError {
            streamsState = .error(err.error())
        } catch {
            streamsState = .error(error.localizedDescription)
        }
    }
}
