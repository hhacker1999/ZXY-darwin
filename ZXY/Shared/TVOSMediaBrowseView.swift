//
//  TVOSMediaBrowseView.swift
//
//  Shared tvOS browse layout — pinned focus banner + scrollable poster grid.
//

#if os(tvOS)

import SwiftUI

// MARK: - Layout

enum TVOSBrowseLayout {
    static let cornerRadius: CGFloat = 16
    static let horizontalInset: CGFloat = 80
    static let bannerHeightFraction: CGFloat = 0.52
    /// Match `TVOSLayout` poster sizing from HomeViewTVOS.
    static let posterWidth: CGFloat = 210
    static let posterHeight: CGFloat = 315
    static let rowHeight: CGFloat = 368
    static let gridSpacing: CGFloat = 32
    /// Space below the tab bar before content begins.
    static let contentTopPadding: CGFloat = 48
    /// Extra space above the grid when there is no header (Library).
    static let gridTopPadding: CGFloat = 32

    struct GridMetrics {
        let columnCount: Int
        let spacing: CGFloat

        var columns: [GridItem] {
            Array(
                repeating: GridItem(.fixed(TVOSBrowseLayout.posterWidth), spacing: spacing),
                count: columnCount
            )
        }
    }

    static func gridMetrics(for containerWidth: CGFloat) -> GridMetrics {
        let available = max(containerWidth - horizontalInset * 2, posterWidth)
        let columnCount = max(
            1,
            Int((available + gridSpacing) / (posterWidth + gridSpacing))
        )
        return GridMetrics(columnCount: columnCount, spacing: gridSpacing)
    }

    /// Inset that centers the fixed-width grid in `containerWidth` so left and
    /// right gutters are equal. Falls back to `horizontalInset` if the grid is
    /// wider than the container would allow with default padding.
    static func symmetricInset(
        containerWidth: CGFloat,
        metrics: GridMetrics
    ) -> CGFloat {
        let columns = CGFloat(metrics.columnCount)
        let gridWidth =
            columns * posterWidth + max(columns - 1, 0) * metrics.spacing
        let candidate = (containerWidth - gridWidth) / 2
        return max(horizontalInset, candidate)
    }
}

// MARK: - Grid-only Shell (Search / Library)

struct TVOSMediaGridView<Header: View, ID: Hashable>: View {
    let itemState: ViewItemState<[AppMedia]>
    let emptyMessage: String
    let gridID: ID
    var showType: Bool = false
    let onLoadMore: () -> Void
    var showsHeader: Bool = true
    @ViewBuilder let header: () -> Header

    @FocusState private var focusedMediaID: Int?

    var body: some View {
        GeometryReader { geo in
            let gridMetrics = TVOSBrowseLayout.gridMetrics(for: geo.size.width)
            let inset = TVOSBrowseLayout.symmetricInset(
                containerWidth: geo.size.width,
                metrics: gridMetrics
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    if showsHeader {
                        header()
                            .padding(.horizontal, inset)
                    }

                    gridContent(gridMetrics: gridMetrics, inset: inset)
                        .padding(.top, showsHeader ? 0 : TVOSBrowseLayout.gridTopPadding)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, TVOSBrowseLayout.contentTopPadding)
                .padding(.bottom, 80)
            }
            .background(AppTheme.Colors.background)
        }
    }

    @ViewBuilder
    private func gridContent(
        gridMetrics: TVOSBrowseLayout.GridMetrics,
        inset: CGFloat
    ) -> some View {
        switch itemState {
        case .initial:
            TVOSBrowsePlaceholder(message: emptyMessage)

        case .loading:
            TVOSBrowseGridShimmer(gridMetrics: gridMetrics, inset: inset)

        case let .error(message):
            TVOSBrowsePlaceholder(message: message, isError: true)

        case let .loaded(items):
            if items.isEmpty {
                TVOSBrowsePlaceholder(message: "No items found.")
            } else {
                TVOSBrowsePosterGrid(
                    items: items,
                    gridID: gridID,
                    gridMetrics: gridMetrics,
                    showType: showType,
                    inset: inset,
                    focusedMediaID: $focusedMediaID,
                    onLoadMore: onLoadMore
                )
            }
        }
    }
}

