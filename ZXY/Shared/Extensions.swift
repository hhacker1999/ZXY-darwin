//
//  Extensions.swift
//
//  Created by Harsh Kumar on 29/03/26.
//

import SwiftUI

extension View {
    func placeholder<C: View>(when show: Bool, @ViewBuilder placeholder: () -> C) -> some View {
        ZStack(alignment: .leading) {
            if show { placeholder() }
            self
        }
    }
    func wrapInBg() -> some View {
        ZStack { Constants.bgColor.ignoresSafeArea(); self }
    }

    /// Zoom the hero from the bottom anchor as the user scrolls:
    /// - Pull past the top (`rubber-band`): grows like `(height + overscroll) / height`, capped.
    /// - Scrolls content down (hero moves up): adds uniform zoom up to `maxScrollZoomExtra` so the
    ///   image scales instead of only translating away—no extra vertical stretch of the layout.
    /// Prefer only on image/scrim; pair with `zIndex` so overlays stay above.
    /// Uses `GeometryProxy.frame(in: .scrollView)`. iOS 17+ / macOS 14+.
    func stretchableHeroBannerInScrollView(
        maxPullScale: CGFloat = 1.42,
        maxScrollZoomExtra: CGFloat = 0.14,
        /// Lower = zoom ramps over more scroll before hitting `maxScrollZoomExtra`.
        scrollZoomSensitivity: CGFloat = 0.28
    ) -> some View {
        visualEffect { effect, geometry in
            let frame = geometry.frame(in: .scrollView)
            let height = max(geometry.size.height, 0.0001)

            let pull = max(0, frame.minY)
            let pullScale = min((height + pull) / height, maxPullScale)

            let scrolledAboveViewport = max(0, -frame.minY)
            let scrollZoomBoost = min(
                scrolledAboveViewport / height * scrollZoomSensitivity,
                maxScrollZoomExtra
            )
            let scrollScale = 1 + scrollZoomBoost

            let scale = min(pullScale * scrollScale, maxPullScale)
            return effect.scaleEffect(scale, anchor: .bottom)
        }
    }
}
