//
//  StreamModels.swift
//
//  Ported from Flutter: app/lib/usecase/stream/model.dart
//

import Foundation

// MARK: - Stream Item

struct StreamItem: Codable {
    let name: String
    let description: String
    let url: String
    let behaviorHints: BehaviorHints
}

// MARK: - Behavior Hints

struct BehaviorHints: Codable {
    let bingeGroup: String?
    let videoSize: Int?
    let filename: String?
}

// MARK: - Stream Response

struct StreamResponse: Codable {
    let uhd: [ResolutionItem]
    let fhd: [ResolutionItem]
    let hd: [ResolutionItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uhd = (try? container.decode([ResolutionItem].self, forKey: .uhd)) ?? []
        fhd = (try? container.decode([ResolutionItem].self, forKey: .fhd)) ?? []
        hd = (try? container.decode([ResolutionItem].self, forKey: .hd)) ?? []
    }

    /// Empty response with no streams
    static let empty = StreamResponse()

    private init() {
        uhd = []
        fhd = []
        hd = []
    }
}

// MARK: - Resolution Item

struct ResolutionItem: Codable, Hashable, Equatable {
    let name: String
    let description: String
    let visualTags: [String]
    let audioTags: [String]
    let fileName: String?
    let languageCodes: [String]
    let size: Int?
    let url: String
    let quality: String?
    let resolution: String

    enum CodingKeys: String, CodingKey {
        case name, description
        case visualTags = "visual_tags"
        case audioTags = "audio_tags"
        case fileName = "file_name"
        case languageCodes = "language_codes"
        case size, url, quality, resolution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        description = (try? container.decode(String.self, forKey: .description)) ?? ""
        visualTags = (try? container.decode([String].self, forKey: .visualTags)) ?? []
        audioTags = (try? container.decode([String].self, forKey: .audioTags)) ?? []
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        languageCodes = (try? container.decode([String].self, forKey: .languageCodes)) ?? []
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        url = try container.decode(String.self, forKey: .url)
        quality = try container.decodeIfPresent(String.self, forKey: .quality)
        resolution = try container.decode(String.self, forKey: .resolution)
    }
}
