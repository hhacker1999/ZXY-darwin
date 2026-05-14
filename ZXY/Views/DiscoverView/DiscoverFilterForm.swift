import SwiftUI

private enum TimePeriodSelection: Hashable, Identifiable {
    case allTime
    case thisWeek
    case thisMonth
    case singleYear(Int)
    case decade(start: Int)

    var id: String {
        switch self {
        case .allTime: "all"
        case .thisWeek: "week"
        case .thisMonth: "month"
        case .singleYear(let y): "y\(y)"
        case .decade(let s): "d\(s)"
        }
    }

    var label: String {
        switch self {
        case .allTime: "All Time"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        case .singleYear(let y): String(y)
        case .decade(let s): "\(s)s"
        }
    }

    static func allCases(includingYearsUpTo currentYear: Int)
        -> [TimePeriodSelection]
    {
        var list: [TimePeriodSelection] = [.allTime, .thisWeek, .thisMonth]
        let currentDecade = (currentYear / 10) * 10
        for i in 0...(currentYear - currentDecade) {
            list.append(.singleYear(currentYear - i))
        }
        for i in 1...4 {
            let d = currentDecade - i * 10
            list.append(.decade(start: d))
        }
        return list
    }

    init(from filter: Filter) {
        if filter.thisWeek {
            self = .thisWeek
        } else if filter.thisMonth {
            self = .thisMonth
        } else if filter.years.isEmpty {
            self = .allTime
        } else if filter.years.count == 1 {
            self = .singleYear(filter.years[0])
        } else if let first = filter.years.first {
            self = .decade(start: (first / 10) * 10)
        } else {
            self = .allTime
        }
    }

    func apply(to filter: Filter) -> Filter {
        switch self {
        case .thisWeek:
            return filter.copyDiscover(
                thisWeek: true,
                thisMonth: false,
                years: []
            )
        case .thisMonth:
            return filter.copyDiscover(
                thisWeek: false,
                thisMonth: true,
                years: []
            )
        case .allTime:
            return filter.copyDiscover(
                thisWeek: false,
                thisMonth: false,
                years: []
            )
        case .singleYear(let y):
            return filter.copyDiscover(
                thisWeek: false,
                thisMonth: false,
                years: [y]
            )
        case .decade(let start):
            return filter.copyDiscover(
                thisWeek: false,
                thisMonth: false,
                years: Array(start..<(start + 10))
            )
        }
    }
}


private enum DiscoverFilterRoute: Hashable {
    case internalFilters
    case traktLists
}


struct DiscoverFilterSheet: View {
    let initialFilter: Filter
    let profile: Profile?
    let onApply: (Filter, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DiscoverFilterTypeView(
                initialFilter: initialFilter,
                profile: profile,
                onApply: { filter, name in
                    onApply(filter, name)
                    dismiss()
                },
                onCancel: { dismiss() }
            )
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
            .frame(minWidth: 560, minHeight: 700)
        #else
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
        #endif
    }
}


private struct DiscoverFilterTypeView: View {
    let initialFilter: Filter
    let profile: Profile?
    let onApply: (Filter, String?) -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discover Sources")
                        .font(.title3.weight(.semibold))
                    Text(
                        "Choose whether to build a custom rule set or browse Trakt-powered lists."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Source") {
                NavigationLink(value: DiscoverFilterRoute.internalFilters) {
                    FilterOptionRow(
                        icon: "line.3.horizontal.decrease.circle",
                        iconColor: .blue,
                        title: "Internal Filters",
                        subtitle:
                            "Fine-tune genre, quality, language and release window"
                    )
                }

                NavigationLink(value: DiscoverFilterRoute.traktLists) {
                    FilterOptionRow(
                        icon: "list.bullet.rectangle.portrait",
                        iconColor: .orange,
                        title: "Trakt Lists",
                        subtitle:
                            "Pick trending, recommended and personal Trakt lists"
                    )
                }
            }
        }
        #if os(macOS)
            .listStyle(.inset)
        #else
            .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
        .background(DiscoverPalette.groupedBackground)
        .navigationTitle("Discover Filters")
        .navigationDestination(for: DiscoverFilterRoute.self) { route in
            switch route {
            case .internalFilters:
                DiscoverInternalFilterForm(initialFilter: initialFilter) {
                    onApply($0, nil)
                }
            case .traktLists:
                DiscoverTraktListPicker(profile: profile, onSelect: onApply)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: onCancel)
            }
        }
    }
}

private struct FilterOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(
                    iconColor.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}


private struct DiscoverInternalFilterForm: View {
    let initialFilter: Filter
    let onApply: (Filter) -> Void

    @State private var draft: Filter
    @State private var timePeriod: TimePeriodSelection

    init(initialFilter: Filter, onApply: @escaping (Filter) -> Void) {
        self.initialFilter = initialFilter
        self.onApply = onApply
        let base =
            initialFilter.type == "trakt"
            ? Filter.discoverDefault() : initialFilter
        _draft = State(initialValue: base)
        _timePeriod = State(initialValue: TimePeriodSelection(from: base))
    }

