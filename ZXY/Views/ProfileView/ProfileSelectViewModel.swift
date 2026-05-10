//
//  ProfileSelectViewModel.swift
//
//  Created by Harsh Kumar on 31/03/26.
//

import Foundation
import Observation

@Observable
@MainActor
class ProfileSelectViewModel {
    let authUc: AuthUsecase
    var selectedProfile: Profile?
    var pinText: String = ""
    var isLoading: Bool = false
    var err: String?
    var showPinInput: Bool = false
    private let router: Router = Router.router

    init(authUc: AuthUsecase) {
        self.authUc = authUc
    }

    func selectProfile(_ profile: Profile) {
        selectedProfile = profile
        pinText = ""
        err = nil

        if profile.isPinProtected {
            showPinInput = true
        } else {
            Task {
                await loginProfile()
            }
        }
    }

    func cancelPinInput() {
        showPinInput = false
        selectedProfile = nil
        pinText = ""
        err = nil
    }

    func submitPin() {
        guard !pinText.isEmpty else {
            err = "PIN cannot be empty"
            return
        }
        err = nil
        Task {
            await loginProfile()
        }
    }

    func loginProfile() async {
        if isLoading {
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            guard let profile = selectedProfile else { return }

            try await authUc.loginProfile(
                id: profile.id,
                pin: pinText
            )

            showPinInput = false
            let updateProfile = try await authUc.getProfile()

            // Set this is as logged in profile in userbloc
            UserBloc.bloc.profile = updateProfile
            router.routerState = .home([])
        } catch let error as HttpError {
            err = error.error()
        } catch {
            err = error.localizedDescription
        }
    }
}
