//
//  StreamModels.swift
//
//  Ported from Flutter: app/lib/usecase/stream/model.dart
//

import Foundation

struct StreamItem: Codable {
    let name: String
    let description: String
    let url: String
}

struct StreamResponse: Codable {
    let uhd: [VideoPlayerStream]
    let fhd: [VideoPlayerStream]
    let hd: [VideoPlayerStream]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uhd = (try? container.decode([VideoPlayerStream].self, forKey: .uhd)) ?? []
        fhd = (try? container.decode([VideoPlayerStream].self, forKey: .fhd)) ?? []
        hd = (try? container.decode([VideoPlayerStream].self, forKey: .hd)) ?? []
    }

    /// Empty response with no streams
    static let empty = StreamResponse()

    private init() {
        uhd = []
        fhd = []
        hd = []
    }
}

struct VideoPlayerStream: Hashable, Equatable, Codable {
    let visualTags: [String]
    let audioTags: [String]
    let fileName: String
    let languageCodes: [String]
    let size: Int
    let url: String
    let quality: String
    let resolution: String
    let source: String
    let hdrTags: [String]

    var name: String { resolution }
    var description: String { fileName }

    enum CodingKeys: String, CodingKey {
        case visualTags = "visual_tags"
        case audioTags = "audio_tags"
        case fileName = "file_name"
        case languageCodes = "language_codes"
        case size, url, quality, resolution, source
        case hdrTags = "hdr_tags"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visualTags = (try? container.decode([String].self, forKey: .visualTags)) ?? []
        audioTags = (try? container.decode([String].self, forKey: .audioTags)) ?? []
        fileName = (try? container.decode(String.self, forKey: .fileName)) ?? ""
        languageCodes = (try? container.decode([String].self, forKey: .languageCodes)) ?? []
        size = (try? container.decode(Int.self, forKey: .size)) ?? 0
        url = try container.decode(String.self, forKey: .url)
        quality = (try? container.decode(String.self, forKey: .quality)) ?? ""
        resolution = (try? container.decode(String.self, forKey: .resolution)) ?? ""
        source =
            (try? container.decode(String.self, forKey: .source))
            ?? resolution
        hdrTags = (try? container.decode([String].self, forKey: .hdrTags)) ?? []
    }

    init(source: String, baseStream: Stream, ptt: PTT.Result) {
        url = baseStream.url!
        fileName = baseStream.behaviorHints.filename
        size = baseStream.behaviorHints.videoSize
        quality = ptt.quality
        resolution = ptt.resolution
        self.source = source
        languageCodes = ptt.languages

        var visual: [String] = []
        hdrTags = ptt.hdr
        if !ptt.codec.isEmpty { visual.append(ptt.codec) }
        if ptt.upscaled { visual.append("Upscaled") }
        visualTags = visual

        var audio: [String] = []
        audio.append(contentsOf: ptt.audio)
        audioTags = audio
    }
}
