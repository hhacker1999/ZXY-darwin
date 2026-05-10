import Inject
import SwiftUI

struct DiscoverView: View {
    @ObserveInjection var inject
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
        VStack(spacing: 0) {
            headerRow

            if vm.filter.type == "trakt", let traktName = vm.activeListName {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Label(traktName, systemImage: "link")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.elementSubtle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.Colors.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    AppTheme.Colors.border,
                                    lineWidth: 0.5
                                )
                            )
                    }
                }
                .padding(.bottom, AppTheme.Spacing.sm)
            } else if !nonTraktSummaryChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        ForEach(
                            Array(nonTraktSummaryChips.enumerated()),
                            id: \.offset
                        ) { _, text in
                            Text(text)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.elementSubtle)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppTheme.Colors.surface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        AppTheme.Colors.border,
                                        lineWidth: 0.5
                                    )
                                )
                        }
                    }
                }
                .padding(.bottom, AppTheme.Spacing.sm)
            }

            MediaGrid(
                itemState: vm.itemsState,
                initialText: "Apply a filter to discover media",
                showType: true,
                onScrollNearEnd: {
                    Task { await vm.loadMore() }
                },
                id: vm.activeFilterForId,
                onItemTapped: { item in
                    if item.type == "movie" {
                        Router.router.addToRoute(route: .movieDetails(item.id))
                    } else {
                        Router.router.addToRoute(route: .seriesDetails(item.id))
                    }
                }
            )
            .padding(.horizontal, AppTheme.Spacing.md - AppTheme.Spacing.sm)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
        .task {
            await vm.initialLoad()
        }
        .enableInjection()
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showFilterSheet) {
            DiscoverFilterSheet(
                initialFilter: vm.filter,
                profile: UserBloc.bloc.profile,
                onApply: { filter, listName in
                    vm.onFilterUpdate(filter, listName: listName)
                }
            )
            #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(AppTheme.Radius.xl)
            #endif
        }
        .sheet(isPresented: $showSaveSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Save to Home")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(
                            "Create a row on your home screen using this active discover filter."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("List Name")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        TextField("Sunday Thrillers", text: $saveListName)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                                .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                                .strokeBorder(
                                    Color.white.opacity(0.12),
                                    lineWidth: 0.7
                                )
                            )
                            .focused($isSaveNameFocused)
                            #if os(iOS)
                                .textInputAutocapitalization(.words)
                            #endif
                    }

                    Label(
                        "You can rename or remove this row later in Home settings.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .padding(20)
                .background(
                    DiscoverViewPalette.groupedBackground.ignoresSafeArea()
                )
                #if os(iOS)
                    .presentationDetents([.height(300)])
                #endif
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
                            saveListName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
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

    private var headerRow: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Text("Discover")
                .font(AppTheme.Typography.headingLarge)
                .foregroundStyle(AppTheme.Colors.elementWhite)

            Spacer(minLength: 0)

            if !vm.filter.isDiscoverDefaultBaseline() {
                iconButton(systemName: "arrow.counterclockwise", label: "Reset")
                {
                    vm.resetFilter()
                }
                iconButton(
                    systemName: "square.and.arrow.down",
                    label: "Save to Home"
                ) {
                    saveListName = ""
                    showSaveSheet = true
                }
            }

            iconButton(systemName: "slider.horizontal.3", label: "Filters") {
                showFilterSheet = true
            }
        }
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private func iconButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.surface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Radius.sm,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Radius.sm,
                        style: .continuous
                    )
                    .stroke(AppTheme.Colors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
        let trimmed = saveListName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
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

private enum DiscoverViewPalette {
    static var groupedBackground: Color {
        #if os(macOS)
            return Color.black.opacity(0.001)
        #else
            return Color(.systemGroupedBackground)
        #endif
    }
}
