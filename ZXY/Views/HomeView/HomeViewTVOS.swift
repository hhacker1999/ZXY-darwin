//
//  HomeViewTVOS.swift
//
//  tvOS-native Home — full-bleed pinned banner driven by shelf focus,
//  shelves scroll underneath the fixed banner layer.
//

#if os(tvOS)

import Foundation
import SwiftUI

// MARK: - Layout Constants

private enum TVOSLayout {
    static let cornerRadius: CGFloat = 16
    static let shelfHorizontalInset: CGFloat = 80
    /// Fraction of screen height for the pinned banner.
    static let bannerHeightFraction: CGFloat = 0.58

    static let posterCardWidth: CGFloat = 210
    static let posterCardHeight: CGFloat = 315
    /// Fixed row height — prevents focus scale from shifting layout or clipping titles.
    static let posterShelfHeight: CGFloat = 368

    static let continueWatchingCardWidth: CGFloat = 460
    static let continueWatchingCardHeight: CGFloat = 240
    static let continueWatchingShelfHeight: CGFloat = 288
    static let continueWatchingPosterWidth: CGFloat = 160
}

// MARK: - Focus Identity

/// Section + media ID — required because the same title can appear in
/// Continue Watching and a discovery row; media ID alone is ambiguous.
private struct TVOSFocusedItem: Hashable {
    let sectionID: String
    let mediaID: Int
}

// MARK: - tvOS Home View

struct HomeViewTVOS: View {
    @Bindable var vm: HomeViewModel

    @State private var featuredMedia: AppMedia?
    @FocusState private var focusedItem: TVOSFocusedItem?
    @State private var focusedSectionID: String?

    var body: some View {
        GeometryReader { geo in
            let bannerHeight = geo.size.height * TVOSLayout.bannerHeightFraction

            VStack(spacing: 0) {
                TVOSTopBanner(media: featuredMedia, height: bannerHeight)

                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 48) {
                            TVOSContinueWatchingShelf(
                                state: vm.continueWatchingState,
                                sectionID: TVOSShelfSectionID.continueWatching,
                                focusedItem: $focusedItem,
                                onRemove: { item in
                                    Task { await vm.removeFromContinueWatching(item: item) }
                                },
                                onMarkWatched: { item in
                                    Task { await vm.markContinueWatchingWatched(item: item) }
                                }
                            )
                            .id(TVOSShelfSectionID.continueWatching)

                            ForEach(Array(vm.discoveryItemState.enumerated()), id: \.element.id) { index, item in
                                TVOSDiscoveryShelf(
                                    item: item,
                                    sectionID: TVOSShelfSectionID.discovery(item.id),
                                    focusedItem: $focusedItem,
                                    isFirstFocusableShelf: isContinueWatchingEmpty && index == 0
                                )
                                .id(TVOSShelfSectionID.discovery(item.id))
                                .onAppear {
                                    if vm.startRowFetchIfNeeded(item: item) {
                                        Task {
                                            await vm.getMediaAndUpdateItemState(item: item)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 80)
                    }
                    .background(AppTheme.Colors.background)
                    .onChange(of: focusedItem) { _, newItem in
                        guard let newItem else { return }
                        if let media = mediaForID(newItem.mediaID) {
                            updateFeatured(media)
                        }
                        guard newItem.sectionID != focusedSectionID else { return }
                        focusedSectionID = newItem.sectionID
                        withAnimation(.easeInOut(duration: 0.25)) {
                            scrollProxy.scrollTo(newItem.sectionID, anchor: .top)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .task {
            await vm.initialise(loadTopBanner: false)
        }
        .task(id: bootstrapToken) {
            bootstrapFeaturedMedia()
        }
        .onChange(of: Router.router.mainRouteState) { old, new in
            guard let oldRoute = old.last else { return }
            let newRoute = new.last
            let returnedFromDetails: Bool
            switch oldRoute {
            case .movieDetails, .seriesDetails:
                returnedFromDetails = true
            default:
                returnedFromDetails = false
            }
            if newRoute == nil && returnedFromDetails {
                Task { await vm.initialiseContinueWatching() }
            }
        }
    }

    private var isContinueWatchingEmpty: Bool {
        switch vm.continueWatchingState {
        case let .loaded(items):
            return items.isEmpty
        case .error:
            return true
        default:
            return false
        }
    }

    private var bootstrapToken: String {
        let cwToken: String = switch vm.continueWatchingState {
        case .initial: "cw-init"
        case .loading: "cw-loading"
        case let .loaded(items): "cw-\(items.count)"
        case .error: "cw-error"
        }
        let discoveryToken = vm.discoveryItemState.map { row in
            switch row.state {
            case .initial: "init"
            case .loading: "loading"
            case let .loaded(media): "loaded-\(media.count)"
            case .error: "error"
            }
        }.joined(separator: "|")
        return "\(cwToken)::\(discoveryToken)"
    }

    private func bootstrapFeaturedMedia() {
        guard featuredMedia == nil else { return }

        switch vm.continueWatchingState {
        case .initial, .loading:
            return
        case let .loaded(items):
            if let first = items.first {
                applyFeatured(first.media, sectionID: TVOSShelfSectionID.continueWatching)
                return
            }
        case .error:
            break
        }

        for row in vm.discoveryItemState {
            if case let .loaded(media) = row.state, let first = media.first {
                applyFeatured(first, sectionID: TVOSShelfSectionID.discovery(row.id))
                return
            }
        }
    }

    private func applyFeatured(_ media: AppMedia, sectionID: String) {
        featuredMedia = media
        focusedItem = TVOSFocusedItem(sectionID: sectionID, mediaID: media.id)
        focusedSectionID = sectionID
    }

    private func updateFeatured(_ media: AppMedia) {
        guard media.id != featuredMedia?.id else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            featuredMedia = media
        }
    }

    private func mediaForID(_ id: Int) -> AppMedia? {
        if case let .loaded(items) = vm.continueWatchingState {
            if let match = items.first(where: { $0.media.id == id }) {
                return match.media
            }
        }
        for row in vm.discoveryItemState {
            if case let .loaded(media) = row.state,
               let match = media.first(where: { $0.id == id })
            {
                return match
            }
        }
        return nil
    }
}

// MARK: - Shelf Section IDs

private enum TVOSShelfSectionID {
    static let continueWatching = "shelf-continue-watching"

    static func discovery(_ id: UUID) -> String {
        "shelf-discovery-\(id.uuidString)"
    }
}

// MARK: - Pinned Top Banner

private struct TVOSTopBanner: View {
    let media: AppMedia?
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            TVOSFocusBackdrop(media: media)

            TVOSFocusHeroDetails(media: media)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.background)
        .clipped()
    }
}

// MARK: - Focus Backdrop

private struct TVOSFocusBackdrop: View {
    let media: AppMedia?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let media {
                    BlocAsyncImage(
                        id: media.backdropPath,
                        size: "original",
                        setGradientFromImage: SettingsBloc.bloc.enableGradient
                    ) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        case .failure:
                            backdropFallback
                        case .empty:
                            ShimmerView()
                        @unknown default:
                            backdropFallback
                        }
                    }
                    .id(media.id)
                    .animation(.easeInOut(duration: 0.3), value: media.id)
                } else {
                    backdropFallback
                }

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: Color.black.opacity(0.55), location: 0.7),
                        .init(color: AppTheme.Colors.background, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.65), location: 0.0),
                        .init(color: Color.black.opacity(0.3), location: 0.5),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private var backdropFallback: some View {
        AppTheme.Colors.background
    }
}

