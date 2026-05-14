//
//  MovieDetails.swift
//
//  Ported from Flutter: app/lib/usecase/resource/movie_details.dart
//

import Foundation


struct MovieDetails: Codable {
    let adult: Bool?
    let externalIds: ExternalIds
    let backdropPath: String?
    let belongsToCollection: BelongsToCollection?
    let collection: MovieCollection?
    let budget: Int?
    let credits: Credits?
    let genres: [Genre]
    let homepage: String?
    let id: Int
    let imdbId: String
    let originCountry: [String]?
    let originalLanguage: String?
    let originalTitle: String
    let overview: String
    let popularity: Double?
    let posterPath: String
    let productionCompanies: [ProductionCompany]?
    let productionCountries: [ProductionCountry]?
    let releaseDate: String
    let revenue: Int?
    let runtime: Int
    let spokenLanguages: [SpokenLanguage]?
    let status: String?
    let tagline: String?
    let title: String
    let video: Bool?
    let voteAverage: Double
    let voteCount: Int?
    let images: Images?
    let similar: SimilarMovies?
    let recommendations: SimilarMovies?
    let imdbRating: Double

    enum CodingKeys: String, CodingKey {
        case adult
        case externalIds = "external_ids"
        case backdropPath = "backdrop_path"
        case belongsToCollection = "belongs_to_collection"
        case collection
        case budget, credits, genres, homepage, id
        case imdbId = "imdb_id"
        case originCountry = "origin_country"
        case originalLanguage = "original_language"
        case originalTitle = "original_title"
        case overview, popularity
        case posterPath = "poster_path"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
        case releaseDate = "release_date"
        case revenue, runtime
        case spokenLanguages = "spoken_languages"
        case status, tagline, title, video
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case images, similar, recommendations
        case imdbRating = "imdb_rating"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adult = try container.decodeIfPresent(Bool.self, forKey: .adult)
        externalIds = try container.decode(ExternalIds.self, forKey: .externalIds)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        belongsToCollection = try container.decodeIfPresent(BelongsToCollection.self, forKey: .belongsToCollection)
        collection = try container.decodeIfPresent(MovieCollection.self, forKey: .collection)
        budget = try container.decodeIfPresent(Int.self, forKey: .budget)
        credits = try container.decodeIfPresent(Credits.self, forKey: .credits)
        genres = (try? container.decode([Genre].self, forKey: .genres)) ?? []
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        id = try container.decode(Int.self, forKey: .id)
        imdbId = try container.decode(String.self, forKey: .imdbId)
        originCountry = try container.decodeIfPresent([String].self, forKey: .originCountry)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
        originalTitle = try container.decode(String.self, forKey: .originalTitle)
        overview = try container.decode(String.self, forKey: .overview)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
        posterPath = try container.decode(String.self, forKey: .posterPath)
        productionCompanies = try container.decodeIfPresent([ProductionCompany].self, forKey: .productionCompanies)
        productionCountries = try container.decodeIfPresent([ProductionCountry].self, forKey: .productionCountries)
        releaseDate = (try? container.decode(String.self, forKey: .releaseDate)) ?? ""
        revenue = try container.decodeIfPresent(Int.self, forKey: .revenue)
        runtime = try container.decode(Int.self, forKey: .runtime)
        spokenLanguages = try container.decodeIfPresent([SpokenLanguage].self, forKey: .spokenLanguages)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
        title = try container.decode(String.self, forKey: .title)
        video = try container.decodeIfPresent(Bool.self, forKey: .video)
        voteAverage = (try? container.decode(Double.self, forKey: .voteAverage)) ?? 0
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount)
        images = try container.decodeIfPresent(Images.self, forKey: .images)
        similar = try container.decodeIfPresent(SimilarMovies.self, forKey: .similar)
        recommendations = try container.decodeIfPresent(SimilarMovies.self, forKey: .recommendations)
        imdbRating = (try? container.decode(Double.self, forKey: .imdbRating)) ?? 0
    }
}


struct BelongsToCollection: Codable {
    let id: Int?
    let name: String?
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}


struct MovieCollection: Codable {
    let id: Int
    let name: String
    let originalLanguage: String?
    let originalName: String?
    let overview: String?
    let posterPath: String
    let backdropPath: String?
    let parts: [CollectionPart]

    enum CodingKeys: String, CodingKey {
        case id, name
        case originalLanguage = "original_language"
        case originalName = "original_name"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case parts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decode(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        parts = (try? container.decode([CollectionPart].self, forKey: .parts)) ?? []
    }
}


struct CollectionPart: Codable {
    let adult: Bool?
    let backdropPath: String?
    let id: Int
    let name: String?
    let originalName: String?
    let overview: String?
    let posterPath: String
    let mediaType: String?
    let originalLanguage: String?
    let genreIds: [Int]?
    let popularity: Double?
    let releaseDate: String?
    let video: Bool?
    let voteAverage: Double?
    let voteCount: Int?
    let originalTitle: String?
    let title: String?
    let imdbRating: Double

    enum CodingKeys: String, CodingKey {
        case adult
        case backdropPath = "backdrop_path"
        case id, name
        case originalName = "original_name"
        case overview
        case posterPath = "poster_path"
        case mediaType = "media_type"
        case originalLanguage = "original_language"
        case genreIds = "genre_ids"
        case popularity
        case releaseDate = "release_date"
        case video
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalTitle = "original_title"
        case title
        case imdbRating = "imdb_rating"
    }

    init(res: ShowResult) {
        adult = res.adult
        backdropPath = res.backdropPath
        id = res.id
        name = res.name
        originalName = res.originalName
        overview = res.overview
        posterPath = res.posterPath ?? ""
        mediaType = "show"
        originalLanguage = ""
        genreIds = res.genreIds
        popularity = res.popularity
        releaseDate = res.firstAirDate
        video = false
        voteAverage = res.voteAverage
        voteCount = res.voteCount
        originalTitle = ""
        title = ""
        imdbRating = res.imdbRating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adult = try container.decodeIfPresent(Bool.self, forKey: .adult)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = (try? container.decode(String.self, forKey: .posterPath)) ?? ""
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
        genreIds = try container.decodeIfPresent([Int].self, forKey: .genreIds)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        video = try container.decodeIfPresent(Bool.self, forKey: .video)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount)
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        imdbRating = (try? container.decode(Double.self, forKey: .imdbRating)) ?? 0
    }
}


struct SimilarMovies: Codable {
    let page: Int?
    let results: [CollectionPart]
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
        results = (try? container.decode([CollectionPart].self, forKey: .results)) ?? []
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        totalResults = try container.decodeIfPresent(Int.self, forKey: .totalResults)
    }
}
