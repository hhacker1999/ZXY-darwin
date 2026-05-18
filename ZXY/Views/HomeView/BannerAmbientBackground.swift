//
//  BannerAmbientBackground.swift
//
//  Full-screen 3×3 mesh mapped to matching regions of the banner artwork.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Model

/// Row-major 3×3 samples (top→bottom, left→right) aligned with the image grid.
struct HomeAmbientGradient: Equatable {
    var cells: [AmbientColorCell]

    static let `default` = HomeAmbientGradient(
        cells: Array(
            repeating: AmbientColorCell(red: 0.08, green: 0.08, blue: 0.09),
            count: 9
        )
    )

    var meshColors: [Color] {
        cells.map(\.color)
    }

}

struct AmbientColorCell: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    static func fromHSB(hue: Double, saturation: Double, brightness: Double) -> AmbientColorCell {
        let color = Color(hue: hue, saturation: saturation, brightness: brightness)
        #if canImport(UIKit)
            let ui = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return AmbientColorCell(red: Double(r), green: Double(g), blue: Double(b))
        #elseif canImport(AppKit)
            let ns = NSColor(color)
            guard let rgb = ns.usingColorSpace(.sRGB) else {
                return AmbientColorCell(red: 0.08, green: 0.08, blue: 0.09)
            }
            return AmbientColorCell(
                red: rgb.redComponent,
                green: rgb.greenComponent,
                blue: rgb.blueComponent
            )
        #else
            return AmbientColorCell(red: 0.08, green: 0.08, blue: 0.09)
        #endif
    }
}

extension AppMedia {
    var bannerArtworkURL: URL? {
        #if os(iOS)
            return MediaConfig.instance.posterURL(posterPath, width: 780)
        #else
            return MediaConfig.instance.backdropURL(backdropPath, width: "w780")
        #endif
    }
}

// MARK: - Tuning

/// Normalizes a 3×3 sample set — keeps spatial color, tames only the extremes.
private enum AmbientColorTuner {
    private static let canvas = (red: 0.031, green: 0.031, blue: 0.031) // #080808
    /// Target for the brightest cell after tuning (higher = more visible wash).
    private static let peakLuminance: Double = 0.3
    /// How much of the brightness above `peakLuminance` to keep (soft knee, not a hard clip).
    private static let brightRetention: Double = 0.45
    private static let saturationFactor: Double = 0.28
    private static let canvasBlendBase: Double = 0.44

    static func tunedCells(from raw: [(red: Double, green: Double, blue: Double)]) -> [AmbientColorCell] {
        let luminances = raw.map { luminance(red: $0.red, green: $0.green, blue: $0.blue) }
        let peak = luminances.max() ?? 0.08
        let scale = luminanceScale(for: peak)

        // Brighter source art needs less crushing into the canvas.
        let canvasBlend = canvasBlendBase - min(peak, 0.55) * 0.18

        return raw.map { sample in
            var red = sample.red * scale
            var green = sample.green * scale
            var blue = sample.blue * scale

            let gray = luminance(red: red, green: green, blue: blue)
            red = red * (1 - saturationFactor) + gray * saturationFactor
            green = green * (1 - saturationFactor) + gray * saturationFactor
            blue = blue * (1 - saturationFactor) + gray * saturationFactor

            red = red * (1 - canvasBlend) + canvas.red * canvasBlend
            green = green * (1 - canvasBlend) + canvas.green * canvasBlend
            blue = blue * (1 - canvasBlend) + canvas.blue * canvasBlend

            return AmbientColorCell(
                red: min(max(red, 0), 1),
                green: min(max(green, 0), 1),
                blue: min(max(blue, 0), 1)
            )
        }
    }

    private static func luminanceScale(for peak: Double) -> Double {
        if peak > peakLuminance {
            let softened = peakLuminance + (peak - peakLuminance) * brightRetention
            return softened / peak
        }
        if peak < 0.05 {
            return min(peakLuminance / max(peak, 0.02), 1.18)
        }
        return 1.0
    }

  /// Rec. 709 luma — used for consistent brightness measurement across cells.
    private static func luminance(red: Double, green: Double, blue: Double) -> Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}

// MARK: - Loader

enum BannerAmbientLoader {
    private static var mediaCache: [Int: HomeAmbientGradient] = [:]
    private static var urlCache: [String: HomeAmbientGradient] = [:]

    @MainActor
    static func gradient(for media: AppMedia) async -> HomeAmbientGradient {
        if let cached = mediaCache[media.id] {
            return cached
        }
        let result = await gradient(for: media.bannerArtworkURL, fallbackId: media.id)
        mediaCache[media.id] = result
        return result
    }

