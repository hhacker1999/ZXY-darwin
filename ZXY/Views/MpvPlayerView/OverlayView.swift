import Foundation
import SwiftUI

// MARK: - Settings Menu Category

enum SettingsCategory: String, CaseIterable, Identifiable {
    case streams = "Video"
    case audio = "Audio"
    case subtitles = "Subtitles"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .streams: return "film"
        case .audio: return "speaker.wave.3.fill"
        case .subtitles: return "captions.bubble.fill"
        }
    }
}

// MARK: - Overlay View

struct OverlayView: View {
    var title: String
    let vm: MpvViewModel
    var onBack: (() -> Void)?

    @State private var showSettings: Bool = false
    @State private var selectedCategory: SettingsCategory? = nil

    var body: some View {
        ZStack {
            // Tap target to dismiss settings
            Color.black.opacity(0.001)
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                Spacer()
                if !vm.loading {
                    centerControls
                }
                Spacer()
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            if showSettings {
                settingsPanel
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: 0.92, anchor: .bottomTrailing)
                        )
                    )
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: { onBack?() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .liquidGlass()

            // Title
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .liquidGlass()

            Spacer()
        }
    }

    // MARK: - Center Controls

    private var centerControls: some View {
        HStack(spacing: 40) {
            // Skip backward
            Button(action: {
                vm.seek(relative: -10)
            }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .liquidGlass()

            // Play / Pause
            Button(action: {
                vm.togglePause()
            }) {
                Image(systemName: !vm.paused ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .liquidGlassProminent()

            // Skip forward
            Button(action: {
                vm.seek(relative: 10)
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .liquidGlass()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Time elapsed
            Text(vm.currentPlayHeadPos.formatted())
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 60, alignment: .trailing)

            // Progress bar
            progressBar
                .frame(height: 36)

            // Time remaining
            Text(vm.duration.formatted())
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 60, alignment: .leading)

            // Settings button
            Button(action: {
                withAnimation(.smooth(duration: 0.35)) {
                    if showSettings {
                        showSettings = false
                        selectedCategory = nil
                    } else {
                        showSettings = true
                        selectedCategory = nil
                    }
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(showSettings ? 1.0 : 0.8))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .liquidGlass()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .liquidGlass()
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = Double(vm.duration.components.seconds) > 0 ? (Double(vm.currentPlayHeadPos.components.seconds) / Double(vm.duration.components.seconds)) : 0
            let buffProgress = Double(vm.duration.components.seconds) > 0 ? (Double(vm.cachePos.components.seconds) / Double(vm.duration.components.seconds)) : 0

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 5)

                // Buffered indicator (simulate ~80%)
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: width * buffProgress, height: 5)

                // Played progress
                Capsule()
                    .fill(.white)
                    .frame(width: max(0, width * progress), height: 5)

                // Thumb
                Circle()
                    .fill(.white)
                    .frame(
                        width: vm.isDragging ? 16 : 12,
                        height: vm.isDragging ? 16 : 12
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .offset(x: max(0, min(width * progress - 6, width - 12)))
                    .animation(.easeOut(duration: 0.15), value: vm.isDragging)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(
                            0,
                            min(value.location.x / width, 1.0)
                        )
                        vm.onDragStartOrUpdate(fraction)
                    }
                    .onEnded { _ in
                        vm.onDragEnd()
                    }
            )
        }
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .trailing) {
            Spacer()
            HStack {
                Spacer()

                HStack(spacing: 0) {
                    // Category list (always visible when settings open)
                    if selectedCategory == nil {
                        settingsCategoryList
                            .transition(
                                .opacity.combined(with: .move(edge: .trailing))
                            )
                    }

                    // Submenu
                    if let category = selectedCategory {
                        settingsSubmenu(for: category)
                            .transition(
                                .opacity.combined(with: .move(edge: .leading))
                            )
                    }
                }
                .frame(width: selectedCategory == nil ? 220 : 280)
                .settingsGlass()
            }
        }
        .onContinuousHover { [weak vm] _ in
            if let vm = vm {
                vm.onUserInteraction()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 90)
    }

    // MARK: - Settings Category List

    private var settingsCategoryList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)

            ForEach(SettingsCategory.allCases) { category in
                Button(action: {
                    withAnimation(.smooth(duration: 0.25)) {
                        selectedCategory = category
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 24)

                        Text(category.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)

                        Spacer()

                        Text(currentSelectionLabel(for: category))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.001))
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: 2)
            Button(action: { [weak vm] in
                if let vm = vm {
                    vm.toggleVideoInfoOverlay()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 24)

                    Text("Toggle Info")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.001))
                )
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 8)
        }
    }

    // MARK: - Settings Submenu

    private func settingsSubmenu(for category: SettingsCategory) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header with back
            Button(action: {
                withAnimation(.smooth(duration: 0.25)) {
                    selectedCategory = nil
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))

                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(category.rawValue)
                        .font(
                            .system(size: 14, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 12)

            switch category {
            case .streams:
                streamsSubmenu
            case .audio:
                audioSubmenu
            case .subtitles:
                subtitleSubmenu
            }

            Spacer().frame(height: 8)
        }
    }

    // MARK: - Streams Submenu

    private var streamsSubmenu: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(vm.streams.enumerated()), id: \.offset) { index, stream in
                    let isSelected = index == vm.selectedStreamIndex

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            vm.switchStream(to: index)
                        }
                    }) {
                        HStack(spacing: 12) {
                            // Selection indicator
                            Image(
                                systemName: isSelected
                                    ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                isSelected ? .white : .white.opacity(0.3)
                            )
                            .frame(width: 20)

                            VStack(alignment: .leading, spacing: 3) {
                                // Resolution
                                Text(stream.resolution)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)

                                HStack(spacing: 6) {
                                    // Quality tag
                                    if let quality = stream.quality, !quality.isEmpty {
                                        Text(quality)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }

                                    // Size as bitrate proxy
                                    if let size = stream.size, size > 0 {
                                        if stream.quality != nil && !stream.quality!.isEmpty {
                                            Text("·")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.white.opacity(0.3))
                                        }
                                        Text(formatFileSize(size))
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    isSelected ? .white.opacity(0.08) : .clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onScrollPhaseChange { [weak vm] _, _ in
            if let vm = vm {
                vm.onUserInteraction()
            }
        }
        .frame(maxHeight: 260)
    }

    // MARK: - Audio Submenu

    private var audioSubmenu: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                // "Off" option
                let isOff = vm.selectAudioTrack == -1

                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        vm.setAudioTrack(index: -1)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(
                            systemName: isOff
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(
                            isOff ? .white : .white.opacity(0.3)
                        )
                        .frame(width: 20)

                        Text("Off")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isOff ? .white.opacity(0.08) : .clear)
                    )
                }
                .buttonStyle(.plain)

                ForEach(Array(vm.audioTracks.enumerated()), id: \.offset) { index, track in
                    let isSelected = index == vm.selectAudioTrack

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            vm.setAudioTrack(index: index)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(
                                systemName: isSelected
                                    ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                isSelected ? .white : .white.opacity(0.3)
                            )
                            .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.lang ?? "Track \(track.id)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)

                                if let title = track.title, !title.isEmpty {
                                    Text(title)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    isSelected ? .white.opacity(0.08) : .clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onScrollPhaseChange { [weak vm] _, _ in
            if let vm = vm {
                vm.onUserInteraction()
            }
        }
        .frame(maxHeight: 260)
    }

    // MARK: - Subtitle Submenu

    private var subtitleSubmenu: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                // "Off" option
                let isOff = vm.selectSubTrack == -1

                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        vm.setSubtitleTrack(index: -1)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(
                            systemName: isOff
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(
                            isOff ? .white : .white.opacity(0.3)
                        )
                        .frame(width: 20)

                        Text("Off")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isOff ? .white.opacity(0.08) : .clear)
                    )
                }
                .buttonStyle(.plain)

                ForEach(Array(vm.subtitleTracks.enumerated()), id: \.offset) { index, track in
                    let isSelected = index == vm.selectSubTrack

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            vm.setSubtitleTrack(index: index)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(
                                systemName: isSelected
                                    ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                isSelected ? .white : .white.opacity(0.3)
                            )
                            .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.lang ?? "Track \(track.id)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)

                                if let title = track.title, !title.isEmpty {
                                    Text(title)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    isSelected ? .white.opacity(0.08) : .clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onScrollPhaseChange { [weak vm] _, _ in
            if let vm = vm {
                vm.onUserInteraction()
            }
        }
        .frame(maxHeight: 260)
    }

    // MARK: - Helpers

    private func currentSelectionLabel(for category: SettingsCategory) -> String {
        switch category {
        case .streams:
            guard vm.selectedStreamIndex >= 0, vm.selectedStreamIndex < vm.streams.count else {
                return ""
            }
            return vm.streams[vm.selectedStreamIndex].resolution
        case .audio:
            if vm.selectAudioTrack == -1 { return "Off" }
            guard vm.selectAudioTrack >= 0, vm.selectAudioTrack < vm.audioTracks.count else {
                return ""
            }
            return vm.audioTracks[vm.selectAudioTrack].lang ?? "Track \(vm.audioTracks[vm.selectAudioTrack].id)"
        case .subtitles:
            if vm.selectSubTrack == -1 { return "Off" }
            guard vm.selectSubTrack >= 0, vm.selectSubTrack < vm.subtitleTracks.count else {
                return ""
            }
            return vm.subtitleTracks[vm.selectSubTrack].lang ?? "Track \(vm.subtitleTracks[vm.selectSubTrack].id)"
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    private func formatTime(_ totalSeconds: Double) -> String {
        let mins = Int(totalSeconds) / 60
        let secs = Int(totalSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

extension View {
    @ViewBuilder
    func liquidGlass() -> some View {
        if #available(macOS 26, iOS 26, *) {
            glassEffect(.regular)
        } else {
            background(.ultraThinMaterial, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func liquidGlassProminent() -> some View {
        if #available(macOS 26, iOS 26, *) {
            glassEffect(.clear)
        } else {
            background(.thickMaterial, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                }
        }
    }

    func settingsGlass() -> some View {
        background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
    }
}
