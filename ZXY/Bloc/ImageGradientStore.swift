import Foundation
import SwiftUI


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

enum ImageUpdate {
    case loading
    case error(String)
    case loaded(CGImage)
}

/// Normalizes a 3×3 sample set — keeps spatial color, tames only the extremes.
enum AmbientColorTuner {
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

@Observable
@MainActor
class ImageGradientAndStoreBloc {
    static let bloc = ImageGradientAndStoreBloc()
    private init() {}

    @ObservationIgnored
    private var gradientCache: [String: HomeAmbientGradient] = [:]
    @ObservationIgnored
    private var imageCache: [String: CGImage] = [:]
    @ObservationIgnored
    private var imageUpdateHandlers: [String: (ImageUpdate) -> Void] = [:]
    @ObservationIgnored
    private let gridColumns = 3
    @ObservationIgnored
    private let gridRows = 3

    var currentGradient: HomeAmbientGradient = .default

    private struct RGB {
        var r, g, b: Double
    }

    @ObservationIgnored
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration)
    }()

    func fetchAndStoreImage(id: String, size: String, handler: (ImageUpdate) -> Void) async throws {
        do {
            guard let url = MediaConfig.instance.backdropURL(id, width: size) else {
                handler(.error("Could not create url"))
                return
            }
            let urlString = url.absoluteString
            if let image = imageCache[urlString] {
                handler(.loaded(image))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                handler(.error("Invalid response"))
                return
            }

            guard httpResponse.statusCode == 200 else {
                handler(.error("Invalid status code"))
                return
            }

            guard let dataProvider = CGDataProvider(data: data as CFData) else {
                handler(.error("Invalid image data"))
                return
            }

            guard let imageSource = CGImageSourceCreateWithDataProvider(dataProvider, nil) else {
                handler(.error("Invalid image data"))
                return
            }

            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                handler(.error("Invalid image data"))
                return
            }
            imageCache[urlString] = cgImage
            handler(.loaded(cgImage))
        } catch {
            handler(.error(error.localizedDescription))
        }
    }

    private func makeBitmapContext(width: Int, height: Int) -> CGContext? {
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

    private func averageRGB(
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

    func setGradientFromImage(from cgImage: CGImage, id: String) {
        if let gradient = gradientCache[id] {
            currentGradient = gradient
            return
        }

        let width = 90
        let height = 51

        guard
            let context = makeBitmapContext(width: width, height: height),
            let data = context.data
        else {
            return
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

        currentGradient = HomeAmbientGradient(cells: AmbientColorTuner.tunedCells(from: rawSamples))
        gradientCache[id] = currentGradient
    }
}


