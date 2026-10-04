import Foundation

class StremioUsecase {
    private let httpService = HttpService.service

    func getStreamioManifestFromAddon(addonUrl: String) async throws -> AddonManifest {
        do {
            let url = URL(string: addonUrl)!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            let response: AddonManifest = try await httpService.send(req, cookieType: .none, logOutput: false)
            return response
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getStreams(baseUrl: String, itemId: String, isMovie: Bool) async throws -> [Stream] {
        do {
            var type = "series"
            if isMovie {
                type = "movie"
            }
            let urlString = "\(baseUrl)/stream/\(type)/\(itemId).json"
            let url = URL(string: urlString)!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            guard let data = try await httpService.sendRaw(
                req,
                cookieType: .none,
                logOutput: false
            ) else {
                return []
            }

            let response = try JSONDecoder().decode(StremioStreamsResponse.self, from: data)
            return response.streams
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }
}

private struct StremioStreamsResponse: Codable {
    let streams: [Stream]
}
