struct Track: Codable, Identifiable {
    let id: Int
    let type: String // "video", "audio", or "sub"
    let srcId: Int?
    let title: String?
    let lang: String?
    let album: String?
    let codec: String?
    let external: Bool?
    let selected: Bool
    let main: Bool?

    /// UI Helper
    var displayName: String {
        let name = title ?? lang ?? "Track \(id)"
        let codecInfo = codec != nil ? " (\(codec!.uppercased()))" : ""
        return name + codecInfo
    }
}
