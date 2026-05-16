//
//  HomeView.swift
//
//  Created by Harsh Kumar on 02/04/26.
//

import Foundation
import SwiftUI

private enum PosterMetrics {
    static let posterWidth: CGFloat = 130
    static let posterHeight: CGFloat = 195 // ~1.5:1 aspect ratio (TMDB poster)
    static let cornerRadius: CGFloat = 12
    static let titleLineLimit = 2
}

private enum CWMetrics {
    static let cardWidth: CGFloat = 300
    static let posterWidth: CGFloat = 100
    static let posterAspectRatio: CGFloat = 2.0 / 3.0 // portrait poster
    static var posterHeight: CGFloat {
        posterWidth / posterAspectRatio
    }

    static var cardHeight: CGFloat {
        posterHeight
    }

    static let cornerRadius: CGFloat = 10
    static let progressBarHeight: CGFloat = 4
    static let progressBarRadius: CGFloat = 2
}

struct HomeView: View {
    @State private var vm: HomeViewModel

    init(mediaUc: MediaUsecase, progressUc: ProgressUsecase) {
        _vm = State(
            wrappedValue: HomeViewModel(
                mediaUc: mediaUc,
                progressUc: progressUc
            )
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopBannerSection(state: vm.topBannerState).backgroundExtensionEffect()
                Spacer().frame(height: AppTheme.Spacing.lg)
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    ContinueWatchingSection(
                        state: vm.continueWatchingState,
                        onRemove: { item in
                            Task {
                                await vm.removeFromContinueWatching(item: item)
                            }
                        },
                        onMarkWatched: { item in
                            Task {
                                await vm.markContinueWatchingWatched(item: item)
                            }
                        }
                    )
                    ForEach(vm.discoveryItemState) { item in
                        DiscoveryRow(item: item) { media in
                            if media.type == "movie" {
                                Router.router.addToRoute(route: .movieDetails(media.id))
                            } else {
                                Router.router.addToRoute(route: .seriesDetails(media.id))
                            }
                        }
                        .onAppear {
                            if vm.startRowFetchIfNeeded(item: item) {
                                Task {
                                    await vm
                                        .getMediaAndUpdateItemState(
                                            item: item
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
        }
        .onChange(of: Router.router.mainRouteState) { old, new in
            guard let oldRoute = old.last else {
                return
            }

            let newRoute = new.last
            let returnedFromDetails: Bool
            switch oldRoute {
            case .movieDetails, .seriesDetails:
                returnedFromDetails = true
            default:
                returnedFromDetails = false
            }
            if newRoute == nil && returnedFromDetails {
                print("We came back from details page")
                Task {
                    await vm.initialiseContinueWatching()
                }
            }
        }
        .background(AppTheme.Colors.background).ignoresSafeArea(edges: .top)
    }
}

private struct ContinueWatchingSection: View {
    let state: ViewItemState<[ContinueWatchingItem]>
    let onRemove: (ContinueWatchingItem) -> Void
    let onMarkWatched: (ContinueWatchingItem) -> Void

    var body: some View {
        switch state {
        case .initial, .loading:
            ContinueWatchingShimmerRow()
        case let .loaded(items):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: 4) {
                        Text("Continue Watching")
                            .font(AppTheme.Typography.headingMedium)
                            .foregroundStyle(AppTheme.Colors.elementWhite)

                        Image(systemName: "chevron.forward")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: AppTheme.Spacing.sm + 2) {
                            ForEach(items, id: \.progress.mediaId) { item in
                                ContinueWatchingCard(
                                    item: item,
                                    onRemove: { onRemove(item) },
                                    onMarkWatched: { onMarkWatched(item) }
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.85),
                            value: items.map(\.progress.mediaId)
                        )
                    }
                }
            }
        case .error:
            EmptyView()
        }
    }
}

private struct ContinueWatchingCard: View {
    let item: ContinueWatchingItem
    let onRemove: () -> Void
    let onMarkWatched: () -> Void

    private var isShow: Bool {
        item.media.type == "show"
    }

    private var displayTitle: String {
        if isShow && !item.media.name.isEmpty { return item.media.name }
        if !item.media.title.isEmpty { return item.media.title }
        return item.media.originalTitle
    }

    /// Parse "tmdbId:season:episode" format for shows
    private var episodeInfo: (season: String, episode: String)? {
        guard isShow else { return nil }
        let parts = item.progress.mediaId.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        return (String(parts[1]), String(parts[2]))
    }

    /// Progress as 0…1
    private var progressFraction: Double {
        min(max(item.progress.progress / 100.0, 0), 1)
    }

    /// Progress percentage integer
    private var progressPercent: Int {
        Int(item.progress.progress.rounded())
    }

    /// Extract release year from releaseDate ("2025-03-15" → "2025")
    private var releaseYear: String? {
        guard let date = item.media.releaseDate, !date.isEmpty else {
            return nil
        }
        return String(date.prefix(4))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 0) {
                // ── Left: Poster thumbnail ─────────────────────
                AsyncImage(
                    url: MediaConfig.instance.posterURL(
                        item.media.posterPath
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
                .frame(
                    width: CWMetrics.posterWidth,
                    height: CWMetrics.posterHeight
                )
                .clipped()

                // ── Right: Info panel ──────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer().frame(height: 6)

                    // Subtitle lines
                    if let ep = episodeInfo {
                        // Show: Season + Episode
                        Text("Season \(ep.season)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.55))

                        Spacer().frame(height: 2)

                        Text("Episode \(ep.episode)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.55))
                    } else {
                        // Movie: Year • Movie
                        HStack(spacing: 0) {
                            if let year = releaseYear {
                                Text(year)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text(" · ")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.white.opacity(0.55))
                            }
                            Text("Movie")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                    }

                    Spacer()

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(
                                cornerRadius: CWMetrics.progressBarRadius,
                                style: .continuous
                            )
                            .fill(Color.white.opacity(0.2))
                            .frame(height: CWMetrics.progressBarHeight)

                            // Fill
                            RoundedRectangle(
                                cornerRadius: CWMetrics.progressBarRadius,
                                style: .continuous
                            )
                            .fill(Color.white)
                            .frame(
                                width: geo.size.width * progressFraction,
                                height: CWMetrics.progressBarHeight
                            )
                        }
                    }
                    .frame(height: CWMetrics.progressBarHeight)

                    Spacer().frame(height: 6)

                    HStack(spacing: 0) {
                        Text("\(progressPercent)% watched")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.45))
                        Spacer(minLength: 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .padding(.trailing, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: CWMetrics.cardWidth, height: CWMetrics.cardHeight)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: CWMetrics.cornerRadius,
                    style: .continuous
                )
            )
            .onTapGesture {
                Router.router.addToRoute(
                    route: !isShow
                        ? .movieDetails(item.media.id)
                        : .seriesDetails(item.media.id)
                )
            }

            Menu {
                Button("Remove from continue watching", role: .destructive) {
                    onRemove()
                }
                Button("Mark as watched") {
                    onMarkWatched()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
        }
        .frame(width: CWMetrics.cardWidth, height: CWMetrics.cardHeight)
        .background(AppTheme.Colors.backgroundTertiary)
        .clipShape(
            RoundedRectangle(
                cornerRadius: CWMetrics.cornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: CWMetrics.cornerRadius,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var posterPlaceholder: some View {
        ZStack {
            AppTheme.Colors.backgroundTertiary
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
    }
}

private struct ContinueWatchingShimmerRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Title shimmer
            ShimmerView()
                .frame(width: 160, height: 18)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                )
                .padding(.horizontal, AppTheme.Spacing.md)

            // Cards shimmer
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm + 2) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        HStack(spacing: 0) {
                            // Poster placeholder
                            ShimmerView()
                                .frame(
                                    width: CWMetrics.posterWidth,
                                    height: CWMetrics.posterHeight
                                )

                            // Info placeholder
                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {
                                // Title line
                                ShimmerView()
                                    .frame(width: 130, height: 14)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 3,
                                            style: .continuous
                                        )
                                    )

                                // Season line
                                ShimmerView()
                                    .frame(width: 80, height: 12)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 3,
                                            style: .continuous
                                        )
                                    )

                                // Episode line
                                ShimmerView()
                                    .frame(width: 70, height: 12)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 3,
                                            style: .continuous
                                        )
                                    )

