//
//  HttpService.swift
//
//  Created by Harsh Kumar on 31/03/26.
//

import Foundation

enum CookieType {
    case none
    case user
    case profile
}

struct Empty: Decodable {}

struct ApiError: Decodable {
    let error: String
}

class HttpService {
    private var userCookie: String?
    private var profileCookie: String?

    static let service = HttpService()

    func loadCookiesIfPresent() -> Bool {
        guard let uCookie = SecureStorage.getSecret(key: "user_cookie") else {
            return false
        }
        userCookie = uCookie
        guard let pCookie = SecureStorage.getSecret(key: "profile_cookie") else {
            return false
        }
        profileCookie = pCookie
        return true
    }

    func clearCookie() {
        userCookie = nil
        profileCookie = nil
    }

    func isProfileLoggedIn() -> Bool {
        return profileCookie != nil && userCookie != nil
    }

    func isUserLoggedIn() -> Bool {
        return userCookie != nil
    }

    /// Build a URL with query parameters appended
    static func buildURL(_ base: String, query: [String: String]? = nil) -> URL {
        var urlString = base
        if let query = query, !query.isEmpty {
            let queryString = query.map { "\($0.key)=\($0.value)" }.joined(
                separator: "&"
            )
            urlString += "?\(queryString)"
        }
        return URL(string: urlString)!
    }

    /// Send a request and discard the response body (fire-and-forget)
    func sendVoid(_ request: URLRequest, cookieType: CookieType) async throws {
        let _: Empty = try await send(request, cookieType: cookieType)
    }

    /// Send a request and return raw Data (for endpoints that may return null/empty bodies)
    func sendRaw(_ request: URLRequest, cookieType: CookieType) async throws
        -> Data?
    {
        var httpReq = request
        if cookieType == .user {
            if userCookie == nil {
                throw CookieNotFound()
            }
            httpReq.setValue("session_token=\(userCookie!)", forHTTPHeaderField: "cookie")
        }

        if cookieType == .profile {
            if profileCookie == nil {
                throw CookieNotFound()
            }
            httpReq.setValue("profile_token=\(profileCookie!)", forHTTPHeaderField: "cookie")
        }

        let (data, urlResponse) = try await URLSession.shared.data(for: httpReq)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw SomethingWentWrong()
        }

        let cookie = httpResponse.value(forHTTPHeaderField: "set-cookie")

        if cookie != nil {
            let broken = cookie!.split(separator: ";")
            for item in broken {
                let trimmed = item.trimmingCharacters(in: [" "])
                let profileTokenStr = "profile_token"
                let sessionTokenStr = "session_token"
                if trimmed.count > profileTokenStr.count,
                   trimmed.hasPrefix(profileTokenStr)
                {
                    let temp = trimmed.split(separator: "=")
                    if temp.last != nil {
                        profileCookie = temp.last!.lowercased()
                        SecureStorage.saveSecret(key: "profile_cookie", value: profileCookie!)
                    }
                }

                if trimmed.count > sessionTokenStr.count,
                   trimmed.hasPrefix(sessionTokenStr)
                {
                    let temp = trimmed.split(separator: "=")
                    if temp.last != nil {
                        userCookie = temp.last!.lowercased()
                        SecureStorage.saveSecret(key: "user_cookie", value: userCookie!)
                    }
                }
            }
        }

        let statusCode = httpResponse.statusCode
        let decoder = JSONDecoder()

        switch statusCode {
        case 200 ... 299:
            break
        case 401:
            if let apiError = try? decoder.decode(ApiError.self, from: data) {
                throw UnAuthorised(err: apiError.error)
            } else {
                throw UnAuthorised()
            }
        case 404:
            throw NotFound()
        case 400:
            if let apiError = try? decoder.decode(ApiError.self, from: data) {
                throw BadRequest(err: apiError.error)
            } else {
                throw BadRequest()
            }
        case 500 ... 599:
            if let apiError = try? decoder.decode(ApiError.self, from: data) {
                throw InternalServerError(err: apiError.error)
            } else {
                throw InternalServerError()
            }
        default:
            throw SomethingWentWrong()
        }

        let bodyString = String(data: data, encoding: .utf8)
        if bodyString == nil || bodyString!.isEmpty || bodyString == "null" {
            return nil
        }

        return data
    }

    /// Use this when expecting result back from the server
    func send<T: Decodable>(_ request: URLRequest, cookieType: CookieType)
        async throws -> T
    {
        var httpReq = request
        if cookieType == .user {
            if userCookie == nil {
                throw CookieNotFound()
            }
            httpReq.setValue("session_token=\(userCookie!)", forHTTPHeaderField: "cookie")
        }

        if cookieType == .profile {
            if profileCookie == nil {
                throw CookieNotFound()
            }

            httpReq.setValue("profile_token=\(profileCookie!)", forHTTPHeaderField: "cookie")
        }

        let (data, urlResponse) = try await URLSession.shared.data(for: httpReq)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw SomethingWentWrong()
        }

        let cookie = httpResponse.value(forHTTPHeaderField: "set-cookie")

        if cookie != nil {
            let broken = cookie!.split(separator: ";")
            for item in broken {
                let trimmed = item.trimmingCharacters(in: [" "])
                let profileTokenStr = "profile_token"
                let sessionTokenStr = "session_token"
                if trimmed.count > profileTokenStr.count
                    && trimmed.hasPrefix(profileTokenStr)
                {
                    let temp = trimmed.split(separator: "=")
                    if temp.last != nil {
                        profileCookie = temp.last!.lowercased()
                        SecureStorage.saveSecret(key: "profile_cookie", value: profileCookie!)
                    }
                }

                if trimmed.count > sessionTokenStr.count
                    && trimmed.hasPrefix(sessionTokenStr)
                {
                    let temp = trimmed.split(separator: "=")
                    if temp.last != nil {
                        userCookie = temp.last!.lowercased()
                        SecureStorage.saveSecret(key: "user_cookie", value: userCookie!)
                    }
                }
            }
        }

        let statusCode = httpResponse.statusCode

        // let rawBody = String(data: data, encoding: .utf8)
        // if rawBody != nil {
        //     print(rawBody!)
        // }

        let decoder = JSONDecoder()

        switch statusCode {
        case 200 ... 299:
            break
        case 401:
            if let apiError = try? decoder.decode(ApiError.self, from: data) {
                throw UnAuthorised(err: apiError.error)
            } else {
                throw UnAuthorised()
            }
        case 404:
            throw NotFound()
        case 400:
            if let apiError = try? decoder.decode(ApiError.self, from: data) {
                throw BadRequest(err: apiError.error)
            } else {
                throw BadRequest()
            }
        case 500 ... 599:
            if let apiError = try? decoder.decode(ApiError.self, from: data) {
                throw InternalServerError(err: apiError.error)
            } else {
                throw InternalServerError()
            }
        default:
            throw SomethingWentWrong()
        }

        if T.self == Empty.self {
            return Empty() as! T
        }

        return try decoder.decode(T.self, from: data)
    }
}
