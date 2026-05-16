//
//  TrailerPlayerView.swift
//
//  Plays a backend-proxied YouTube trailer using AVPlayer with the
//  required profile auth header. Renders a SwiftUI view that stays
//  invisible until the first frame is ready, allowing the caller
//  to keep showing a poster/backdrop behind it as a fallback.
//

import AppKit
import AVFoundation
import Foundation
import SwiftUI

struct TrailerPlayerView: View {
    let url: URL
    let headers: [String: String]
    let isMuted: Bool

    @State private var isReadyToPlay = false
    @State private var hasFailed = false

    init(url: URL, headers: [String: String], isMuted: Bool = false) {
        self.url = url
        self.headers = headers
        self.isMuted = isMuted
    }

    var body: some View {
        ZStack {
            if !hasFailed {
                TrailerPlayerRepresentable(
                    url: url,
                    headers: headers,
                    isMuted: isMuted,
                    onReadyToPlay: { isReadyToPlay = true },
                    onFailed: { hasFailed = true }
                )
                .opacity(isReadyToPlay ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: isReadyToPlay)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TrailerPlayerRepresentable: NSViewRepresentable {
    let url: URL
    let headers: [String: String]
    let isMuted: Bool
    let onReadyToPlay: () -> Void
    let onFailed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReadyToPlay: onReadyToPlay, onFailed: onFailed)
    }

    func makeNSView(context _: Context) -> TrailerPlayerNSView {
        return TrailerPlayerNSView()
        // Start with an empty view layout; do not build the asset here
    }

    func updateNSView(_ nsView: TrailerPlayerNSView, context: Context) {
        nsView.setMuted(isMuted)

        // CRITICAL FIX: Only set up a new asset session if the URL has actually changed!
        if context.coordinator.currentURL != url {
            context.coordinator.currentURL = url

            // Clean up any ongoing background asset tasks before opening a new one
            context.coordinator.detach()

            let asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
            )
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            player.isMuted = isMuted
            player.actionAtItemEnd = .none

            context.coordinator.attach(to: item, player: player)
            nsView.attach(player: player)
        }
    }

    static func dismantleNSView(
        _ nsView: TrailerPlayerNSView,
        coordinator: Coordinator
    ) {
        coordinator.detach()
        nsView.cleanup()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let onReadyToPlay: () -> Void
        private let onFailed: () -> Void
        private weak var item: AVPlayerItem?
        private weak var player: AVPlayer?
        private var statusObservation: NSKeyValueObservation?
        private var loopObserver: NSObjectProtocol?
        private var hasNotifiedReady = false

        /// Track the active streaming resource to compare against
        var currentURL: URL?

        init(
            onReadyToPlay: @escaping () -> Void,
            onFailed: @escaping () -> Void
        ) {
            self.onReadyToPlay = onReadyToPlay
            self.onFailed = onFailed
        }

        func attach(to item: AVPlayerItem, player: AVPlayer) {
            self.item = item
            self.player = player
            hasNotifiedReady = false // Reset state notifications

            statusObservation = item.observe(
                \.status,
                options: [.new, .initial]
            ) { [weak self] item, _ in
                guard let self = self else { return }
                Task { @MainActor in
                    switch item.status {
                    case .readyToPlay:
                        if !self.hasNotifiedReady {
                            self.hasNotifiedReady = true
                            self.player?.play()
                            self.onReadyToPlay()
                        }
                    case .failed:
                        self.onFailed()
                    default:
                        break
                    }
                }
            }

            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        func detach() {
            statusObservation?.invalidate()
            statusObservation = nil
            if let loopObserver = loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
            }
            loopObserver = nil
            player?.pause()
            player = nil
            item = nil
            hasNotifiedReady = false
        }
    }
}

final class TrailerPlayerNSView: NSView {
    private var playerLayer: AVPlayerLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        let layer = CALayer()
        layer.backgroundColor = .clear
        layer.masksToBounds = true
        self.layer = layer
    }

    /// Scale applied to the video layer to crop letterbox/pillarbox bars that
    /// are sometimes baked into trailer source files (e.g. 2.35:1 cinemascope
    /// uploaded inside a 16:9 frame). 1.12 ≈ 12% zoom, enough to clip the
    /// typical letterbox bars without losing meaningful content.
    private let cropZoom: CGFloat = 1.12

    func attach(player: AVPlayer) {
        playerLayer?.removeFromSuperlayer()
        let newLayer = AVPlayerLayer(player: player)
        newLayer.videoGravity = .resizeAspectFill
        newLayer.masksToBounds = true
        layer?.addSublayer(newLayer)
        playerLayer = newLayer
        updatePlayerLayerFrame()
    }

    private func updatePlayerLayerFrame() {
        guard let playerLayer = playerLayer else { return }
        let zoomedWidth = bounds.width * cropZoom
        let zoomedHeight = bounds.height * cropZoom
        let xOffset = (bounds.width - zoomedWidth) / 2
        let yOffset = (bounds.height - zoomedHeight) / 2
        playerLayer.frame = CGRect(
            x: xOffset,
            y: yOffset,
            width: zoomedWidth,
            height: zoomedHeight
        )
    }

    func setMuted(_ muted: Bool) {
        guard let player = playerLayer?.player else { return }
        if player.isMuted != muted {
            player.isMuted = muted
        }
    }

    func cleanup() {
        playerLayer?.player?.pause()
        playerLayer?.player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    override func layout() {
        super.layout()
        updatePlayerLayerFrame()
    }
}
