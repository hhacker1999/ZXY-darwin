import Combine
import Foundation
import SwiftUI

enum LetterboxingMode: String, CaseIterable, Identifiable {
    /// Black bars when the window aspect does not match the video.
    case letterbox = "Letterbox"
    /// Crop instead of bars so the frame is filled.
    case cropToFill = "Crop to fill"
    /// Distort to fill the frame.
    case stretch = "Stretch"

    var id: String {
        rawValue
    }
}

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

#if os(macOS)
    struct MPVMetalPlayerView: NSViewControllerRepresentable {
        var coordinator: MpvViewModel
        func makeNSViewController(context _: Context) -> some NSViewController {
            let mpv = MPVMetalViewController()
            mpv.playDelegate = coordinator
            coordinator.player = mpv
            return mpv
        }

        func updateNSViewController(_: NSViewControllerType, context _: Context)
        {}

        static func dismantleNSViewController(
            _ nsViewController: MPVMetalViewController,
            coordinator _: MpvViewModel
        ) {
            print("Deinit called inside of metal player view")
            nsViewController.cleanup()
        }
    }
#else

    struct MPVMetalPlayerView: UIViewControllerRepresentable {
        var coordinator: MpvViewModel

        func makeUIViewController(context _: Context) -> some UIViewController {
            let mpv = MPVMetalViewController()
            mpv.playDelegate = coordinator
            coordinator.player = mpv
            return mpv
        }

        func updateUIViewController(_: UIViewControllerType, context _: Context)
        {}

        static func dismantleUIViewController(
            _ uiViewController: MPVMetalViewController,
            coordinator _: MpvViewModel
        ) {
            print("Deinit called inside of metal player view (iOS)")
            uiViewController.cleanup()
        }
    }
#endif

@MainActor
@Observable
final class MpvViewModel: MPVPlayerDelegate {
    init(
        streams: [ResolutionItem],
        selectedStreamIndex: Int,
        streamUc: StreamUsecase,
        progressUc: ProgressUsecase,
        initialProgress: Double = 0,
        mediaId: String,
        name: String
    ) {
        self.streams = streams
        self.streamUc = streamUc
        self.selectedStreamIndex = selectedStreamIndex
        self.mediaId = mediaId
        isShow = false
        episodeNo = -1
        seasonNo = -1
        self.initialProgress = initialProgress
        self.progressUc = progressUc
        self.name = name
    }

    init(
        streams: [ResolutionItem],
        selectedStreamIndex: Int,
        streamUc: StreamUsecase,
        progressUc: ProgressUsecase,
        initialProgress: Double = 0,
        mediaId: String,
        seasonNo: Int,
        episodeNo: Int,
        name: String
    ) {
        self.streams = streams
        self.streamUc = streamUc
        self.selectedStreamIndex = selectedStreamIndex
        self.mediaId = mediaId
        isShow = true
        self.episodeNo = episodeNo
        self.seasonNo = seasonNo
        self.initialProgress = initialProgress
        self.progressUc = progressUc
        self.name = name
    }

    deinit {
        print("--------------------------------------------------")
        print("Deinit called inside the MPV View model")
        print("--------------------------------------------------")

        #if os(macOS)
            NSCursor.unhide()
        #endif
    }

    @ObservationIgnored
    let streamUc: StreamUsecase

    @ObservationIgnored
    let progressUc: ProgressUsecase

    @ObservationIgnored
    let mediaId: String
    @ObservationIgnored
    let name: String
    @ObservationIgnored
    let seasonNo: Int
    @ObservationIgnored
    let episodeNo: Int
    @ObservationIgnored
    let isShow: Bool
    @ObservationIgnored
    var initialProgress: Double
    @ObservationIgnored
    var progressTask: Task<Void, Never>?

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
    /// When true, auto-hide must not dismiss the overlay (settings UI is open).
    var settingsPanelOpen = false

    var duration: Duration = .zero
    var currentPos: Duration = .zero
    var currentPlayHeadPos: Duration = .zero
    var cachePos: Duration = .zero

    @ObservationIgnored
    var lastProgressPosition: Duration = .zero

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

    var letterboxingMode: LetterboxingMode = .letterbox

    var currentDecoder: String = "NA"
    var volume: Double = 50
    var mute: Bool = false
    var isDragging = false

    var fetchingStreams: Bool = false
    var hasError: Bool = false
    var hasEnded: Bool = false

