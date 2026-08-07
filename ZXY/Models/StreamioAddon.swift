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

struct BehaviorHints: Codable {
    let configurable: Bool
    let configurationRequired: Bool

    enum CodingKeys: String, CodingKey {
        case configurable
        case configurationRequired
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
