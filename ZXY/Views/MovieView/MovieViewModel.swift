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

    func initialise() async {
        movieState = .loading
        do {
            let movieDetails = try await mediaUc.getMovieDetails(id: id)
            await fetchMovieProgress()
            movieState = .loaded(movieDetails)
            Task {
                await getStreams(imdbId: movieDetails.imdbId)
            }
        } catch let err as HttpError {
            movieState = .error(err.error())
        } catch {
            movieState = .error(error.localizedDescription)
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
            streamsState = .loaded(streams)
        } catch let err as HttpError {
            streamsState = .error(err.error())
        } catch {
            streamsState = .error(error.localizedDescription)
        }
    }
}
