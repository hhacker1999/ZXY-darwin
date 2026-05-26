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
    init(id: Int, mediaUc: MediaUsecase, streamUc: StreamUsecase, progressUc: ProgressUsecase, episodeNo: Int = -1, seasonNo: Int = -1) {
        self.id = id
        self.mediaUc = mediaUc
        self.progressUc = progressUc
        self.streamUc = streamUc
        selectedEpisode = episodeNo != -1 ? episodeNo : 1
        selectedSeason = seasonNo != -1 ? seasonNo : 1
        isExplicitSeasonEpisode = seasonNo != -1 && episodeNo != -1
    }

    var selectedEpisode: Int
    var selectedSeason: Int

    @ObservationIgnored
    let isExplicitSeasonEpisode: Bool

    var seriesState: ViewItemState<SeriesDetails> = .initial
    var episodeStreamState: ViewItemState<[ResolutionItem]> = .initial
    var progressState: [String: WatchProgress] = [:]
    var isInLibrary: Bool = false

    @ObservationIgnored
    var seriesDetails: SeriesDetails? = nil

    @ObservationIgnored
    var streamsTask: Task<Void, Never>?

    func initialise() async {
        if case .loaded = seriesState {
            syncDiscordPresenceIfLoaded()
            return
        }
        seriesState = .loading
        do {
            // `async let` schedules each request immediately; all three overlap
            // until the `await`s below.
            async let detailsTask = mediaUc.getSeriesDetails(id: id)
            async let progressTask = progressUc.getProgressShow(showId: id)
            async let libraryTask = mediaUc.isInLibrary(tmdbId: id, tp: "show")

            let details = try await detailsTask
            seriesDetails = details

            do {
                let progressList = try await progressTask
                var tempProgress: [String: WatchProgress] = [:]
                for p in progressList {
                    tempProgress[p.mediaId] = p
                }
                progressState = tempProgress
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

            if !isExplicitSeasonEpisode {
                updateCurrentSeasonAndEpisodeFromProgress()
            }
            getCurrentEpisodesStream()
            seriesState = .loaded(details)
            syncDiscordPresenceIfLoaded()
        } catch let err as HttpError {
            seriesState = .error(err.error())
        } catch {
            seriesState = .error(error.localizedDescription)
        }
    }

    func syncDiscordPresenceIfLoaded() {
        #if os(macOS)
            guard case let .loaded(details) = seriesState else { return }
            DiscordRichPresenceBloc.bloc.setViewingShow(
                title: details.name,
                backdropPath: details.backdropPath
            )
        #endif
    }

    func updateInLibrary() async {
        ToastProgressBloc.bloc.enableLoading()
        defer {
            ToastProgressBloc.bloc.disableLoading()
        }
        do {
            if isInLibrary {
                try await mediaUc.removeFromLibrary(tmdbId: id, tp: "show")
            } else {
                try await mediaUc.addToLibrary(tmdbId: id, tp: "show")
            }
            isInLibrary.toggle()
        } catch let err as HttpError {
            ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
        } catch {
            ToastProgressBloc.bloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func markWatched(mediaId: String) async {
        ToastProgressBloc.bloc.enableLoading()
        defer {
            ToastProgressBloc.bloc.disableLoading()
        }
        do {
            try await progressUc.updateShowToWatched(showId: mediaId)
            await fetchShowProgress()
        } catch let err as HttpError {
            ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
        } catch {
            ToastProgressBloc.bloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func fetchShowProgress(loadOverlay: Bool = false, afterVideoEnds: Bool = false) async {
        guard let d = seriesDetails else {
            return
        }

        if loadOverlay {
            ToastProgressBloc.bloc.enableLoading()
        }
        defer {
            if loadOverlay {
                ToastProgressBloc.bloc.disableLoading()
            }
        }
        do {
            let progress = try await progressUc.getProgressShow(showId: id)
            var tempProgress: [String: WatchProgress] = [:]
            for progress in progress {
                tempProgress[progress.mediaId] = progress
            }
            progressState = tempProgress

            let id = "\(d.id):\(selectedSeason):\(selectedEpisode)"
            if afterVideoEnds, progressState[id]?.isWatched ?? false {
                updateCurrentSeasonAndEpisodeFromProgress()
                getCurrentEpisodesStream()
            }
        } catch let err as HttpError {
            ToastProgressBloc.bloc.showToast(message: err.error(), isError: true)
        } catch {
            ToastProgressBloc.bloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func updateCurrentSeasonAndEpisodeFromProgress() {
        guard let details = seriesDetails else {
            return
        }

        for season in details.seasons {
            for episode in season.episodes {
                let id = "\(details.id):\(season.seasonNumber):\(episode.episodeNumber)"
                if let episodeProgress = progressState[id] {
                    if !episodeProgress.isWatched {
                        selectedSeason = season.seasonNumber
                        selectedEpisode = episode.episodeNumber
                        return
                    }
                } else {
                    selectedSeason = season.seasonNumber
                    selectedEpisode = episode.episodeNumber
                    return
                }
            }
        }
    }

    func onEpisodeSelect(season: Int, episode: Int) {
        if season == selectedSeason, episode == selectedEpisode {
            return
        }
        selectedEpisode = episode
        selectedSeason = season
        getCurrentEpisodesStream()
    }

    private func getCurrentEpisodesStream() {
        guard let details = seriesDetails else {
            return
        }

        episodeStreamState = .loading
        streamsTask?.cancel()
        streamsTask = Task {
            do {
                let response = try await streamUc.getSeriesStreams(
                    id: details.externalIds.imdbId ?? "",
                    season: selectedSeason,
                    episode: selectedEpisode
                )
                if Task.isCancelled {
                    return
                }
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
            } catch {
                // 1. If the task was cancelled, don't update the state to .error
                // This prevents the UI from flickering to an error message when switching episodes
                guard !Task.isCancelled else { return }

                if let err = error as? HttpError {
                    episodeStreamState = .error(err.error())
                } else {
                    episodeStreamState = .error(error.localizedDescription)
                }
            }
        }
    }
}
