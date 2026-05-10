//
//  SeriesDetails.swift
//
//  Ported from Flutter: app/lib/usecase/resource/tv_details.dart
//

import Foundation

// MARK: - Series Details

struct SeriesDetails: Codable {
    let adult: Bool?
    let backdropPath: String?
    let createdBy: [CreatedBy]?
    let episodeRunTime: [Int]?
    let firstAirDate: String?
    let genres: [Genre]
    let homepage: String?
    let id: Int
    let inProduction: Bool?
    let languages: [String]?
    let lastAirDate: String?
    let lastEpisodeToAir: Episode?
    let name: String
    let nextEpisodeToAir: Episode?
    let networks: [Network]?
    let numberOfEpisodes: Int?
    let numberOfSeasons: Int?
    let originCountry: [String]?
    let originalLanguage: String?
    let originalName: String
    let overview: String
    let popularity: Double?
    let posterPath: String?
    let productionCompanies: [Network]?
    let productionCountries: [ProductionCountry]?
    let spokenLanguages: [SpokenLanguage]?
    let status: String?
    let tagline: String?
    let type: String?
    let voteAverage: Double
    let voteCount: Int?
    let seasons: [Season]
    let externalIds: ExternalIds
    let credits: Credits?
    let images: Images?
    let similar: SimilarShows?
    let recommendations: SimilarShows?
    let imdbRating: Double

    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case createdBy = "created_by"
        case episodeRunTime = "episode_run_time"
        case firstAirDate = "first_air_date"
        case genres, homepage, id
        case inProduction = "in_production"
        case languages
        case lastAirDate = "last_air_date"
        case lastEpisodeToAir = "last_episode_to_air"
        case name
        case nextEpisodeToAir = "next_episode_to_air"
        case networks
        case numberOfEpisodes = "number_of_episodes"
        case numberOfSeasons = "number_of_seasons"
        case originCountry = "origin_country"
        case originalLanguage = "original_language"
        case originalName = "original_name"
        case overview, popularity
        case posterPath = "poster_path"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
        case spokenLanguages = "spoken_languages"
        case status, tagline, type
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case seasons
        case externalIds = "external_ids"
        case credits, images, similar, recommendations
        case imdbRating = "imdb_rating"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adult = try container.decodeIfPresent(Bool.self, forKey: .adult)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        createdBy = try container.decodeIfPresent([CreatedBy].self, forKey: .createdBy)
        episodeRunTime = try container.decodeIfPresent([Int].self, forKey: .episodeRunTime)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        genres = (try? container.decode([Genre].self, forKey: .genres)) ?? []
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        id = try container.decode(Int.self, forKey: .id)
        inProduction = try container.decodeIfPresent(Bool.self, forKey: .inProduction)
        languages = try container.decodeIfPresent([String].self, forKey: .languages)
        lastAirDate = try container.decodeIfPresent(String.self, forKey: .lastAirDate)
        lastEpisodeToAir = try container.decodeIfPresent(Episode.self, forKey: .lastEpisodeToAir)
        name = try container.decode(String.self, forKey: .name)
        nextEpisodeToAir = try container.decodeIfPresent(Episode.self, forKey: .nextEpisodeToAir)
        networks = try container.decodeIfPresent([Network].self, forKey: .networks)
        numberOfEpisodes = try container.decodeIfPresent(Int.self, forKey: .numberOfEpisodes)
        numberOfSeasons = try container.decodeIfPresent(Int.self, forKey: .numberOfSeasons)
        originCountry = try container.decodeIfPresent([String].self, forKey: .originCountry)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
        originalName = try container.decode(String.self, forKey: .originalName)
        overview = try container.decode(String.self, forKey: .overview)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        productionCompanies = try container.decodeIfPresent([Network].self, forKey: .productionCompanies)
        productionCountries = try container.decodeIfPresent([ProductionCountry].self, forKey: .productionCountries)
        spokenLanguages = try container.decodeIfPresent([SpokenLanguage].self, forKey: .spokenLanguages)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        voteAverage = (try? container.decode(Double.self, forKey: .voteAverage)) ?? 0
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount)
        seasons = (try? container.decode([Season].self, forKey: .seasons)) ?? []
        externalIds = try container.decode(ExternalIds.self, forKey: .externalIds)
        credits = try container.decodeIfPresent(Credits.self, forKey: .credits)
        images = try container.decodeIfPresent(Images.self, forKey: .images)
        similar = try container.decodeIfPresent(SimilarShows.self, forKey: .similar)
        recommendations = try container.decodeIfPresent(SimilarShows.self, forKey: .recommendations)
        imdbRating = (try? container.decode(Double.self, forKey: .imdbRating)) ?? 0
    }
}

