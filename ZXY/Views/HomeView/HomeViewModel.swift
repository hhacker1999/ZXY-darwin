//
//  HomeViewModel.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 01/04/26.
//

import Foundation

@Observable
@MainActor
class HomeViewDiscoveryItem: Identifiable {
    let id = UUID()
    var state = ViewItemState<[AppMedia]>.initial
    var topBannerState = ViewItemState<[AppMedia]>.initial
    @ObservationIgnored
    var isFetching = false
    let name: String
    let filter: Filter
    init(name: String, filter: Filter) {
        self.name = name
        self.filter = filter
    }
}

@MainActor
@Observable
class HomeViewModel {
    private let userBloc = UserBloc.bloc
    var discoveryItemState: [HomeViewDiscoveryItem] = []
    var continueWatchingState: ViewItemState<[ContinueWatchingItem]> = .initial
    var topBannerState: ViewItemState<[AppMedia]> = .initial

    let mediaUc: MediaUsecase
    let progressUc: ProgressUsecase
    init(mediaUc: MediaUsecase, progressUc: ProgressUsecase) {
        self.mediaUc = mediaUc
        self.progressUc = progressUc
        Task {
            await initialise()
        }
    }

    func initialise() async {
        guard let profile = userBloc.profile else {
            return
        }
        guard let libraryItems = profile.libraryItems else {
            return
        }

        Task {
            await initialiseContinueWatching()
        }

        Task {
            await initialiseTopBanner()
        }

        var tempItems: [HomeViewDiscoveryItem] = []
        for item in libraryItems {
            tempItems.append(
                HomeViewDiscoveryItem(
                    name: item.name,
                    filter: item.filter
                )
            )
        }
        discoveryItemState = tempItems
    }

    func initialiseTopBanner() async {
        topBannerState = .loading
        do {
            let trendMovies = try await mediaUc.getLibraryFromFilter(
                filter: Filter(type: "trakt", items: 5, isMovie: true, traktUrl: "trending")
            )

            let trendShows = try await mediaUc.getLibraryFromFilter(
                filter: Filter(type:"trakt", items: 5, isMovie: false, traktUrl: "trending")
            )
            var tempList: [AppMedia] = []

            let maxCount = min(
                5,
                trendShows.results.count,
                trendMovies.results.count
            )
            for index in 0..<maxCount {
                tempList.append(trendShows.results[index])
                tempList.append(trendMovies.results[index])
            }
            topBannerState = .loaded(tempList)

        } catch let error as HttpError {
            topBannerState = .error(error.error())
        } catch {
            topBannerState = .error(error.localizedDescription)
        }
    }

    func initialiseContinueWatching() async {
        do {
            let cw = try await progressUc.getContinueWatching()
            continueWatchingState = .loaded(cw)
        } catch let error as HttpError {
            continueWatchingState = .error(error.error())
        } catch {
            continueWatchingState = .error(error.localizedDescription)
        }
    }

    func startRowFetchIfNeeded(item: HomeViewDiscoveryItem) -> Bool {
        guard case .initial = item.state else {
            return false
        }
        guard !item.isFetching else {
            return false
        }

        item.isFetching = true
        item.state = .loading
        return true
    }

    func getMediaAndUpdateItemState(item: HomeViewDiscoveryItem)
        async
    {
        do {
            let response = try await mediaUc.getLibraryFromFilter(
                filter: item.filter
            )
            item.state = .loaded(response.results)
        } catch let error as HttpError {
            item.state = .error(error.error())
        } catch {
            item.state = .error(error.localizedDescription)
        }
        item.isFetching = false
    }
}
