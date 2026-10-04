//
//  UserBloc.swift
//
//  Created by Harsh Kumar on 01/04/26.
//

import Foundation

struct StreamAddon: Identifiable {
    var profileAddon: ProfileAddon
    let addonManifest: AddonManifest
    let types: [String]
    let idPrefixes: [String]
    let baseUrl: String

    var id: Int {
        profileAddon.id
    }
}

@MainActor
@Observable
class UserBloc {
    static let bloc = UserBloc()

    private init() {}

    var user: User?
    var profile: Profile?
    var streamAddons: [StreamAddon]?

    func setProfile(incomingProfile: Profile, stremioUc: StremioUsecase) async {
        profile = incomingProfile
        if let profile = profile {
            if !profile.addons.isEmpty {
                let stremioUc = stremioUc
                let addons = await withTaskGroup(
                    of: (Int, StreamAddon?).self,
                    returning: [StreamAddon].self
                ) { group in
                    for (index, addon) in profile.addons.enumerated() {
                        group.addTask {
                            do {
                                let manifest = try await stremioUc.getStreamioManifestFromAddon(
                                    addonUrl: addon.manifestUrl
                                )

                                var types: [String] = []
                                var prefixes: [String] = []
                                for resource in manifest.resources {
                                    if resource.name == "stream" {
                                        for type in resource.types {
                                            types.append(type)
                                        }

                                        for prefix in resource.idPrefixes! {
                                            prefixes.append(prefix)
                                        }
                                    }
                                }
                                var manifestUrlCopy = addon.manifestUrl
                                let manifestString = "/manifest.json"
                                manifestUrlCopy.removeLast(manifestString.count)
                                return (
                                    index,
                                    StreamAddon(profileAddon: addon, addonManifest: manifest, types: types, idPrefixes: prefixes, baseUrl: manifestUrlCopy)
                                )
                            } catch let error as HttpError {
                                await ToastProgressBloc.bloc.showToast(
                                    message: error.error(),
                                    isError: true
                                )
                                return (index, nil)
                            } catch {
                                await ToastProgressBloc.bloc.showToast(
                                    message: error.localizedDescription,
                                    isError: true
                                )
                                return (index, nil)
                            }
                        }
                    }

                    var collected: [(Int, StreamAddon)] = []
                    for await (index, streamAddon) in group {
                        if let streamAddon {
                            collected.append((index, streamAddon))
                        }
                    }
                    return collected.sorted { $0.0 < $1.0 }.map(\.1)
                }
                streamAddons = addons
            }
        }
    }

    func resetUser() {
        user = nil
        profile = nil
        streamAddons = nil
    }

    func resetProfile() {
        profile = nil
        streamAddons = nil
    }
}
