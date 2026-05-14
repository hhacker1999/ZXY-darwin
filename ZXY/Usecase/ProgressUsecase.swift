//
//  Progress.swift
//
//  Ported from Flutter: app/lib/usecase/progress/usecase.dart
//

import Foundation

class ProgressUsecase {
    private let httpService = HttpService.service

    func getContinueWatching() async throws -> [ContinueWatchingItem] {
        do {
            let url = URL(string: "\(Constants.baseUrl)/continue_watching")!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            guard
                let data = try await httpService.sendRaw(
                    req,
                    cookieType: .profile
                )
            else {
                return []
            }

            return try JSONDecoder().decode(
                [ContinueWatchingItem].self,
                from: data
            )
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func removeContinueWatching(mediaId: String) async throws {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)/continue_watching/\(mediaId)"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getMovieProgress(movieId: Int) async throws -> WatchProgress? {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)/movie/\(movieId)/progress"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            guard
                let data = try await httpService.sendRaw(
                    req,
                    cookieType: .profile
                )
            else {
                return nil
            }

            return try JSONDecoder().decode(WatchProgress.self, from: data)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func updateWatchProgressMovie(
        movieId: String,
        progress: Double
    ) async throws {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)/movie/update_progress"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "movie_id": movieId,
                "progress": progress,
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

    func updateMovieToWatched(movieId: String) async throws {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)/movie/\(movieId)/watched"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getProgressShow(showId: Int) async throws -> [WatchProgress] {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)/show/\(showId)/progress"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            guard
                let data = try await httpService.sendRaw(
                    req,
                    cookieType: .profile
                )
            else {
                return []
            }

            return try JSONDecoder().decode([WatchProgress].self, from: data)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func updateWatchProgressShow(
        showId: String,
        season: Int,
        episode: Int,
        progress: Double
    ) async throws {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)/show/update_progress"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "show_id": showId,
                "progress": progress,
                "episode": episode,
                "season": season,
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

    func updateShowToWatched(showId: String) async throws {
        do {
            let url = URL(
                string: "\(Constants.baseUrl)/show/\(showId)/watched"
            )!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }
}