                                Spacer()

                                // Progress bar
                                ShimmerView()
                                    .frame(height: 4)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 2,
                                            style: .continuous
                                        )
                                    )

                                // Percentage text
                                ShimmerView()
                                    .frame(width: 80, height: 10)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 3,
                                            style: .continuous
                                        )
                                    )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(
                            width: CWMetrics.cardWidth,
                            height: CWMetrics.cardHeight
                        )
                        .background(AppTheme.Colors.backgroundTertiary)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: CWMetrics.cornerRadius,
                                style: .continuous
                            )
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .scrollDisabled(true)
        }
    }
}

private struct DiscoveryRow: View {
    @Bindable var item: HomeViewDiscoveryItem
    let onTap: (AppMedia) -> Void
    private let stableContentHeight = PosterMetrics.posterHeight + 34

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // ── Section title ────────────────────────────────
            Text(item.name)
                .font(AppTheme.Typography.headingMedium)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .padding(.horizontal, AppTheme.Spacing.md)

            // ── Content based on state ───────────────────────
            switch item.state {
            case .initial, .loading:
                ShimmerRow()
                    .frame(height: stableContentHeight)
            case let .loaded(media):
                MediaRow(media: media) { item in
                    onTap(item)
                }
                .frame(height: stableContentHeight)
            case let .error(message):
                ErrorRow(message: message)
            }
        }
    }
}

