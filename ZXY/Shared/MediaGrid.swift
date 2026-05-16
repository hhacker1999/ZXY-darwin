import Inject
import SwiftUI


private enum GridMetrics {
    static let minPosterWidth: CGFloat = 140
    static let posterAspectRatio: CGFloat = 1.5 // Height / Width
    static let cornerRadius: CGFloat = 12
    static let titleLineLimit = 2
}

struct MediaGrid<T:Hashable>: View {
    @ObserveInjection var inject

    let itemState: ViewItemState<[AppMedia]>
    let initialText: String
    var showType: Bool = false
    let onScrollNearEnd: () -> Void
    let id: T
    let onItemTapped: (AppMedia) -> Void

    /// We let the grid fill as many columns as possible with at least `minPosterWidth`
    private let columns = [
        GridItem(.adaptive(minimum: GridMetrics.minPosterWidth), spacing: AppTheme.Spacing.md),
    ]

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

                case let .error(msg):
                    Text(msg)
                        .font(AppTheme.Typography.bodyLarge)
                        .foregroundColor(AppTheme.Colors.error)
                        .padding(.top, AppTheme.Spacing.xl)

                case let .loaded(items):
                    if items.isEmpty {
                        Text("No items found.")
                            .font(AppTheme.Typography.bodyLarge)
                            .foregroundColor(AppTheme.Colors.elementSubtle)
                            .padding(.top, AppTheme.Spacing.xl)
                    } else {
                        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.lg) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
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
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.xxl)
                    }
                }
            }
        }
        .enableInjection()
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }

    private var shimmerGrid: some View {
        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.lg) {
            ForEach(0 ..< 12, id: \.self) { _ in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ShimmerView()
                        .aspectRatio(1 / GridMetrics.posterAspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: GridMetrics.cornerRadius, style: .continuous))

                    ShimmerView()
                        .frame(height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    ShimmerView()
                        .frame(width: 80, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
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
                AsyncImage(url: MediaConfig.instance.posterURL(media.posterPath)) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(1 / GridMetrics.posterAspectRatio, contentMode: .fit)
                    case .failure:
                        posterPlaceholder
                    case .empty:
                        ShimmerView()
                    @unknown default:
                        posterPlaceholder
                    }
                }
                .aspectRatio(1 / GridMetrics.posterAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: GridMetrics.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: GridMetrics.cornerRadius, style: .continuous)
                        .stroke(AppTheme.Colors.border.opacity(isHovered ? 0.8 : 0.4), lineWidth: isHovered ? 1.5 : 0.5)
                )
                .shadow(color: AppTheme.Shadows.card.opacity(isHovered ? 0.6 : 0.3), radius: isHovered ? 12 : 8, x: 0, y: isHovered ? 6 : 4)

                // Optional Type Label
                if showType {
                    Text(displayType)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            // ── Title label ──────────────────────────────────
            Text(displayTitle)
                .font(AppTheme.Typography.bodySmall)
                .foregroundStyle(AppTheme.Colors.elementSubtle)
                .lineLimit(GridMetrics.titleLineLimit)
                .frame(height: AppTheme.Spacing.xl, alignment: .topLeading)
        }
        .scaleEffect(isHovered ? 1.08 : 1.0)
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
