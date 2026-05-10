//
//  ShimmerView.swift
//
//  Created by Harsh Kumar on 05/04/26.
//

import Foundation
import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        AppTheme.Colors.backgroundTertiary
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.08),
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
