import Foundation
import Inject
import SwiftUI

struct MediaLoadedContent: View {
    @ObserveInjection var inject
    let details: MediaDetails
    let isMobile: Bool
    var streamState: ViewItemState<[ResolutionItem]> = .initial
    var movieProgress: Double = 0
    var seriesVm: SeriesViewModel? = nil

    private var castList: [Cast] {
        return details.cast.filter { $0.profilePath != nil && !($0.profilePath!.isEmpty) }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let headerHeight: CGFloat = isMobile
                ? (width * 3) / 2
                : (width * 9) / 16

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header (poster for mobile, banner for desktop) ──
                    if isMobile {
                        MediaInfoPosterView(
                            details: details,
                            width: width,
                            height: headerHeight,
                            streamState: streamState,
                            movieProgress: movieProgress,
                            seriesVm: seriesVm
                        )
                    } else {
                        MediaInfoBannerView(
                            details: details,
                            width: width,
                            height: headerHeight,
                            streamState: streamState,
                            movieProgress: movieProgress,
                            seriesVm: seriesVm
                        )
                    }

                    Spacer().frame(height: AppTheme.Spacing.lg)

                    // ── Seasons & Episodes (series only) ──
                    if !details.seasons.isEmpty, let seriesVm = seriesVm {
                        SeasonEpisodeSection(
                            seasons: details.seasons,
                            seriesVm: seriesVm,
                            isMobile: isMobile,
                            media: details
                        )
                        .padding(.horizontal, AppTheme.Spacing.md)

                        Spacer().frame(
                            height: isMobile
                                ? AppTheme.Spacing.md : AppTheme.Spacing.lg
                        )
                    }

                    // ── Scrollable content below header ──
                    VStack(alignment: .leading, spacing: 0) {
                        // Cast & Crew
                        if !castList.isEmpty {
                            CastAndCrewSection(
                                castList: castList,
                                isMobile: isMobile
                            )
                            Spacer().frame(
                                height: isMobile
                                    ? AppTheme.Spacing.sm : AppTheme.Spacing.lg
                            )
                        }

                        // Collection
                        if let collection = details.collection,
                           !collection.parts.isEmpty
                        {
                            Spacer().frame(
                                height: isMobile
                                    ? AppTheme.Spacing.md : AppTheme.Spacing.lg
                            )
                            MediaDetailsMediaRow(
                                title: collection.name,
                                items: collection.parts,
                                isMovie: details.isMovie
                            )
                        }

                        // Recommendations
                        if !details.recommendations.isEmpty {
                            Spacer().frame(
                                height: isMobile
                                    ? AppTheme.Spacing.md : AppTheme.Spacing.lg
                            )
                            MediaDetailsMediaRow(
                                title: "You may also like",
                                items: details.recommendations,
                                isMovie: details.isMovie
                            )
                        }

                        // Similar
                        if !details.similar.isEmpty {
                            Spacer().frame(
                                height: isMobile
                                    ? AppTheme.Spacing.md : AppTheme.Spacing.lg
                            )
                            MediaDetailsMediaRow(
                                title: "Similar \(details.isMovie ? "Movies" : "Shows")",
                                items: details.similar,
                                isMovie: details.isMovie
                            )
                        }

                        Spacer().frame(height: AppTheme.Spacing.xxl)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
        }
        .enableInjection()
    }
}

private struct MediaInfoPosterView: View {
    let details: MediaDetails
    let width: CGFloat
    let height: CGFloat
    var streamState: ViewItemState<[ResolutionItem]> = .initial
    var movieProgress: Double = 0
    var seriesVm: SeriesViewModel? = nil

    @State private var showStreamSheet = false

    private var effectiveStreamState: ViewItemState<[ResolutionItem]> {
        if let seriesVm = seriesVm { return seriesVm.episodeStreamState }
        return streamState
    }

    private var effectiveSeasonNo: Int { seriesVm?.selectedSeason ?? -1 }
    private var effectiveEpisodeNo: Int { seriesVm?.selectedEpisode ?? -1 }

    private var playProgressFraction: Double {
        let raw: Double
        if let seriesVm = seriesVm {
            let key = "\(details.id):\(seriesVm.selectedSeason):\(seriesVm.selectedEpisode)"
            raw = seriesVm.progressState[key]?.progress ?? 0
        } else {
            raw = movieProgress
        }
        return min(max(raw / 100.0, 0), 1)
    }