    @MainActor
    static func gradient(for imageURL: URL?, fallbackId: Int = 0) async -> HomeAmbientGradient {
        guard let imageURL else {
            return .default
        }
        let key = imageURL.absoluteString
        if let cached = urlCache[key] {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            if let sampled = BannerImageSampler.regionalGradient(from: data) {
                urlCache[key] = sampled
                return sampled
            }
        } catch {
            // Fall through.
        }

        let fallback = BannerImageSampler.fallbackGradient(forId: fallbackId)
        urlCache[key] = fallback
        return fallback
    }
}

extension MediaDetails {
    func heroArtworkURL(isMobile: Bool) -> URL? {
        if isMobile {
            return MediaConfig.instance.posterURL(posterPath ?? "", width: 780)
        }
        return MediaConfig.instance.backdropURL(backdropPath ?? "", width: "original")
    }
}

// MARK: - Sampling

enum BannerImageSampler {
    private static let gridColumns = 3
    private static let gridRows = 3

    static func regionalGradient(from imageData: Data) -> HomeAmbientGradient? {
        guard let cgImage = cgImage(from: imageData) else { return nil }
        return regionalGradient(from: cgImage)
    }

    static func fallbackGradient(for media: AppMedia) -> HomeAmbientGradient {
        fallbackGradient(forId: media.id)
    }

    static func fallbackGradient(forId id: Int) -> HomeAmbientGradient {
        let baseHue = Double(abs(id.hashValue) % 360) / 360.0
        let raw = (0 ..< 9).map { index in
            let row = index / 3
            let col = index % 3
            let hue = (baseHue + Double(col) * 0.07 + Double(row) * 0.05)
                .truncatingRemainder(dividingBy: 1)
            let cell = AmbientColorCell.fromHSB(hue: hue, saturation: 0.5, brightness: 0.4)
            return (red: cell.red, green: cell.green, blue: cell.blue)
        }
        return HomeAmbientGradient(cells: AmbientColorTuner.tunedCells(from: raw))
    }

    private static func cgImage(from data: Data) -> CGImage? {
        #if canImport(UIKit)
            return UIImage(data: data)?.cgImage
        #elseif canImport(AppKit)
            guard let image = NSImage(data: data) else { return nil }
            var rect = CGRect(origin: .zero, size: image.size)
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
            return nil
        #endif
    }

    static func regionalGradient(from cgImage: CGImage) -> HomeAmbientGradient? {
        let width = 90
        let height = 51

        guard
            let context = makeBitmapContext(width: width, height: height),
            let data = context.data
        else {
            return nil
        }

        context.interpolationQuality = .medium
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var rawSamples: [(red: Double, green: Double, blue: Double)] = []

        let cellW = width / gridColumns
        let cellH = height / gridRows

        for row in 0 ..< gridRows {
            for col in 0 ..< gridColumns {
                let rgb = averageRGB(
                    bytes: bytes,
                    width: width,
                    x0: col * cellW,
                    y0: row * cellH,
                    x1: min((col + 1) * cellW, width),
                    y1: min((row + 1) * cellH, height)
                )
                rawSamples.append((red: rgb.r, green: rgb.g, blue: rgb.b))
            }
        }

        return HomeAmbientGradient(cells: AmbientColorTuner.tunedCells(from: rawSamples))
    }

    private struct RGB {
        var r, g, b: Double
    }

    private static func averageRGB(
        bytes: UnsafeMutablePointer<UInt8>,
        width: Int,
        x0: Int,
        y0: Int,
        x1: Int,
        y1: Int
    ) -> RGB {
        var rSum = 0.0
        var gSum = 0.0
        var bSum = 0.0
        var count = 0

        for y in y0 ..< y1 {
            for x in x0 ..< x1 {
                let offset = (y * width + x) * 4
                rSum += Double(bytes[offset]) / 255
                gSum += Double(bytes[offset + 1]) / 255
                bSum += Double(bytes[offset + 2]) / 255
                count += 1
            }
        }

        guard count > 0 else {
            return RGB(r: 0.08, g: 0.08, b: 0.09)
        }

        return RGB(
            r: rSum / Double(count),
            g: gSum / Double(count),
            b: bSum / Double(count)
        )
    }

    private static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    }
}

// MARK: - Full-page background

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

// MARK: - Fading hero image

/// Hero artwork — gradient mask on the `Image` (white = opaque, clear = transparent at bottom).
struct BannerFadingHeroImage: View {
    let width: CGFloat
    let height: CGFloat
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
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
            AppTheme.Colors.backgroundTertiary
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
        .frame(width: width, height: height)
    }
}

/// Gradient mask (white = show image, clear = fully transparent at bottom).
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

/// Darkens the upper hero only; bottom stays clear so the image dissolve reads through.
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
