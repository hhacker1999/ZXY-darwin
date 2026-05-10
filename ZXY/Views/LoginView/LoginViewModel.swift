//
//  LoginViewModel.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 29/03/26.
//

import Foundation
import Observation

@Observable
@MainActor
class LoginViewModel {
    var isSignup: Bool = false
    var isLoading: Bool = false
    let authUc: AuthUsecase
    var user: User?
    var err: String?
    var navigateToProfiles: Bool = false

    private let router: Router = Router.router

    init(authUc: AuthUsecase) {
        self.authUc = authUc
    }

    func login(email: String, pwd: String) async {
        if email.isEmpty || pwd.isEmpty {
            err = "Email or password cannot be empty"
            return
        }
        err = nil
        do {
            defer {
                isLoading = false
            }
            isLoading = true
            let loggedInUser = try await authUc.loginUser(
                email: email,
                pwd: pwd
            )
            user = loggedInUser
            isLoading = false

            // Set this users as app user in user bloc
            UserBloc.bloc.user = user
            router.routerState = .profileLogIn(loggedInUser.profiles)
        } catch let error as HttpError {
            err = error.error()
        } catch {
            err = error.localizedDescription
        }
    }
}