extension TVOSMediaGridView where Header == EmptyView {
    init(
        itemState: ViewItemState<[AppMedia]>,
        emptyMessage: String,
        gridID: ID,
        showType: Bool = false,
        onLoadMore: @escaping () -> Void
    ) {
        self.itemState = itemState
        self.emptyMessage = emptyMessage
        self.gridID = gridID
        self.showType = showType
        self.onLoadMore = onLoadMore
        self.showsHeader = false
        self.header = { EmptyView() }
    }
}

// MARK: - Browse Shell

struct TVOSMediaBrowseView<Header: View, ID: Hashable>: View {
    let itemState: ViewItemState<[AppMedia]>
    let emptyMessage: String
    let gridID: ID
    var showType: Bool = true
    let onLoadMore: () -> Void
    @ViewBuilder let header: () -> Header

    @State private var featuredMedia: AppMedia?
    @FocusState private var focusedMediaID: Int?

    var body: some View {
        GeometryReader { geo in
            let bannerHeight = geo.size.height * TVOSBrowseLayout.bannerHeightFraction
            let gridMetrics = TVOSBrowseLayout.gridMetrics(for: geo.size.width)
            let inset = TVOSBrowseLayout.symmetricInset(
                containerWidth: geo.size.width,
                metrics: gridMetrics
            )

            VStack(spacing: 0) {
                TVOSBrowseBanner(media: featuredMedia, height: bannerHeight)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        header()
                            .padding(.horizontal, inset)
                            .padding(.top, 28)

                        browseContent(gridMetrics: gridMetrics, inset: inset)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 80)
                }
                .background(AppTheme.Colors.background)
                .onChange(of: focusedMediaID) { _, newID in
                    guard let newID, let media = mediaForID(newID) else { return }
                    updateFeatured(media)
                }
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .task(id: bootstrapToken) {
            bootstrapFeaturedMedia()
        }
    }

    @ViewBuilder
    private func browseContent(
        gridMetrics: TVOSBrowseLayout.GridMetrics,
        inset: CGFloat
    ) -> some View {
        switch itemState {
        case .initial:
            TVOSBrowsePlaceholder(message: emptyMessage)

        case .loading:
            TVOSBrowseGridShimmer(gridMetrics: gridMetrics, inset: inset)

        case let .error(message):
            TVOSBrowsePlaceholder(message: message, isError: true)

        case let .loaded(items):
            if items.isEmpty {
                TVOSBrowsePlaceholder(message: "No items found.")
            } else {
                TVOSBrowsePosterGrid(
                    items: items,
                    gridID: gridID,
                    gridMetrics: gridMetrics,
                    showType: showType,
                    inset: inset,
                    focusedMediaID: $focusedMediaID,
                    onLoadMore: onLoadMore
                )
            }
        }
    }

    private var bootstrapToken: String {
        switch itemState {
        case .initial: "init"
        case .loading: "loading"
        case let .loaded(items): "loaded-\(items.count)-\(items.first?.id ?? 0)"
        case .error: "error"
        }
    }

    private func bootstrapFeaturedMedia() {
        guard featuredMedia == nil else { return }
        guard case let .loaded(items) = itemState, let first = items.first else { return }
        featuredMedia = first
        focusedMediaID = first.id
    }

    private func updateFeatured(_ media: AppMedia) {
        guard media.id != featuredMedia?.id else { return }
        featuredMedia = media
    }

    private func mediaForID(_ id: Int) -> AppMedia? {
        guard case let .loaded(items) = itemState else { return nil }
        return items.first { $0.id == id }
    }
}

// MARK: - Header Primitives

struct TVOSBrowseTitleHeader: View {
    let title: String
    var trailing: AnyView?

    init(title: String) {
        self.title = title
        trailing = nil
    }

    init<Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            Text(title)
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            if let trailing {
                trailing
            }
        }
    }
}

struct TVOSBrowseIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .frame(width: 56, height: 56)
                .background(AppTheme.Colors.surface)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.card)
        .accessibilityLabel(label)
    }
}

struct TVOSBrowseFilterChips: View {
    let chips: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, text in
                    Text(text)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.Colors.surface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                }
            }
        }
    }
}

struct TVOSBrowseSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementMuted)

            TextField(placeholder, text: $text)
                .font(TVOSTypography.fieldText)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .onChange(of: text) { _, newValue in
                    if newValue.isEmpty {
                        onClear()
                    }
                }
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                }
                .buttonStyle(.card)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Banner

