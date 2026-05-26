//
//  AppMedia.swift
//
//  Created by Harsh Kumar on 01/04/26.
//

import Foundation

struct AppMedia: Codable {
    let adult: Bool
    let backdropPath: String
    let id: Int
    let title, originalTitle, overview, posterPath, nonLogoPosterPath: String
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
    let videos: Videos

    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case id, title
        case originalTitle = "original_title"
        case overview
        case posterPath = "poster_path"
        case nonLogoPosterPath = "non_logo_poster_path"
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
        case videos
    }
}

struct Videos: Codable {
    let results: [VideoMedia]?

    /// First YouTube official trailer key (site == "YouTube", type == "Trailer").
    var youtubeTrailerKey: String? {
        guard let results = results else { return nil }
        let match = results.first { v in
            v.site == "YouTube" && v.type == "Trailer"
        }
        guard let key = match?.key, !key.isEmpty else { return nil }
        return key
    }
}

struct VideoMedia: Codable {
    let name: String
    let key: String
    let site: String
    let type: String
    let official: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        key = (try? container.decode(String.self, forKey: .key)) ?? ""
        site = (try? container.decode(String.self, forKey: .site)) ?? ""
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        official = (try? container.decode(Bool.self, forKey: .official)) ?? false
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