// MARK: - Focus Hero Details

private struct TVOSFocusHeroDetails: View {
    let media: AppMedia?

    var body: some View {
        Group {
            if let media {
                heroContent(media)
                    .id(media.id)
            } else {
                heroPlaceholder
            }
        }
        .animation(.easeInOut(duration: 0.3), value: media?.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, TVOSLayout.shelfHorizontalInset)
        .padding(.bottom, 32)
    }

    private var heroPlaceholder: some View {
        VStack(alignment: .leading, spacing: 16) {
            ShimmerView()
                .frame(width: 400, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            ShimmerView()
                .frame(width: 280, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    @ViewBuilder
    private func heroContent(_ media: AppMedia) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerTitleBlock(media)
            Spacer().frame(height: 12)
            Text(TVOSMediaDisplay.metadataLine(for: media))
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))
                .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
            Spacer().frame(height: 14)
            Text(media.overview)
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(3)
                .lineSpacing(4)
                .frame(maxWidth: 760, alignment: .leading)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func headerTitleBlock(_ media: AppMedia) -> some View {
        let displayTitle = TVOSMediaDisplay.title(for: media)
        if let logoPath = TVOSMediaDisplay.logoPath(for: media), !logoPath.isEmpty {
            BlocAsyncImage(id: logoPath, size: "w500") { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 500, maxHeight: 110, alignment: .leading)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
                default:
                    titleFallback(displayTitle)
                }
            }
            .frame(maxWidth: 500, maxHeight: 110, alignment: .leading)
        } else {
            titleFallback(displayTitle)
        }
    }

    private func titleFallback(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .shadow(color: .black.opacity(0.85), radius: 6, x: 0, y: 3)
            .frame(maxWidth: 680, alignment: .leading)
    }
}

