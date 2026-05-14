import AppKit
import CoreMedia
import Foundation
import Libmpv

@MainActor
protocol MPVPlayerDelegate: AnyObject {
    func propertyChange(mpv: OpaquePointer, propertyName: String, data: Any?)
    func onTrackList(tracks: [Track])
    func onFileLoaded()
    func onFileEnd()
    func onFileError()
}

/// warning: metal API validation has been disabled to ignore crash when playing HDR videos.
/// Edit Scheme -> Run -> Diagnostics -> Metal API Validation -> Turn it off
/// https://github.com/KhronosGroup/MoltenVK/issues/2226
final class MPVMetalViewController: NSViewController {
    var metalLayer = MetalLayer()
    var mpv: OpaquePointer!
    var playDelegate: MPVPlayerDelegate?
    var edrRange: CGFloat?
    lazy var queue = DispatchQueue(label: "mpv", qos: .userInitiated)
    private let resizeDebounce = 0.08
    private var lastResizeDate = Date()

    var playUrl: URL?
    var hdrAvailable: Bool = false
    // var hdrEnabled = false
    // {
    // didSet {
    //     // FIXME: target-colorspace-hint does not support being changed at runtime.
    //     // this option should be set when mpv init otherwise can cause player slow and hangs.
    //     // not recommended to use this way.
    //     if hdrEnabled {
    //         checkError(mpv_set_option_string(mpv, "target-colorspace-hint", "yes"))
    //     } else {
    //         checkError(mpv_set_option_string(mpv, "target-colorspace-hint", "no"))
    //     }
    // }
    // }

    override func viewDidAppear() {
        guard let window = view.window else { return }

        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }

        window.styleMask.remove(.resizable)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        guard let window = view.window else { return }

