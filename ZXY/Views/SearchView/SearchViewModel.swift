import SwiftUI

@MainActor
@Observable
class SearchViewModel {
    let mediaUc: MediaUsecase

    var itemsState: ViewItemState<[AppMedia]> = .initial

    private var showPage: Int = 0
    private var moviePage: Int = 0
    private var totalShowPages: Int = 0
    private var totalMoviePages: Int = 0
    var keyword: String = ""
    private var isLoadingMoreResults: Bool = false

    init(mediaUc: MediaUsecase) {
        self.mediaUc = mediaUc
    }

    func loadResults(keyword: String) async {
        self.keyword = keyword
        itemsState = .loading

        do {
            async let showsResTask = mediaUc.searchShows(page: 1, keyword: keyword)
            async let moviesResTask = mediaUc.searchMovies(page: 1, keyword: keyword)

            let (showsRes, moviesRes) = try await (showsResTask, moviesResTask)

            showPage = showsRes.page
            totalShowPages = showsRes.totalPages
            moviePage = moviesRes.page
            totalMoviePages = moviesRes.totalPages

            var intermixedList: [AppMedia] = []
            let iterations = max(showsRes.results.count, moviesRes.results.count)

            for i in 0 ..< iterations {
                if i < showsRes.results.count {
                    intermixedList.append(showsRes.results[i])
                }
                if i < moviesRes.results.count {
                    intermixedList.append(moviesRes.results[i])
                }
            }

            itemsState = .loaded(intermixedList)
        } catch let error as HttpError {
            itemsState = .error(error.error())
        } catch {
            itemsState = .error(error.localizedDescription)
        }
    }

    func reset() {
        itemsState = .initial
    }

    func loadMoreResults() async {
        guard !isLoadingMoreResults else { return }

        isLoadingMoreResults = true
        defer { isLoadingMoreResults = false }

        guard case let .loaded(oldItems) = itemsState else { return }

        do {
            var newShowsRes: PaginatedResponse<AppMedia>?
            var newMoviesRes: PaginatedResponse<AppMedia>?

            if showPage < totalShowPages, moviePage < totalMoviePages {
                // Fetch both
                async let showsResTask = mediaUc.searchShows(page: showPage + 1, keyword: keyword)
                async let moviesResTask = mediaUc.searchMovies(page: moviePage + 1, keyword: keyword)

                let (showsRes, moviesRes) = try await (showsResTask, moviesResTask)
                newShowsRes = showsRes
                newMoviesRes = moviesRes

            } else if showPage < totalShowPages {
                newShowsRes = try await mediaUc.searchShows(page: showPage + 1, keyword: keyword)
            } else if moviePage < totalMoviePages {
                newMoviesRes = try await mediaUc.searchMovies(page: moviePage + 1, keyword: keyword)
            } else {
                // No more items to load
                return
            }

            var intermixedList: [AppMedia] = []

            if let showsRes = newShowsRes, let moviesRes = newMoviesRes {
                showPage = showsRes.page
                totalShowPages = showsRes.totalPages
                moviePage = moviesRes.page
                totalMoviePages = moviesRes.totalPages

                let iterations = max(showsRes.results.count, moviesRes.results.count)

                for i in 0 ..< iterations {
                    if i < showsRes.results.count {
                        intermixedList.append(showsRes.results[i])
                    }
                    if i < moviesRes.results.count {
                        intermixedList.append(moviesRes.results[i])
                    }
                }
            } else if let showsRes = newShowsRes {
                showPage = showsRes.page
                totalShowPages = showsRes.totalPages
                intermixedList.append(contentsOf: showsRes.results)
            } else if let moviesRes = newMoviesRes {
                moviePage = moviesRes.page
                totalMoviePages = moviesRes.totalPages
                intermixedList.append(contentsOf: moviesRes.results)
            }

            itemsState = .loaded(oldItems + intermixedList)
        } catch let error as HttpError {
            itemsState = .error(error.error())
        } catch {
            itemsState = .error(error.localizedDescription)
        }
    }
}
