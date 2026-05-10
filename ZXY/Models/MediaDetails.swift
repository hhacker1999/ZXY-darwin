struct MediaDetails {
    let name: String
    let runtime: Int
    let cast: [Cast]
    let crew: [Cast]
    let similar: [CollectionPart]
    let recommendations: [CollectionPart]
    let collection: MovieCollection?
    let isMovie: Bool
    let images: Images?
    let imdbRating: Double
    let voteAverage: Double
    let airOrReleaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let genres: [Genre]
    let overView: String
    let seasons: [Season]
    let imdbId: String?

    init(from details: MovieDetails) {
        name = details.originalTitle
        runtime = details.runtime
        cast = details.credits != nil && details.credits!.cast != nil ? details.credits!.cast! : []
        crew = details.credits != nil && details.credits!.crew != nil ? details.credits!.crew! : []
        similar = details.similar != nil ? details.similar!.results : []
        recommendations = details.recommendations != nil ? details.recommendations!.results : []
        collection = details.collection
        isMovie = true
        seasons = []
        imdbId = nil
        images = details.images
        imdbRating = details.imdbRating
        voteAverage = details.voteAverage
        airOrReleaseDate = details.releaseDate
        posterPath = details.posterPath
        backdropPath = details.backdropPath
        genres = details.genres
        overView = details.overview
    }

    init(from details: SeriesDetails) {
        let runtimes = details.episodeRunTime ?? []
        var averageRuntime = 0
        var temp = 0
        var count = 0
        for rt in runtimes {
            temp += rt
            count += 1
        }
        averageRuntime = count == 0 ? 0 : Int(temp / count)

        name = details.originalName
        runtime = averageRuntime
        cast = details.credits?.cast ?? []
        crew = details.credits?.crew ?? []
        similar = details.similar != nil ? details.similar!.results.map { res in CollectionPart(
            res: res
        ) } : []
        recommendations = details.recommendations != nil ? details.recommendations!.results.map { res in CollectionPart(
            res: res
        ) } : []
        collection = nil
        isMovie = false
        seasons = details.seasons
        imdbId = details.externalIds.imdbId
        images = details.images
        imdbRating = details.imdbRating
        voteAverage = details.voteAverage
        airOrReleaseDate = details.firstAirDate
        posterPath = details.posterPath
        backdropPath = details.backdropPath
        genres = details.genres
        overView = details.overview
    }
}
