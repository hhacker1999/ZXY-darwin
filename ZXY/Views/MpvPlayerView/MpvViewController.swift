import CoreMedia
import Foundation
import Libmpv

#if os(macOS)
    import AppKit

    final class MPVMetalViewController: NSViewController {
        var metalLayer = MetalLayer()
        var mpv: MPV = .init()
        var playDelegate: MPVPlayerDelegate? {
            didSet {
                mpv.playDelegate = playDelegate
            }
        }

        private let resizeDebounce = 0.08
        private var lastResizeDate = Date()

        var playUrl: URL?
        // var hdrAvailable: Bool = false
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

            mpv.setupMpv(metalLayer: &metalLayer)

            if let url = playUrl {
                mpv.loadFile(url)
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

        func cleanup() {
            NotificationCenter.default.removeObserver(self)

            mpv.cleanup()
        }

        deinit {
            print("Deinit called inside of controller")
            cleanup()
        }
    }
#else
    import UIKit

    final class MPVMetalViewController: UIViewController {
        var metalLayer = MetalLayer()
        var mpv: MPV = .init()
        var playDelegate: MPVPlayerDelegate?

        var playUrl: URL?

        override func viewDidLoad() {
            super.viewDidLoad()

            metalLayer.frame = view.frame
            metalLayer.contentsScale = UIScreen.main.nativeScale
            metalLayer.framebufferOnly = true
            metalLayer.backgroundColor = UIColor.black.cgColor

            view.layer.addSublayer(metalLayer)

            mpv.setupMpv(metalLayer: &metalLayer)
            setupNotification()

            if let url = playUrl {
                mpv.loadFile(url)
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            metalLayer.frame = view.frame
        }

        func setupNotification() {
            NotificationCenter.default.addObserver(self, selector: #selector(enterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(enterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        }

        @objc func enterBackground() {
            // fix black screen issue when app enter foreground again
            mpv.pause()
            mpv.checkErrPublic(option: "vid", args: "no")
        }

        @objc func enterForeground() {
            mpv.checkErrPublic(option: "vid", args: "auto")
            mpv.play()
        }

        func cleanup() {
            NotificationCenter.default.removeObserver(self)

            mpv.cleanup()
        }

        deinit {
            print("Deinit called inside of controller")
            cleanup()
        }
    }
#endif
