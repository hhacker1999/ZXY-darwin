import SwiftUI

// MARK: - Video Info Overlay

struct VideoInfoOverlayView: View {
    let vm: MpvViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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

            // Divider
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 10)

            // Info rows
            VStack(alignment: .leading, spacing: 6) {
                // HDR Section
                hdrSection

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.vertical, 2)

                // Video Properties
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

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.vertical, 2)

                // Color Properties
                infoRow(
                    icon: "waveform.path",
                    label: "Sig Peak",
                    value: String(format: "%.2f", vm.sigPeak)
                )

                infoRow(icon: "paintpalette", label: "Colormatrix", value: vm.colormatrix)

                infoRow(icon: "target", label: "Primaries", value: vm.primaries)

                infoRow(icon: "sun.max", label: "Gamma", value: vm.gamma)

                infoRow(icon: "display", label: "EDR Range", value: vm.edrRange)

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.vertical, 2)

                // Decoder
                infoRow(icon: "cpu", label: "Decoder", value: vm.currentDecoder)

                // Buffer
                infoRow(
                    icon: "clock.arrow.circlepath",
                    label: "Buffered",
                    value: formatBufferDuration(vm.cachePos - vm.currentPos)
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 260)
        .infoOverlayGlass()
    }

    // MARK: - HDR Section

    private var hdrSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // HDR Available status
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

            // HDR Toggle
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

    // MARK: - Info Row

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

    // MARK: - Helpers

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

// MARK: - Glass modifier for info overlay

extension View {
    @ViewBuilder
    func infoOverlayGlass() -> some View {
        if #available(macOS 26, iOS 26, *) {
            self
            // glassEffect(.clear, in: .rect(cornerRadius: 14))
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
            // .clipShape(.rect(cornerRadius: 14))
            // .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
