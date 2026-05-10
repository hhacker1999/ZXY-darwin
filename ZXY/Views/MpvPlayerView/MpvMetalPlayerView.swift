import Combine
import Foundation
import SwiftUI

enum MPVProperty {
    static let videoParamsColormatrix = "video-params/colormatrix"
    static let videoParamsColorlevels = "video-params/colorlevels"
    static let videoParamsPrimaries = "video-params/primaries"
    static let videoParamsGamma = "video-params/gamma"
    static let videoParamsSigPeak = "video-params/sig-peak"
    static let videoParamsSceneMaxR = "video-params/scene-max-r"
    static let videoParamsSceneMaxG = "video-params/scene-max-g"
    static let videoParamsSceneMaxB = "video-params/scene-max-b"
    static let videoBitRate = "video-bitrate"
    static let duration = "duration"
    static let timePos = "time-pos"
    static let cacheDuration = "demuxer-cache-duration"
    static let path = "path"
    static let pause = "pause"
    static let pausedForCache = "paused-for-cache"
    static let seeking = "seeking"
    static let hwCurrent = "hwdec-current"
    static let videoCodec = "video-codec"
    static let trackList = "track-list"
    static let downloadSpeed = "cache-speed"
}

struct MPVMetalPlayerView: NSViewControllerRepresentable {
    var coordinator: MpvViewModel
    func makeNSViewController(context _: Context) -> some NSViewController {
        let mpv = MPVMetalViewController()
        mpv.playDelegate = coordinator
        coordinator.player = mpv
        return mpv
    }

    func updateNSViewController(_: NSViewControllerType, context _: Context) {}

    static func dismantleNSViewController(_ nsViewController: MPVMetalViewController, coordinator _: MpvViewModel) {
        print("Deinit called inside of metal player view")
        nsViewController.cleanup()
    }

    // func makeCoordinator() -> MpvViewModel {
    //     coordinator
    // }
}

@MainActor
@Observable
final class MpvViewModel: MPVPlayerDelegate {
    init(streams: [ResolutionItem], selectedStreamIndex: Int, streamUc: StreamUsecase) {
        self.streams = streams
        self.streamUc = streamUc
        self.selectedStreamIndex = selectedStreamIndex
    }

    deinit {
        print("--------------------------------------------------")
        print("Deinit called inside the MPV View model")
        print("--------------------------------------------------")
        NSCursor.unhide()
    }

    let streamUc: StreamUsecase

    @ObservationIgnored
    weak var player: MPVMetalViewController?

    var hdrAvailable: Bool = false
    var edrRange: String = "1.0"

    // @ObservationIgnored
    // var currentUrl: URL
    var streams: [ResolutionItem]
    var selectedStreamIndex: Int = 0

    @ObservationIgnored
    var isMpvLoaded: Bool = false

    var paused: Bool = false
    var hdrEnabled: Bool = true

    var loading: Bool = true
    var overlayVisible = false

    var duration: Duration = .zero
    var currentPos: Duration = .zero
    var currentPlayHeadPos: Duration = .zero
    var cachePos: Duration = .zero

    @ObservationIgnored
    var cacheDur: Double = 0
    var downloadSpeed: Double = 0

    // Video info properties
    var sigPeak: Double = 0.0
    var colormatrix: String = "—"
    var primaries: String = "—"
    var gamma: String = "—"
    var videoBitRate: Double = 0.0
    var videoCodecName: String = "—"
    var showVideoInfoOverlay: Bool = false

    @ObservationIgnored
    var overlayTask: Task<Void, Never>?
    var videoInFocus: Bool = true

    var audioTracks: [Track] = []
    var subtitleTracks: [Track] = []
    var selectAudioTrack: Int = -1
    var selectSubTrack: Int = -1

    var currentDecoder: String = "NA"
    var volume: Double = 50
    var mute: Bool = false
    var isDragging = false

    var fetchingStreams: Bool = false
    var hasError: Bool = false
    var hasEnded: Bool = false

    func onTrackList(tracks: [Track]) {
        audioTracks.removeAll()
        subtitleTracks.removeAll()
        selectSubTrack = -1
        selectAudioTrack = -1
        var tempAudioTracks: [Track] = []
        var tempSubTracks: [Track] = []
        for track in tracks {
            if let external = track.external {
                if external {
                    continue
                }
            }
            if track.type == "audio" {
                tempAudioTracks.append(track)
            }
            if track.type == "sub" {
                tempSubTracks.append(track)
            }
        }
        audioTracks = tempAudioTracks
        subtitleTracks = tempSubTracks
        for i in 0 ..< tempAudioTracks.count {
            if tempAudioTracks[i].selected {
                selectAudioTrack = i
            }
        }
        for i in 0 ..< tempSubTracks.count {
            if tempSubTracks[i].selected {
                selectSubTrack = i
            }
        }
    }

    func playUrl(_ url: URL) {
        player?.loadFile(url)
        paused = false
    }

    func play() {
        player?.play()
        paused = false
    }

