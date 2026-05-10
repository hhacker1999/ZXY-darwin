import Foundation
import SwiftUI

struct MediaDetailsMediaRow: View {
    let title: String
    let items: [CollectionPart]
    let isMovie: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Typography.headingMedium)
                .foregroundStyle(AppTheme.Colors.elementWhite)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: AppTheme.Spacing.sm + 2) {
                    ForEach(items, id: \.id) { item in
                        MoviePosterCard(item: item)
                            .onTapGesture {
                                if isMovie {
                                    Router.router.addToRoute(
                                        route: .movieDetails(item.id)
                                    )
                                } else {
                                    Router.router.addToRoute(
                                        route: .seriesDetails(item.id)
                                    )
                                }
                            }
                    }
                }
            }
        }
    }
}

private struct MoviePosterCard: View {
    let item: CollectionPart

    private var displayTitle: String {
        if let title = item.title, !title.isEmpty { return title }
        if let name = item.name, !name.isEmpty { return name }
        return item.originalTitle ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs + 2) {
            // Poster image
            AsyncImage(
                url: MediaConfig.instance.posterURL(item.posterPath)
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
                width: MediaMetrics.posterWidth,
                height: MediaMetrics.posterHeight
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MediaMetrics.posterRadius,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: MediaMetrics.posterRadius,
                    style: .continuous
                )
                .stroke(AppTheme.Colors.border, lineWidth: 0.5)
            )
            .shadow(color: AppTheme.Shadows.card, radius: 8, x: 0, y: 4)

            // Title
            Text(displayTitle)
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .lineLimit(2)
                .frame(
                    width: MediaMetrics.posterWidth, alignment: .leading
                )
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
}
