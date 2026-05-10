//
//  Filter+Discover.swift
//  LearnSwift
//
//  Discover helpers — parity with Flutter `LibraryFilter.defaultFilter` / `copyWith`.
//

import Foundation

extension Filter {
    /// Matches Flutter `LibraryFilter.defaultFilter()` (internal TMDB discover baseline).
    static func discoverDefault() -> Filter {
        Filter(
            type: "internal",
            items: 15,
            traktURL: "",
            isTrending: false,
            isMovie: true,
            thisWeek: false,
            thisMonth: false,
            years: [],
            isFirstAir: true,
            imdbRating: 0,
            language: "",
            sort: "popularity",
            isAsc: false,
            includedGenres: [],
            excludedGenres: [],
            page: 1,
            minVotes: 0
        )
    }

    /// True when the filter equals the discover baseline (no custom discover selection).
    func isDiscoverDefaultBaseline() -> Bool {
        self == Filter.discoverDefault()
    }

    func copyDiscover(
        type: String? = nil,
        items: Int? = nil,
        traktURL: String? = nil,
        isTrending: Bool? = nil,
        isMovie: Bool? = nil,
        thisWeek: Bool? = nil,
        thisMonth: Bool? = nil,
        years: [Int]? = nil,
        isFirstAir: Bool? = nil,
        imdbRating: Int? = nil,
        language: String? = nil,
        sort: String? = nil,
        isAsc: Bool? = nil,
        includedGenres: [Int]? = nil,
        excludedGenres: [Int]? = nil,
        page: Int? = nil,
        minVotes: Int? = nil
    ) -> Filter {
        Filter(
            type: type ?? self.type,
            items: items ?? self.items,
            traktURL: traktURL ?? self.traktURL,
            isTrending: isTrending ?? self.isTrending,
            isMovie: isMovie ?? self.isMovie,
            thisWeek: thisWeek ?? self.thisWeek,
            thisMonth: thisMonth ?? self.thisMonth,
            years: years ?? self.years,
            isFirstAir: isFirstAir ?? self.isFirstAir,
            imdbRating: imdbRating ?? self.imdbRating,
            language: language ?? self.language,
            sort: sort ?? self.sort,
            isAsc: isAsc ?? self.isAsc,
            includedGenres: includedGenres ?? self.includedGenres,
            excludedGenres: excludedGenres ?? self.excludedGenres,
            page: page ?? self.page,
            minVotes: minVotes ?? self.minVotes
        )
    }

    /// Full memberwise initializer (used by discover and Codable).
    init(
        type: String,
        items: Int,
        traktURL: String?,
        isTrending: Bool,
        isMovie: Bool,
        thisWeek: Bool,
        thisMonth: Bool,
        years: [Int],
        isFirstAir: Bool,
        imdbRating: Int,
        language: String,
        sort: String,
        isAsc: Bool,
        includedGenres: [Int],
        excludedGenres: [Int],
        page: Int,
        minVotes: Int
    ) {
        self.type = type
        self.items = items
        self.traktURL = traktURL
        self.isTrending = isTrending
        self.isMovie = isMovie
        self.thisWeek = thisWeek
        self.thisMonth = thisMonth
        self.years = years
        self.isFirstAir = isFirstAir
        self.imdbRating = imdbRating
        self.language = language
        self.sort = sort
        self.isAsc = isAsc
        self.includedGenres = includedGenres
        self.excludedGenres = excludedGenres
        self.page = page
        self.minVotes = minVotes
    }
}
