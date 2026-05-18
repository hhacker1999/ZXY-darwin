import Foundation
import SwiftUI

// MARK: - Section (title + horizontal shelf)

struct MediaShelfSection: View {
    let title: String
    let media: [AppMedia]
    let onTap: (AppMedia) -> Void
    /// When false, parent already applies horizontal padding (e.g. movie detail scroll).
    var insetContent: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.MediaLibrary.sectionHeaderFont)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .padding(.horizontal, insetContent ? AppTheme.Spacing.md : 0)

            MediaShelfRow(media: media, onTap: onTap, insetContent: insetContent)
        }
    }
}

// MARK: - Horizontal row

struct MediaShelfRow: View {
    let media: [AppMedia]
    let onTap: (AppMedia) -> Void
    var insetContent: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: AppTheme.Spacing.sm + 2) {
                ForEach(media, id: \.id) { item in
                    MediaShelfPosterCard(media: item)
                        .onTapGesture {
                            onTap(item)
                        }
                }
            }
            .padding(.horizontal, insetContent ? AppTheme.Spacing.md : 0)
        }
    }
}

// MARK: - Poster card

struct MediaShelfPosterCard: View {
    let media: AppMedia
    @State private var reloadToken = UUID()
    @State private var hasSuccessfulLoad = false

    private var displayTitle: String {
        if !media.title.isEmpty { return media.title }
        if !media.name.isEmpty { return media.name }
        return media.originalTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs + 2) {
            AsyncImage(url: posterURL) { phase in
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
                    ShimmerView()
                @unknown default:
                    posterPlaceholder
                }
            }
            .id(reloadToken)
            .frame(
                width: AppTheme.MediaLibrary.rowPosterWidth,
                height: AppTheme.MediaLibrary.rowPosterHeight
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppTheme.MediaLibrary.rowPosterCornerRadius,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: AppTheme.MediaLibrary.rowPosterCornerRadius,
                    style: .continuous
                )
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
            )
            .shadow(color: AppTheme.Shadows.card, radius: 8, x: 0, y: 4)

            Text(displayTitle)
                .font(AppTheme.MediaLibrary.posterTitleFont)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .lineLimit(AppTheme.MediaLibrary.shelfTitleLineLimit)
                .frame(
                    width: AppTheme.MediaLibrary.rowPosterWidth,
                    alignment: .leading
                )
        }
        .onAppear {
            if !hasSuccessfulLoad {
                reloadToken = UUID()
            }
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

    private var posterURL: URL? {
        MediaConfig.instance.posterURL(media.posterPath)
    }
}

// MARK: - Loading / error

struct MediaShelfShimmerRow: View {
    var insetContent: Bool = true

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
                                width: AppTheme.MediaLibrary.rowPosterWidth,
                                height: AppTheme.MediaLibrary.rowPosterHeight
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: AppTheme.MediaLibrary.rowPosterCornerRadius,
                                    style: .continuous
                                )
                            )

                        ShimmerView()
                            .frame(
                                width: AppTheme.MediaLibrary.rowPosterWidth * 0.7,
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
            .padding(.horizontal, insetContent ? AppTheme.Spacing.md : 0)
        }
        .scrollDisabled(true)
    }
}

struct MediaShelfErrorRow: View {
    let message: String
    var insetContent: Bool = true

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
        .padding(.horizontal, insetContent ? AppTheme.Spacing.md : 0)
    }
}

// MARK: - Navigation

enum MediaShelfNavigation {
    static func openDetails(for media: AppMedia) {
        if media.type == "movie" {
            Router.router.addToRoute(route: .movieDetails(media.id))
        } else {
            Router.router.addToRoute(route: .seriesDetails(media.id))
        }
    }
}

// MARK: - CollectionPart → AppMedia

extension CollectionPart {
    /// Maps TMDB collection / similar / recommendation items to shelf `AppMedia`.
    func asAppMedia(preferMovie: Bool) -> AppMedia {
        let isMovie: Bool
        if let mediaType {
            isMovie = mediaType == "movie"
        } else {
            isMovie = preferMovie
        }

        return AppMedia(
            adult: adult ?? false,
            backdropPath: backdropPath ?? "",
            id: id,
            title: title ?? "",
            originalTitle: originalTitle ?? originalName ?? "",
            overview: overview ?? "",
            posterPath: posterPath,
            type: isMovie ? "movie" : "show",
            originalLanguage: originalLanguage ?? "",
            popularity: popularity ?? 0,
            releaseDate: releaseDate,
            voteAverage: voteAverage ?? 0,
            voteCount: voteCount ?? 0,
            name: name ?? "",
            originCountry: nil,
            genreIds: genreIds,
            imdbRating: imdbRating,
            images: Images(backdrops: nil, logos: nil, posters: nil),
            videos: Videos(results: nil)
        )
    }
}
