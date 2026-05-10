//
//  AppMedia.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 01/04/26.
//

import Foundation

struct AppMedia: Codable {
    let adult: Bool
    let backdropPath: String
    let id: Int
    let title, originalTitle, overview, posterPath: String
    let type, originalLanguage: String
    let popularity: Double
    let releaseDate: String?
    let voteAverage: Double
    let voteCount: Int
    let name: String
    let originCountry: [String]?
    let genreIds: [Int]?
    let imdbRating: Double
    let images: Images

    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case id, title
        case originalTitle = "original_title"
        case overview
        case posterPath = "poster_path"
        case type
        case originalLanguage = "original_language"
        case popularity
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case name
        case originCountry = "origin_country"
        case genreIds = "genre_ids"
        case imdbRating = "imdb_rating"
        case images
    }
}

struct Images: Codable {
    let backdrops: [MediaImage]?
    let logos: [MediaImage]?
    let posters: [MediaImage]?
}

struct MediaImage: Codable {
    let aspectRatio: Double
    let height: Int
    let iso3166_1, iso639_1, filePath: String
    let voteAverage: Double
    let voteCount, width: Int

    enum CodingKeys: String, CodingKey {
        case aspectRatio = "aspect_ratio"
        case height
        case iso3166_1 = "iso_3166_1"
        case iso639_1 = "iso_639_1"
        case filePath = "file_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case width
    }
}
