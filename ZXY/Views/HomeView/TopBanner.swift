//
//  TopBanner.swift
//
//  Created by Harsh Kumar on 05/04/26.
//

import Foundation
import Inject
import SwiftUI

struct TopBannerSection: View {
    @ObserveInjection var inject
    let state: ViewItemState<[AppMedia]>

    var body: some View {
        switch state {
        case .initial, .loading:
            TopBannerShimmer()
        case let .loaded(items):
            if !items.isEmpty {
                TopBannerCarousel(items: items)
                    .enableInjection()
            }
        case .error:
            EmptyView()
        }
    }
}

private struct TopBannerCarousel: View {
    let items: [AppMedia]
    @State private var scrolledIndex: Int? = 0
    /// Mirrors `scrolledIndex` but never goes back to nil during scroll
    /// gestures, so UI (like the mute button) doesn't flicker.
    @State private var stableActiveIndex: Int = 0
    @State private var isGestureActive: Bool = false

    private let aspectRatio: CGFloat = {
        #if os(iOS)
            return 0.64
        #else
            return 1.78
        #endif
    }()

    /// True if any banner slide has a YouTube trailer available.
    /// Used to decide whether to show the mute button at all.
    private var anySlideHasTrailer: Bool {
        items.contains { $0.videos.youtubeTrailerKey != nil }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BannerSlide(
                media: items[stableActiveIndex],
                aspectRatio: aspectRatio
            )
            .id(stableActiveIndex)
            .onTapGesture {
                Router.router.addToRoute(
                    route: items[stableActiveIndex].type == "movie" ?
                        .movieDetails(items[stableActiveIndex].id) :
                        .seriesDetails(items[stableActiveIndex].id)
                )
            }
            .transition(
                .opacity
            )
            .aspectRatio(aspectRatio, contentMode: .fit)
        }
        #if os(macOS)
        .onTrackpadSwipe(onSwipe: { event in
            if event.phase == .began {
                isGestureActive = true
            }

            if isGestureActive && event.phase == .changed {
                let offset = event.scrollingDeltaX

                if offset > 15 {
                    isGestureActive = false
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if stableActiveIndex == 0 {
                            stableActiveIndex = items.count - 1
                        } else {
                            stableActiveIndex -= 1
                        }
                    }
                }

                if offset < -15 {
                    isGestureActive = false
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if stableActiveIndex == items.count - 1 {
                            stableActiveIndex = 0
                        } else {
                            stableActiveIndex += 1
                        }
                    }
                }
            }

            if event.phase == .ended || event.phase == .cancelled {
                isGestureActive = false
            }

        })
        #endif
        .contentShape(Rectangle())
    }
}

private struct MuteToggleButton: View {
    @Binding var isMuted: Bool

    private let buttonSize: CGFloat = 44
    private let iconSize: CGFloat = 18

    var body: some View {
        Button {
            isMuted.toggle()
        } label: {
            Image(
                systemName: isMuted
                    ? "speaker.slash.fill"
                    : "speaker.wave.2.fill"
            )
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: buttonSize, height: buttonSize)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.5))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isMuted ? "Unmute trailer" : "Mute trailer")
    }
}

private struct BannerSlide: View {
    let media: AppMedia
    let aspectRatio: Double

    private var isShow: Bool {
        media.type == "show"
    }

    private var displayTitle: String {
        if isShow && !media.name.isEmpty { return media.name }
        if !media.title.isEmpty { return media.title }
        return media.originalTitle
    }

    /// Get the first available English logo, or any logo
    private var logoPath: String? {
        guard let logos = media.images.logos else {
            return nil
        }
        // Prefer English logo
        let englishLogo = logos.first { $0.iso639_1 == "en" }
        if let logo = englishLogo { return logo.filePath }
        // Fallback to any logo
        return logos.first?.filePath
    }

    /// Genre names from MediaConfig lookup
    private var genreNames: [String] {
        let genreMap =
            isShow
                ? MediaConfig.instance.showGenres
                : MediaConfig.instance.movieGenres
        guard let genreIds = media.genreIds else {
            return []
        }
        return
            genreIds
                .prefix(3)
                .compactMap { genreMap[$0]?.name }
    }

    /// Type + genres info line: "TV Show · Thriller · Drama"
    private var infoLine: String {
        var parts: [String] = []
        parts.append(isShow ? "TV Show" : "Movie")
        parts.append(contentsOf: genreNames)
        return parts.joined(separator: " · ")
    }

    /// First official-style YouTube trailer key, if any
    private var youtubeTrailerKey: String? {
        media.videos.youtubeTrailerKey
    }

    private var logoMaxWidth: CGFloat {
        #if os(iOS)
            300
        #else
            420
        #endif
    }

    private var logoMaxHeight: CGFloat {
        #if os(iOS)
            108
        #else
            180
        #endif
    }

