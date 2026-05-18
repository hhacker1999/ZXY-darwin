//
//  ShimmerView.swift
//
//  Created by Harsh Kumar on 05/04/26.
//

import Foundation
import SwiftUI

// MARK: - Home ambient loading

private struct ContentBlendsWithAmbientKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When true, loading chrome is translucent so the ambient mesh gradient shows through.
    var contentBlendsWithAmbient: Bool {
        get { self[ContentBlendsWithAmbientKey.self] }
        set { self[ContentBlendsWithAmbientKey.self] = newValue }
    }
}

/// Opaque card / placeholder fill on library grids; translucent on home & media detail.
struct LoadingSurfaceFill: View {
    @Environment(\.contentBlendsWithAmbient) private var blendsWithAmbient

    var body: some View {
        if blendsWithAmbient {
            Color.white.opacity(0.07)
        } else {
            AppTheme.Colors.backgroundTertiary
        }
    }
}

struct ShimmerView: View {
    @Environment(\.contentBlendsWithAmbient) private var blendsWithAmbient
    @State private var phase: CGFloat = -1

    private var highlightOpacity: Double {
        blendsWithAmbient ? 0.18 : 0.08
    }

    var body: some View {
        LoadingSurfaceFill()
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(highlightOpacity),
                        Color.white.opacity(0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 250)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}
