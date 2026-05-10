import SwiftUI

@MainActor
@Observable
class LibraryViewModel {
    let mediaUc: MediaUsecase

    var itemsState: ViewItemState<[AppMedia]> = .loading

    private var currentPage: Int = 1
    private var hasMore: Bool = true
    private var isLoading: Bool = false
    private var items: [AppMedia] = []

    init(mediaUc: MediaUsecase) {
        self.mediaUc = mediaUc
    }

    func initialLoad() async {
        currentPage = 1
        hasMore = true
        items = []
        await getItems(isLoadMore: false)
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        await getItems(isLoadMore: true)
    }

    private func getItems(isLoadMore: Bool) async {
        guard !isLoading else { return }
        isLoading = true

        if !isLoadMore {
            itemsState = .loading
        }

        do {
            let filter = Filter(
                type: "library",
                items: 20,
                isMovie: true,
                traktUrl: nil,
                page: currentPage
            )

            let response = try await mediaUc.getLibraryFromFilter(filter: filter)

            if isLoadMore {
                items.append(contentsOf: response.results)
            } else {
                items = response.results
            }

            currentPage = response.page + 1
            hasMore = !response.results.isEmpty
            itemsState = .loaded(items)
            isLoading = false
        } catch let error as HttpError {
            isLoading = false
            if !isLoadMore {
                itemsState = .error(error.error())
            }
        } catch {
            isLoading = false
            if !isLoadMore {
                itemsState = .error(error.localizedDescription)
            }
        }
    }
}
