import Foundation
import SwiftUI

@MainActor
@Observable
class MovieViewModel: StreamViewModel {
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

    @ObservationIgnored
    var streamsTask: Task<Void, Error>? = nil

    let id: Int
    init(id: Int, mediaUc: MediaUsecase, streamUc: StreamUsecase, progressUc: ProgressUsecase, stremioUc: StremioUsecase) {
        self.id = id
        self.mediaUc = mediaUc
        self.streamUc = streamUc
        self.progressUc = progressUc
        self.stremioUc = stremioUc
    }

    var movieState: ViewItemState<MovieDetails> = .initial
    // TODO: Remove this old streams state
    var streamsState: ViewItemState<[ResolutionItem]> = .initial

    var streamsStateNew: ViewItemState<[VideoPlayerStream]> = .initial

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

    /// NOTE: This is responsible for getting streams and setting internal state only
    private func fetchStreamsInternal() async {
        if streamsTask == nil {
            streamsTask = Task<Void, Error> {

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
                var containsMovie = false
                for addon in streamAddons {
                    if addon.types.contains("movie") {
                        containsMovie = true
                        break
                    }
                }
                guard containsMovie else {
                    ToastProgressBloc.bloc.showToast(
                        message: "Add addons in settings for movies",
                        isError: true
                    )
                    return
                }
                var results: [VideoPlayerStream] = []
                var fourK: [VideoPlayerStream] = []
                var fhd: [VideoPlayerStream] = []
                var hd: [VideoPlayerStream] = []

                do {
                    streamsStateNew = .loading
                    for addon in streamAddons {
                        var streams: [Stream]
                        guard addon.types.contains("movie") else {
                            continue
                        }

                        if addon.idPrefixes.contains(
                            "tmdb"
                        ) {
                            streams = try await stremioUc.getStreams(baseUrl: addon.baseUrl, itemId: "tmdb\(getCurrentMedia().id)", isMovie: true)
                        } else {
                            streams = try await stremioUc.getStreams(baseUrl: addon.baseUrl, itemId: getCurrentMedia().imdbId!, isMovie: true)
                        }

                        for stream in streams {
                            if let url = stream.url {
                                if url.starts(with: "http://") {
                                    let hint = stream.behaviorHints
                                    if !hint.filename.isEmpty {
                                        let pttResult = PTT.parse(hint.filename).normalize()
                                        if pttResult.resolution == "4k" {
                                            fourK.append(VideoPlayerStream(source: addon.addonManifest.name, baseStream: stream, ptt: pttResult))
                                        }
                                        if pttResult.resolution == "1080p" {
                                            fhd.append(VideoPlayerStream(source: addon.addonManifest.name, baseStream: stream, ptt: pttResult))
                                        }
                                        if pttResult.resolution == "720p" {
                                            hd.append(VideoPlayerStream(source: addon.addonManifest.name, baseStream: stream, ptt: pttResult))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    fourK = fourK.sorted { $0.size < $1.size }
                    fhd = fhd.sorted { $0.size < $1.size }
                    hd = hd.sorted { $0.size < $1.size }
                    results.append(contentsOf: fourK)
                    results.append(contentsOf: fhd)
                    results.append(contentsOf: hd)
                    streamsStateNew = .loaded(results)

                } catch let err as HttpError {
                    streamsStateNew = .error(err.error())
                } catch {
                    streamsStateNew = .error(error.localizedDescription)
                }
            }
        } else {
            print("Streams task is already in progress")
        }

        defer { streamsTask = nil }

        do {
            try await streamsTask!.value
        } catch {
            fatalError("Error in streams task")
        }
    }


    // ------------------- Methods for StreamviewModel-----------------------------
    func isMovie() -> Bool {
        return true
    }

    func getMediaProgressSync() -> Double {
        return progress
    }

    func hasNext() -> Bool {
        return false
    }

    func getCurrentMedia() -> MediaDetails {
        if case let .loaded(movieDetails) = movieState {
            return MediaDetails(from: movieDetails)
        }
        fatalError("Movie details are not loaded")
    }

    func updateProgress(progress _: Double) async {}


    func getStreams() async throws -> [VideoPlayerStream] {
        if case .loading = streamsStateNew, case .initial = streamsStateNew {
            await fetchStreamsInternal()
        }

        if case let .loaded(streams) = streamsStateNew {
            return streams
        }
        if case let .error(err) = streamsStateNew {
            throw err
        }
        fatalError("Invalid state in get streams")
    }

    func getSelectedStreamIndex() -> Int {
        // FIXME: update this to reflect current selected media
        return 0
    }
}
