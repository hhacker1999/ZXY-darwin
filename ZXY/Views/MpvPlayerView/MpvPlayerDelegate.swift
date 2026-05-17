@MainActor
protocol MPVPlayerDelegate: AnyObject {
    func propertyChange(propertyName: String, data: Any?)
    func onTrackList(tracks: [Track])
    func onFileLoaded()
    func onFileEnd()
    func onFileError()
}
