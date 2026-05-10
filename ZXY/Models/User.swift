//
//  User.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 29/03/26.
//
import Foundation

struct User: Codable {
    let userID, name, email, createdAt: String
    let profiles: [Profile]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case name, email
        case createdAt = "created_at"
        case profiles
    }
}

struct ProfileService: Codable, Hashable, Equatable, Identifiable {
    let id: String
    let name: String
    let enabled: Bool
    let inputType: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case enabled
        case inputType = "input_type"
    }
}

struct Profile: Codable, Hashable, Equatable {
    let id: Int
    let name: String
    let isPinProtected: Bool
    let traktExpiry: String?
    let traktValid, isAdmin: Bool
    let libraryItems: [LibraryItem]?
    let traktLists: [TraktList]?
    let services: [ProfileService]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isPinProtected = "is_pin_protected"
        case traktExpiry = "trakt_expiry"
        case traktValid = "trakt_valid"
        case isAdmin = "is_admin"
        case libraryItems = "library_items"
        case traktLists = "trakt_lists"
        case services
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isPinProtected = try container.decode(Bool.self, forKey: .isPinProtected)
        traktExpiry = try container.decodeIfPresent(String.self, forKey: .traktExpiry)
        traktValid = try container.decode(Bool.self, forKey: .traktValid)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        libraryItems = try container.decodeIfPresent([LibraryItem].self, forKey: .libraryItems)
        traktLists = try container.decodeIfPresent([TraktList].self, forKey: .traktLists)
        services = try container.decodeIfPresent([ProfileService].self, forKey: .services) ?? []
    }
}

struct LibraryItem: Codable, Hashable, Equatable {
    let name: String
    let filter: Filter
}

struct Filter: Hashable, Equatable {
    let type: String
    let items: Int
    let traktURL: String?
    let isTrending: Bool
    let isMovie: Bool
    let thisWeek: Bool
    let thisMonth: Bool
    let years: [Int]
    let isFirstAir: Bool
    let imdbRating: Int
    let language: String
    let sort: String
    let isAsc: Bool
    let includedGenres: [Int]
    let excludedGenres: [Int]
    let page: Int
    let minVotes: Int

    init(type: String, items: Int, isMovie: Bool, traktUrl: String?) {
        self.type = type
        self.items = items
        isTrending = false
        self.isMovie = isMovie
        thisWeek = false
        thisMonth = false
        years = []
        isFirstAir = false
        imdbRating = 0
        language = ""
        sort = "popularity"
        isAsc = false
        includedGenres = []
        excludedGenres = []
        page = 1
        minVotes = 0
        traktURL = traktUrl
    }

    init(type: String, items: Int, isMovie: Bool, traktUrl: String?, page: Int) {
        self.type = type
        self.items = items
        isTrending = false
        self.isMovie = isMovie
        thisWeek = false
        thisMonth = false
        years = []
        isFirstAir = false
        imdbRating = 0
        language = ""
        sort = "popularity"
        isAsc = false
        includedGenres = []
        excludedGenres = []
        self.page = page
        minVotes = 0
        traktURL = traktUrl
    }

    init() {
        type = "internal"
        items = 10
        isTrending = false
        isMovie = true
        thisWeek = false
        thisMonth = false
        years = []
        isFirstAir = false
        imdbRating = 0
        language = ""
        sort = "popularity"
        isAsc = false
        includedGenres = []
        excludedGenres = []
        page = 1
        minVotes = 0
        traktURL = nil
    }

    enum CodingKeys: String, CodingKey {
        case type, items
        case traktURL = "trakt_url"
        case isTrending = "is_trending"
        case isMovie = "is_movie"
        case thisWeek = "this_week"
        case thisMonth = "this_month"
        case years
        case isFirstAir = "is_first_air"
        case imdbRating = "imdb_rating"
        case language, sort
        case isAsc = "is_asc"
        case includedGenres = "included_genres"
        case excludedGenres = "excluded_genres"
        case page
        case minVotes = "min_votes"
    }
}

extension Filter: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        items = try c.decode(Int.self, forKey: .items)
        traktURL = try c.decodeIfPresent(String.self, forKey: .traktURL)
        isTrending = try c.decodeIfPresent(Bool.self, forKey: .isTrending) ?? false
        isMovie = try c.decode(Bool.self, forKey: .isMovie)
        thisWeek = try c.decodeIfPresent(Bool.self, forKey: .thisWeek) ?? false
        thisMonth = try c.decodeIfPresent(Bool.self, forKey: .thisMonth) ?? false
        years = Self.decodeIntArray(from: c, forKey: .years)
        isFirstAir = try c.decodeIfPresent(Bool.self, forKey: .isFirstAir) ?? false
        imdbRating = try c.decodeIfPresent(Int.self, forKey: .imdbRating) ?? 0
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? ""
        sort = try c.decodeIfPresent(String.self, forKey: .sort) ?? "popularity"
        isAsc = try c.decodeIfPresent(Bool.self, forKey: .isAsc) ?? false
        includedGenres = Self.decodeIntArray(from: c, forKey: .includedGenres)
        excludedGenres = Self.decodeIntArray(from: c, forKey: .excludedGenres)
        page = try c.decodeIfPresent(Int.self, forKey: .page) ?? 1
        minVotes = try c.decodeIfPresent(Int.self, forKey: .minVotes) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(items, forKey: .items)
        try c.encodeIfPresent(traktURL, forKey: .traktURL)
        try c.encode(isTrending, forKey: .isTrending)
        try c.encode(isMovie, forKey: .isMovie)
        try c.encode(thisWeek, forKey: .thisWeek)
        try c.encode(thisMonth, forKey: .thisMonth)
        try c.encode(years, forKey: .years)
        try c.encode(isFirstAir, forKey: .isFirstAir)
        try c.encode(imdbRating, forKey: .imdbRating)
        try c.encode(language, forKey: .language)
        try c.encode(sort, forKey: .sort)
        try c.encode(isAsc, forKey: .isAsc)
        try c.encode(includedGenres, forKey: .includedGenres)
        try c.encode(excludedGenres, forKey: .excludedGenres)
        try c.encode(page, forKey: .page)
        try c.encode(minVotes, forKey: .minVotes)
    }

    private static func decodeIntArray(
        from c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [Int] {
        if let ints = try? c.decode([Int].self, forKey: key) {
            return ints
        }
        if let strings = try? c.decode([String].self, forKey: key) {
            return strings.compactMap { Int($0) }
        }
        return []
    }
}

struct TraktList: Codable, Hashable, Equatable {
    let name, description: String
    let ids: IDS
    let privacy: String
}

struct IDS: Codable, Hashable, Equatable {
    let trakt: Int
    let slug: String
}