private struct MediaRow: View {
    let media: [AppMedia]
    let onTap: (AppMedia) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: AppTheme.Spacing.sm + 2) {
                ForEach(media, id: \.id) { item in
                    PosterCard(media: item).onTapGesture {
                        onTap(item)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

private struct PosterCard: View {
    let media: AppMedia
    @State private var reloadToken = UUID()
    @State private var hasSuccessfulLoad = false

    /// TMDB uses `title` for movies and `name` for shows
    private var displayTitle: String {
        if !media.title.isEmpty { return media.title }
        if !media.name.isEmpty { return media.name }
        return media.originalTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs + 2) {
            // ── Poster image ─────────────────────────────────
            AsyncImage(url: posterURL) {
                phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .onAppear {
                            hasSuccessfulLoad = true
                        }
                case .failure:
                    posterPlaceholder
                case .empty:
                    posterShimmer
                @unknown default:
                    posterPlaceholder
                }
            }
            .id(reloadToken)
            .frame(
                width: PosterMetrics.posterWidth,
                height: PosterMetrics.posterHeight
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PosterMetrics.cornerRadius,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: PosterMetrics.cornerRadius,
                    style: .continuous
                )
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
            )
            .shadow(color: AppTheme.Shadows.card, radius: 8, x: 0, y: 4)

            // ── Title label ──────────────────────────────────
            Text(displayTitle)
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .lineLimit(PosterMetrics.titleLineLimit)
                .frame(width: PosterMetrics.posterWidth, alignment: .leading)
        }
        .onAppear {
            if !hasSuccessfulLoad {
                reloadToken = UUID()
            }
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            AppTheme.Colors.backgroundTertiary
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
    }

    private var posterShimmer: some View {
        ShimmerView()
    }

    private var posterURL: URL? {
        MediaConfig.instance.posterURL(media.posterPath)
    }
}

private struct ShimmerRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm + 2) {
                ForEach(0 ..< 6, id: \.self) { _ in
                    VStack(
                        alignment: .leading,
                        spacing: AppTheme.Spacing.xs + 2
                    ) {
                        ShimmerView()
                            .frame(
                                width: PosterMetrics.posterWidth,
                                height: PosterMetrics.posterHeight
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: PosterMetrics.cornerRadius,
                                    style: .continuous
                                )
                            )

                        ShimmerView()
                            .frame(
                                width: PosterMetrics.posterWidth * 0.7,
                                height: 12
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 4,
                                    style: .continuous
                                )
                            )
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .scrollDisabled(true)
    }
}

private struct ErrorRow: View {
    let message: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.Colors.error)
            Text(message)
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .lineLimit(1)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            AppTheme.Colors.errorSurface
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Radius.sm,
                        style: .continuous
                    )
                )
        )
        .padding(.horizontal, AppTheme.Spacing.md)
    }
}
