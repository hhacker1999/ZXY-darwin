//
//  SearchViewTVOS.swift
//
//  tvOS-native Search — search field above the same poster grid used by
//  Library. No hero banner, no suggestion chips, no titles below cards.
//

#if os(tvOS)

import SwiftUI

struct SearchViewTVOS: View {
    @State private var vm: SearchViewModel
    @State private var searchText: String = ""

    init(mediaUc: MediaUsecase) {
        vm = SearchViewModel(mediaUc: mediaUc)
    }

    var body: some View {
        TVOSMediaGridView(
            itemState: vm.itemsState,
            emptyMessage: "Search for movies and TV shows",
            gridID: vm.keyword,
            showType: true,
            onLoadMore: {
                Task { await vm.loadMoreResults() }
            }
        ) {
            SearchHeaderTVOS(
                searchText: $searchText,
                state: vm.itemsState,
                keyword: vm.keyword,
                onSubmit: submitSearch,
                onClear: clearSearch
            )
        }
    }

    private func submitSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await vm.loadResults(keyword: trimmed) }
    }

    private func clearSearch() {
        searchText = ""
        vm.reset()
    }
}

// MARK: - Header

private struct SearchHeaderTVOS: View {
    @Binding var searchText: String
    let state: ViewItemState<[AppMedia]>
    let keyword: String
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text("Search")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)

                if let label = subtitleLabel {
                    Text(label)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }

            SearchFieldTVOS(
                text: $searchText,
                placeholder: "Movies, TV shows, actors",
                onSubmit: onSubmit,
                onClear: onClear
            )
            .frame(maxWidth: 760)
        }
    }

    private var subtitleLabel: String? {
        switch state {
        case .initial:
            return nil
        case .loading:
            return keyword.isEmpty ? nil : "Searching…"
        case let .loaded(items):
            if keyword.isEmpty { return nil }
            if items.isEmpty { return "No matches" }
            if items.count == 1 { return "1 result" }
            return "\(items.count) results"
        case .error:
            return "Something went wrong"
        }
    }
}

private struct SearchFieldTVOS: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementMuted)

            TextField(placeholder, text: $text)
                .font(TVOSTypography.fieldText)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .tint(AppTheme.Colors.elementWhite)
                .onChange(of: text) { _, newValue in
                    if newValue.isEmpty { onClear() }
                }
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                }
                .buttonStyle(.card)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        )
    }
}

#endif
