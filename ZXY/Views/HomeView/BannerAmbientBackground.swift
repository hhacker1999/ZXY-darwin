import Foundation
import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct HomePageAmbientBackground: View {
    let gradient: HomeAmbientGradient

    /// 3×3 control points pinned to screen corners and edge midpoints.
    private let meshPoints: [SIMD2<Float>] = [
        SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
        SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
        SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
    ]

    var body: some View {
        ZStack {
            AppTheme.Colors.background

            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints,
                colors: gradient.meshColors
            )

            Color.black.opacity(0.04)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.65), value: gradient)
    }
}

#if os(iOS)
/// iPhone tab screens each carry the shared ambient mesh behind transparent content.
struct IOSAmbientTabScreen<Content: View>: View {
    @Bindable private var gradientStore = ImageGradientAndStoreBloc.bloc
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            HomePageAmbientBackground(gradient: gradientStore.currentGradient)
            content
        }
        .hideScrollContentBackground()
    }
}
#endif

///
/// /// Hero artwork — gradient mask on the `Image` (white = opaque, clear = transparent at bottom).
/// ///
/// /// Backed by `BlocAsyncImage` so loading / decoding / caching is shared with
/// /// the rest of the app via `ImageGradientAndStoreBloc`.
struct BannerFadingHeroImage: View {
    let width: CGFloat
    let height: CGFloat
    let path: String
    let imageWidth: String
    var setGradientFromImage: Bool = SettingsBloc.bloc.enableGradient

    var body: some View {
        BlocAsyncImage(id: path, size: imageWidth, setGradientFromImage: setGradientFromImage) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .mask {
                        BannerImageBottomFadeMask(height: height)
                    }
            case .failure:
                heroPlaceholder
                    .mask {
                        BannerImageBottomFadeMask(height: height)
                    }
            case .empty:
                ShimmerView()
                    .mask {
                        BannerImageBottomFadeMask(height: height)
                    }
            @unknown default:
                heroPlaceholder
                    .mask {
                        BannerImageBottomFadeMask(height: height)
                    }
            }
        }
        .frame(width: width, height: height)
    }

    private var heroPlaceholder: some View {
        ZStack {
            LoadingSurfaceFill()
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
        .frame(width: width, height: height)
    }
}

///
/// /// Gradient mask (white = show image, clear = fully transparent at bottom).
struct BannerImageBottomFadeMask: View {
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.white
                .frame(height: height * 0.46)
            LinearGradient(
                stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white.opacity(0.65), location: 0.3),
                    .init(color: .white.opacity(0.15), location: 0.72),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.54)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

///
/// /// Darkens the upper hero only; bottom stays clear so the image dissolve reads through.
struct HeroTextLegibilityScrim: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black.opacity(0.35), location: 0.42),
                .init(color: .clear, location: 0.62),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}
