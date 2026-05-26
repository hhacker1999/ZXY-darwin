//
//  HomeView.swift
//
//  Created by Harsh Kumar on 02/04/26.
//

import Foundation
import SwiftUI

struct HomeView: View {
    @Binding private var vm: HomeViewModel

    init(vm: Binding<HomeViewModel>) {
        _vm =
            vm
    }

    var body: some View {
        #if os(iOS)
            IOSAmbientTabScreen {
                homeScrollContent
            }
            .homeHeroScrollEdgeInsets()
            .onChange(of: Router.router.mainRouteState) { old, new in
                handleMainRouteChange(old: old, new: new)
            }
        #else
            homeScrollContent
                .homeHeroScrollEdgeInsets()
                .onChange(of: Router.router.mainRouteState) { old, new in
                    handleMainRouteChange(old: old, new: new)
                }
        #endif
    }

    private var homeScrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopBannerSection(
                    state: vm.topBannerState,
                    onActiveMediaChange: { _ in
                        Task {}
                    }
                )
                #if os(macOS)
                .backgroundExtensionEffect()
                #endif
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
        .task {
            Task { await vm.initialise() }
        }
        .hideScrollContentBackground()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleMainRouteChange(old: [Route], new: [Route]) {
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
            Task {
                await vm.initialiseContinueWatching()
            }
        }
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
                            .font(AppTheme.MediaLibrary.sectionHeaderFont)
                            .foregroundStyle(AppTheme.Colors.elementWhite)

                        Image(systemName: "chevron.forward")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: AppTheme.MediaLibrary.shelfRowItemSpacing) {
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

    @State private var isMenuHovered = false

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
        cardContent
            .frame(
                width: AppTheme.MediaLibrary.cwCardWidth,
                height: AppTheme.MediaLibrary.cwCardHeight
            )
            .background { LoadingSurfaceFill() }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppTheme.MediaLibrary.cwCornerRadius,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: AppTheme.MediaLibrary.cwCornerRadius,
                    style: .continuous
                )
                .stroke(
                    AppTheme.MediaLibrary.shelfPosterBorderColor,
                    lineWidth: 1
                )
            )
    }

    private var cardContent: some View {
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
                width: AppTheme.MediaLibrary.cwPosterWidth,
                height: AppTheme.MediaLibrary.cwPosterHeight
            )
            .clipped()

            // ── Right: Info panel ──────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(displayTitle)
                    .font(AppTheme.MediaLibrary.cwTitleFont)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer().frame(height: 6)

                // Subtitle lines
                if let ep = episodeInfo {
                    // Show: Season + Episode
                    Text("Season \(ep.season)")
                        .font(AppTheme.MediaLibrary.cwSubtitleFont)
                        .foregroundStyle(Color.white.opacity(0.55))

                    Spacer().frame(height: 2)

                    Text("Episode \(ep.episode)")
                        .font(AppTheme.MediaLibrary.cwSubtitleFont)
                        .foregroundStyle(Color.white.opacity(0.55))
                } else {
                    // Movie: Year • Movie
                    HStack(spacing: 0) {
                        if let year = releaseYear {
                            Text(year)
                                .font(AppTheme.MediaLibrary.cwSubtitleFont)
                                .foregroundStyle(Color.white.opacity(0.55))
                            Text(" · ")
                                .font(AppTheme.MediaLibrary.cwSubtitleFont)
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        Text("Movie")
                            .font(AppTheme.MediaLibrary.cwSubtitleFont)
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }

                Spacer()

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(
                            cornerRadius: AppTheme.MediaLibrary.cwProgressBarRadius,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.2))
                        .frame(height: AppTheme.MediaLibrary.cwProgressBarHeight)

                        // Fill
                        RoundedRectangle(
                            cornerRadius: AppTheme.MediaLibrary.cwProgressBarRadius,
                            style: .continuous
                        )
                        .fill(Color.white)
                        .frame(
                            width: geo.size.width * progressFraction,
                            height: AppTheme.MediaLibrary.cwProgressBarHeight
                        )
                    }
                }
                .frame(height: AppTheme.MediaLibrary.cwProgressBarHeight)

                Spacer().frame(height: 6)

                HStack(alignment: .center, spacing: 8) {
                    Text("\(progressPercent)% watched")
                        .font(AppTheme.MediaLibrary.cwPercentFont)
                        .foregroundStyle(Color.white.opacity(0.45))

                    Spacer(minLength: 0)

                    continueWatchingMenu
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(
            width: AppTheme.MediaLibrary.cwCardWidth,
            height: AppTheme.MediaLibrary.cwCardHeight
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: AppTheme.MediaLibrary.cwCornerRadius,
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
    }

    private var continueWatchingMenu: some View {
        Menu {
            Button("Mark as watched") {
                onMarkWatched()
            }
            Button("Remove from continue watching", role: .destructive) {
                onRemove()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(isMenuHovered ? 0.85 : 0.55))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(macOS)
            .menuStyle(.borderlessButton)
            .onHover { isMenuHovered = $0 }
        #endif
    }

    private var posterPlaceholder: some View {
        ZStack {
            LoadingSurfaceFill()
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
                .frame(
                    width: AppTheme.MediaLibrary.sectionTitleShimmerWidth,
                    height: AppTheme.MediaLibrary.sectionTitleShimmerHeight
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 4,
                        style: .continuous
                    )
                )
                .padding(.horizontal, AppTheme.Spacing.md)

            // Cards shimmer
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.MediaLibrary.shelfRowItemSpacing) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        HStack(spacing: 0) {
                            // Poster placeholder
                            ShimmerView()
                                .frame(
                                    width: AppTheme.MediaLibrary.cwPosterWidth,
                                    height: AppTheme.MediaLibrary.cwPosterHeight
                                )

                            // Info placeholder
                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {
                                // Title line
                                ShimmerView()
                                    .frame(
                                        width: AppTheme.MediaLibrary.cwShimmerInnerTitleWidth,
                                        height: 14
                                    )
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
                            width: AppTheme.MediaLibrary.cwCardWidth,
                            height: AppTheme.MediaLibrary.cwCardHeight
                        )
                        .background { LoadingSurfaceFill() }
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: AppTheme.MediaLibrary.cwCornerRadius,
                                style: .continuous
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: AppTheme.MediaLibrary.cwCornerRadius,
                                style: .continuous
                            )
                            .stroke(
                                AppTheme.MediaLibrary.shelfPosterBorderColor,
                                lineWidth: 1
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
    private let stableContentHeight = AppTheme.MediaLibrary.shelfRowStableHeight

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // ── Section title ────────────────────────────────
            Text(item.name)
                .font(AppTheme.MediaLibrary.sectionHeaderFont)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .padding(.horizontal, AppTheme.Spacing.md)

            // ── Content based on state ───────────────────────
            switch item.state {
            case .initial, .loading:
                MediaShelfShimmerRow()
                    .frame(height: stableContentHeight)
            case let .loaded(media):
                MediaShelfRow(media: media) { item in
                    onTap(item)
                }
                .frame(height: stableContentHeight)
            case let .error(message):
                MediaShelfErrorRow(message: message)
            }
        }
    }
}
