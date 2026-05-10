//
//  PaginatedResponse.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 01/04/26.
//

import Foundation

struct PaginatedResponse<T: Decodable>: Decodable {
    let page: Int
    let totalPages: Int
    let totalResults: Int
    let results: [T]

    enum CodingKeys: String, CodingKey {
        case page
        case totalPages = "total_pages"
        case totalResults = "total_results"
        case results
    }
}
