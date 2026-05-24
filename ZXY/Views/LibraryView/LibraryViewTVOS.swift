//
//  LibraryViewTVOS.swift
//
//  tvOS-native Library — focus-driven hero banner + poster grid with
//  movie/show type badges. The first poster auto-focuses on load.
//

#if os(tvOS)

import SwiftUI

struct LibraryViewTVOS: View {
    @State private var vm: LibraryViewModel

    init(mediaUc: MediaUsecase) {
        vm = LibraryViewModel(mediaUc: mediaUc)
    }

    var body: some View {
        TVOSMediaBrowseView(
            itemState: vm.itemsState,
            emptyMessage: "Your library is empty",
            gridID: "library",
            showType: true,
            onLoadMore: {
                Task { await vm.loadMore() }
            }
        ) {
            LibraryHeaderTVOS(state: vm.itemsState)
        }
        .task {
            await vm.initialLoad()
        }
    }
}

// MARK: - Header

private struct LibraryHeaderTVOS: View {
    let state: ViewItemState<[AppMedia]>

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text("Library")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)

            Text(subtitle)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementMuted)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        switch state {
        case .initial, .loading:
            return "Your saved movies and shows"
        case .error:
            return "Unable to load library"
        case let .loaded(items):
            if items.isEmpty { return "Empty" }
            if items.count == 1 { return "1 item" }
            return "\(items.count) items"
        }
    }
}

#endif
