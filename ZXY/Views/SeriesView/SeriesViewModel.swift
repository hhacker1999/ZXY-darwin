import Foundation
import SwiftUI

@MainActor
@Observable
class SeriesViewModel {
    let mediaUc: MediaUsecase
    let streamUc: StreamUsecase
    let progressUc: ProgressUsecase
    let userBloc: UserBloc = .bloc
    let id: Int
    init(id: Int, mediaUc: MediaUsecase, streamUc: StreamUsecase, progressUc: ProgressUsecase) {
        self.id = id
        self.mediaUc = mediaUc
        self.progressUc = progressUc
        self.streamUc = streamUc
    }

    var seriesState: ViewItemState<SeriesDetails> = .initial
    var episodeStreamState: ViewItemState<[ResolutionItem]> = .initial
    var progressState: [String: WatchProgress] = [:]

    func initialise() async {
        seriesState = .loading
        do {
            let seriesDetails = try await mediaUc.getSeriesDetails(id: id)
            let progress = try await progressUc.getProgressShow(showId: id)
            var tempProgress: [String: WatchProgress] = [:]
            for progress in progress {
                tempProgress[progress.mediaId] = progress
            }
            progressState = tempProgress
            seriesState = .loaded(seriesDetails)
        } catch let err as HttpError {
            seriesState = .error(err.error())
        } catch {
            seriesState = .error(error.localizedDescription)
        }
    }

    func getEpisodeStreams(imdbId: String, season: Int, episode: Int) async {
        episodeStreamState = .loading
        do {
            let response = try await streamUc.getSeriesStreams(
                id: imdbId,
                season: season,
                episode: episode
            )
            var items: [ResolutionItem] = []
            for item in response.uhd {
                items.append(item)
            }
            for item in response.fhd {
                items.append(item)
            }
            for item in response.hd {
                items.append(item)
            }
            episodeStreamState = .loaded(items)
        } catch let err as HttpError {
            episodeStreamState = .error(err.error())
        } catch {
            episodeStreamState = .error(error.localizedDescription)
        }
    }
}
