import Foundation
import SwiftUI

struct MediaLoadedContent: View {
    let details: MediaDetails
    let isMobile: Bool
    @State private var ambientGradient: HomeAmbientGradient = .default
    var streamsState: ViewItemState<[VideoPlayerStream]>? = nil
    var onMoviePlay: (() -> Bool)? = nil
    var streamVm: (any StreamViewModel)? = nil
    var movieProgress: Double = 0
    var movieIsWatched: Bool = false
    var seriesVm: SeriesViewModel? = nil
    var onMarkMovieWatched: () -> Void = {}

    private var castList: [Cast] {
        return details.cast.filter {
            $0.profilePath != nil && !($0.profilePath!.isEmpty)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let headerHeight: CGFloat =
                isMobile
                    ? (width * 3) / 2
                    : (width * 9) / 16

            ZStack {
                HomePageAmbientBackground(gradient: ambientGradient)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Header (poster for mobile, banner for desktop) ──
                        if isMobile {
                            MediaInfoPosterView(
                                details: details,
                                width: width,
                                height: headerHeight,
                                streamsState: streamsState,
                                onMoviePlay: onMoviePlay,
                                streamVm: streamVm,
                                movieProgress: movieProgress,
                                movieIsWatched: movieIsWatched,
                                seriesVm: seriesVm,
                                onMarkMovieWatched: onMarkMovieWatched
                            )
                        } else {
                            MediaInfoBannerView(
                                details: details,
                                width: width,
                                height: headerHeight,
                                streamsState: streamsState,
                                onMoviePlay: onMoviePlay,
                                streamVm: streamVm,
                                movieProgress: movieProgress,
                                movieIsWatched: movieIsWatched,
                                seriesVm: seriesVm,
                                onMarkMovieWatched: onMarkMovieWatched
                            )
                        }

                        Spacer().frame(height: AppTheme.Spacing.lg)

                        // ── Seasons & Episodes (series only) ──
                        if !details.seasons.isEmpty, let seriesVm = seriesVm {
                            SeasonEpisodeSection(
                                seasons: details.seasons,
                                seriesVm: seriesVm,
                                isMobile: isMobile
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
                                        ? AppTheme.Spacing.sm
                                        : AppTheme.Spacing.lg
                                )
                            }

                            // Collection
                            if let collection = details.collection,
                               !collection.parts.isEmpty
                            {
                                Spacer().frame(
                                    height: isMobile
                                        ? AppTheme.Spacing.md
                                        : AppTheme.Spacing.lg
                                )
                                MediaShelfSection(
                                    title: collection.name,
                                    media: collection.parts.map {
                                        $0.asAppMedia(
                                            preferMovie: details.isMovie
                                        )
                                    },
                                    onTap: MediaShelfNavigation.openDetails,
                                    insetContent: false
                                )
                            }

                            // Recommendations
                            if !details.recommendations.isEmpty {
                                Spacer().frame(
                                    height: isMobile
                                        ? AppTheme.Spacing.md
                                        : AppTheme.Spacing.lg
                                )
                                MediaShelfSection(
                                    title: "You may also like",
                                    media: details.recommendations.map {
                                        $0.asAppMedia(
                                            preferMovie: details.isMovie
                                        )
                                    },
                                    onTap: MediaShelfNavigation.openDetails,
                                    insetContent: false
                                )
                            }

                            // Similar
                            if !details.similar.isEmpty {
                                Spacer().frame(
                                    height: isMobile
                                        ? AppTheme.Spacing.md
                                        : AppTheme.Spacing.lg
                                )
                                MediaShelfSection(
                                    title:
                                    "Similar \(details.isMovie ? "Movies" : "Shows")",
                                    media: details.similar.map {
                                        $0.asAppMedia(
                                            preferMovie: details.isMovie
                                        )
                                    },
                                    onTap: MediaShelfNavigation.openDetails,
                                    insetContent: false
                                )
                            }

                            Spacer().frame(height: AppTheme.Spacing.xxl)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                }
                .hideScrollContentBackground()
            }
        }
        #if os(iOS)
        .ignoresSafeArea(edges: isMobile ? .top : [])
        #endif
    }
}

private struct MediaInfoPosterView: View {
    let details: MediaDetails
    let width: CGFloat
    let height: CGFloat
    var streamsState: ViewItemState<[VideoPlayerStream]>? = nil
    var onMoviePlay: (() -> Bool)? = nil
    var streamVm: (any StreamViewModel)? = nil
    var movieProgress: Double = 0
    var movieIsWatched: Bool = false
    var seriesVm: SeriesViewModel? = nil
    var onMarkMovieWatched: () -> Void = {}

