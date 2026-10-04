import SwiftUI

struct VideoInfoOverlayView: View {
    enum Style {
        /// In-player glass card (macOS).
        case floatingCard
        /// Scrollable body for an iOS sheet (no duplicate title chrome).
        case sheetContent
    }

    let vm: MpvViewModel
    var style: Style = .floatingCard

    var body: some View {
        switch style {
        case .floatingCard:
            floatingCard
        case .sheetContent:
            sheetContent
        }
    }

    private var floatingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            floatingCardChrome
            statsRows
        }
        .frame(width: 260)
        .infoOverlayGlass()
    }

    private var floatingCardChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Text("Video Info")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 10)
        }
    }

    private var sheetContent: some View {
        statsRows
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var statsRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            hdrSection

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 2)

            infoRow(icon: "film", label: "Codec", value: vm.videoCodecName)

            infoRow(
                icon: "speedometer",
                label: "Bitrate",
                value: formatBitRate(vm.videoBitRate)
            )

            infoRow(
                icon: "arrow.down.circle",
                label: "Download",
                value: String(format: "%.2f Mbps", vm.downloadSpeed)
            )

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 2)

            infoRow(
                icon: "waveform.path",
                label: "Sig Peak",
                value: String(format: "%.2f", vm.sigPeak)
            )

            infoRow(icon: "paintpalette", label: "Colormatrix", value: vm.colormatrix)

            infoRow(icon: "target", label: "Primaries", value: vm.primaries)

            infoRow(icon: "sun.max", label: "Gamma", value: vm.gamma)

            infoRow(icon: "display", label: "EDR Range", value: vm.edrRange)

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 2)

            infoRow(icon: "cpu", label: "Decoder", value: vm.currentDecoder)

            infoRow(
                icon: "clock.arrow.circlepath",
                label: "Buffered",
                value: formatBufferDuration(vm.cachePos - vm.currentPos)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var hdrSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: vm.hdrAvailable ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(vm.hdrAvailable ? .green : .red.opacity(0.7))
                    .frame(width: 16)

                Text("HDR Available")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Text(vm.hdrAvailable ? "Yes" : "No")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(vm.hdrAvailable ? .green : .white.opacity(0.4))
            }

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        vm.hdrEnabled
                            ? Color(hue: 0.08, saturation: 0.9, brightness: 1.0)
                            : .white.opacity(0.4)
                    )
                    .frame(width: 16)

                Text("HDR Output")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Toggle("", isOn: Binding(
                    get: { vm.hdrAvailable && vm.hdrEnabled },
                    set: { _ in vm.toggleHDR() }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.65)
                .frame(width: 40)
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

    private func formatBitRate(_ bitsPerSecond: Double) -> String {
        let mbps = bitsPerSecond / 1_000_000
        if mbps >= 1.0 {
            return String(format: "%.1f Mbps", mbps)
        }
        let kbps = bitsPerSecond / 1000
        if kbps >= 1.0 {
            return String(format: "%.0f Kbps", kbps)
        }
        return "—"
    }

    private func formatBufferDuration(_ duration: Duration) -> String {
        let seconds = Double(duration.components.seconds)
        if seconds < 0 { return "0.0s" }
        return String(format: "%.1fs", seconds)
    }
}

extension View {
    @ViewBuilder
    func infoOverlayGlass() -> some View {
        if #available(macOS 26, iOS 26, *) {
            self
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
        }
    }
}
