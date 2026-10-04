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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        id = try container.decode(String.self, forKey: .id)
        version = try container.decode(String.self, forKey: .version)
        description = try container.decode(String.self, forKey: .description)
        resources = try container.decode([Resource].self, forKey: .resources)
        types = try container.decode([String].self, forKey: .types)
        logo = try container.decode(String.self, forKey: .logo)
        behaviorHints = try container.decodeIfPresent(BehaviorHints.self, forKey: .behaviorHints) ?? .empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(id, forKey: .id)
        try container.encode(version, forKey: .version)
        try container.encode(description, forKey: .description)
        try container.encode(resources, forKey: .resources)
        try container.encode(types, forKey: .types)
        try container.encode(logo, forKey: .logo)
        try container.encode(behaviorHints, forKey: .behaviorHints)
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
    let behaviorHints: BehaviorHints
    let externalURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case url
        case behaviorHints
        case externalURL = "externalUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        behaviorHints = try container.decodeIfPresent(BehaviorHints.self, forKey: .behaviorHints) ?? .empty
        externalURL = try container.decodeIfPresent(String.self, forKey: .externalURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encode(behaviorHints, forKey: .behaviorHints)
        try container.encodeIfPresent(externalURL, forKey: .externalURL)
    }
}

struct BehaviorHints: Codable {
    static let empty = BehaviorHints(
        bingeGroup: "",
        videoSize: 0,
        filename: "",
        configurable: false,
        configurationRequired: false
    )

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

    init(
        bingeGroup: String,
        videoSize: Int,
        filename: String,
        configurable: Bool,
        configurationRequired: Bool
    ) {
        self.bingeGroup = bingeGroup
        self.videoSize = videoSize
        self.filename = filename
        self.configurable = configurable
        self.configurationRequired = configurationRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bingeGroup = try container.decodeIfPresent(String.self, forKey: .bingeGroup) ?? ""
        videoSize = try container.decodeIfPresent(Int.self, forKey: .videoSize) ?? 0
        filename = try container.decodeIfPresent(String.self, forKey: .filename) ?? ""
        configurable = try container.decodeIfPresent(Bool.self, forKey: .configurable) ?? false
        configurationRequired = try container.decodeIfPresent(Bool.self, forKey: .configurationRequired) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bingeGroup, forKey: .bingeGroup)
        try container.encode(videoSize, forKey: .videoSize)
        try container.encode(filename, forKey: .filename)
        try container.encode(configurable, forKey: .configurable)
        try container.encode(configurationRequired, forKey: .configurationRequired)
    }
}
