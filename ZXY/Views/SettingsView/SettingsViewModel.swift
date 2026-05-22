//
//  SettingsViewModel.swift
//
//  Mirrors `app/lib/views/settings_view/settings_view_model.dart`. Holds
//  per-page state for the settings screen + side-effects (auth/library/sources).
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    // ── Library customization state ────────────────────────────────
    var libraryItems: [LibraryItem] = []
    var hasLibraryChanges: Bool = false

    // ── Trakt login flow ───────────────────────────────────────────
    var waitingTraktLogin: Bool = false

    // ── Inline async indicators ────────────────────────────────────
    var isSavingLibrary: Bool = false
    var isMutatingSources: Bool = false

    @ObservationIgnored
    private let authUc: AuthUsecase
    @ObservationIgnored
    private let userBloc: UserBloc = .bloc
    @ObservationIgnored
    private let httpService: HttpService = .service
    @ObservationIgnored
    private let router: Router = .router
    @ObservationIgnored
    private let toastBloc: ToastProgressBloc = .bloc
    @ObservationIgnored
    private var initializedProfileId: Int?
    @ObservationIgnored
    private var traktPollTask: Task<Void, Never>?

    init(authUc: AuthUsecase) {
        self.authUc = authUc
    }

    func initIfNeeded(for profile: Profile) {
        guard initializedProfileId != profile.id else { return }
        initializedProfileId = profile.id
        libraryItems = profile.libraryItems ?? []
        hasLibraryChanges = false
    }

    func addLibraryItem(_ item: LibraryItem) {
        libraryItems.append(item)
        hasLibraryChanges = true
    }

    func updateLibraryItem(at index: Int, with item: LibraryItem) {
        guard libraryItems.indices.contains(index) else { return }
        libraryItems[index] = item
        hasLibraryChanges = true
    }

    func deleteLibraryItem(at index: Int) {
        guard libraryItems.indices.contains(index) else { return }
        libraryItems.remove(at: index)
        hasLibraryChanges = true
    }

    func moveLibraryItem(from offsets: IndexSet, to destination: Int) {
        libraryItems.move(fromOffsets: offsets, toOffset: destination)
        hasLibraryChanges = true
    }

    func saveLibraryItems() async {
        guard !isSavingLibrary else { return }
        isSavingLibrary = true
        defer { isSavingLibrary = false }
        do {
            try await authUc.updateProfileList(list: libraryItems)
            let profile = try await authUc.getProfile()
            userBloc.profile = profile
            hasLibraryChanges = false
            toastBloc.showToast(message: "Home page lists saved", isError: false)
        } catch let error as HttpError {
            toastBloc.showToast(message: error.error(), isError: true)
        } catch {
            toastBloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func updateSource(type: String, value: String? = nil, enabled: Bool) async {
        await runMutatingSources("Source updated") {
            try await self.authUc.updateService(
                tp: type,
                value: value,
                enabled: enabled
            )
        }
    }

    private func runMutatingSources(
        _ successMessage: String,
        _ work: () async throws -> Void
    ) async {
        guard !isMutatingSources else { return }
        isMutatingSources = true
        toastBloc.enableLoading()
        defer {
            isMutatingSources = false
            toastBloc.disableLoading()
        }
        do {
            try await work()
            let profile = try await authUc.getProfile()
            userBloc.profile = profile
            toastBloc.showToast(message: successMessage, isError: false)
        } catch let error as HttpError {
            toastBloc.showToast(message: error.error(), isError: true)
        } catch {
            toastBloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func loginTrakt(opener: @MainActor @escaping (URL) -> Void) async {
        do {
            waitingTraktLogin = true
            let urlString = try await authUc.getTraktLoginUrl()
            if let url = URL(string: urlString) {
                opener(url)
            }
            startTraktPolling()
        } catch let error as HttpError {
            waitingTraktLogin = false
            toastBloc.showToast(message: error.error(), isError: true)
        } catch {
            waitingTraktLogin = false
            toastBloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    func deleteTrakt() async {
        do {
            try await authUc.deleteTraktLogin()
            let profile = try await authUc.getProfile()
            userBloc.profile = profile
            toastBloc.showToast(message: "Trakt disconnected", isError: false)
        } catch let error as HttpError {
            toastBloc.showToast(message: error.error(), isError: true)
        } catch {
            toastBloc.showToast(message: error.localizedDescription, isError: true)
        }
    }

    private func startTraktPolling() {
        traktPollTask?.cancel()
        traktPollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { return }
                guard let self else { return }
                do {
                    let profile = try await self.authUc.getProfile()
                    if profile.traktValid {
                        self.userBloc.profile = profile
                        self.waitingTraktLogin = false
                        return
                    }
                } catch {
                    // keep polling on transient errors
                }
            }
        }
    }

    func switchProfile() {
        guard let user = userBloc.user else { return }
        userBloc.profile = nil
        SecureStorage.saveKey(key: "profile_cookie", value: "")
        httpService.clearCookie()
        // Re-load session-only cookie so profile selection can re-login.
        _ = httpService.loadCookiesIfPresent()
        router.routerState = .profileLogIn(user.profiles)
    }

    func logout() {
        authUc.logout()
        userBloc.user = nil
        userBloc.profile = nil
        SecureStorage.saveKey(key: "user_cookie", value: "")
        SecureStorage.saveKey(key: "profile_cookie", value: "")
        router.mainRouteState = []
        router.routerState = .logIn
    }

    func deleteAccount() async {
        do {
            try await authUc.deleteAccount()
            authUc.logout()
            userBloc.user = nil
            userBloc.profile = nil
            SecureStorage.saveKey(key: "user_cookie", value: "")
            SecureStorage.saveKey(key: "profile_cookie", value: "")
            router.mainRouteState = []
            router.routerState = .logIn
        } catch let error as HttpError {
            toastBloc.showToast(message: error.error(), isError: true)
        } catch {
            toastBloc.showToast(message: error.localizedDescription, isError: true)
        }
    }
}
