import Foundation
import SwiftUI

@MainActor
@Observable
final class DiscoverViewModel {
    let mediaUc: MediaUsecase
    let authUc: AuthUsecase

    private(set) var filter: Filter = .discoverDefault()

    @ObservationIgnored
    private(set) var activeFilterForId: Filter?

    private(set) var activeListName: String?

    var itemsState: ViewItemState<[AppMedia]> = .loading

    @ObservationIgnored
    private var isLoading = false

    @ObservationIgnored
    private var currentPage = 1

    @ObservationIgnored
    private var hasMore = true

    @ObservationIgnored
    private var items: [AppMedia] = []

    var isSavingList = false

    init(mediaUc: MediaUsecase, authUc: AuthUsecase) {
        self.mediaUc = mediaUc
        self.authUc = authUc
    }

    /// First load (call from `.task` on appear — same pattern as `LibraryViewModel.initialLoad`).
    func initialLoad() async {
        if case .loaded = itemsState {
            return
        }
        await getItemsFromFilter(isLoadMore: false)
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        await getItemsFromFilter(isLoadMore: true)
    }

    func onFilterUpdate(_ newFilter: Filter, listName: String? = nil) {
        filter = normalizedFilterForStorage(newFilter)
        activeListName = listName
        currentPage = 1
        hasMore = true
        items = []
        Task { await self.getItemsFromFilter(isLoadMore: false) }
    }

    func resetFilter() {
        activeListName = nil
        currentPage = 1
        hasMore = true
        items = []
        filter = .discoverDefault()
        Task { await self.getItemsFromFilter(isLoadMore: false) }
    }

    /// Saves the current discover filter as a home library row (no events bus — profile refresh only).
    func saveFilterToHomeList(name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        isSavingList = true
        defer { isSavingList = false }

        do {
            var list = UserBloc.bloc.profile?.libraryItems ?? []
            let toStore = normalizedFilterForStorage(filter)
            list.append(LibraryItem(name: trimmed, filter: toStore))
            try await authUc.updateProfileList(list: list)
            let profile = try await authUc.getProfile()
            UserBloc.bloc.profile = profile
            return true
        } catch {
            #if DEBUG
                print("saveFilterToHomeList: \(error)")
            #endif
            return false
        }
    }

    private func normalizedFilterForStorage(_ f: Filter) -> Filter {
        f.copyDiscover(page: 1)
    }

    private func getItemsFromFilter(isLoadMore: Bool) async {
        guard !isLoading else { return }
        isLoading = true

        if !isLoadMore {
            itemsState = .loading
            activeFilterForId = filter
        }

        do {
            let request = filter.copyDiscover(items: 20, page: currentPage)
            let response = try await mediaUc.getLibraryFromFilter(filter: request)

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
            #if DEBUG
                print("DiscoverViewModel getItemsFromFilter: \(error)")
            #endif
        }
    }
}