    func setupProgressTask() {
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if let self = self {
                    if self.lastProgressPosition == self.currentPos {
                        continue
                    }

                    let currentPos = self.currentPos
                    let s1 = Double(currentPos.components.seconds)
                    let s2 = Double(self.duration.components.seconds)

                    if s2 < 0 || s1 < 0 {
                        continue
                    }

                    let currentProgress = (s1 / s2) * 100
                    if self.isShow {
                        try? await progressUc.updateWatchProgressShow(
                            showId: self.mediaId,
                            season: self.seasonNo,
                            episode: self.episodeNo,
                            progress: currentProgress
                        )
                    } else {
                        try? await progressUc.updateWatchProgressMovie(
                            movieId: self.mediaId,
                            progress: currentProgress
                        )
                    }
                    self.lastProgressPosition = currentPos
                } else {
                    return
                }
            }
        }
    }

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
        player?.mpv.loadFile(url)
        paused = false
    }

    func play() {
        player?.mpv.play()
        paused = false
    }

    func onUserInteraction() {
        if !overlayVisible {
            overlayVisible = true
            #if os(macOS)
                NSCursor.unhide()
            #endif
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
                guard !self.settingsPanelOpen else {
                    return
                }
                self.overlayVisible = false
                self.videoInFocus = true

                #if os(macOS)
                    if shouldHideCursor() {
                        NSCursor.hide()
                    }
                #endif
            }
        }
    }

    func toggleSettingsPanel() {
        onUserInteraction()
        settingsPanelOpen.toggle()
    }

    func closeSettingsPanel() {
        settingsPanelOpen = false
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
        player?.mpv.pause()
    }

    func seek(relative time: TimeInterval) {
        onUserInteraction()
        currentPlayHeadPos += Duration.seconds(time)
        player?.mpv.seek(relative: time)
    }

    func toggleVideoInfoOverlay() {
        showVideoInfoOverlay.toggle()
    }

    func cleanUp() {
        overlayTask?.cancel()
        progressTask?.cancel()
        progressTask = nil
        overlayTask = nil
        player?.cleanup()
    }

    func toggleMute() {
        onUserInteraction()
        if mute {
            player?.mpv.setFlag("mute", false)
        } else {
            player?.mpv.setFlag("mute", true)
        }
        mute.toggle()
    }

    func switchStream(to index: Int) {
        onUserInteraction()
        guard index >= 0, index < streams.count, index != selectedStreamIndex
        else { return }
        selectedStreamIndex = index
        loading = true
        player?.mpv.stop()

        let s1 = Double(currentPos.components.seconds)
        let s2 = Double(duration.components.seconds)

        if s2 > 0, s1 > 0 {
            initialProgress = (s1 / s2) * 100
        }

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
            player?.mpv.setString("aid", "no")
            selectAudioTrack = -1
        } else if index >= 0, index < audioTracks.count {
            let track = audioTracks[index]
            player?.mpv.setInt64("aid", Int64(track.id))
            selectAudioTrack = index
        }
    }

    func setSubtitleTrack(index: Int) {
        onUserInteraction()
        if index == -1 {
            player?.mpv.setString("sid", "no")
            selectSubTrack = -1
        } else if index >= 0, index < subtitleTracks.count {
            let track = subtitleTracks[index]
            player?.mpv.setInt64("sid", Int64(track.id))
            selectSubTrack = index
        }
    }

    func setLetterboxingMode(_ mode: LetterboxingMode) {
        onUserInteraction()
        letterboxingMode = mode
        applyLetterboxingToPlayer()
    }

    private func applyLetterboxingToPlayer() {
        guard let mpv = player?.mpv else { return }
        switch letterboxingMode {
        case .letterbox:
            mpv.applyLetterboxingLetterbox()
        case .cropToFill:
            mpv.applyLetterboxingCropToFill()
        case .stretch:
            mpv.applyLetterboxingStretch()
        }
    }

    func onDragStartOrUpdate(_ fraction: Double) {
        // NOTE: It means that drag just started
        if !isDragging {
            isDragging = true
            player?.mpv.pause()
            paused = true
        }
        onUserInteraction()
        currentPlayHeadPos = duration * fraction
    }

    func onDragEnd() {
        isDragging = false
        let durationDiff = currentPlayHeadPos - currentPos
        player?.mpv.seek(relative: Double(durationDiff.components.seconds))
        player?.mpv.play()
        paused = false
    }

    func getAndLoadFinalUrl() async {
        do {
            let finalUrl = try await streamUc.getStreamUrl(
                tempUrl: streams[selectedStreamIndex].url
            )
            print("--------------------------------------------------")
            print("final url we got is \(finalUrl)")
            print("--------------------------------------------------")
            player?.mpv.loadFile(URL(string: finalUrl)!)
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
        player.mpv.toggleHDR(enabled: hdrEnabled)
    }

    func onFileLoaded() {
        applyLetterboxingToPlayer()
        // NOTE: Start from where we left off
        if initialProgress != 0 {
            let seekSeconds =
                Double(duration.components.seconds) * (initialProgress / 100)
            player?.mpv.seek(relative: seekSeconds)
        }
    }

    func onFileEnd() {
        hasEnded = true
    }

    func onFileError() {
        hasError = true
    }

    func propertyChange(propertyName: String, data: Any?) {
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
                hdrAvailable = player.mpv.hdrAvailable
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
                    if currentPlayHeadPos.components.seconds
                        > cachePos.components.seconds
                    {
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
                player.mpv.setVolume(volume)
                applyLetterboxingToPlayer()
                Task { [weak self] in
                    guard let self = self else {
                        return
                    }
                    await self.getAndLoadFinalUrl()
                }
                isMpvLoaded = true
                setupProgressTask()
            }
        default: break
        }
    }

    func shouldHideCursor() -> Bool {
        // 1. Get the current location of the mouse cursor in global screen coordinates
        let mouseLocation = NSEvent.mouseLocation

        // 2. Find which screen the mouse is currently on
        guard let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else {
            return true // Fallback: if we can't find the screen, allow hiding
        }

        let screenFrame = currentScreen.frame
        let visibleFrame = currentScreen.visibleFrame

        // 3. Calculate the top boundary where the Menu Bar / Status Bar lives
        // On macOS, coordinate (0,0) is the bottom-left of the primary screen.
        let menuBarHeight = screenFrame.height - (visibleFrame.origin.y + visibleFrame.size.height)
        let menuBarMinY = screenFrame.origin.y + screenFrame.height - menuBarHeight

        // 4. Check if the mouse is inside that top Status Bar region
        if mouseLocation.y >= menuBarMinY {
            return false // Do NOT hide the cursor; user is interacting with the Status Bar
        }

        // Optional: Check if mouse is interacting with the Dock at the bottom
        if mouseLocation.y < visibleFrame.origin.y {
            return false // Do NOT hide the cursor; user is interacting with the Dock
        }

        return true // Safe to hide
    }
}
