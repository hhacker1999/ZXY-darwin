//
//  Errors.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 29/03/26.
//

import Foundation

protocol HttpError: Error {
    func error() -> String
}

struct CookieNotFound: HttpError {
    var err: String = "Cookie not found"
    func error() -> String {
        err
    }
}

struct SomethingWentWrong: HttpError {
    var err: String = "Something went wrong"
    func error() -> String {
        err
    }
}

struct InternalServerError: HttpError {
    var err: String = "Internal Server Error"
    func error() -> String {
        err
    }
}

struct UnAuthorised: HttpError {
    var err: String = "Unauthorised"
    func error() -> String {
        err
    }
}

struct NotFound: HttpError {
    var err: String = "Unauthorised"
    func error() -> String {
        err
    }
}

struct BadRequest: HttpError {
    var err: String = "Invalid Request"
    func error() -> String {
        err
    }
}