    func onUserInteraction() {
        if !overlayVisible {
            overlayVisible = true
            NSCursor.unhide()
        }
        overlayTask?.cancel()
        overlayTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else {
                return
            }
            guard let self = self else {
                return
            }
            if !Task.isCancelled {
                self.overlayVisible = false
                self.videoInFocus = true
                NSCursor.hide()
            }
        }
    }

    func togglePause() {
        onUserInteraction()
        if !paused {
            pause()
        } else {
            play()
        }
    }

    func pause() {
        paused = true
        player?.pause()
    }

    func seek(relative time: TimeInterval) {
        onUserInteraction()
        currentPlayHeadPos += Duration.seconds(time)
        player?.seek(relative: time)
    }

    func toggleVideoInfoOverlay() {
        showVideoInfoOverlay.toggle()
    }

    func cleanUp() {
        overlayTask?.cancel()
        overlayTask = nil
        player?.cleanup()
    }

    func toggleMute() {
        onUserInteraction()
        if mute {
            player?.setFlag("mute", false)
        } else {
            player?.setFlag("mute", true)
        }
        mute.toggle()
    }

    func switchStream(to index: Int) {
        onUserInteraction()
        guard index >= 0, index < streams.count, index != selectedStreamIndex else { return }
        selectedStreamIndex = index
        loading = true
        Task { [weak self] in
            guard let self = self else {
                return
            }
            await self.getAndLoadFinalUrl()
        }
    }

    func setAudioTrack(index: Int) {
        onUserInteraction()
        if index == -1 {
            player?.setString("aid", "no")
            selectAudioTrack = -1
        } else if index >= 0, index < audioTracks.count {
            let track = audioTracks[index]
            player?.setInt64("aid", Int64(track.id))
            selectAudioTrack = index
        }
    }

    func setSubtitleTrack(index: Int) {
        onUserInteraction()
        if index == -1 {
            player?.setString("sid", "no")
            selectSubTrack = -1
        } else if index >= 0, index < subtitleTracks.count {
            let track = subtitleTracks[index]
            player?.setInt64("sid", Int64(track.id))
            selectSubTrack = index
        }
    }

    func onDragStartOrUpdate(_ fraction: Double) {
        // NOTE: It means that drag just started
        if !isDragging {
            isDragging = true
            player?.pause()
            paused = true
        }
        onUserInteraction()
        currentPlayHeadPos = duration * fraction
    }

    func onDragEnd() {
        isDragging = false
        let durationDiff = currentPlayHeadPos - currentPos
        player?.seek(relative: Double(durationDiff.components.seconds))
        player?.play()
        paused = false
    }

    func getAndLoadFinalUrl() async {
        do {
            let finalUrl = try await streamUc.getStreamUrl(tempUrl: streams[selectedStreamIndex].url)
            print("--------------------------------------------------")
            print("final url we got is \(finalUrl)")
            print("--------------------------------------------------")
            player?.loadFile(URL(string: finalUrl)!)
        } catch {
            print("--------------------------------------------------")
            print("error getting final url \(error.localizedDescription)")
            print("--------------------------------------------------")
        }
    }

    func toggleHDR() {
        guard let player = player else {
            return
        }
        if !hdrAvailable {
            return
        }
        hdrEnabled.toggle()
        player.toggleHDR(hdrEnabled)
    }

    func onFileLoaded() {}

    func onFileEnd() {
        hasEnded = true
    }

    func onFileError() {
        hasError = true
    }

    func propertyChange(mpv _: OpaquePointer, propertyName: String, data: Any?) {
        guard let player else { return }
        switch propertyName {
        case MPVProperty.pausedForCache:
            loading = data as! Bool
        case MPVProperty.duration:
            duration = Duration.seconds(data as! Double)
        case MPVProperty.timePos:
            currentPos = Duration.seconds(data as! Double)
            if !isDragging {
                currentPlayHeadPos = currentPos
            }
        case MPVProperty.cacheDuration:
            guard let data = data as? Double else {
                return
            }
            cachePos = currentPos + Duration.seconds(data)
            cacheDur = data
        case MPVProperty.downloadSpeed:
            downloadSpeed = ((data as! Double) * 8) / 1_000_000
        case MPVProperty.hwCurrent:
            currentDecoder = data as! String
        case MPVProperty.videoParamsSigPeak:
            if let peak = data as? Double {
                sigPeak = peak
            }
            if let player = self.player {
                hdrAvailable = player.hdrAvailable
            }
        case MPVProperty.videoParamsColormatrix:
            if let value = data as? String {
                colormatrix = value
            }
        case MPVProperty.videoParamsPrimaries:
            if let value = data as? String {
                primaries = value
            }
        case MPVProperty.videoParamsGamma:
            if let value = data as? String {
                gamma = value
            }
        case MPVProperty.seeking:
            if let value = data as? Bool {
                if value {
                    if currentPlayHeadPos.components.seconds > cachePos.components.seconds {
                        loading = true
                    }
                } else {
                    if loading {
                        loading = false
                    }
                }
            }
        case MPVProperty.videoBitRate:
            if let value = data as? Double {
                videoBitRate = value
            }
        case MPVProperty.videoCodec:
            if let value = data as? String {
                videoCodecName = value
            }
        case "edr":
            if let edrRangeIncoming = data as? CGFloat {
                edrRange = String(format: "%.1f", edrRangeIncoming)
            }
        case "loaded":
            if !isMpvLoaded {
                player.setVolume(volume)
                Task { [weak self] in
                    guard let self = self else {
                        return
                    }
                    await self.getAndLoadFinalUrl()
                }
                isMpvLoaded = true
            }
        default: break
        }
    }
}
