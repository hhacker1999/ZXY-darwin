import Foundation

class StreamUsecase {
    private let httpService = HttpService.service
    private let streamPath = "/v2/streams"

    func getMovieStreams(id: String) async throws -> [VideoPlayerStream] {
        do {
            let url = HttpService.buildURL(
                "\(Constants.baseUrl)\(streamPath)",
                query: ["type": "movie", "id": id]
            )
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            guard let data = try await httpService.sendRaw(
                req,
                cookieType: .profile, logOutput: false
            ) else {
                return []
            }

            let streamRes = try JSONDecoder().decode(StreamResponse.self, from: data)
            var items: [VideoPlayerStream] = []
            for item in streamRes.uhd {
                items.append(item)
            }
            for item in streamRes.fhd {
                items.append(item)
            }
            for item in streamRes.hd {
                items.append(item)
            }

            return items
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getSeriesStreams(
        id: String,
        season: Int,
        episode: Int
    ) async throws -> StreamResponse {
        do {
            let url = HttpService.buildURL(
                "\(Constants.baseUrl)\(streamPath)",
                query: [
                    "type": "series",
                    "id": id,
                    "season": String(season),
                    "episode": String(episode),
                ]
            )
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            guard let data = try await httpService.sendRaw(
                req,
                cookieType: .profile, logOutput: false
            ) else {
                return .empty
            }

            return try JSONDecoder().decode(StreamResponse.self, from: data)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }
}
