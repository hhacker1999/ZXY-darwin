//
//  SharedModels.swift
//  LearnSwift
//
//  Ported from Flutter: app/lib/usecase/resource/models.dart
//

import Foundation

// MARK: - Genre

struct Genre: Codable {
    let id: Int
    let name: String
}

struct GenreResponse: Codable {
    let movieGenre: [Genre]
    let showGenre: [Genre]

    enum CodingKeys: String, CodingKey {
        case movieGenre = "movie_genre"
        case showGenre = "show_genre"
    }
}

// MARK: - Image Configuration

struct ImageConfiguration: Codable {
    let baseUrl: String
    let secureBaseUrl: String
    let backdropSizes: [String]
    let logoSizes: [String]
    let posterSizes: [String]
    let profileSizes: [String]
    let stillSizes: [String]

    enum CodingKeys: String, CodingKey {
        case baseUrl = "base_url"
        case secureBaseUrl = "secure_base_url"
        case backdropSizes = "backdrop_sizes"
        case logoSizes = "logo_sizes"
        case posterSizes = "poster_sizes"
        case profileSizes = "profile_sizes"
        case stillSizes = "still_sizes"
    }
}

struct ImageConfigurationResponse: Codable {
    let images: ImageConfiguration
}

// MARK: - Credits

struct Credits: Codable {
    let cast: [Cast]?
    let crew: [Cast]?
}

struct Cast: Codable {
    let adult: Bool?
    let gender: Int?
    let id: Int
    let knownForDepartment: String?
    let name: String
    let originalName: String?
    let popularity: Double?
    let profilePath: String?
    let character: String?
    let creditId: String?
    let order: Int?
    let department: String?
    let job: String?

    enum CodingKeys: String, CodingKey {
        case adult, gender, id
        case knownForDepartment = "known_for_department"
        case name
        case originalName = "original_name"
        case popularity
        case profilePath = "profile_path"
        case character
        case creditId = "credit_id"
        case order, department, job
    }
}

// MARK: - External IDs

struct ExternalIds: Codable {
    let imdbId: String?
    let freebaseMid: String?
    let freebaseId: String?
    let tvdbId: Int?
    let tvrageId: Int?
    let wikidataId: String?
    let facebookId: String?
    let instagramId: String?
    let twitterId: String?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case freebaseMid = "freebase_mid"
        case freebaseId = "freebase_id"
        case tvdbId = "tvdb_id"
        case tvrageId = "tvrage_id"
        case wikidataId = "wikidata_id"
        case facebookId = "facebook_id"
        case instagramId = "instagram_id"
        case twitterId = "twitter_id"
    }
}

// MARK: - Production Company

struct ProductionCompany: Codable {
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

// MARK: - Production Country

struct ProductionCountry: Codable {
    let iso31661: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case name
    }
}

// MARK: - Spoken Language

struct SpokenLanguage: Codable {
    let englishName: String?
    let iso6391: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case englishName = "english_name"
        case iso6391 = "iso_639_1"
        case name
    }
}