    private var playButtonSuffix: String? {
        guard seriesVm != nil else { return nil }
        let s = String(format: "%02d", effectiveSeasonNo)
        let e = String(format: "%02d", effectiveEpisodeNo)
        return "S\(s):E\(e)"
    }

    private var logoPath: String? {
        guard let images = details.images else { return nil }
        guard let logos = images.logos else { return nil }
        let englishLogo = logos.first {
            $0.iso639_1 == "en" && !$0.filePath.hasSuffix(".svg")
        }
        if let logo = englishLogo { return logo.filePath }
        return logos.first?.filePath
    }

    private var releaseYear: String? {
        guard details.airOrReleaseDate != nil, !details.airOrReleaseDate!.isEmpty else { return nil }
        return String(details.airOrReleaseDate!.prefix(4))
    }

    private var runtimeLabel: String? {
        let rt = details.runtime
        guard rt > 0 else { return nil }
        let h = rt / 60
        let m = rt % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Hero poster with everything overlaid ──
            ZStack(alignment: .bottom) {
                // Poster image
                AsyncImage(
                    url: MediaConfig.instance.posterURL(
                        details.posterPath ?? "", width: 500
                    )
                ) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        posterPlaceholder
                    case .empty:
                        ShimmerView()
                    @unknown default:
                        posterPlaceholder
                    }
                }
                .frame(width: width, height: height)
                .clipped()

                // Gradient
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(
                            color: Color.black.opacity(0.3), location: 0.28
                        ),
                        .init(
                            color: Color.black.opacity(0.85), location: 0.55
                        ),
                        .init(
                            color: Color.black.opacity(0.97), location: 1.0
                        ),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: width, height: height)

                // Content pinned to bottom
                VStack(alignment: .leading, spacing: 0) {
                    // Logo or title fallback
                    if let path = logoPath, !path.isEmpty {
                        AsyncImage(
                            url: MediaConfig.instance.logoURL(path, width: 154)
                        ) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(
                                        maxWidth: 160,
                                        maxHeight: height * 0.12
                                    )
                            default:
                                titleFallback
                            }
                        }
                    } else {
                        titleFallback
                    }

                    Spacer().frame(height: 10)

                    // Year · runtime
                    HStack(spacing: 0) {
                        if let year = releaseYear {
                            Text(year)
                                .font(
                                    .system(size: 14, weight: .medium)
                                )
                                .foregroundStyle(AppTheme.Colors.elementSubtle)
                        }
                        if releaseYear != nil && runtimeLabel != nil {
                            Text(" · ")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.elementMuted)
                        }
                        if let runtime = runtimeLabel {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(
                                        AppTheme.Colors.elementMuted
                                    )
                                Text(runtime)
                                    .font(
                                        .system(size: 14, weight: .medium)
                                    )
                                    .foregroundStyle(
                                        AppTheme.Colors.elementSubtle
                                    )
                            }
                        }
                    }

                    Spacer().frame(height: 10)

                    // Genre chips
                    if !details.genres.isEmpty {
                        genreChips(genres: details.genres)
                    }

                    Spacer().frame(height: 10)

                    // Ratings row
                    ratingsRow

                    // Play button
                    if details.isMovie || seriesVm != nil {
                        Spacer().frame(height: 14)
                        PlayStreamButton(
                            label: "Play",
                            suffix: playButtonSuffix,
                            progressFraction: playProgressFraction,
                            action: { showStreamSheet = true }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Back button (top-left)
                VStack {
                    HStack {
                        GlassCircularButton(
                            icon: "chevron.left",
                            action: { Router.router.popRoute() }
                        )
                        Spacer()
                        GlassCircularButton(
                            icon: "bookmark",
                            action: {}
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.md)
                    Spacer()
                }
                .frame(width: width, height: height)
            }
            .frame(width: width, height: height)

            // ── Overview below poster ──
            Text(details.overView)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .lineSpacing(4)
                .lineLimit(5)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.md)
        }
        .sheet(isPresented: $showStreamSheet) {
            StreamSheet(
                state: effectiveStreamState,
                episodeNo: effectiveEpisodeNo,
                seasonNo: effectiveSeasonNo,
                media: details
            )
            .frame(minWidth: 500)
            #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var titleFallback: some View {
        Text(details.name)
            .font(AppTheme.Typography.headingLarge)
            .foregroundStyle(.white)
            .fontWeight(.bold)
    }

    private var posterPlaceholder: some View {
        ZStack {
            AppTheme.Colors.backgroundTertiary
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
    }

    private var ratingsRow: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            RatingTagView(
                rating: details.imdbRating != 0
                    ? String(format: "%.1f", details.imdbRating) : nil,
                source: .imdb,
                isMobile: true
            )
            RatingTagView(
                rating: String(format: "%.2f", details.voteAverage),
                source: .tmdb,
                isMobile: true
            )
        }
    }
}

