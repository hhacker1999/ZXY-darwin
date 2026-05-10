//
//  User.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 01/04/26.
//

import Foundation

@MainActor
@Observable
class UserBloc {
    static let bloc = UserBloc()
    private init() {
    }

    var user: User?
    var profile: Profile?
}
