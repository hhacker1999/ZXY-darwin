import Foundation

struct AddonManifest: Codable {
    let name: String
    let id: String
    let version: String
    let description: String
    let resources: [Resource]
    let types: [String]
    let logo: String
    let behaviorHints: BehaviorHints

    enum CodingKeys: String, CodingKey {
        case name
        case id
        case version
        case description
        case resources
        case types
        case logo
        case behaviorHints
    }
}

struct Resource: Codable {
    let name: String
    let types: [String]
    let idPrefixes: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case types
        case idPrefixes
    }
}

struct Stream: Codable {
    let name: String
    let description: String
    let url: String?
    let behaviorHints: BehaviorHints?
    let externalURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case url
        case behaviorHints
        case externalURL = "externalUrl"
    }
}

struct BehaviorHints: Codable {
    let bingeGroup: String
    let videoSize: Int
    let filename: String
    let configurable: Bool
    let configurationRequired: Bool

    enum CodingKeys: String, CodingKey {
        case bingeGroup
        case videoSize
        case filename
        case configurable
        case configurationRequired
    }
}
