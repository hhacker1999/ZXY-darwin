import Foundation
import SwiftUI

@MainActor
@Observable
class MovieViewModel {
    let mediaUc: MediaUsecase
    let streamUc: StreamUsecase
    let userBloc: UserBloc = .bloc
    let id: Int
    init(id: Int, mediaUc: MediaUsecase, streamUc: StreamUsecase) {
        self.id = id
        self.mediaUc = mediaUc
        self.streamUc = streamUc
    }

    var movieState: ViewItemState<MovieDetails> = .initial
    var streamsState: ViewItemState<[ResolutionItem]> = .initial

    func initialise() async {
        movieState = .loading
        do {
            let movieDetails = try await mediaUc.getMovieDetails(id: id)
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