// MARK: - Created By

struct CreatedBy: Codable {
    let id: Int?
    let creditId: String?
    let name: String?
    let originalName: String?
    let gender: Int?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case creditId = "credit_id"
        case name
        case originalName = "original_name"
        case gender
        case profilePath = "profile_path"
    }
}

// MARK: - Episode

struct Episode: Codable {
    let id: Int?
    let name: String
    let overview: String
    let voteAverage: Double?
    let voteCount: Int?
    let airDate: String?
    let episodeNumber: Int
    let episodeType: String?
    let productionCode: String?
    let runtime: Int?
    let seasonNumber: Int?
    let showId: Int?
    let stillPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case airDate = "air_date"
        case episodeNumber = "episode_number"
        case episodeType = "episode_type"
        case productionCode = "production_code"
        case runtime
        case seasonNumber = "season_number"
        case showId = "show_id"
        case stillPath = "still_path"
    }
}

// MARK: - Network

struct Network: Codable {
    let id: Int?
    let logoPath: String?
    let name: String?
    let originCountry: String?

    enum CodingKeys: String, CodingKey {
        case id
        case logoPath = "logo_path"
        case name
        case originCountry = "origin_country"
    }
}

// MARK: - Season

struct Season: Codable {
    let id: String?
    let airDate: String?
    let episodes: [Episode]
    let name: String?
    let networks: [Network]?
    let overview: String?
    let posterPath: String?
    let seasonNumber: Int
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case airDate = "air_date"
        case episodes, name, networks, overview
        case posterPath = "poster_path"
        case seasonNumber = "season_number"
        case voteAverage = "vote_average"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        airDate = try container.decodeIfPresent(String.self, forKey: .airDate)
        episodes = (try? container.decode([Episode].self, forKey: .episodes)) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name)
        networks = try container.decodeIfPresent([Network].self, forKey: .networks)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        seasonNumber = try container.decode(Int.self, forKey: .seasonNumber)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
    }
}

// MARK: - Show Result (named ShowResult to avoid clash with Swift's Result)

struct ShowResult: Codable {
    let adult: Bool?
    let backdropPath: String?
    let genreIds: [Int]?
    let id: Int
    let originCountry: [String]?
    let originalLanguage: String?
    let originalName: String
    let overview: String?
    let popularity: Double?
    let posterPath: String?
    let firstAirDate: String?
    let name: String
    let voteAverage: Double?
    let voteCount: Int?
    let imdbRating: Double

    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case genreIds = "genre_ids"
        case id
        case originCountry = "origin_country"
        case originalLanguage = "original_language"
        case originalName = "original_name"
        case overview, popularity
        case posterPath = "poster_path"
        case firstAirDate = "first_air_date"
        case name
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case imdbRating = "imdb_rating"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adult = try container.decodeIfPresent(Bool.self, forKey: .adult)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        genreIds = try container.decodeIfPresent([Int].self, forKey: .genreIds)
        id = try container.decode(Int.self, forKey: .id)
        originCountry = try container.decodeIfPresent([String].self, forKey: .originCountry)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
        originalName = try container.decode(String.self, forKey: .originalName)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        name = try container.decode(String.self, forKey: .name)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount)
        imdbRating = (try? container.decode(Double.self, forKey: .imdbRating)) ?? 0
    }
}

// MARK: - Similar Shows

struct SimilarShows: Codable {
    let page: Int?
    let results: [ShowResult]
    let totalPages: Int?
    let totalResults: Int?

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(Int.self, forKey: .page)
        results = (try? container.decode([ShowResult].self, forKey: .results)) ?? []
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        totalResults = try container.decodeIfPresent(Int.self, forKey: .totalResults)
    }
}

// MARK: - Similar Series (legacy alias)

typealias SimilarSeries = SimilarShows