private struct MediaInfoBannerView: View {
    let details: MediaDetails
    let width: CGFloat
    let height: CGFloat
    var streamState: ViewItemState<[ResolutionItem]> = .initial
    var movieProgress: Double = 0
    var seriesVm: SeriesViewModel? = nil

    @State private var showStreamSheet = false

    private var effectiveStreamState: ViewItemState<[ResolutionItem]> {
        if let seriesVm = seriesVm { return seriesVm.episodeStreamState }
        return streamState
    }

    private var effectiveSeasonNo: Int { seriesVm?.selectedSeason ?? -1 }
    private var effectiveEpisodeNo: Int { seriesVm?.selectedEpisode ?? -1 }

    private var playProgressFraction: Double {
        let raw: Double
        if let seriesVm = seriesVm {
            let key = "\(details.id):\(seriesVm.selectedSeason):\(seriesVm.selectedEpisode)"
            raw = seriesVm.progressState[key]?.progress ?? 0
        } else {
            raw = movieProgress
        }
        return min(max(raw / 100.0, 0), 1)
    }

    private var playButtonSuffix: String? {
        guard seriesVm != nil else { return nil }
        let s = String(format: "%02d", effectiveSeasonNo)
        let e = String(format: "%02d", effectiveEpisodeNo)
        return "S\(s):E\(e)"
    }

    private var logoPath: String? {
        guard let images = details.images else { return nil }
        guard let logos = images.logos else { return nil }
        let englishLogo = logos.first {
            $0.iso639_1 == "en" && !$0.filePath.hasSuffix(".svg")
        }
        if let logo = englishLogo { return logo.filePath }
        return logos.first?.filePath
    }

    private var releaseYear: String? {
        guard details.airOrReleaseDate != nil, !details.airOrReleaseDate!.isEmpty else { return nil }
        return String(details.airOrReleaseDate!.prefix(4))
    }

    private var runtimeLabel: String? {
        let rt = details.runtime
        guard rt > 0 else { return nil }
        let h = rt / 60
        let m = rt % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop image
            AsyncImage(
                url: MediaConfig.instance.backdropURL(
                    details.backdropPath ?? "", width: "original"
                )
            ) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    bannerPlaceholder
                case .empty:
                    ShimmerView()
                @unknown default:
                    bannerPlaceholder
                }
            }
            .frame(width: width, height: height)
            .clipped()

            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.2),
                    .init(color: Color.black.opacity(0.8), location: 0.7),
                    .init(color: Color.black.opacity(0.95), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: height)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Logo or title
                if let path = logoPath, !path.isEmpty {
                    AsyncImage(
                        url: MediaConfig.instance.logoURL(path)
                    ) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 280, maxHeight: 100)
                        default:
                            bannerTitleFallback
                        }
                    }
                } else {
                    bannerTitleFallback
                }

                Spacer().frame(height: AppTheme.Spacing.sm)

                // Year · runtime
                HStack(spacing: 0) {
                    if let year = releaseYear {
                        Text(year)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.elementSubtle)
                    }
                    if releaseYear != nil && runtimeLabel != nil {
                        Text(" · ")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    }
                    if let runtime = runtimeLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.Colors.elementMuted)
                            Text(runtime)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.elementSubtle)
                        }
                    }
                }

                Spacer().frame(height: AppTheme.Spacing.md)

                // Genre chips
                if !details.genres.isEmpty {
                    genreChips(genres: details.genres)
                }

                Spacer().frame(height: AppTheme.Spacing.sm)

                // Ratings
                HStack(spacing: AppTheme.Spacing.xs) {
                    RatingTagView(
                        rating: details.imdbRating != 0
                            ? String(format: "%.1f", details.imdbRating) : nil,
                        source: .imdb,
                        isMobile: false
                    )
                    RatingTagView(
                        rating: String(format: "%.2f", details.voteAverage),
                        source: .tmdb,
                        isMobile: false
                    )
                }

                Spacer().frame(height: AppTheme.Spacing.lg)

                // Overview
                Text(details.overView)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .frame(maxWidth: width * 0.5, alignment: .leading)

                // Play button
                if details.isMovie || seriesVm != nil {
                    Spacer().frame(height: AppTheme.Spacing.lg)
                    PlayStreamButton(
                        label: "Play",
                        suffix: playButtonSuffix,
                        progressFraction: playProgressFraction,
                        action: { showStreamSheet = true }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)

            // Top buttons
            VStack {
                HStack {
                    GlassCircularButton(
                        icon: "chevron.left",
                        action: { Router.router.popRoute() }
                    )
                    Spacer()
                    GlassCircularButton(
                        icon: "bookmark",
                        action: {}
                    )
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                Spacer()
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .sheet(isPresented: $showStreamSheet) {
            StreamSheet(
                state: effectiveStreamState,
                episodeNo: effectiveEpisodeNo,
                seasonNo: effectiveSeasonNo,
                media: details
            )
            .frame(minWidth: 500)
            #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var bannerTitleFallback: some View {
        Text(details.name)
            .font(AppTheme.Typography.displayMedium)
            .foregroundStyle(.white)
            .fontWeight(.bold)
    }

    private var bannerPlaceholder: some View {
        ZStack {
            AppTheme.Colors.backgroundTertiary
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
    }
}

private func genreChips(genres: [Genre]) -> some View {
    // Use a FlowLayout-like wrapping via WrappingHStack
    // SwiftUI doesn't have built-in Wrap, so we use a horizontal scroll for simplicity
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: AppTheme.Spacing.xs) {
            ForEach(genres, id: \.id) { genre in
                Text(genre.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 20,
                                style: .continuous
                            )
                            .stroke(
                                Color.white.opacity(0.18),
                                lineWidth: 1
                            )
                        )
                    )
            }
        }
    }
}