        window.styleMask.insert(.resizable)
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }

    override func loadView() {
        view = NoRingPlayerView(
            frame: .init(
                x: 0,
                y: 0,
                width: NSScreen.main!.frame.width,
                height: NSScreen.main!.frame.height
            )
        )
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        metalLayer.frame = view.frame
        metalLayer.contentsScale = NSScreen.main!.backingScaleFactor
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = NSColor.black.cgColor
        view.layer = metalLayer
        view.wantsLayer = true

        setupMpv()

        if let url = playUrl {
            loadFile(url)
        }

        // observer EDR range value change
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            if let screen = NSScreen.screens.first {
                let maxRange = screen
                    .maximumExtendedDynamicRangeColorComponentValue
                DispatchQueue.main.async {
                    self.playDelegate?.propertyChange(
                        mpv: self.mpv,
                        propertyName: "edr",
                        data: maxRange
                    )
                }
            }
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        if let window = view.window {
            let now = Date()
            guard now.timeIntervalSince(lastResizeDate) > resizeDebounce else {
                return
            }
            lastResizeDate = now

            let scale = window.screen!.backingScaleFactor
            let layerSize = view.bounds.size

            metalLayer.frame = CGRect(
                x: 0,
                y: 0,
                width: layerSize.width,
                height: layerSize.height
            )
            metalLayer.drawableSize = CGSize(
                width: layerSize.width * scale,
                height: layerSize.height * scale
            )
        }
    }

    func setupMpv() {
        mpv = mpv_create()
        if mpv == nil {
            print("failed creating context\n")
            exit(1)
        }

        // https://mpv.io/manual/stable/#options
        #if DEBUG
            checkError(mpv_request_log_messages(mpv, "debug"))
        #else
            checkError(mpv_request_log_messages(mpv, "no"))
        #endif
        // #if os(macOS)
        //     checkError(mpv_set_option_string(mpv, "input-media-keys", "yes"))
        // #endif

        checkError(mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &metalLayer))
        checkError(mpv_set_option_string(mpv, "vo", "gpu-next"))
        checkError(mpv_set_option_string(mpv, "gpu-api", "vulkan"))
        checkError(mpv_set_option_string(mpv, "gpu-context", "moltenvk"))
        checkError(mpv_set_option_string(mpv, "hwdec", "videotoolbox"))
        checkError(mpv_set_option_string(mpv, "ytdl", "no"))
        checkError(mpv_set_option_string(mpv, "target-colorspace-hint", "yes"))
        checkError(mpv_set_option_string(mpv, "sid", "no"))
        // checkError(mpv_set_option_string(mpv, "subtitle-auto-sel", "no"))
        checkError(mpv_set_option_string(mpv, "cache", "yes"))
        checkError(mpv_set_option_string(mpv, "demuxer-max-bytes", "1024MiB"))
        checkError(mpv_set_option_string(mpv, "demuxer-readahead-secs", "3600"))
        //        checkError(mpv_set_option_string(mpv, "tone-mapping-visualize", "yes"))  // only for debugging purposes
        //        checkError(mpv_set_option_string(mpv, "profile", "fast"))   // can fix frame drop in poor device when play 4k

        mpv_observe_property(
            mpv,
            0,
            MPVProperty.videoParamsSigPeak,
            MPV_FORMAT_DOUBLE
        )
        mpv_observe_property(
            mpv,
            0,
            MPVProperty.videoParamsColormatrix,
            MPV_FORMAT_STRING
        )
        mpv_observe_property(
            mpv,
            0,
            MPVProperty.videoParamsPrimaries,
            MPV_FORMAT_STRING
        )
        mpv_observe_property(
            mpv,
            0,
            MPVProperty.videoParamsGamma,
            MPV_FORMAT_STRING
        )
        mpv_observe_property(
            mpv,
            0,
            MPVProperty.pausedForCache,
            MPV_FORMAT_FLAG
        )
        mpv_observe_property(mpv, 0, MPVProperty.seeking, MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, MPVProperty.hwCurrent, MPV_FORMAT_STRING)
        mpv_observe_property(mpv, 0, MPVProperty.videoCodec, MPV_FORMAT_STRING)
        mpv_observe_property(mpv, 0, MPVProperty.trackList, MPV_FORMAT_STRING)
        mpv_observe_property(
            mpv,
            0,
            MPVProperty.downloadSpeed,
            MPV_FORMAT_DOUBLE
        )
        mpv_observe_property(
            mpv,
            0,
            MPVProperty.videoBitRate,
            MPV_FORMAT_DOUBLE
        )
        mpv_observe_property(
            mpv,
            0,
            MPVProperty.cacheDuration,
            MPV_FORMAT_DOUBLE
        )
        mpv_observe_property(mpv, 0, MPVProperty.duration, MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, MPVProperty.timePos, MPV_FORMAT_DOUBLE)
        mpv_set_wakeup_callback(
            mpv,
            { ctx in
                guard let client = ctx else { return }
                let viewController = Unmanaged<MPVMetalViewController>
                    .fromOpaque(client).takeUnretainedValue()
                viewController.readEvents()
            },
            Unmanaged.passRetained(self).toOpaque()
        )

        // Initialize Mpv
        checkError(mpv_initialize(mpv))
        DispatchQueue.main.async {
            self.playDelegate?.propertyChange(
                mpv: self.mpv,
                propertyName: "loaded",
                data: nil
            )
        }
    }

    func toggleHDR(_ enabled: Bool) {
        DispatchQueue.main.async {
            if enabled {
                self.metalLayer.wantsExtendedDynamicRangeContent = true
                // self.metalLayer.pixelFormat = .rgba16Float
            } else {
                self.metalLayer.wantsExtendedDynamicRangeContent = false
                // self.metalLayer.pixelFormat = .bgra8Unorm
            }
        }
    }

    func loadFile(
        _ url: URL,
        time: Double? = nil
    ) {
        var args = [url.absoluteString]
        var options = [String]()

        args.append("replace")
        args.append("-1")

        if let time, time > 0 {
            options.append("start=\(Int(time))")
        }

        if !options.isEmpty {
            args.append(options.joined(separator: ","))
        }

        command("loadfile", args: args)
    }

    func play() {
        setFlag("pause", false)
    }

    func pause() {
        setFlag("pause", true)
    }

    func seek(relative time: TimeInterval) {
        command("seek", args: [String(time), "relative"])
    }

    func stop() {
        command("stop", args: [])
    }

    private func getDouble(_ name: String) -> Double {
        guard mpv != nil else { return 0.0 }
        var data = Double()
        mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &data)
        return data
    }

    private func getString(_ name: String) -> String? {
        guard mpv != nil else { return nil }
        let cstr = mpv_get_property_string(mpv, name)
        let str: String? = cstr == nil ? nil : String(cString: cstr!)
        mpv_free(cstr)
        return str
    }

    func setFlag(_ name: String, _ flag: Bool) {
        guard mpv != nil else { return }
        var data: Int = flag ? 1 : 0
        mpv_set_property(mpv, name, MPV_FORMAT_FLAG, &data)
    }

    func setVolume(_ volume: Double) {
        var volume = volume
        mpv_set_property(mpv, "volume", MPV_FORMAT_DOUBLE, &volume)
    }

    func setInt64(_ name: String, _ value: Int64) {
        guard mpv != nil else { return }
        var data = value
        mpv_set_property(mpv, name, MPV_FORMAT_INT64, &data)
    }

    func setString(_ name: String, _ value: String) {
        guard mpv != nil else { return }
        mpv_set_property_string(mpv, name, value)
    }

    func command(
        _ command: String,
        args: [String?] = [],
        checkForErrors: Bool = true,
        returnValueCallback: ((Int32) -> Void)? = nil
    ) {
        guard mpv != nil else {
            return
        }
        var cargs = makeCArgs(command, args).map {
            $0.flatMap { UnsafePointer<CChar>(strdup($0)) }
        }
        defer {
            for ptr in cargs where ptr != nil {
                free(UnsafeMutablePointer(mutating: ptr!))
            }
        }
        // print("\(command) -- \(args)")
        let returnValue = mpv_command(mpv, &cargs)
        if checkForErrors {
            checkError(returnValue)
        }
        if let cb = returnValueCallback {
            cb(returnValue)
        }
    }

    private func makeCArgs(_ command: String, _ args: [String?]) -> [String?] {
        if !args.isEmpty, args.last == nil {
            fatalError("Command do not need a nil suffix")
        }

        var strArgs = args
        strArgs.insert(command, at: 0)
        strArgs.append(nil)

        return strArgs
    }

    func readEvents() {
        queue.async { [weak self] in
            guard let self else { return }

            while self.mpv != nil {
                let event = mpv_wait_event(self.mpv, 0)
                if event?.pointee.event_id == MPV_EVENT_NONE {
                    break
                }

                switch event!.pointee.event_id {
                case MPV_EVENT_PROPERTY_CHANGE:
                    let dataOpaquePtr = OpaquePointer(event!.pointee.data)
                    if let property = UnsafePointer<mpv_event_property>(
                        dataOpaquePtr
                    )?.pointee {
                        let propertyName = String(cString: property.name)
                        print("Event came \(propertyName)")
                        switch propertyName {
                        case MPVProperty.videoParamsSigPeak:
                            if let sigPeak = UnsafePointer<Double>(
                                OpaquePointer(property.data)
                            )?.pointee {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }
                                    let maxEDRRange =
                                        NSScreen.main?
                                            .maximumPotentialExtendedDynamicRangeColorComponentValue
                                            ?? 1.0
                                    // display screen support HDR and current playing HDR video
                                    self.hdrAvailable =
                                        maxEDRRange > 1.0 && sigPeak > 1.0
                                    // self.playDelegate?.propertyChange(mpv: self.mpv, propertyName: propertyName, data: sigPeak)
                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: sigPeak
                                    )
                                }
                            }
                        case MPVProperty.cacheDuration:
                            if let duration = UnsafePointer<Double>(
                                OpaquePointer(property.data)
                            )?.pointee {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }
                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: duration
                                    )
                                }
                            }
                        case MPVProperty.duration:
                            if let duration = UnsafePointer<Double>(
                                OpaquePointer(property.data)
                            )?.pointee {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: duration
                                    )
                                }
                            }
                        case MPVProperty.timePos:
                            if let pos = UnsafePointer<Double>(
                                OpaquePointer(property.data)
                            )?.pointee {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: pos
                                    )
                                }
                            }
                        case MPVProperty.downloadSpeed:
                            if let downloadSpeed = UnsafePointer<Double>(
                                OpaquePointer(property.data)
                            )?.pointee {
                                print("download speed is \(downloadSpeed)")

                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: downloadSpeed
                                    )
                                }
                            }
                        case MPVProperty.hwCurrent:
                            if let dataPtr = property.data {
                                let rawPtr = dataPtr.bindMemory(
                                    to: UnsafePointer<CChar>.self,
                                    capacity: 1
                                )
                                let currentDecoder = String(
                                    cString: rawPtr.pointee
                                )

                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: currentDecoder
                                    )
                                }
                            }
                        case MPVProperty.videoParamsColormatrix:
                            if let dataPtr = property.data {
                                let rawPtr = dataPtr.bindMemory(
                                    to: UnsafePointer<CChar>.self,
                                    capacity: 1
                                )
                                let value = String(cString: rawPtr.pointee)

                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: value
                                    )
                                }
                            }
                        case MPVProperty.videoParamsPrimaries:
                            if let dataPtr = property.data {
                                let rawPtr = dataPtr.bindMemory(
                                    to: UnsafePointer<CChar>.self,
                                    capacity: 1
                                )
                                let value = String(cString: rawPtr.pointee)

                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: value
                                    )
                                }
                            }
                        case MPVProperty.videoParamsGamma:
                            if let dataPtr = property.data {
                                let rawPtr = dataPtr.bindMemory(
                                    to: UnsafePointer<CChar>.self,
                                    capacity: 1
                                )
                                let value = String(cString: rawPtr.pointee)

                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: value
                                    )
                                }
                            }
                        case MPVProperty.videoBitRate:
                            if let bitRate = UnsafePointer<Double>(
                                OpaquePointer(property.data)
                            )?.pointee {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: bitRate
                                    )
                                }
                            }
                        case MPVProperty.videoCodec:
                            if let dataPtr = property.data {
                                let rawPtr = dataPtr.bindMemory(
                                    to: UnsafePointer<CChar>.self,
                                    capacity: 1
                                )
                                let codecName = String(cString: rawPtr.pointee)
                                print("Current videoCodec used \(codecName)")

                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self, self.mpv != nil
                                    else { return }

                                    self.playDelegate?.propertyChange(
                                        mpv: self.mpv,
                                        propertyName: propertyName,
                                        data: codecName
                                    )
                                }
                            }
                        case MPVProperty.pausedForCache:
                            let buffering =
                                UnsafePointer<Bool>(
                                    OpaquePointer(property.data)
                                )?.pointee ?? true

                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, self.mpv != nil else {
                                    return
                                }

                                self.playDelegate?.propertyChange(
                                    mpv: self.mpv,
                                    propertyName: propertyName,
                                    data: buffering
                                )
                            }
                        case MPVProperty.seeking:
                            let seeking =
                                UnsafePointer<Bool>(
                                    OpaquePointer(property.data)
                                )?.pointee ?? true

                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, self.mpv != nil else {
                                    return
                                }

                                self.playDelegate?.propertyChange(
                                    mpv: self.mpv,
                                    propertyName: propertyName,
                                    data: seeking
                                )
                            }
                        case MPVProperty.trackList:
                            if let dataPtr = property.data {
                                let stringPtrPtr = dataPtr.bindMemory(
                                    to: UnsafePointer<CChar>.self,
                                    capacity: 1
                                )
                                let jsonString = String(
                                    cString: stringPtrPtr.pointee
                                )
                                // print("found json tracks\(jsonString)")
                                if let jsonData = jsonString.data(using: .utf8) {
                                    do {
                                        let allTracks = try JSONDecoder()
                                            .decode(
                                                [Track].self,
                                                from: jsonData
                                            )

                                        DispatchQueue.main.async {
                                            [weak self] in
                                            guard let self = self,
                                                  self.mpv != nil
                                            else { return }

                                            self.playDelegate?.onTrackList(
                                                tracks: allTracks
                                            )
                                        }
                                    } catch {
                                        print(
                                            "Failed to parse track list: \(error)"
                                        )
                                    }
                                }
                            }
                        default: break
                        }
                    }
                case MPV_EVENT_FILE_LOADED:
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.mpv != nil else { return }

                        self.playDelegate?.onFileLoaded()
                    }
                case MPV_EVENT_END_FILE:
                    // Cast the data pointer to mpv_event_end_file to see WHY it ended
                    if let data = event!.pointee.data {
                        let endEvent = data.assumingMemoryBound(
                            to: mpv_event_end_file.self
                        ).pointee

                        // Convert the reason enum to a readable string or check against constants
                        switch endEvent.reason {
                        case MPV_END_FILE_REASON_EOF:
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, self.mpv != nil else {
                                    return
                                }

                                self.playDelegate?.onFileEnd()
                            }
                        case MPV_END_FILE_REASON_STOP:
                            print("MPV: Playback was manually stopped.")
                        case MPV_END_FILE_REASON_QUIT:
                            print("MPV: Player is quitting.")
                        case MPV_END_FILE_REASON_ERROR:
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, self.mpv != nil else {
                                    return
                                }

                                self.playDelegate?.onFileError()
                            }
                        case MPV_END_FILE_REASON_REDIRECT:
                            print("MPV: Stream redirected.")
                        default:
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, self.mpv != nil else {
                                    return
                                }

                                self.playDelegate?.onFileError()
                            }
                            print(
                                "MPV: End file reason unknown: \(endEvent.reason)"
                            )
                        }
                    }
                case MPV_EVENT_SHUTDOWN:
                    print("event: shutdown\n")
                    mpv_terminate_destroy(mpv)
                    mpv = nil
                case MPV_EVENT_LOG_MESSAGE:
                    let msg = UnsafeMutablePointer<mpv_event_log_message>(
                        OpaquePointer(event!.pointee.data)
                    )
                    print(
                        "[\(String(cString: (msg!.pointee.prefix)!))] \(String(cString: (msg!.pointee.level)!)): \(String(cString: (msg!.pointee.text)!))",
                        terminator: ""
                    )
                default:
                    let eventName = mpv_event_name(event!.pointee.event_id)
                    print("event: \(String(cString: eventName!))")
                }
            }
        }
    }

    func cleanup() {
        NotificationCenter.default.removeObserver(self)

        if mpv != nil {
            mpv_set_wakeup_callback(mpv, nil, nil)

            // Wait for any pending queue operations to complete
            queue.sync {
                if self.mpv != nil {
                    mpv_terminate_destroy(self.mpv)
                    self.mpv = nil
                }
            }

            // Release the retained self from wakeup callback
            Unmanaged.passUnretained(self).release()
        }
    }

    deinit {
        print("Deinit called inside of controller")
        cleanup()
    }

    private func checkError(_ status: CInt) {
        if status < 0 {
            print(
                "MPV API error: \(String(cString: mpv_error_string(status)))\n"
            )
        }
    }
}
