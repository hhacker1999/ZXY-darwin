//
//  TopBanner.swift
//  LearnSwift
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
        case .loaded(let items):
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
    @State private var currentPage: Int = 0

    private let aspectRatio: CGFloat = {
        #if os(ios)
            return 0.64
        #else
            return 1.78
        #endif
    }()

    var body: some View {
        ZStack {
            Color.clear.aspectRatio(aspectRatio, contentMode: .fit)
            GeometryReader { geo in
                let bannerHeight = geo.size.width / aspectRatio
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(
                            Array(items.enumerated()),
                            id: \.offset
                        ) { index, media in
                            BannerSlide(
                                media: media,
                                width: geo.size.width,
                                height: bannerHeight
                            )
                            .tag(index)
                        }
                    }
                    .frame(height: bannerHeight)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .aspectRatio(aspectRatio, contentMode: .fit)
            }
        }
    }
}

private struct BannerSlide: View {
    let media: AppMedia
    let width: CGFloat
    let height: CGFloat

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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // ── Background poster image ────────────────────
            AsyncImage(
                url: {
                    #if os(ios)
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
                case .success(let image):
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

            // ── Bottom gradient ────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(
                        color: Color.black.opacity(0.2),
                        location: 0.4
                    ),
                    .init(
                        color: Color.black.opacity(0.7),
                        location: 0.7
                    ),
                    .init(
                        color: AppTheme.Colors.background,
                        location: 1.0
                    ),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.55)

            // ── Content overlay ────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                // Logo or Title
                if let path = logoPath, !path.isEmpty {
                    AsyncImage(
                        url: MediaConfig.instance.logoURL(path)
                    ) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    maxWidth: 220,
                                    maxHeight: 80
                                )
                                .shadow(
                                    color: .black.opacity(0.6),
                                    radius: 12,
                                    x: 0,
                                    y: 4
                                )
                        default:
                            titleFallback
                        }
                    }
                } else {
                    titleFallback
                }

                Spacer().frame(height: 10)

                // Genre info line
                Text(infoLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .shadow(
                        color: .black.opacity(0.8),
                        radius: 4,
                        x: 0,
                        y: 1
                    )

                Text(media.overview).font(AppTheme.Typography.bodySmall)
                    .foregroundStyle(AppTheme.Colors.elementSubtle)

                Spacer().frame(height: 40)
            }
            .frame(
                maxWidth: max(width * 0.5, 450),
                alignment: .bottomLeading
            )
            .padding(.horizontal, AppTheme.Spacing.md)
        }.frame(maxWidth: width)
    }

    private var titleFallback: some View {
        Text(displayTitle)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .shadow(
                color: .black.opacity(0.8),
                radius: 8,
                x: 0,
                y: 2
            )
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

// MARK: - Banner Page Indicator

private struct BannerPageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
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

// MARK: - Top Banner Shimmer

private struct TopBannerShimmer: View {
    private let aspectRatio: CGFloat = {
        #if os(ios)
            return 0.65
        #else
            return 1.8
        #endif
    }()

    var body: some View {
        GeometryReader { geo in
            let bannerHeight = geo.size.width / aspectRatio

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
                .frame(height: bannerHeight * 0.5)

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

                        ForEach(0..<4, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(height: bannerHeight)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
}