private struct GlassCircularButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 44
    var iconSize: CGFloat = 20

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                    )
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.85 : 1.0)
        .animation(
            .spring(response: 0.25, dampingFraction: 0.7),
            value: isPressed
        )
        .onLongPressGesture(
            minimumDuration: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}


private struct PlayStreamButton: View {
    var label: String = "Play"
    var suffix: String? = nil
    var progressFraction: Double = 0
    let action: () -> Void
    @State private var isHovered = false

    private var hasProgress: Bool { progressFraction > 0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                if hasProgress {
                    playProgressBar
                }
                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(AppTheme.Colors.buttonPrimaryLabel)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.Colors.buttonPrimary)
                    .shadow(
                        color: Color.white.opacity(isHovered ? 0.3 : 0.15),
                        radius: isHovered ? 16 : 8,
                        y: 2
                    )
            )
            .scaleEffect(isHovered ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var playProgressBar: some View {
        let trackWidth: CGFloat = 48
        let trackHeight: CGFloat = 5
        let fillWidth = max(trackHeight, trackWidth * progressFraction)
        return ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(AppTheme.Colors.buttonPrimaryLabel.opacity(0.22))
                .frame(width: trackWidth, height: trackHeight)
            Capsule(style: .continuous)
                .fill(AppTheme.Colors.buttonPrimaryLabel.opacity(0.95))
                .frame(width: fillWidth, height: trackHeight)
        }
        .frame(width: trackWidth, height: trackHeight)
    }
}


private struct StreamSheet: View {
    let state: ViewItemState<[ResolutionItem]>
    let episodeNo: Int
    let seasonNo: Int
    let media: MediaDetails
    @Environment(\.dismiss) private var dismiss

    private var itemCount: Int {
        if case let .loaded(streams) = state { return streams.count }
        return 0
    }

