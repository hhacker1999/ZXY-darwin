import Foundation

protocol StreamViewModel: AnyObject {
    func isMovie() -> Bool
    func getMediaProgressSync() -> Double
    func hasNext() -> Bool
    func getCurrentMedia() -> MediaDetails
    func updateProgress(progress: Double) async
    func getStreams() async throws -> [VideoPlayerStream]
    func getSelectedStreamIndex() -> Int
    func setSelectedStreamIndex(_ index: Int)
    func getSeasonNo() -> Int
    func getEpisodeNo() -> Int
}
