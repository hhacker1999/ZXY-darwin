import Foundation
import SwiftUI

struct CastAndCrewSection: View {
    let castList: [Cast]
    let isMobile: Bool

    private var circleSize: CGFloat {
        isMobile
            ? MediaMetrics.castCircleSizeMobile
            : MediaMetrics.castCircleSizeDesktop
    }

    private var itemWidth: CGFloat {
        isMobile
            ? MediaMetrics.castItemWidthMobile
            : MediaMetrics.castItemWidthDesktop
    }

    private var rowHeight: CGFloat {
        isMobile
            ? MediaMetrics.castRowHeightMobile
            : MediaMetrics.castRowHeightDesktop
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Cast and Crew")
                .font(
                    isMobile
                        ? AppTheme.Typography.headingSmall
                        : AppTheme.Typography.headingMedium
                )
                .foregroundStyle(AppTheme.Colors.elementWhite)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: AppTheme.Spacing.lg) {
                    ForEach(
                        Array(castList.prefix(20).enumerated()), id: \.offset
                    ) { _, cast in
                        VStack(
                            spacing: isMobile
                                ? AppTheme.Spacing.sm : AppTheme.Spacing.md
                        ) {
                            // Profile image
                            AsyncImage(
                                url: URL(
                                    string:
                                        "https://image.tmdb.org/t/p/w185\(cast.profilePath ?? "")"
                                )
                            ) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    castPlaceholder
                                case .empty:
                                    ShimmerView()
                                @unknown default:
                                    castPlaceholder
                                }
                            }
                            .frame(width: circleSize, height: circleSize)
                            .clipShape(Circle())

                            // Name + character
                            VStack(spacing: 2) {
                                Text(cast.name)
                                    .font(
                                        isMobile
                                            ? AppTheme.Typography.bodySmall
                                            : AppTheme.Typography.bodyMedium
                                    )
                                    .foregroundStyle(
                                        AppTheme.Colors.elementWhite
                                    )
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)

                                if let character = cast.character ?? cast.job {
                                    Text(character)
                                        .font(
                                            .system(
                                                size: isMobile ? 10 : 12)
                                        )
                                        .foregroundStyle(
                                            AppTheme.Colors.elementSubtle
                                        )
                                        .lineLimit(1)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .frame(width: itemWidth)
                    }
                }
            }
            .frame(height: rowHeight)
        }
    }

    private var castPlaceholder: some View {
        ZStack {
            LoadingSurfaceFill()
            Image(systemName: "person.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
    }
}
