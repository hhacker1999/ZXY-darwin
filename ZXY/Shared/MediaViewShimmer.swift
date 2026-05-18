import Foundation
import SwiftUI

struct MediaViewShimmer: View {
    let isMobile: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let headerHeight: CGFloat = isMobile
                ? (width * 3) / 2
                : (width * 9) / 16

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header shimmer
                    ZStack(alignment: .bottomLeading) {
                        ShimmerView()
                            .frame(width: width, height: headerHeight)
                            .mask {
                                BannerImageBottomFadeMask(height: headerHeight)
                            }
                            .zIndex(0)

                        HeroTextLegibilityScrim(
                            width: width,
                            height: headerHeight * 0.55
                        )
                        .zIndex(1)

                        // Skeleton content in header
                        VStack(alignment: .leading, spacing: 10) {
                            ShimmerView()
                                .frame(width: 160, height: 40)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 6,
                                        style: .continuous)
                                )
                            ShimmerView()
                                .frame(width: 120, height: 14)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 4,
                                        style: .continuous)
                                )
                            HStack(spacing: AppTheme.Spacing.xs) {
                                ForEach(0..<3, id: \.self) { _ in
                                    ShimmerView()
                                        .frame(width: 60, height: 24)
                                        .clipShape(
                                            RoundedRectangle(
                                                cornerRadius: 12,
                                                style: .continuous)
                                        )
                                }
                            }
                            HStack(spacing: AppTheme.Spacing.xs) {
                                ShimmerView()
                                    .frame(width: 70, height: 28)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 14,
                                            style: .continuous)
                                    )
                                ShimmerView()
                                    .frame(width: 70, height: 28)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 14,
                                            style: .continuous)
                                    )
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                        .zIndex(2)
                    }

                    Spacer().frame(height: AppTheme.Spacing.lg)

                    // Overview shimmer
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<3, id: \.self) { _ in
                            ShimmerView()
                                .frame(
                                    width: width * (isMobile ? 0.9 : 0.5),
                                    height: 12
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 4,
                                        style: .continuous)
                                )
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)

                    Spacer().frame(height: AppTheme.Spacing.xl)

                    // Cast shimmer
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        ShimmerView()
                            .frame(width: 120, height: 18)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 4, style: .continuous)
                            )
                            .padding(.horizontal, AppTheme.Spacing.md)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.lg) {
                                ForEach(0..<6, id: \.self) { _ in
                                    VStack(spacing: AppTheme.Spacing.sm) {
                                        ShimmerView()
                                            .frame(
                                                width: isMobile ? 90 : 140,
                                                height: isMobile ? 90 : 140
                                            )
                                            .clipShape(Circle())
                                        ShimmerView()
                                            .frame(width: 70, height: 10)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 3,
                                                    style: .continuous)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.md)
                        }
                        .scrollDisabled(true)
                    }

                    Spacer().frame(height: AppTheme.Spacing.xl)

                    // Media row shimmer
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        ShimmerView()
                            .frame(
                                width: AppTheme.MediaLibrary.sectionTitleShimmerWidth,
                                height: AppTheme.MediaLibrary.sectionTitleShimmerHeight
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 4, style: .continuous)
                            )
                            .padding(.horizontal, AppTheme.Spacing.md)

                        MediaShelfShimmerRow(insetContent: false)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        #if os(iOS)
            .ignoresSafeArea(edges: isMobile ? .top : [])
        #endif
    }
}
