import Inject
import SwiftUI

private enum GridMetrics {
    static var minPosterWidth: CGFloat {
        AppTheme.MediaLibrary.gridMinPosterWidth
    }
    static let posterAspectRatio: CGFloat = 1.5  // Height / Width
    static var cornerRadius: CGFloat {
        AppTheme.MediaLibrary.gridPosterCornerRadius
    }
    static var titleLineLimit: Int { AppTheme.MediaLibrary.shelfTitleLineLimit }
    static var columnSpacing: CGFloat {
        AppTheme.MediaLibrary.gridColumnSpacing
    }
    static var rowSpacing: CGFloat { AppTheme.MediaLibrary.gridRowSpacing }
}

struct MediaGrid<T: Hashable>: View {
    @ObserveInjection var inject
    @Environment(\.contentBlendsWithAmbient) private var blendsWithAmbient

    let itemState: ViewItemState<[AppMedia]>
    let initialText: String
    var showType: Bool = false
    let onScrollNearEnd: () -> Void
    let id: T
    let onItemTapped: (AppMedia) -> Void

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: GridMetrics.minPosterWidth),
                spacing: GridMetrics.columnSpacing,
                alignment: .top
            )
        ]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack {
                switch itemState {
                case .initial:
                    Text(initialText)
                        .font(AppTheme.Typography.bodyLarge)
                        .foregroundColor(AppTheme.Colors.elementSubtle)
                        .padding(.top, AppTheme.Spacing.xl)

                case .loading:
                    shimmerGrid

                case .error(let msg):
                    Text(msg)
                        .font(AppTheme.Typography.bodyLarge)
                        .foregroundColor(AppTheme.Colors.error)
                        .padding(.top, AppTheme.Spacing.xl)

                case .loaded(let items):
                    if items.isEmpty {
                        Text("No items found.")
                            .font(AppTheme.Typography.bodyLarge)
                            .foregroundColor(AppTheme.Colors.elementSubtle)
                            .padding(.top, AppTheme.Spacing.xl)
                    } else {
                        LazyVGrid(
                            columns: columns,
                            spacing: GridMetrics.rowSpacing
                        ) {
                            ForEach(Array(items.enumerated()), id: \.offset) {
                                index,
                                item in
                                GridPosterCard(media: item, showType: showType)
                                    .onTapGesture {
                                        onItemTapped(item)
                                    }
                                    .onAppear {
                                        // Simple infinite scroll logic
                                        if index >= items.count - 4 {
                                            onScrollNearEnd()
                                        }
                                    }
                            }
                        }
                        .id(id)
                        .padding(
                            .horizontal,
                            AppTheme.Layout.mediaGridScrollHorizontalPadding
                        )
                        .padding(.top, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.xxl)
                    }
                }
            }
        }
        .enableInjection()
        .modifier(MediaGridScrollChrome(blendsWithAmbient: blendsWithAmbient))
    }

    private var shimmerGrid: some View {
        LazyVGrid(columns: columns, spacing: GridMetrics.rowSpacing) {
            ForEach(0..<12, id: \.self) { _ in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ShimmerView()
                        .aspectRatio(
                            1 / GridMetrics.posterAspectRatio,
                            contentMode: .fit
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: GridMetrics.cornerRadius,
                                style: .continuous
                            )
                        )

                    ShimmerView()
                        .frame(height: 14)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 4,
                                style: .continuous
                            )
                        )

                    ShimmerView()
                        .frame(width: 80, height: 14)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 4,
                                style: .continuous
                            )
                        )
                }
            }
        }
        .padding(.horizontal, AppTheme.Layout.mediaGridScrollHorizontalPadding)
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.xxl)
    }
}

private struct GridPosterCard: View {
    let media: AppMedia
    let showType: Bool

    @State private var isHovered = false

    private var displayTitle: String {
        if !media.title.isEmpty { return media.title }
        if !media.name.isEmpty { return media.name }
        return media.originalTitle
    }

    private var displayType: String {
        media.type == "movie" ? "Movie" : "Series"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs + 2) {
            // ── Poster image ─────────────────────────────────
            ZStack(alignment: .topTrailing) {
                AsyncImage(
                    url: MediaConfig.instance.posterURL(media.posterPath)
                ) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(
                                1 / GridMetrics.posterAspectRatio,
                                contentMode: .fit
                            )
                    case .failure:
                        posterPlaceholder
                    case .empty:
                        ShimmerView()
                    @unknown default:
                        posterPlaceholder
                    }
                }
                .aspectRatio(
                    1 / GridMetrics.posterAspectRatio,
                    contentMode: .fit
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: GridMetrics.cornerRadius,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: GridMetrics.cornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        AppTheme.Colors.border.opacity(isHovered ? 0.8 : 0.4),
                        lineWidth: isHovered ? 1.5 : 0.5
                    )
                )
                .shadow(
                    color: AppTheme.Shadows.card.opacity(isHovered ? 0.6 : 0.3),
                    radius: gridShadowRadius,
                    x: 0,
                    y: gridShadowYOffset
                )

                // Optional Type Label
                if showType {
                    Text(displayType)
                        .font(AppTheme.MediaLibrary.gridTypeBadgeFont)
                        .foregroundStyle(Color.white)
                        .padding(
                            .horizontal,
                            AppTheme.MediaLibrary.gridTypeBadgePaddingH
                        )
                        .padding(
                            .vertical,
                            AppTheme.MediaLibrary.gridTypeBadgePaddingV
                        )
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(
                            AppTheme.MediaLibrary.gridTypeBadgeOuterPadding
                        )
                }
            }

            // ── Title label ──────────────────────────────────
            Text(displayTitle)
                .font(AppTheme.MediaLibrary.gridPosterTitleFont)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .lineLimit(GridMetrics.titleLineLimit)
                .frame(
                    height: AppTheme.MediaLibrary.gridTitleBlockHeight,
                    alignment: .topLeading
                )
        }
        .scaleEffect(isHovered ? gridHoverScale : 1.0)
    }

    private var gridShadowRadius: CGFloat {
        #if os(iOS)
            isHovered ? 8 : 5
        #else
            isHovered ? 12 : 8
        #endif
    }

    private var gridShadowYOffset: CGFloat {
        #if os(iOS)
            isHovered ? 4 : 3
        #else
            isHovered ? 6 : 4
        #endif
    }

    private var gridHoverScale: CGFloat {
        #if os(iOS)
            1.0
        #else
            isHovered ? 1.08 : 1.0
        #endif
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

private struct MediaGridScrollChrome: ViewModifier {
    let blendsWithAmbient: Bool

    func body(content: Content) -> some View {
        if blendsWithAmbient {
            content
                .scrollContentBackground(.hidden)
        } else {
            content
                .background(AppTheme.Colors.background.ignoresSafeArea())
        }
    }
}