    private var isMovieOnly: Bool {
        details.isMovie && seriesVm == nil
    }

    @State private var showStreamSheet = false

    private var effectiveStreamState: ViewItemState<[VideoPlayerStream]> {
        if let seriesVm = seriesVm { return seriesVm.episodeStreamState }
        return streamsState ?? .initial
    }

    private func playButtonTapped() {
        if let onMoviePlay {
            if onMoviePlay() {
                showStreamSheet = true
            }
        } else {
            showStreamSheet = true
        }
    }

    private var effectiveSeasonNo: Int {
        seriesVm?.selectedSeason ?? -1
    }

    private var effectiveEpisodeNo: Int {
        seriesVm?.selectedEpisode ?? -1
    }

    private var playProgressFraction: Double {
        let raw: Double
        if let seriesVm = seriesVm {
            let key =
                "\(details.id):\(seriesVm.selectedSeason):\(seriesVm.selectedEpisode)"
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
        guard details.airOrReleaseDate != nil,
              !details.airOrReleaseDate!.isEmpty
        else { return nil }
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
                BannerFadingHeroImage(
                    width: width,
                    height: height,
                    path: details.posterPath ?? "",
                    imageWidth: "w780"
                )
                .stretchableHeroBannerInScrollView()
                .zIndex(0)

                HeroTextLegibilityScrim(
                    width: width,
                    height: height * 0.55
                )
                .zIndex(1)

                // Content pinned to bottom
                VStack(alignment: .leading, spacing: 0) {
                    // Logo or title fallback
                    if let path = logoPath, !path.isEmpty {
                        AsyncImage(
                            url: MediaConfig.instance.logoURL(path)
                        ) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(
                                        maxWidth: 420,
                                        maxHeight: 180,
                                        alignment: .bottomLeading
                                    )
                            default:
                                titleFallback
                            }
                        }
                        .frame(
                            maxWidth: 420,
                            maxHeight: 180,
                            alignment: .bottomLeading
                        )
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
                        HStack(alignment: .center, spacing: 10) {
                            PlayStreamButton(
                                label: "Play",
                                suffix: playButtonSuffix,
                                progressFraction: playProgressFraction,
                                action: playButtonTapped
                            )
                            if isMovieOnly {
                                MovieWatchedCheckButton(
                                    isWatched: movieIsWatched,
                                    action: onMarkMovieWatched
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .zIndex(2)
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
            if let playbackVm = streamVm ?? seriesVm {
                StreamSheet(
                    state: effectiveStreamState,
                    streamVm: playbackVm
                )
                .streamSheetPresentationChrome()
            }
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
            LoadingSurfaceFill()
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
    var streamsState: ViewItemState<[VideoPlayerStream]>? = nil
    var onMoviePlay: (() -> Bool)? = nil
    var streamVm: (any StreamViewModel)? = nil
    var movieProgress: Double = 0
    var movieIsWatched: Bool = false
    var seriesVm: SeriesViewModel? = nil
    var onMarkMovieWatched: () -> Void = {}

    private var isMovieOnly: Bool {
        details.isMovie && seriesVm == nil
    }

    @State private var showStreamSheet = false

    private var effectiveStreamState: ViewItemState<[VideoPlayerStream]> {
        if let seriesVm = seriesVm { return seriesVm.episodeStreamState }
        return streamsState ?? .initial
    }

    private func playButtonTapped() {
        if let onMoviePlay {
            if onMoviePlay() {
                showStreamSheet = true
            }
        } else {
            showStreamSheet = true
        }
    }

    private var effectiveSeasonNo: Int {
        seriesVm?.selectedSeason ?? -1
    }

    private var effectiveEpisodeNo: Int {
        seriesVm?.selectedEpisode ?? -1
    }

    private var playProgressFraction: Double {
        let raw: Double
        if let seriesVm = seriesVm {
            let key =
                "\(details.id):\(seriesVm.selectedSeason):\(seriesVm.selectedEpisode)"
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
        guard details.airOrReleaseDate != nil,
              !details.airOrReleaseDate!.isEmpty
        else { return nil }
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
            BannerFadingHeroImage(
                width: width,
                height: height,
                path: details.backdropPath ?? "",
                imageWidth: "original"
            )
            .stretchableHeroBannerInScrollView()
            .zIndex(0)

            HeroTextLegibilityScrim(
                width: width,
                height: height * 0.55
            )
            .zIndex(1)

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
                                .frame(
                                    maxWidth: 420,
                                    maxHeight: 180,
                                    alignment: .bottomLeading
                                )
                        default:
                            bannerTitleFallback
                        }
                    }
                    .frame(
                        maxWidth: 420,
                        maxHeight: 180,
                        alignment: .bottomLeading
                    )
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
                    HStack(alignment: .center, spacing: 10) {
                        PlayStreamButton(
                            label: "Play",
                            suffix: playButtonSuffix,
                            progressFraction: playProgressFraction,
                            action: playButtonTapped
                        )
                        if isMovieOnly {
                            MovieWatchedCheckButton(
                                isWatched: movieIsWatched,
                                action: onMarkMovieWatched
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
            .zIndex(2)
        }
        .frame(width: width, height: height)
        .sheet(isPresented: $showStreamSheet) {
            if let playbackVm = streamVm ?? seriesVm {
                StreamSheet(
                    state: effectiveStreamState,
                    streamVm: playbackVm
                )
                .streamSheetPresentationChrome()
            }
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
            LoadingSurfaceFill()
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

private struct MovieWatchedCheckButton: View {
    let isWatched: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(
                    systemName: isWatched
                        ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    isWatched
                        ? Color.white
                        : Color.white.opacity(0.9)
                )
                Text(isWatched ? "Watched" : "Mark watched")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        isWatched
                            ? Color.white
                            : Color.white.opacity(0.88)
                    )
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(backgroundFill)
                    Capsule(style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: 1)
                }
                .shadow(
                    color: shadowColor,
                    radius: isHovered && !isWatched ? 14 : (isWatched ? 10 : 8),
                    y: 2
                )
            }
            .scaleEffect((isHovered && !isWatched) ? 1.02 : 1.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.72),
                value: isHovered
            )
        }
        .buttonStyle(.plain)
        .disabled(isWatched)
        .opacity(isWatched ? 0.92 : 1)
        .accessibilityLabel(isWatched ? "Watched" : "Mark as watched")
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
    }

    private var backgroundFill: LinearGradient {
        if isWatched {
            return LinearGradient(
                colors: [
                    AppTheme.Colors.success.opacity(0.52),
                    AppTheme.Colors.success.opacity(0.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.22),
                Color.white.opacity(0.06),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var strokeColor: Color {
        isWatched
            ? AppTheme.Colors.success.opacity(0.55)
            : Color.white.opacity(0.26)
    }

    private var shadowColor: Color {
        if isWatched {
            return Color.black.opacity(0.45)
        }
        if isHovered {
            return Color.white.opacity(0.14)
        }
        return Color.black.opacity(0.4)
    }
}

private struct PlayStreamButton: View {
    var label: String = "Play"
    var suffix: String? = nil
    var progressFraction: Double = 0
    let action: () -> Void
    @State private var isHovered = false

    private var hasProgress: Bool {
        progressFraction > 0
    }

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
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: isHovered
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
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

extension View {
    /// On iPhone / compact layouts SwiftUI may adapt ``sheet`` to a popover-style panel; force a bottom sheet and system page sizing.
    @ViewBuilder
    func streamSheetPresentationChrome() -> some View {
        #if os(iOS)
            presentationCompactAdaptation(.sheet)
                .presentationSizing(.page)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        #elseif os(macOS)
            frame(minWidth: 500)
        #else
            frame(width: 960, height: 680)
        #endif
    }
}

struct StreamSheet: View {
    let state: ViewItemState<[VideoPlayerStream]>
    let streamVm: any StreamViewModel
    @Environment(\.dismiss) private var dismiss

    private var itemCount: Int {
        if case let .loaded(streams) = state { return streams.count }
        return 0
    }

    private var idealHeight: CGFloat {
        let base: CGFloat = 132 // header + padding
        let perItem: CGFloat = 118
        let computed = base + CGFloat(itemCount) * perItem
        return min(max(computed, 380), 720)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Choose a Stream")
                        .font(AppTheme.Typography.headingMedium)
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                    if itemCount > 0 {
                        Text("\(itemCount) available")
                            .font(AppTheme.Typography.bodySmall)
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    }
                }
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
            Group {
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

    @ViewBuilder
    private func streamListView(streams: [VideoPlayerStream]) -> some View {
        List {
            ForEach(Array(streams.enumerated()), id: \.offset) {
                index,
                stream in
                StreamRow(stream: stream) {
                    dismiss()
                    streamVm.setSelectedStreamIndex(index)
                    Router.router.addToRoute(
                        route: .mpvVideoView(
                            StreamPlaybackRoute(viewModel: streamVm)
                        )
                    )
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: AppTheme.Spacing.xs,
                        leading: AppTheme.Spacing.md,
                        bottom: AppTheme.Spacing.xs,
                        trailing: AppTheme.Spacing.md
                    )
                )
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.plain)
        #endif
        .hideScrollContentBackground()
    }
}

private enum StreamTagStyle {
    case hdr
    case video
    case audio

    var foreground: Color {
        switch self {
        case .hdr: return Color(hex: "#FDE68A")
        case .video: return AppTheme.Colors.elementSubtle
        case .audio: return Color(hex: "#93C5FD")
        }
    }

    var background: Color {
        switch self {
        case .hdr: return Color(hex: "#FBBF24").opacity(0.14)
        case .video: return AppTheme.Colors.surface
        case .audio: return AppTheme.Colors.info.opacity(0.14)
        }
    }

    var border: Color {
        switch self {
        case .hdr: return Color(hex: "#FBBF24").opacity(0.35)
        case .video: return AppTheme.Colors.border
        case .audio: return AppTheme.Colors.info.opacity(0.35)
        }
    }
}

private struct StreamMetadataTag: View {
    let text: String
    let style: StreamTagStyle

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(style.background)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(style.border, lineWidth: 0.5)
            )
    }
}

struct StreamRow: View {
    let stream: VideoPlayerStream
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    init(stream: VideoPlayerStream, onTap: @escaping () -> Void) {
        self.stream = stream
        self.onTap = onTap
    }

    private var isUHD: Bool {
        stream.resolution.lowercased() == "4k"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                resolutionBadge

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
                        Label {
                            Text(stream.source)
                                .font(AppTheme.Typography.labelLarge)
                                .foregroundStyle(AppTheme.Colors.elementWhite)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.elementMuted)
                        }
                        .labelStyle(.titleAndIcon)

                        Spacer(minLength: AppTheme.Spacing.sm)

                        metadataSummary
                    }

                    if !stream.combinedVideoTags.isEmpty || !stream.combinedAudioTags.isEmpty {
                        tagRows
                    }

                    if let languages = stream.languageSummary {
                        Text(languages.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.elementPlaceholder)
                            .tracking(0.4)
                    }

                    if !stream.fileName.isEmpty {
                        Text(stream.fileName)
                            .font(AppTheme.Typography.bodySmall)
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementPlaceholder)
                    .padding(.top, 2)
            }
            .padding(AppTheme.Spacing.md)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
        #if os(iOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        #endif
    }

    private var resolutionBadge: some View {
        Text(stream.displayResolution)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(isUHD ? Color(hex: "#FDE68A") : AppTheme.Colors.elementWhite)
            .frame(minWidth: 52)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                    .fill(
                        isUHD
                            ? Color(hex: "#FBBF24").opacity(0.12)
                            : AppTheme.Colors.surface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                    .strokeBorder(
                        isUHD
                            ? Color(hex: "#FBBF24").opacity(0.4)
                            : AppTheme.Colors.border,
                        lineWidth: 1
                    )
            )
    }

    @ViewBuilder
    private var metadataSummary: some View {
        HStack(spacing: 4) {
            if !stream.quality.isEmpty {
                Text(stream.quality.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
            }
            if let size = stream.formattedFileSize {
                if !stream.quality.isEmpty {
                    Text("·")
                        .foregroundStyle(AppTheme.Colors.elementPlaceholder)
                }
                Text(size)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
            }
        }
    }

    @ViewBuilder
    private var tagRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !stream.combinedVideoTags.isEmpty {
                tagRow(tags: stream.combinedVideoTags, style: .video, hdrTags: Set(stream.hdrTags.map { $0.lowercased() }))
            }
            if !stream.combinedAudioTags.isEmpty {
                tagRow(tags: stream.combinedAudioTags, style: .audio, hdrTags: [])
            }
        }
    }

    private func tagRow(tags: [String], style: StreamTagStyle, hdrTags: Set<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    let tagStyle: StreamTagStyle =
                        hdrTags.contains(tag.lowercased()) ? .hdr : style
                    StreamMetadataTag(text: tag, style: tagStyle)
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
            .fill(
                isHovered || isPressed
                    ? AppTheme.Colors.surfaceHovered
                    : AppTheme.Colors.backgroundTertiary
            )
    }

    private var cardBorder: Color {
        if isHovered || isPressed {
            return AppTheme.Colors.borderStrong
        }
        return AppTheme.Colors.border
    }
}

private struct SeasonEpisodeSection: View {
    let seasons: [Season]
    let seriesVm: SeriesViewModel
    let isMobile: Bool

    @State private var showStreamSheet: Bool = false

    private var selectedSeasonIndex: Int {
        seasons.firstIndex(where: { $0.seasonNumber == seriesVm.selectedSeason }) ?? 0
    }

    private var currentSeason: Season? {
        guard selectedSeasonIndex >= 0, selectedSeasonIndex < seasons.count
        else { return nil }
        return seasons[selectedSeasonIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // ── Season Picker ──
            seasonPicker

            // ── Episode Carousel ──
            if let season = currentSeason, !season.episodes.isEmpty {
                episodeCarousel(
                    episodes: season.episodes,
                    seasonNumber: season.seasonNumber
                )
            }
        }
        .sheet(isPresented: $showStreamSheet) {
            StreamSheet(
                state: seriesVm.episodeStreamState,
                streamVm: seriesVm
            )
            .streamSheetPresentationChrome()
        }
    }

    private var seasonPicker: some View {
        Menu {
            ForEach(Array(seasons.enumerated()), id: \.offset) {
                index,
                season in
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
                Text(
                    currentSeason?.name
                        ?? "Season \(currentSeason?.seasonNumber ?? 1)"
                )
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Colors.elementWhite)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(
                    cornerRadius: AppTheme.Radius.sm,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Radius.sm,
                        style: .continuous
                    )
                    .strokeBorder(AppTheme.Colors.border, lineWidth: 1)
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func episodeCarousel(episodes: [Episode], seasonNumber: Int)
        -> some View
    {
        let spacing: CGFloat = isMobile ? 14 : 18
        let minCardWidth: CGFloat = isMobile ? 260 : 340
        let columns = [
            GridItem(
                .adaptive(minimum: minCardWidth),
                spacing: spacing,
                alignment: .top
            ),
        ]
        return LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: spacing
        ) {
            ForEach(Array(episodes.enumerated()), id: \.offset) { _, episode in
                let progressKey =
                    "\(seriesVm.id):\(seasonNumber):\(episode.episodeNumber)"
                EpisodeCard(
                    episode: episode,
                    seasonNumber: seasonNumber,
                    tmdbShowId: seriesVm.id,
                    isMobile: isMobile,
                    progress: seriesVm.progressState[progressKey],
                    onTap: {
                        loadStreamsAndShow(
                            seasonNumber: seasonNumber,
                            episodeNumber: episode.episodeNumber
                        )
                    },
                    onMarkWatched: { mediaId in
                        Task {
                            await seriesVm.markWatched(mediaId: mediaId)
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 2)
    }

    private func loadStreamsAndShow(seasonNumber: Int, episodeNumber: Int) {
        seriesVm.onEpisodeSelect(
            season: seasonNumber,
            episode: episodeNumber
        )
        showStreamSheet = true
    }
}

private struct EpisodeCard: View {
    let episode: Episode
    let seasonNumber: Int
    let tmdbShowId: Int
    let isMobile: Bool
    let progress: WatchProgress?
    let onTap: () -> Void
    let onMarkWatched: (String) -> Void

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
        guard let airDate = episode.airDate, !airDate.isEmpty else {
            return nil
        }
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
                            url: MediaConfig.instance.stillURL(
                                stillPath,
                                width: "original"
                            )
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

                        Menu {
                            Button("Mark as watched") {
                                onMarkWatched(
                                    "\(tmdbShowId):\(seasonNumber):\(episode.episodeNumber)"
                                )
                            }
                            Button("Mark season as watched") {
                                onMarkWatched("\(tmdbShowId):\(seasonNumber)")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
            .clipShape(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
            )
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
    private func bottomFrostedOverlay(width: CGFloat, height: CGFloat)
        -> some View
    {
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
                            .strokeBorder(
                                Color.white.opacity(0.25),
                                lineWidth: 1
                            )
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
            LoadingSurfaceFill()
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

#if os(macOS)
    /// macOS: system navigation chrome is minimal or absent.
    /// These controls sit over the hero like the hidden navigation bar on iOS.
    struct MediaDetailMacTopBar: View {
        let showLibraryButton: Bool
        let isInLibrary: Bool
        let onBack: () -> Void
        let onLibrary: () -> Void

        var body: some View {
            HStack(spacing: AppTheme.Spacing.md) {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Back")

                Spacer(minLength: 0)

                if showLibraryButton {
                    Button(action: onLibrary) {
                        Image(
                            systemName: isInLibrary
                                ? "bookmark.fill" : "bookmark"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(isInLibrary ? "In Library" : "Add to Library")
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
    }
#endif