    /// Tighter on iPhone only; mac keeps original bottom inset so copy stays put.
    private var overlayBottomSpacing: CGFloat {
        #if os(iOS)
            AppTheme.Spacing.sm
        #else
            40
        #endif
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.width / aspectRatio
            let width = geo.size.width
            ZStack(alignment: .bottomLeading) {
                ZStack(alignment: .bottom) {
                    // ── Background poster image ────────────────────
                    AsyncImage(
                        url: {
                            #if os(iOS)
                                return MediaConfig.instance.posterURL(
                                    media.posterPath,
                                    width: 780
                                )
                            #else
                                return MediaConfig.instance.backdropURL(
                                    media.backdropPath,
                                    width: "original"
                                )
                            #endif
                        }()
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

                    // ── Readability scrim (helps text on bright/white backgrounds) ──
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black.opacity(0.25), location: 0.45),
                            .init(color: .black.opacity(0.7), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: width, height: height * 0.65)
                    .allowsHitTesting(false)
                }
                .compositingGroup()
                .frame(width: width, height: height)
                .stretchableHeroBannerInScrollView()
                .zIndex(0)

                // ── Trailer video (only for the slide in viewport) ─────
                // if isActive,
                //    let trailerKey = youtubeTrailerKey,
                //    let trailerURL = MediaConfig.instance.trailerStreamURL(
                //        youtubeKey: trailerKey
                //    ),
                //    let headers = HttpService.service.profileAuthHeaders()
                // {
                //     TrailerPlayerView(
                //         url: trailerURL,
                //         headers: headers,
                //         isMuted: isMuted
                //     )
                //     .frame(width: width, height: height)
                //     .clipped()
                // }
                //
                // // ── Bottom gradient ────────────────────────────
                // LinearGradient(
                //     stops: [
                //         .init(color: .clear, location: 0.0),
                //         .init(
                //             color: Color.black.opacity(0.2),
                //             location: 0.4
                //         ),
                //         .init(
                //             color: Color.black.opacity(0.7),
                //             location: 0.7
                //         ),
                //         .init(
                //             color: AppTheme.Colors.background,
                //             location: 1.0
                //         ),
                //     ],
                //     startPoint: .top,
                //     endPoint: .bottom
                // )
                // .frame(height: height * 0.55)

                // ── Content overlay ────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    // Logo or Title
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
                                        maxWidth: logoMaxWidth,
                                        maxHeight: logoMaxHeight,
                                        alignment: .bottomLeading
                                    )
                                    .shadow(
                                        color: .black.opacity(0.85),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                                    .shadow(
                                        color: .black.opacity(0.7),
                                        radius: 18,
                                        x: 0,
                                        y: 6
                                    )
                            default:
                                titleFallback
                            }
                        }
                        .frame(
                            maxWidth: logoMaxWidth,
                            maxHeight: logoMaxHeight,
                            alignment: .bottomLeading
                        )
                    } else {
                        titleFallback
                    }

                    Spacer().frame(height: 10)

                    // Genre info line
                    Text(infoLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .shadow(
                            color: .black.opacity(0.9),
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                        .shadow(
                            color: .black.opacity(0.7),
                            radius: 10,
                            x: 0,
                            y: 2
                        )

                    Text(media.overview)
                        .font(AppTheme.Typography.bodySmall)
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                        .shadow(
                            color: .black.opacity(0.85),
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                        .shadow(
                            color: .black.opacity(0.6),
                            radius: 10,
                            x: 0,
                            y: 2
                        )

                    Spacer().frame(height: overlayBottomSpacing)
                }
                .frame(
                    maxWidth: max(width * 0.5, 450),
                    alignment: .bottomLeading
                )
                .padding(.horizontal, AppTheme.Spacing.md)
                .zIndex(1)
            }
            .frame(maxWidth: width)
        }
    }

    private var titleFallback: some View {
        Text(displayTitle)
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .shadow(
                color: .black.opacity(0.9),
                radius: 4,
                x: 0,
                y: 2
            )
            .shadow(
                color: .black.opacity(0.7),
                radius: 16,
                x: 0,
                y: 4
            )
            .frame(maxWidth: 420, alignment: .bottomLeading)
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

private struct BannerPageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< count, id: \.self) { index in
                let isActive = index == current
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .fill(
                    isActive
                        ? Color.white
                        : Color.white.opacity(0.35)
                )
                .frame(
                    width: isActive ? 20 : 6,
                    height: 6
                )
                .animation(
                    .easeInOut(duration: 0.25),
                    value: current
                )
            }
        }
    }
}

private struct TopBannerShimmer: View {
    private let aspectRatio: CGFloat = {
        #if os(iOS)
            return 0.65
        #else
            return 1.8
        #endif
    }()

    var body: some View {
        GeometryReader { geo in
            let bannerHeight = geo.size.width / aspectRatio

            ZStack(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    ShimmerView()
                        .frame(width: geo.size.width, height: bannerHeight)

                    // Gradient overlay
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(
                                color: AppTheme.Colors.background
                                    .opacity(0.5),
                                location: 0.6
                            ),
                            .init(
                                color: AppTheme.Colors.background,
                                location: 1.0
                            ),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width, height: bannerHeight * 0.5)
                }
                .compositingGroup()
                .frame(width: geo.size.width, height: bannerHeight)
                .stretchableHeroBannerInScrollView()
                .zIndex(0)

                // Skeleton content
                VStack(spacing: 12) {
                    // Logo placeholder
                    ShimmerView()
                        .frame(width: 180, height: 50)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 6,
                                style: .continuous
                            )
                        )

                    // Genre line placeholder
                    ShimmerView()
                        .frame(width: 160, height: 14)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 4,
                                style: .continuous
                            )
                        )

                    Spacer().frame(height: 20)

                    // Fake page indicators
                    HStack(spacing: 4) {
                        RoundedRectangle(
                            cornerRadius: 3,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 20, height: 6)

                        ForEach(0 ..< 4, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .padding(.bottom, 16)
                .zIndex(1)
            }
            .frame(height: bannerHeight)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}