    private var genreMap: [Int: Genre] {
        draft.isMovie
            ? MediaConfig.instance.movieGenres : MediaConfig.instance.showGenres
    }

    var body: some View {
        List {
            Section("Media") {
                Picker("Type", selection: isMovieBinding) {
                    Text("Movies").tag(true)
                    Text("TV Shows").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section("Release Window") {
                Picker(
                    "Period",
                    selection: Binding(
                        get: { timePeriod },
                        set: { newValue in
                            timePeriod = newValue
                            draft = newValue.apply(to: draft)
                        }
                    )
                ) {
                    ForEach(
                        TimePeriodSelection.allCases(
                            includingYearsUpTo: Calendar.current.component(
                                .year,
                                from: Date()
                            )
                        )
                    ) { option in
                        Text(option.label).tag(option)
                    }
                }

                if !draft.isMovie {
                    Picker("Date Type", selection: isFirstAirBinding) {
                        Text("First Air").tag(true)
                        Text("Last Air").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Quality") {
                Picker("IMDb Rating", selection: imdbRatingBinding) {
                    ForEach(0..<10, id: \.self) { i in
                        Text(i == 0 ? "Any" : "\(i)+").tag(i)
                    }
                }

                if draft.imdbRating > 0 {
                    Picker("Min Votes", selection: minVotesBinding) {
                        Text("Any").tag(0)
                        Text("1,000+").tag(1_000)
                        Text("10,000+").tag(10_000)
                        Text("50,000+").tag(50_000)
                    }
                }

                Picker("Language", selection: languageBinding) {
                    Text("Any").tag(Optional<String>.none)
                    ForEach(LangHelper.iso6391List, id: \.self.0) {
                        language in
                        Text(language.1).tag(Optional(language.0))
                    }
                }
            }

            Section("Included Genres") {
                GenreChipGrid(
                    genres: genreMap,
                    selectedIds: includedGenresBinding,
                    accentColor: .blue
                )
                .listRowInsets(
                    EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
                )
            }

            Section("Excluded Genres") {
                GenreChipGrid(
                    genres: genreMap,
                    selectedIds: excludedGenresBinding,
                    accentColor: .pink
                )
                .listRowInsets(
                    EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
                )
            }

            Section("Sort") {
                Picker("Sort By", selection: sortBinding) {
                    Text("Popularity").tag("popularity")
                    Text("IMDb Rating").tag("imdb_rating")
                    Text("Release Date").tag("date")
                }

                Picker("Order", selection: isAscBinding) {
                    Text("Descending").tag(false)
                    Text("Ascending").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
        #if os(macOS)
            .listStyle(.inset)
        #else
            .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
        .background(DiscoverPalette.groupedBackground)
        .navigationTitle("Internal Filters")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset") {
                    draft = Filter.discoverDefault()
                    timePeriod = .allTime
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    onApply(
                        draft.copyDiscover(
                            type: "internal",
                            traktURL: "",
                            page: 1
                        )
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var isMovieBinding: Binding<Bool> {
        Binding(
            get: { draft.isMovie },
            set: { newValue in
                draft = draft.copyDiscover(
                    isMovie: newValue,
                    includedGenres: [],
                    excludedGenres: []
                )
                timePeriod = TimePeriodSelection(from: draft)
            }
        )
    }

    private var isFirstAirBinding: Binding<Bool> {
        Binding(
            get: { draft.isFirstAir },
            set: { draft = draft.copyDiscover(isFirstAir: $0) }
        )
    }

    private var imdbRatingBinding: Binding<Int> {
        Binding(
            get: { draft.imdbRating },
            set: { value in
                let minVotes = value == 0 ? 0 : draft.minVotes
                draft = draft.copyDiscover(
                    imdbRating: value,
                    minVotes: minVotes
                )
            }
        )
    }

    private var minVotesBinding: Binding<Int> {
        Binding(
            get: { draft.minVotes },
            set: { draft = draft.copyDiscover(minVotes: $0) }
        )
    }

    private var languageBinding: Binding<String?> {
        Binding(
            get: { draft.language.isEmpty ? nil : draft.language },
            set: { draft = draft.copyDiscover(language: $0 ?? "") }
        )
    }

    private var sortBinding: Binding<String> {
        Binding(
            get: { draft.sort },
            set: { draft = draft.copyDiscover(sort: $0) }
        )
    }

    private var isAscBinding: Binding<Bool> {
        Binding(
            get: { draft.isAsc },
            set: { draft = draft.copyDiscover(isAsc: $0) }
        )
    }

    private var includedGenresBinding: Binding<[Int]> {
        Binding(
            get: { draft.includedGenres },
            set: { draft = draft.copyDiscover(includedGenres: $0) }
        )
    }

    private var excludedGenresBinding: Binding<[Int]> {
        Binding(
            get: { draft.excludedGenres },
            set: { draft = draft.copyDiscover(excludedGenres: $0) }
        )
    }
}


private struct GenreChipGrid: View {
    let genres: [Int: Genre]
    @Binding var selectedIds: [Int]
    var accentColor: Color = .blue

    private var sortedGenreIds: [Int] {
        genres.keys.sorted()
    }

    var body: some View {
        if sortedGenreIds.isEmpty {
            ContentUnavailableView(
                "Genres Unavailable",
                systemImage: "tag.slash",
                description: Text(
                    "Genres are still loading. Open this filter again in a moment."
                )
            )
            .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 110),
                        spacing: 8,
                        alignment: .leading
                    )
                ],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(sortedGenreIds, id: \.self) { genreId in
                    if let genre = genres[genreId] {
                        let isSelected = selectedIds.contains(genreId)
                        GenreChip(
                            name: genre.name,
                            isSelected: isSelected,
                            accentColor: accentColor
                        ) {
                            if isSelected {
                                selectedIds.removeAll { $0 == genreId }
                            } else {
                                selectedIds.append(genreId)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct GenreChip: View {
    let name: String
    let isSelected: Bool
    var accentColor: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                Text(name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? accentColor : .primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? accentColor.opacity(0.16)
                            : DiscoverPalette.chipFill
                    )
            )
        }
        .buttonStyle(.plain)
    }
}


private struct DiscoverTraktListPicker: View {
    let profile: Profile?
    let onSelect: (Filter, String?) -> Void

    private var traktLists: [TraktList] {
        profile?.traktLists ?? []
    }

    var body: some View {
        List {
            Section("Featured") {
                TraktOptionRow(
                    icon: "flame.fill",
                    tint: .orange,
                    title: "Trending Movies",
                    subtitle: "Most popular movies right now"
                ) {
                    onSelect(
                        Filter.discoverDefault().copyDiscover(
                            type: "trakt",
                            traktURL: "trending",
                            isMovie: true,
                            page: 1
                        ),
                        "Trending Movies"
                    )
                }

                TraktOptionRow(
                    icon: "flame.fill",
                    tint: .orange,
                    title: "Trending Shows",
                    subtitle: "Most popular TV shows right now"
                ) {
                    onSelect(
                        Filter.discoverDefault().copyDiscover(
                            type: "trakt",
                            traktURL: "trending",
                            isMovie: false,
                            page: 1
                        ),
                        "Trending Shows"
                    )
                }

                if profile?.traktValid == true {
                    TraktOptionRow(
                        icon: "sparkles",
                        tint: .yellow,
                        title: "Recommended Shows",
                        subtitle: "Personalized Trakt picks"
                    ) {
                        onSelect(
                            Filter.discoverDefault().copyDiscover(
                                type: "trakt",
                                traktURL: "recommended",
                                isMovie: false,
                                page: 1
                            ),
                            "Recommended Shows"
                        )
                    }

                    TraktOptionRow(
                        icon: "sparkles",
                        tint: .yellow,
                        title: "Recommended Movies",
                        subtitle: "Personalized Trakt picks"
                    ) {
                        onSelect(
                            Filter.discoverDefault().copyDiscover(
                                type: "trakt",
                                traktURL: "recommended",
                                isMovie: true,
                                page: 1
                            ),
                            "Recommended Movies"
                        )
                    }
                }
            }

            if profile?.traktValid == true {
                Section("Your Lists") {
                    if traktLists.isEmpty {
                        Text("No custom Trakt lists were found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(traktLists, id: \.ids.trakt) { list in
                            TraktOptionRow(
                                icon: "bookmark.fill",
                                tint: .blue,
                                title: list.name,
                                subtitle: list.description.isEmpty
                                    ? "Trakt list" : list.description
                            ) {
                                onSelect(
                                    Filter.discoverDefault().copyDiscover(
                                        type: "trakt",
                                        traktURL: String(list.ids.trakt),
                                        page: 1
                                    ),
                                    list.name
                                )
                            }
                        }
                    }
                }
            } else {
                Section("Account") {
                    Text(
                        "Connect Trakt in Settings to access recommended and personal lists."
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        #if os(macOS)
            .listStyle(.inset)
        #else
            .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
        .background(DiscoverPalette.groupedBackground)
        .navigationTitle("Trakt Lists")
    }
}

private struct TraktOptionRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(
                        tint.opacity(0.14),
                        in: RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

private enum DiscoverPalette {
    static var groupedBackground: Color {
        #if os(macOS)
            return Color.black.opacity(0.001)
        #else
            return Color(.systemGroupedBackground)
        #endif
    }

    static var chipFill: Color {
        #if os(macOS)
            return Color.white.opacity(0.06)
        #else
            return Color(.secondarySystemFill)
        #endif
    }
}
