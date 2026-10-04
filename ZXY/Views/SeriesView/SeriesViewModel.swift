import Foundation
import SwiftUI

@MainActor
@Observable
class SeriesViewModel: StreamViewModel {
    @ObservationIgnored
    let mediaUc: MediaUsecase
    @ObservationIgnored
    let streamUc: StreamUsecase
    @ObservationIgnored
    let progressUc: ProgressUsecase
    @ObservationIgnored
    let stremioUc: StremioUsecase
    @ObservationIgnored
    let userBloc: UserBloc = .bloc
    let id: Int
    init(
        id: Int,
        mediaUc: MediaUsecase,
        streamUc: StreamUsecase,
        progressUc: ProgressUsecase,
        stremioUc: StremioUsecase,
        episodeNo: Int = -1,
        seasonNo: Int = -1
    ) {
        self.id = id
        self.mediaUc = mediaUc
        self.progressUc = progressUc
        self.streamUc = streamUc
        self.stremioUc = stremioUc
        selectedEpisode = episodeNo != -1 ? episodeNo : 1
        selectedSeason = seasonNo != -1 ? seasonNo : 1
        isExplicitSeasonEpisode = seasonNo != -1 && episodeNo != -1
    }

    var selectedEpisode: Int
    var selectedSeason: Int
    private var selectedStreamIndex: Int = 0

    @ObservationIgnored
    let isExplicitSeasonEpisode: Bool

    var seriesState: ViewItemState<SeriesDetails> = .initial
    var episodeStreamState: ViewItemState<[VideoPlayerStream]> = .initial
    var progressState: [String: WatchProgress] = [:]
    var isInLibrary: Bool = false

    @ObservationIgnored
    var seriesDetails: SeriesDetails? = nil

    @ObservationIgnored
    var streamsTask: Task<Void, Error>? = nil

    @ObservationIgnored
    private var streamsFetchKey: String?

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
            fetchStreamsInternal()
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

