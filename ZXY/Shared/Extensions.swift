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

    /// Uniform zoom when a containing `ScrollView` rubber-bands past the top edge (hero grows
    /// proportionally instead of empty background). Prefer only on image/scrim; pair with
    /// `zIndex` so overlays stay above—`visualEffect` can otherwise composite on top of siblings.
    /// Uses `GeometryProxy.frame(in: .scrollView)`. iOS 17+ / macOS 14+.
    func stretchableHeroBannerInScrollView(maxScale: CGFloat = 1.42) -> some View {
        visualEffect { effect, geometry in
            let frame = geometry.frame(in: .scrollView)
            let overscroll = max(0, frame.minY)
            let height = max(geometry.size.height, 0.0001)
            let rawScale = (height + overscroll) / height
            let scale = min(rawScale, maxScale)
            return effect.scaleEffect(scale, anchor: .bottom)
        }
    }
}