// MARK: - Media Display Helpers

private enum TVOSMediaDisplay {
    static func title(for media: AppMedia) -> String {
        let isShow = media.type == "show"
        if isShow && !media.name.isEmpty { return media.name }
        if !media.title.isEmpty { return media.title }
        return media.originalTitle
    }

    static func logoPath(for media: AppMedia) -> String? {
        guard let logos = media.images.logos else { return nil }
        let eng = logos.first { $0.iso639_1 == "en" }
        return eng?.filePath ?? logos.first?.filePath
    }

    static func metadataLine(for media: AppMedia) -> String {
        let isShow = media.type == "show"
        var parts: [String] = [isShow ? "TV Show" : "Movie"]

        if let year = releaseYear(for: media) {
            parts.append(year)
        }

        let genreMap = isShow
            ? MediaConfig.instance.showGenres
            : MediaConfig.instance.movieGenres
        let genreNames: [String] = (media.genreIds ?? [])
            .prefix(3)
            .compactMap { genreMap[$0]?.name }
        parts.append(contentsOf: genreNames)

        if media.voteAverage > 0 {
            parts.append(String(format: "★ %.1f", media.voteAverage))
        }

        return parts.joined(separator: " · ")
    }

    private static func releaseYear(for media: AppMedia) -> String? {
        guard let date = media.releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}

// MARK: - Continue Watching Shelf

private struct TVOSContinueWatchingShelf: View {
    let state: ViewItemState<[ContinueWatchingItem]>
    let sectionID: String
    var focusedItem: FocusState<TVOSFocusedItem?>.Binding
    let onRemove: (ContinueWatchingItem) -> Void
    let onMarkWatched: (ContinueWatchingItem) -> Void

    var body: some View {
        switch state {
        case .initial, .loading:
            TVOSSectionShimmer(
                title: "Continue Watching",
                shelfHeight: TVOSLayout.continueWatchingShelfHeight,
                cardWidth: TVOSLayout.continueWatchingCardWidth,
                cardHeight: TVOSLayout.continueWatchingCardHeight
            )
        case let .loaded(items):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    TVOSSectionTitle(title: "Continue Watching")

                    TVOSHorizontalShelf(height: TVOSLayout.continueWatchingShelfHeight) {
                        ForEach(Array(items.enumerated()), id: \.element.progress.mediaId) { index, item in
                            TVOSContinueWatchingCard(
                                item: item,
                                sectionID: sectionID,
                                focusedItem: focusedItem,
                                isDefaultFocus: index == 0,
                                onRemove: { onRemove(item) },
                                onMarkWatched: { onMarkWatched(item) }
                            )
                        }
                    }
                }
                .focusSection()
            }
        case .error:
            EmptyView()
        }
    }
}

private struct TVOSContinueWatchingCard: View {
    let item: ContinueWatchingItem
    let sectionID: String
    var focusedItem: FocusState<TVOSFocusedItem?>.Binding
    let isDefaultFocus: Bool
    let onRemove: () -> Void
    let onMarkWatched: () -> Void

    @Environment(\.isFocused) private var isFocused

    private var focusIdentity: TVOSFocusedItem {
        TVOSFocusedItem(sectionID: sectionID, mediaID: item.media.id)
    }

    private var isShow: Bool { item.media.type == "show" }

    private var displayTitle: String {
        TVOSMediaDisplay.title(for: item.media)
    }

    private var episodeInfo: (season: String, episode: String)? {
        guard isShow else { return nil }
        let parts = item.progress.mediaId.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        return (String(parts[1]), String(parts[2]))
    }

    private var progressFraction: Double {
        min(max(item.progress.progress / 100.0, 0), 1)
    }

    private var progressPercent: Int {
        Int(item.progress.progress.rounded())
    }

    private let cardWidth: CGFloat = TVOSLayout.continueWatchingCardWidth
    private let posterWidth: CGFloat = TVOSLayout.continueWatchingPosterWidth
    private let cardHeight: CGFloat = TVOSLayout.continueWatchingCardHeight