    private var idealHeight: CGFloat {
        let base: CGFloat = 120 // header + padding
        let perItem: CGFloat = 60
        let computed = base + CGFloat(itemCount) * perItem
        return min(max(computed, 340), 700)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack {
                Text("Available Streams")
                    .font(AppTheme.Typography.headingMedium)
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.md)

            Divider()
                .overlay(AppTheme.Colors.divider)

            // ── Content ──
            switch state {
            case .initial, .loading:
                streamLoadingView
            case let .error(message):
                streamErrorView(message: message)
            case let .loaded(streams):
                if streams.isEmpty {
                    streamEmptyView
                } else {
                    streamListView(streams: streams)
                }
            }
        }
        .frame(idealHeight: idealHeight)
        .background(AppTheme.Colors.backgroundSecondary)
    }


    private var streamLoadingView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.regular)

            Text("Finding streams…")
                .font(AppTheme.Typography.bodyMedium)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private func streamErrorView(message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.Colors.warning)
                .symbolRenderingMode(.hierarchical)

            Text("Something went wrong")
                .font(AppTheme.Typography.labelLarge)
                .foregroundStyle(AppTheme.Colors.elementWhite)

            Text(message)
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(AppTheme.Colors.elementMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private var streamEmptyView: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "film.stack")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.Colors.elementMuted)
                .symbolRenderingMode(.hierarchical)

            Text("No streams found")
                .font(AppTheme.Typography.labelLarge)
                .foregroundStyle(AppTheme.Colors.elementWhite)

            Text("No available streams for this title.")
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private func streamListView(streams: [ResolutionItem]) -> some View {
        List {
            ForEach(Array(streams.enumerated()), id: \.offset) { index, stream in
                StreamRow(stream: stream) {
                    dismiss()
                    Router.router.addToRoute(route: .mpvVideoView(MPVViewArgs(resItems: streams, selectedIndex: index, mediaId: media.id, episodeNo: episodeNo, seasonNo: seasonNo, name: media.name)))
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(AppTheme.Colors.divider)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}


private struct StreamRow: View {
    let stream: ResolutionItem
    let onTap: () -> Void
    @State private var isHovered = false

    init(stream: ResolutionItem, onTap: @escaping () -> Void) {
        self.stream = stream
        self.onTap = onTap
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(stream.name)
                .font(AppTheme.Typography.labelLarge)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .layoutPriority(1)

            if !stream.description.isEmpty {
                AppTheme.Colors.divider
                    .frame(width: 1)

                Text(stream.description)
                    .font(AppTheme.Typography.bodySmall)
                    .foregroundStyle(AppTheme.Colors.elementMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .contentShape(Rectangle())
        .opacity(isHovered ? 0.7 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

private struct SeasonEpisodeSection: View {
    let seasons: [Season]
    let seriesVm: SeriesViewModel
    let isMobile: Bool
    let media: MediaDetails

    @State private var showStreamSheet: Bool = false

    private var selectedSeasonIndex: Int {
        seasons.firstIndex(where: { $0.seasonNumber == seriesVm.selectedSeason }) ?? 0
    }

    private var currentSeason: Season? {
        guard selectedSeasonIndex >= 0, selectedSeasonIndex < seasons.count else { return nil }
        return seasons[selectedSeasonIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // ── Season Picker ──
            seasonPicker

            // ── Episode Carousel ──
            if let season = currentSeason, !season.episodes.isEmpty {
                episodeCarousel(episodes: season.episodes, seasonNumber: season.seasonNumber)
            }
        }
        .sheet(isPresented: $showStreamSheet) {
            StreamSheet(state: seriesVm.episodeStreamState, episodeNo: seriesVm.selectedEpisode, seasonNo: seriesVm.selectedSeason, media: media)
                .frame(minWidth: 500)
            #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var seasonPicker: some View {
        Menu {
            ForEach(Array(seasons.enumerated()), id: \.offset) { index, season in
                Button(action: {
                    withAnimation(.smooth(duration: 0.25)) {
                        seriesVm.onEpisodeSelect(
                            season: season.seasonNumber,
                            episode: 1
                        )
                    }
                }) {
                    HStack {
                        Text(season.name ?? "Season \(season.seasonNumber)")
                        if index == selectedSeasonIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentSeason?.name ?? "Season \(currentSeason?.seasonNumber ?? 1)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.elementWhite)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                            .strokeBorder(AppTheme.Colors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func episodeCarousel(episodes: [Episode], seasonNumber: Int) -> some View {
        let spacing: CGFloat = isMobile ? 14 : 18
        let minCardWidth: CGFloat = isMobile ? 260 : 340
        let columns = [
            GridItem(.adaptive(minimum: minCardWidth), spacing: spacing, alignment: .top),
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(Array(episodes.enumerated()), id: \.offset) { _, episode in
                let progressKey = "\(seriesVm.id):\(seasonNumber):\(episode.episodeNumber)"
                EpisodeCard(
                    episode: episode,
                    seasonNumber: seasonNumber,
                    isMobile: isMobile,
                    progress: seriesVm.progressState[progressKey],
                    onTap: {
                        loadStreamsAndShow(seasonNumber: seasonNumber, episodeNumber: episode.episodeNumber)
                    }
                )
            }
        }
        .padding(.horizontal, 2)
    }

    private func loadStreamsAndShow(seasonNumber: Int, episodeNumber: Int) {
        showStreamSheet = true
        seriesVm.onEpisodeSelect(
            season: seasonNumber,
            episode: episodeNumber
        )
    }
}

private struct EpisodeCard: View {
    let episode: Episode
    let seasonNumber: Int
    let isMobile: Bool
    let progress: WatchProgress?
    let onTap: () -> Void

    /// Overall card aspect ratio (width / height). Matches the prior
    /// combined thumbnail + info ratio so the card footprint is unchanged.
    private let cardAspect: CGFloat = 300.0 / 258.0

    private var progressFraction: Double {
        guard let p = progress else { return 0 }
        return min(max(p.progress / 100.0, 0), 1)
    }

    private var hasProgress: Bool {
        progressFraction > 0
    }

    private var isWatched: Bool {
        progress?.isWatched ?? false
    }

    private static func formatRuntime(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var runtimeLabel: String? {
        guard let rt = episode.runtime, rt > 0 else { return nil }
        if hasProgress {
            let remaining = max(
                0,
                Int((Double(rt) * (1.0 - progressFraction)).rounded())
            )
            return "\(Self.formatRuntime(minutes: remaining)) left"
        }
        return Self.formatRuntime(minutes: rt)
    }

    private var airDateValue: Date? {
        guard let airDate = episode.airDate, !airDate.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: airDate)
    }

    private var isUpcoming: Bool {
        guard let date = airDateValue else { return false }
        return date > Date()
    }

    private var formattedAirDate: String? {
        guard let date = airDateValue else { return nil }
        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy"
        return display.string(from: date)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let corner = AppTheme.Radius.md

            ZStack(alignment: .bottomLeading) {
                // Background thumbnail
                Group {
                    if let stillPath = episode.stillPath, !stillPath.isEmpty {
                        AsyncImage(
                            url: MediaConfig.instance.stillURL(stillPath, width: "original")
                        ) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                thumbnailPlaceholder
                            case .empty:
                                ShimmerView()
                            @unknown default:
                                thumbnailPlaceholder
                            }
                        }
                    } else {
                        thumbnailPlaceholder
                    }
                }
                .frame(width: w, height: h)
                .clipped()

                // Bottom frosted overlay with gradient mask so only the
                // lower portion is blurred / darkened.
                bottomFrostedOverlay(width: w, height: h)

                // Info content pinned to bottom
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Episode \(episode.episodeNumber)")
                            .foregroundStyle(Color.white.opacity(0.75))

                        if let airDate = formattedAirDate {
                            Text("·")
                                .foregroundStyle(Color.white.opacity(0.45))
                            Text(airDate)
                                .foregroundStyle(Color.white.opacity(0.65))
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .lineLimit(1)

                    Text(episode.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !episode.overview.isEmpty {
                        Text(episode.overview)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .lineLimit(3)
                            .lineSpacing(1)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.9))
                            if let runtime = runtimeLabel {
                                Text(runtime)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.9))
                            } else {
                                Text("Play")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                        }

                        if hasProgress {
                            episodeProgressBar
                                .padding(.leading, 10)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .frame(width: w, alignment: .leading)

                // Status badge (top-right): upcoming takes priority over watched
                if isUpcoming || isWatched {
                    VStack {
                        HStack {
                            Spacer()
                            if isUpcoming {
                                upcomingBadge
                            } else {
                                watchedBadge
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .frame(width: w, height: h)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .aspectRatio(cardAspect, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private func bottomFrostedOverlay(width: CGFloat, height: CGFloat) -> some View {
        let overlayHeight = height * 0.55

        ZStack(alignment: .bottom) {
            // Blurred backdrop limited to the bottom region via mask.
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(width: width, height: overlayHeight)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black.opacity(0.6), location: 0.25),
                            .init(color: .black, location: 0.6),
                            .init(color: .black, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Dark gradient to ensure text legibility on top of the blur.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.black.opacity(0.35), location: 0.5),
                    .init(color: Color.black.opacity(0.75), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: overlayHeight)
        }
        .frame(width: width, height: height, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var upcomingBadge: some View {
        Text("UPCOMING")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
    }

    private var watchedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text("WATCHED")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(AppTheme.Colors.success.opacity(0.55))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            AppTheme.Colors.backgroundTertiary
            Image(systemName: "tv")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.Colors.elementDim)
        }
    }

    private var episodeProgressBar: some View {
        let trackWidth: CGFloat = 48
        let trackHeight: CGFloat = 5
        return ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.22))
                .frame(width: trackWidth, height: trackHeight)

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.95))
                .frame(
                    width: max(trackHeight, trackWidth * progressFraction),
                    height: trackHeight
                )
        }
        .frame(width: trackWidth, height: trackHeight)
    }
}
