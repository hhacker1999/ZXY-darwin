//
//  DiscoverViewTVOS.swift
//
//  tvOS-native Discover — filter-driven browse with focus banner.
//

#if os(tvOS)

import SwiftUI

struct DiscoverViewTVOS: View {
    @State private var vm: DiscoverViewModel
    @State private var showFilterSheet = false
    @State private var showSaveSheet = false
    @State private var saveListName = ""
    @State private var saveBanner: String?
    @FocusState private var isSaveNameFocused: Bool

    init(mediaUc: MediaUsecase, authUc: AuthUsecase) {
        vm = DiscoverViewModel(mediaUc: mediaUc, authUc: authUc)
    }

    var body: some View {
        TVOSMediaBrowseView(
            itemState: vm.itemsState,
            emptyMessage: "Apply a filter to discover media",
            gridID: vm.activeFilterForId ?? vm.filter,
            showType: true,
            onLoadMore: {
                Task { await vm.loadMore() }
            }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                TVOSBrowseTitleHeader(title: "Discover") {
                    HStack(spacing: 16) {
                        if !vm.filter.isDiscoverDefaultBaseline() {
                            TVOSBrowseIconButton(
                                systemName: "arrow.counterclockwise",
                                label: "Reset"
                            ) {
                                vm.resetFilter()
                            }
                            TVOSBrowseIconButton(
                                systemName: "square.and.arrow.down",
                                label: "Save to Home"
                            ) {
                                saveListName = ""
                                showSaveSheet = true
                            }
                        }

                        TVOSBrowseIconButton(
                            systemName: "slider.horizontal.3",
                            label: "Filters"
                        ) {
                            showFilterSheet = true
                        }
                    }
                }

                if vm.filter.type == "trakt", let traktName = vm.activeListName {
                    TVOSBrowseFilterChips(chips: [traktName])
                } else if !nonTraktSummaryChips.isEmpty {
                    TVOSBrowseFilterChips(chips: nonTraktSummaryChips)
                }
            }
        }
        .task {
            await vm.initialLoad()
        }
        .sheet(isPresented: $showFilterSheet) {
            DiscoverFilterSheet(
                initialFilter: vm.filter,
                profile: UserBloc.bloc.profile,
                onApply: { filter, listName in
                    vm.onFilterUpdate(filter, listName: listName)
                }
            )
        }
        .sheet(isPresented: $showSaveSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Save to Home")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Create a row on your home screen using this active discover filter.")
                            .font(TVOSTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    TVOSTextField(label: "List Name", text: $saveListName)
                        .focused($isSaveNameFocused)

                    Label(
                        "You can rename or remove this row later in Home settings.",
                        systemImage: "info.circle"
                    )
                    .font(TVOSTypography.caption)
                    .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .padding(48)
                .background(Color.black.opacity(0.001).ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showSaveSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            submitSaveList()
                        }
                        .fontWeight(.semibold)
                        .disabled(
                            saveListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSaveNameFocused = true
                }
            }
        }
        .overlay {
            if vm.isSavingList {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                }
            }
        }
        .alert(
            "Save",
            isPresented: Binding(
                get: { saveBanner != nil },
                set: { if !$0 { saveBanner = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveBanner = nil }
        } message: {
            if let saveBanner {
                Text(saveBanner)
            }
        }
    }

    private var nonTraktSummaryChips: [String] {
        guard vm.filter.type != "trakt" else { return [] }
        return summaryChips(for: vm.filter)
    }

    private func summaryChips(for filter: Filter) -> [String] {
        var chips: [String] = []
        chips.append(filter.isMovie ? "Movies" : "TV Shows")

        if filter.thisWeek {
            chips.append("This Week")
        } else if filter.thisMonth {
            chips.append("This Month")
        } else if !filter.years.isEmpty {
            if filter.years.count == 1 {
                chips.append(String(filter.years[0]))
            } else if let y = filter.years.first {
                let decade = (y / 10) * 10
                chips.append("\(decade)s")
            }
        }

        if filter.imdbRating > 0 {
            chips.append("IMDb \(filter.imdbRating)+")
        }

        if !filter.language.isEmpty {
            chips.append(LangHelper.getDisplayName(filter.language))
        }

        let genreMap =
            filter.isMovie
            ? MediaConfig.instance.movieGenres : MediaConfig.instance.showGenres
        for gid in filter.includedGenres {
            if let g = genreMap[gid] {
                chips.append(g.name)
            }
        }

        if filter.sort != "popularity" {
            let sortLabel: String
            switch filter.sort {
            case "imdb_rating": sortLabel = "IMDb Rating"
            case "date": sortLabel = "Release Date"
            default: sortLabel = filter.sort
            }
            chips.append(sortLabel)
        }

        return chips
    }

    private func submitSaveList() {
        let trimmed = saveListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveBanner = "Name cannot be empty"
            return
        }
        showSaveSheet = false
        Task {
            let ok = await vm.saveFilterToHomeList(name: trimmed)
            saveBanner =
                ok
                ? "List '\(trimmed)' added to home"
                : "Failed to save list"
        }
    }
}

#endif