    func fetchShowProgress(loadOverlay: Bool = false) async {
        guard seriesDetails != nil else {
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
        selectedStreamIndex = 0
        fetchStreamsInternal()
    }

    private func stremioItemId(for addon: StreamAddon) -> String {
        let seasonEpisode = "\(selectedSeason):\(selectedEpisode)"
        if addon.idPrefixes.contains("tmdb") {
            return "tmdb\(getCurrentMedia().id):\(seasonEpisode)"
        }
        return "\(getCurrentMedia().imdbId!):\(seasonEpisode)"
    }

    /// Fetches streams for the current season/episode and updates `episodeStreamState`.
    private func fetchStreamsInternal() {
        guard seriesDetails != nil else {
            return
        }

        let fetchKey = "\(selectedSeason):\(selectedEpisode)"
        if case .loaded = episodeStreamState, streamsFetchKey == fetchKey {
            return
        }
        if case .error = episodeStreamState, streamsFetchKey == fetchKey {
            return
        }
        if case .loading = episodeStreamState, streamsFetchKey == fetchKey {
            return
        }


        streamsTask?.cancel()
        streamsTask = nil
        streamsFetchKey = fetchKey
        episodeStreamState = .loading

        if streamsTask == nil {
            streamsTask = Task<Void, Error> { [weak self] in
                guard let self else { return }
                defer { self.streamsTask = nil }

                guard let streamAddons = userBloc.streamAddons else {
                    ToastProgressBloc.bloc.showToast(
                        message: "Add addons in settings",
                        isError: true
                    )
                    return
                }
                guard !streamAddons.isEmpty else {
                    ToastProgressBloc.bloc.showToast(
                        message: "Add addons in settings",
                        isError: true
                    )
                    return
                }
                var containsSeries = false
                for addon in streamAddons {
                    if addon.types.contains("series") {
                        containsSeries = true
                        break
                    }
                }
                guard containsSeries else {
                    ToastProgressBloc.bloc.showToast(
                        message: "Add addons in settings for series",
                        isError: true
                    )
                    return
                }

                var results: [VideoPlayerStream] = []
                var fourK: [VideoPlayerStream] = []
                var fhd: [VideoPlayerStream] = []
                var hd: [VideoPlayerStream] = []

                do {
                    for addon in streamAddons {
                        guard addon.types.contains("series") else {
                            continue
                        }

                        let streams = try await stremioUc.getStreams(
                            baseUrl: addon.baseUrl,
                            itemId: stremioItemId(for: addon),
                            isMovie: false
                        )

                        for stream in streams {
                            if let url = stream.url {
                                if url.starts(with: "http://") || url.starts(with: "https://") {
                                    let hint = stream.behaviorHints
                                    if !hint.filename.isEmpty {
                                        let pttResult = PTT.parse(hint.filename).normalize()
                                        if pttResult.resolution == "4k" {
                                            fourK.append(
                                                VideoPlayerStream(
                                                    source: addon.addonManifest.name,
                                                    baseStream: stream,
                                                    ptt: pttResult
                                                )
                                            )
                                        }
                                        if pttResult.resolution == "1080p" {
                                            fhd.append(
                                                VideoPlayerStream(
                                                    source: addon.addonManifest.name,
                                                    baseStream: stream,
                                                    ptt: pttResult
                                                )
                                            )
                                        }
                                        if pttResult.resolution == "720p" {
                                            hd.append(
                                                VideoPlayerStream(
                                                    source: addon.addonManifest.name,
                                                    baseStream: stream,
                                                    ptt: pttResult
                                                )
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    fourK = fourK.sorted { $0.size > $1.size }
                    fhd = fhd.sorted { $0.size > $1.size }
                    hd = hd.sorted { $0.size > $1.size }
                    results.append(contentsOf: fourK)
                    results.append(contentsOf: fhd)
                    results.append(contentsOf: hd)
                    episodeStreamState = .loaded(results)
                } catch is CancellationError {
                    throw CancellationError()
                } catch let err as HttpError {
                    episodeStreamState = .error(err.error())
                } catch {
                    episodeStreamState = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - StreamViewModel

    func isMovie() -> Bool {
        false
    }

    func getMediaProgressSync() -> Double {
        let key = "\(id):\(selectedSeason):\(selectedEpisode)"
        return progressState[key]?.progress ?? 0
    }

    func hasNext() -> Bool {
        guard let details = seriesDetails else { return false }
        let orderedSeasons = details.seasons.sorted { $0.seasonNumber < $1.seasonNumber }
        guard
            let seasonIndex = orderedSeasons.firstIndex(where: {
                $0.seasonNumber == selectedSeason
            })
        else { return false }

        let orderedEpisodes = orderedSeasons[seasonIndex].episodes.sorted {
            $0.episodeNumber < $1.episodeNumber
        }
        guard
            let episodeIndex = orderedEpisodes.firstIndex(where: {
                $0.episodeNumber == selectedEpisode
            })
        else { return false }

        if episodeIndex + 1 < orderedEpisodes.count {
            return true
        }
        for nextSeason in orderedSeasons.dropFirst(seasonIndex + 1) {
            if !nextSeason.episodes.isEmpty {
                return true
            }
        }
        return false
    }

    /// Moves selection to the next episode when one exists. Returns whether navigation occurred.
    func advanceToNextEpisode() -> Bool {
        guard hasNext(), let details = seriesDetails else { return false }
        let orderedSeasons = details.seasons.sorted { $0.seasonNumber < $1.seasonNumber }
        guard
            let seasonIndex = orderedSeasons.firstIndex(where: {
                $0.seasonNumber == selectedSeason
            })
        else { return false }

        let season = orderedSeasons[seasonIndex]
        let orderedEpisodes = season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
        guard
            let episodeIndex = orderedEpisodes.firstIndex(where: {
                $0.episodeNumber == selectedEpisode
            })
        else { return false }

        if episodeIndex + 1 < orderedEpisodes.count {
            let next = orderedEpisodes[episodeIndex + 1]
            onEpisodeSelect(season: selectedSeason, episode: next.episodeNumber)
            return true
        }
        for nextSeason in orderedSeasons.dropFirst(seasonIndex + 1) {
            let nextEpisodes = nextSeason.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
            guard let first = nextEpisodes.first else { continue }
            onEpisodeSelect(season: nextSeason.seasonNumber, episode: first.episodeNumber)
            return true
        }
        return false
    }

    func getCurrentMedia() -> MediaDetails {
        if let seriesDetails {
            return MediaDetails(from: seriesDetails)
        }
        fatalError("Series details are not loaded")
    }

    func updateProgress(progress: Double) async {
        let key = "\(id):\(selectedSeason):\(selectedEpisode)"
        let current = progressState[key]
        progressState[key] = WatchProgress(
            mediaId: current?.mediaId ?? key,
            progress: progress,
            userId: current?.userId ?? 0,
            profileId: current?.profileId ?? 0,
            isWatched: current?.isWatched ?? false,
            createdAt: current?.createdAt ?? "",
            updatedAt: current?.updatedAt ?? ""
        )
        try? await progressUc.updateWatchProgressShow(
            showId: "\(id)",
            season: selectedSeason,
            episode: selectedEpisode,
            progress: progress
        )
    }

    func getStreams() async throws -> [VideoPlayerStream] {
        fetchStreamsInternal()
        try await streamsTask?.value

        if case let .loaded(streams) = episodeStreamState {
            return streams
        }
        if case let .error(err) = episodeStreamState {
            throw SomethingWentWrong(err: err)
        }
        fatalError("Invalid state in get streams")
    }

    func getSelectedStreamIndex() -> Int {
        selectedStreamIndex
    }

    func setSelectedStreamIndex(_ index: Int) {
        selectedStreamIndex = index
    }

    func getSeasonNo() -> Int {
        selectedSeason
    }

    func getEpisodeNo() -> Int {
        selectedEpisode
    }

    /// Returns whether the stream picker sheet should be presented.
    func handlePlayPressed() -> Bool {
        switch episodeStreamState {
        case .loaded:
            return true
        case let .error(message):
            ToastProgressBloc.bloc.showToast(message: message, isError: true)
            return false
        case .initial, .loading:
            fetchStreamsInternal()
            return true
        }
    }
}