    var body: some View {
        Button {
            Router.router.addToRoute(
                route: !isShow
                    ? .movieDetails(item.media.id)
                    : .seriesDetails(item.media.id)
            )
        } label: {
            HStack(spacing: 0) {
                AsyncImage(
                    url: MediaConfig.instance.posterURL(item.media.posterPath)
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
                .frame(width: posterWidth, height: cardHeight)
                .clipped()

                VStack(alignment: .leading, spacing: 0) {
                    Text(displayTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    Spacer().frame(height: 10)

                    if let ep = episodeInfo {
                        Text("S\(ep.season) · E\(ep.episode)")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.55))
                    } else {
                        Text("Movie")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }

                    Spacer()

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 5)
                            Capsule(style: .continuous)
                                .fill(Color.white)
                                .frame(
                                    width: geo.size.width * progressFraction,
                                    height: 5
                                )
                        }
                    }
                    .frame(height: 5)

                    Spacer().frame(height: 10)

                    Text("\(progressPercent)% watched")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: TVOSLayout.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isFocused ? 0.14 : 0.08))
            )
        }
        .buttonStyle(.card)
        .focused(focusedItem, equals: focusIdentity)
        .applyIf(isDefaultFocus) { view in
            view.defaultFocus(focusedItem, focusIdentity)
        }
        .contextMenu {
            Button("Mark as watched") { onMarkWatched() }
            Button("Remove from continue watching", role: .destructive) { onRemove() }
        }
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

// MARK: - Discovery Shelf

private struct TVOSDiscoveryShelf: View {
    let item: HomeViewDiscoveryItem
    let sectionID: String
    var focusedItem: FocusState<TVOSFocusedItem?>.Binding
    let isFirstFocusableShelf: Bool

    var body: some View {
        switch item.state {
        case .initial, .loading:
            TVOSSectionShimmer(
                title: item.name,
                shelfHeight: TVOSLayout.posterShelfHeight,
                cardWidth: TVOSLayout.posterCardWidth,
                cardHeight: TVOSLayout.posterCardHeight
            )
        case let .loaded(media):
            TVOSShelfSection(
                title: item.name,
                media: media,
                sectionID: sectionID,
                focusedItem: focusedItem,
                isFirstShelf: isFirstFocusableShelf
            )
        case let .error(message):
            MediaShelfErrorRow(message: message)
                .padding(.horizontal, TVOSLayout.shelfHorizontalInset)
        }
    }
}

// MARK: - Generic Shelf Section

private struct TVOSShelfSection: View {
    let title: String
    let media: [AppMedia]
    let sectionID: String
    var focusedItem: FocusState<TVOSFocusedItem?>.Binding
    var isFirstShelf: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TVOSSectionTitle(title: title)

            TVOSHorizontalShelf(height: TVOSLayout.posterShelfHeight) {
                ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                    TVOSPosterCard(
                        media: item,
                        sectionID: sectionID,
                        focusedItem: focusedItem,
                        isDefaultFocus: isFirstShelf && index == 0
                    )
                }
            }
        }
        .focusSection()
    }
}

// MARK: - Horizontal Shelf Container

private struct TVOSHorizontalShelf<Content: View>: View {
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: 32) {
                content()
            }
            .padding(.horizontal, TVOSLayout.shelfHorizontalInset)
        }
        .frame(height: height)
        .scrollClipDisabled()
    }
}

// MARK: - Section Title

private struct TVOSSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 38, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, TVOSLayout.shelfHorizontalInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Poster Card

private struct TVOSPosterCard: View {
    let media: AppMedia
    let sectionID: String
    var focusedItem: FocusState<TVOSFocusedItem?>.Binding
    let isDefaultFocus: Bool

    private var focusIdentity: TVOSFocusedItem {
        TVOSFocusedItem(sectionID: sectionID, mediaID: media.id)
    }

    var body: some View {
        Button {
            MediaShelfNavigation.openDetails(for: media)
        } label: {
            posterImage
                .frame(width: TVOSLayout.posterCardWidth, height: TVOSLayout.posterCardHeight)
                .clipShape(
                    RoundedRectangle(cornerRadius: TVOSLayout.cornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.card)
        .focused(focusedItem, equals: focusIdentity)
        .applyIf(isDefaultFocus) { view in
            view.defaultFocus(focusedItem, focusIdentity)
        }
    }

    @ViewBuilder
    private var posterImage: some View {
        AsyncImage(url: MediaConfig.instance.posterURL(media.posterPath)) { phase in
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
    }

    private var posterPlaceholder: some View {
        ZStack {
            LoadingSurfaceFill()
            Image(systemName: "film")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
    }
}

// MARK: - Section Shimmer

private struct TVOSSectionShimmer: View {
    let title: String
    let shelfHeight: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TVOSSectionTitle(title: title)

            TVOSHorizontalShelf(height: shelfHeight) {
                ForEach(0..<6, id: \.self) { _ in
                    ShimmerView()
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(
                            RoundedRectangle(cornerRadius: TVOSLayout.cornerRadius, style: .continuous)
                        )
                }
            }
        }
    }
}

// MARK: - Conditional View Modifier

private extension View {
    @ViewBuilder
    func applyIf(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#endif
