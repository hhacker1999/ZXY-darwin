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
                guard now.timeIntervalSince(lastResizeDate) > resizeDebounce
                else {
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
        var playDelegate: MPVPlayerDelegate? {
            didSet {
                mpv.playDelegate = playDelegate
            }
        }

        var playUrl: URL?

        private let resizeDebounce: TimeInterval = 0.08
        private var lastResizeDate = Date.distantPast

        override func viewDidLoad() {
            super.viewDidLoad()

            view.isOpaque = true
            view.backgroundColor = .black

            metalLayer.frame = view.bounds
            metalLayer.contentsScale = screenNativeScale
            metalLayer.framebufferOnly = true
            metalLayer.backgroundColor = UIColor.black.cgColor

            view.layer.addSublayer(metalLayer)

            mpv.setupMpv(metalLayer: &metalLayer)
            setupNotification()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            let now = Date()
            guard view.bounds.width > 0, view.bounds.height > 0 else { return }
            guard now.timeIntervalSince(lastResizeDate) > resizeDebounce else {
                return
            }
            lastResizeDate = now

            let scale = screenNativeScale
            metalLayer.frame = view.bounds
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = CGSize(
                width: view.bounds.width * scale,
                height: view.bounds.height * scale
            )
        }

        private var screenNativeScale: CGFloat {
            view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        }

        func setupNotification() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(enterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(enterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
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