private struct TVOSBrowseBanner: View {
    let media: AppMedia?
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            TVOSBrowseBackdrop(media: media)
            TVOSBrowseHeroDetails(media: media)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.background)
        .clipped()
    }
}

private struct TVOSBrowseBackdrop: View {
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

private struct TVOSBrowseHeroDetails: View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, TVOSBrowseLayout.horizontalInset)
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
            Text(TVOSBrowseMediaDisplay.metadataLine(for: media))
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
        let displayTitle = TVOSBrowseMediaDisplay.title(for: media)
        if let logoPath = TVOSBrowseMediaDisplay.logoPath(for: media), !logoPath.isEmpty {
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

private enum TVOSBrowseMediaDisplay {
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

// MARK: - Grid

private struct TVOSBrowsePosterGrid<ID: Hashable>: View {
    let items: [AppMedia]
    let gridID: ID
    let gridMetrics: TVOSBrowseLayout.GridMetrics
    let showType: Bool
    let inset: CGFloat
    var focusedMediaID: FocusState<Int?>.Binding
    let onLoadMore: () -> Void

    var body: some View {
        LazyVGrid(
            columns: gridMetrics.columns,
            alignment: .leading,
            spacing: TVOSBrowseLayout.gridSpacing
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                TVOSBrowsePosterCard(
                    media: item,
                    showType: showType,
                    focusedMediaID: focusedMediaID,
                    isDefaultFocus: index == 0
                )
                .frame(width: TVOSBrowseLayout.posterWidth, height: TVOSBrowseLayout.rowHeight, alignment: .top)
                .id(item.id)
                .onAppear {
                    if index >= items.count - gridMetrics.columnCount {
                        onLoadMore()
                    }
                }
            }
        }
        .id(gridID)
        .padding(.horizontal, inset)
        .scrollClipDisabled()
        .focusSection()
    }
}

private struct TVOSBrowsePosterCard: View {
    let media: AppMedia
    let showType: Bool
    var focusedMediaID: FocusState<Int?>.Binding
    let isDefaultFocus: Bool

    var body: some View {
        Button {
            MediaShelfNavigation.openDetails(for: media)
        } label: {
            posterImage
                .frame(width: TVOSBrowseLayout.posterWidth, height: TVOSBrowseLayout.posterHeight)
                .clipShape(
                    RoundedRectangle(cornerRadius: TVOSBrowseLayout.cornerRadius, style: .continuous)
                )
                .overlay(alignment: .topLeading) {
                    if showType {
                        TVOSBrowseTypeBadge(isShow: media.type == "show")
                            .padding(10)
                    }
                }
        }
        .buttonStyle(.card)
        .focused(focusedMediaID, equals: media.id)
        .browseApplyIf(isDefaultFocus) { view in
            view.defaultFocus(focusedMediaID, media.id)
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

private struct TVOSBrowseTypeBadge: View {
    let isShow: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isShow ? "tv.fill" : "film.fill")
                .font(.system(size: 12, weight: .bold))

            Text(isShow ? "TV SHOW" : "MOVIE")
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.65))
        )
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Placeholder & Shimmer

private struct TVOSBrowsePlaceholder: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        Text(message)
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(isError ? AppTheme.Colors.error : AppTheme.Colors.elementSubtle)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, TVOSBrowseLayout.horizontalInset)
            .padding(.vertical, 48)
    }
}

private struct TVOSBrowseGridShimmer: View {
    let gridMetrics: TVOSBrowseLayout.GridMetrics
    let inset: CGFloat

    var body: some View {
        LazyVGrid(
            columns: gridMetrics.columns,
            alignment: .leading,
            spacing: TVOSBrowseLayout.gridSpacing
        ) {
            ForEach(0..<gridMetrics.columnCount * 2, id: \.self) { _ in
                ShimmerView()
                    .frame(width: TVOSBrowseLayout.posterWidth, height: TVOSBrowseLayout.posterHeight)
                    .clipShape(
                        RoundedRectangle(cornerRadius: TVOSBrowseLayout.cornerRadius, style: .continuous)
                    )
                    .frame(width: TVOSBrowseLayout.posterWidth, height: TVOSBrowseLayout.rowHeight, alignment: .top)
            }
        }
        .padding(.horizontal, inset)
    }
}

private extension View {
    @ViewBuilder
    func browseApplyIf(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#endif
