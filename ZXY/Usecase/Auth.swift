//
//  Auth.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 29/03/26.
//

import SwiftUI

struct ProfileLoginBody: Encodable {
    let pin: String
    let id: Int
}

class AuthUsecase {
    private let httpService = HttpService.service

    func loginUser(email: String, pwd: String) async throws -> User {
        do {
            let url = URL(string: "\(Constants.baseUrl)/login")
            var req = URLRequest(url: url!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = [
                "email": email,
                "password": pwd,
            ]

            req.httpBody = try JSONEncoder().encode(body)

            let user: User = try await httpService.send(
                req,
                cookieType: .none
            )
            return user

        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func signup(name: String, email: String, password: String) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/signup")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "name": name,
                "email": email,
                "password": password,
            ]
            req.httpBody = try JSONEncoder().encode(body)
            try await httpService.sendVoid(req, cookieType: .none)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func loginProfile(id: Int, pin: String = "") async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/profile/login")
            var req = URLRequest(url: url!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] =
                [
                    "profile_id": id,
                    "pin": pin,
                ]

            req.httpBody = try JSONSerialization.data(
                withJSONObject: body,
                options: []
            )

            let _: Empty = try await httpService.send(
                req,
                cookieType: .user
            )
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getUser() async throws -> User {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user")!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let user: User = try await httpService.send(req, cookieType: .user)
            return user
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func getProfile() async throws -> Profile {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user/profile")
            var req = URLRequest(url: url!)
            req.httpMethod = "GET"

            let profile: Profile = try await httpService.send(
                req,
                cookieType: .profile
            )
            return profile

        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func storeUserDebridKey(debridType: String, apiKey: String) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user/debrid/api")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "debrid_type": debridType,
                "api_key": apiKey,
            ]
            req.httpBody = try JSONEncoder().encode(body)
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func deleteUserDebridKey() async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user/debrid/api")!
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

    func updateService(tp: String, value: String? = nil, enabled: Bool) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user/source")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            if !enabled {
                req.httpMethod = "DELETE"
            }
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: Any] = ["type": tp]
            if let value = value { body["value"] = value }
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    // MARK: - Profile Management

    func createProfile(name: String, pin: String?, copyKey: Bool) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user/profile")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "name": name,
                "use_default_profile_key": copyKey,
                "pin": pin ?? "",
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

    func updateProfile(name: String, pin: String?, profileId: Int) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user/profile")!
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "name": name,
                "profile_id": profileId,
                "pin": pin ?? "",
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

    func updateProfileList(list: [LibraryItem]) async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user/profile/list")!
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(list)
            try await httpService.sendVoid(req, cookieType: .profile)
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func deleteProfile(profileId: Int) async throws {
        do {
            let url = URL(
                string:
                "\(Constants.baseUrl)/user/profile?profile_id=\(profileId)"
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

    // MARK: - Trakt

    func getTraktLoginUrl() async throws -> String {
        do {
            let url = URL(string: "\(Constants.baseUrl)/trakt_url")!
            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            let response: [String: String] = try await httpService.send(
                req,
                cookieType: .profile
            )
            guard let traktUrl = response["url"] else {
                throw SomethingWentWrong()
            }
            return traktUrl
        } catch {
            print("--- DEBUG ERROR ---")
            print("Type: \(type(of: error))")
            print("Description: \(error)")
            throw error
        }
    }

    func deleteTraktLogin() async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/trakt")!
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

    // MARK: - Account

    func deleteAccount() async throws {
        do {
            let url = URL(string: "\(Constants.baseUrl)/user")!
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

    // MARK: - Session

    func logout() {
        httpService.clearCookie()
    }
}
