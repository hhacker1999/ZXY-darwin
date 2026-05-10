//
//  Media.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 01/04/26.
//

import Foundation

class MediaUsecase {
    private let httpService = HttpService.service

    private let moviePath = "/discover/movies"
    private let showPath = "/discover/shows"
    private let libraryPath = "/discover/library"
    private let modifyLibraryPath = "/user/library"
    private let trendingMoviePath = "/trending/movies"
    private let trendingShowPath = "/trending/shows"

    func getLibraryFromFilter(filter: Filter) async throws -> PaginatedResponse<
        AppMedia
    > {
        do {
            let url = URL(string: "\(Constants.baseUrl)\(libraryPath)")
            var req = URLRequest(url: url!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "content-type")

            let data = try JSONEncoder().encode(filter)
            req.httpBody = data

            let response: PaginatedResponse<AppMedia> =
                try await httpService.send(req, cookieType: .profile)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func discoverMovies(
        filter: [String: String]? = nil
    ) async throws -> PaginatedResponse<AppMedia> {
        do {
            let url = HttpService.buildURL(
                "\(Constants.baseUrl)\(moviePath)",
                query: filter
            )
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: PaginatedResponse<AppMedia> =
                try await httpService.send(req, cookieType: .profile)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func discoverShows(
        filter: [String: String]? = nil
    ) async throws -> PaginatedResponse<AppMedia> {
        do {
            let url = HttpService.buildURL(
                "\(Constants.baseUrl)\(showPath)",
                query: filter
            )
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: PaginatedResponse<AppMedia> =
                try await httpService.send(req, cookieType: .profile)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getMovieDetails(id: Int) async throws -> MovieDetails {
        do {
            let url = URL(
                string:
                    "\(Constants.baseUrl)/movie/\(id)?append_to_response=credits"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let details: MovieDetails = try await httpService.send(
                req,
                cookieType: .profile
            )
            return details
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getSeriesDetails(id: Int) async throws -> SeriesDetails {
        do {
            let url = URL(
                string:
                    "\(Constants.baseUrl)/show/\(id)?append_to_response=credits"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let details: SeriesDetails = try await httpService.send(
                req,
                cookieType: .profile
            )
            return details
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getSeasonDetails(id: Int, seasonNo: Int) async throws -> Season {
        do {
            let url = URL(
                string:
                    "\(Constants.baseUrl)/show/\(id):\(seasonNo)?append_to_response=credits"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let season: Season = try await httpService.send(
                req,
                cookieType: .profile
            )
            return season
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getEpisodeDetails(
        id: Int,
        seasonNo: Int,
        episodeNumber: Int
    ) async throws -> Episode {
        do {
            let url = URL(
                string:
                    "\(Constants.baseUrl)/show/\(id):\(seasonNo):\(episodeNumber)?append_to_response=credits"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let episode: Episode = try await httpService.send(
                req,
                cookieType: .profile
            )
            return episode
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getTrendingMovies(
        filter: [String: String]? = nil
    ) async throws -> PaginatedResponse<AppMedia> {
        do {
            let url = HttpService.buildURL(
                "\(Constants.baseUrl)\(trendingMoviePath)",
                query: filter
            )
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: PaginatedResponse<AppMedia> =
                try await httpService.send(req, cookieType: .profile)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getTrendingShows(
        filter: [String: String]? = nil
    ) async throws -> PaginatedResponse<AppMedia> {
        do {
            let url = HttpService.buildURL(
                "\(Constants.baseUrl)\(trendingShowPath)",
                query: filter
            )
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: PaginatedResponse<AppMedia> =
                try await httpService.send(req, cookieType: .profile)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getGenre() async throws -> GenreResponse {
        do {
            let url = URL(string: "\(Constants.baseUrl)/genre")!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: GenreResponse = try await httpService.send(
                req,
                cookieType: .none
            )
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getConfiguration() async throws -> ImageConfiguration {
        do {
            let url = URL(string: "\(Constants.baseUrl)/configuration")!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: ImageConfigurationResponse =
                try await httpService.send(
                    req,
                    cookieType: .profile
                )
            return response.images
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func searchMovies(
        page: Int,
        keyword: String
    ) async throws -> PaginatedResponse<AppMedia> {
        do {
            let url = URL(
                string:
                    "\(Constants.baseUrl)/search/movie?page=\(page)&keyword=\(keyword)"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: PaginatedResponse<AppMedia> =
                try await httpService.send(req, cookieType: .profile)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func searchShows(
        page: Int,
        keyword: String
    ) async throws -> PaginatedResponse<AppMedia> {
        do {
            let url = URL(
                string:
                    "\(Constants.baseUrl)/search/show?page=\(page)&keyword=\(keyword)"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: PaginatedResponse<AppMedia> =
                try await httpService.send(req, cookieType: .profile)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func addToLibrary(tmdbId: Int, tp: String) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)\(modifyLibraryPath)")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "tmdb_id": tmdbId,
                "type": tp,
            ]
            req.httpBody = try JSONSerialization.data(
                withJSONObject: body,
                options: []
            )
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func removeFromLibrary(tmdbId: Int, tp: String) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)\(modifyLibraryPath)")!
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "tmdb_id": tmdbId,
                "type": tp,
            ]
            req.httpBody = try JSONSerialization.data(
                withJSONObject: body,
                options: []
            )
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func isInLibrary(tmdbId: Int, tp: String) async throws -> Bool {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)\(modifyLibraryPath)/check"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "tmdb_id": tmdbId,
                "type": tp,
            ]
            req.httpBody = try JSONSerialization.data(
                withJSONObject: body,
                options: []
            )

            let response: [String: Bool] = try await httpService.send(
                req,
                cookieType: .profile
            )
            return response["found"] ?? false
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

}
