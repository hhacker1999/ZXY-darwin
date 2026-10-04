import CoreMedia
import Foundation
import Libmpv
import Metal

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

        private let resizeDebounce: TimeInterval = 0.08
        private var lastResizeDate = Date.distantPast
        private var didSetupMpv = false
        private var didAppear = false
        private var didCleanUp = false
        private var lastAppliedBounds: CGSize = .zero
        private var lastAppliedScale: CGFloat = 0
        private var lastDrawableSize: CGSize = .zero
        private var screenParamsObserver: NSObjectProtocol?

        override func viewDidAppear() {
            super.viewDidAppear()
            guard let window = view.window else { return }

            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }

            window.styleMask.remove(.resizable)

            didAppear = true
            view.needsLayout = true
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

            configureMetalLayerHierarchy()
            setupScreenParameterObserver()
        }

        override func viewDidLayout() {
            super.viewDidLayout()

            let now = Date()
            guard now.timeIntervalSince(lastResizeDate) > resizeDebounce else {
                return
            }
            lastResizeDate = now

            synchronizeMetalSurface()
        }

        private func configureMetalLayerHierarchy() {
            if metalLayer.device == nil {
                metalLayer.device = MTLCreateSystemDefaultDevice()
            }
            metalLayer.framebufferOnly = true
            metalLayer.backgroundColor = NSColor.black.cgColor
            view.layer = metalLayer
            view.wantsLayer = true
        }

        private var backingScaleFactor: CGFloat {
            view.window?.screen?.backingScaleFactor
                ?? NSScreen.main?.backingScaleFactor
                ?? 2
        }

        /// Updates layer geometry when bounds or scale changed. Returns whether anything changed.
        @discardableResult
        private func updateMetalLayerGeometryIfNeeded() -> Bool {
            guard view.bounds.width > 1, view.bounds.height > 1 else { return false }

            let scale = backingScaleFactor
            let bounds = view.bounds.size
            if bounds == lastAppliedBounds, scale == lastAppliedScale {
                return false
            }

            lastAppliedBounds = bounds
            lastAppliedScale = scale
            metalLayer.frame = CGRect(origin: .zero, size: bounds)
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )
            return true
        }

        private func synchronizeMetalSurface() {
            updateMetalLayerGeometryIfNeeded()

            if !didSetupMpv {
                guard didAppear else { return }
                guard metalLayer.drawableSize.width > 1,
                      metalLayer.drawableSize.height > 1
                else { return }

                didSetupMpv = true
                lastDrawableSize = metalLayer.drawableSize
                mpv.setupMpv(metalLayer: &metalLayer)
                return
            }

            rebindRenderSurfaceIfDrawableSizeChanged()
        }

        private func rebindRenderSurfaceIfDrawableSizeChanged() {
            let size = metalLayer.drawableSize
            guard size.width > 1, size.height > 1 else { return }
            guard size != lastDrawableSize else { return }
            lastDrawableSize = size
            mpv.rebindRenderSurface(metalLayer: &metalLayer)
        }

        private func setupScreenParameterObserver() {
            screenParamsObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                guard let screen = NSScreen.screens.first else { return }
                let maxRange = screen.maximumExtendedDynamicRangeColorComponentValue
                self.playDelegate?.propertyChange(propertyName: "edr", data: maxRange)
            }
        }

        func cleanup() {
            guard !didCleanUp else { return }
            didCleanUp = true

            if let screenParamsObserver {
                NotificationCenter.default.removeObserver(screenParamsObserver)
                self.screenParamsObserver = nil
            }

            mpv.cleanup()
        }

        deinit {
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
        private var didSetupMpv = false
        private var didAppear = false
        private var didCleanUp = false
        private var lastAppliedBounds: CGSize = .zero
        private var lastAppliedScale: CGFloat = 0
        private var lastDrawableSize: CGSize = .zero

        override func viewDidLoad() {
            super.viewDidLoad()

            view.isOpaque = true
            view.backgroundColor = .black

            configureMetalLayerHierarchy()
            setupNotification()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            didAppear = true
            view.setNeedsLayout()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            let now = Date()
            guard view.bounds.width > 1, view.bounds.height > 1 else { return }
            guard now.timeIntervalSince(lastResizeDate) > resizeDebounce else {
                return
            }
            lastResizeDate = now

            synchronizeMetalSurface()
        }

        private func configureMetalLayerHierarchy() {
            if metalLayer.device == nil {
                metalLayer.device = MTLCreateSystemDefaultDevice()
            }
            metalLayer.framebufferOnly = true
            metalLayer.backgroundColor = UIColor.black.cgColor
            view.layer.addSublayer(metalLayer)
        }

        private var screenNativeScale: CGFloat {
            view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        }

        @discardableResult
        private func updateMetalLayerGeometryIfNeeded() -> Bool {
            guard view.bounds.width > 1, view.bounds.height > 1 else { return false }

            let scale = screenNativeScale
            let bounds = view.bounds.size
            if bounds == lastAppliedBounds, scale == lastAppliedScale {
                return false
            }

            lastAppliedBounds = bounds
            lastAppliedScale = scale
            metalLayer.frame = view.bounds
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )
            return true
        }

        private func synchronizeMetalSurface() {
            updateMetalLayerGeometryIfNeeded()

            if !didSetupMpv {
                guard didAppear else { return }
                guard metalLayer.drawableSize.width > 1,
                      metalLayer.drawableSize.height > 1
                else { return }

                didSetupMpv = true
                lastDrawableSize = metalLayer.drawableSize
                mpv.setupMpv(metalLayer: &metalLayer)
                return
            }

            rebindRenderSurfaceIfDrawableSizeChanged()
        }

        private func rebindRenderSurfaceIfDrawableSizeChanged() {
            let size = metalLayer.drawableSize
            guard size.width > 1, size.height > 1 else { return }
            guard size != lastDrawableSize else { return }
            lastDrawableSize = size
            mpv.rebindRenderSurface(metalLayer: &metalLayer)
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
            mpv.pause()
            mpv.checkErrPublic(option: "vid", args: "no")
        }

        @objc func enterForeground() {
            mpv.checkErrPublic(option: "vid", args: "auto")
            mpv.play()
        }

        func cleanup() {
            guard !didCleanUp else { return }
            didCleanUp = true

            NotificationCenter.default.removeObserver(self)
            mpv.cleanup()
        }

        deinit {
            cleanup()
        }
    }
#endif
