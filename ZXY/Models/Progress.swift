//
//  Progress.swift
//
//  Ported from Flutter: app/lib/usecase/progress/model.dart
//

import Foundation

// MARK: - Watch Progress

struct WatchProgress: Codable {
    let mediaId: String
    let progress: Double
    let userId: Int
    let profileId: Int
    let isWatched: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case mediaId = "MediaId"
        case progress = "Progress"
        case userId = "UserId"
        case profileId = "ProfileId"
        case isWatched = "IsWatched"
        case createdAt = "CreatedAt"
        case updatedAt = "UpdatedAt"
    }
}

// MARK: - Continue Watching Item

struct ContinueWatchingItem: Codable {
    let media: AppMedia
    let progress: WatchProgress
}
