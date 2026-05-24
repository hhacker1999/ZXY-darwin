import SwiftUI

struct SeriesViewTVOS: View {
    @Bindable var vm: SeriesViewModel
    @State private var showStreamSheet = false

    private var playProgressFraction: Double {
        let key = "\(vm.id):\(vm.selectedSeason):\(vm.selectedEpisode)"
        let raw = vm.progressState[key]?.progress ?? 0
        return min(max(raw / 100.0, 0), 1)
    }

    private var hasProgress: Bool {
        let key = "\(vm.id):\(vm.selectedSeason):\(vm.selectedEpisode)"
        return (vm.progressState[key]?.progress ?? 0) > 0
    }

    private var playButtonSuffix: String {
        let s = String(format: "%02d", vm.selectedSeason)
        let e = String(format: "%02d", vm.selectedEpisode)
        return "S\(s):E\(e)"
    }

    var body: some View {
        ZStack {
            switch vm.seriesState {
            case .initial, .loading:
                TVOSBackdrop()
                ProgressView()
                    .controlSize(.large)
            case .error(let err):
                TVOSBackdrop()
                VStack(spacing: 32) {
                    Text("Error loading series details")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                    Text(err)
                        .font(.system(size: 26))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                    Button("Go Back") {
                        Router.router.popRoute()
                    }
                    .buttonStyle(.card)
                }
            case .loaded(let details):
                let mediaDetails = MediaDetails(from: details)
                loadedContent(mediaDetails)
            }
        }
        .sheet(isPresented: $showStreamSheet) {
            if case .loaded(let details) = vm.seriesState {
                StreamSheet(
                    state: vm.episodeStreamState,
                    episodeNo: vm.selectedEpisode,
                    seasonNo: vm.selectedSeason,
                    media: MediaDetails(from: details)
                )
                .streamSheetPresentationChrome()
            }
        }
        .task {
            await vm.initialise()
        }
        .onDisappear {
            vm.streamsTask?.cancel()
        }
        .onChange(of: Router.router.mainRouteState) { old, _ in
            guard let oldRoute = old.last else {
                return
            }
            if case let .mpvVideoView(args) = oldRoute {
                if args.mediaId == "\(vm.id)" {
                    Task {
                        await vm.fetchShowProgress(loadOverlay: true, afterVideoEnds: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func loadedContent(_ details: MediaDetails) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            ZStack(alignment: .topLeading) {
                // Cinematic immersive backdrop
                backdropView(details, size: geo.size)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 64) {
                        // Top Split-Pane Section
                        HStack(alignment: .top, spacing: 64) {
                            // Left Column: Details & Actions
                            VStack(alignment: .leading, spacing: 0) {
                                // Title Logo or Text
                                titleView(details)
                                
                                Spacer().frame(height: 24)
                                
                                // Metadata row
                                metadataRow(details)
                                
                                Spacer().frame(height: 32)
                                
                                // Overview
                                Text(details.overView)
                                    .font(.system(size: 26, weight: .regular))
                                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                                    .lineSpacing(6)
                                    .lineLimit(5)
                                    .frame(maxWidth: width * 0.55, alignment: .leading)
                                
                                Spacer().frame(height: 48)
                                
                                // Actions
                                actionsRow(details)
                            }
                            .frame(width: width * 0.55, alignment: .leading)
                            
                            Spacer()
                            
                            // Right Column: Poster Card
                            VStack {
                                if let posterPath = details.posterPath, !posterPath.isEmpty {
                                    AsyncImage(url: MediaConfig.instance.posterURL(posterPath)) { phase in
                                        switch phase {
                                        case let .success(image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        default:
                                            posterPlaceholder
                                        }
                                    }
                                    .frame(width: 320, height: 480)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 12)
                                } else {
                                    posterPlaceholder
                                }
                            }
                            .frame(width: width * 0.35, alignment: .center)
                        }
                        .padding(.horizontal, 80)
                        .padding(.top, 100)
                        
                        // Seasons & Episodes Section
                        if !details.seasons.isEmpty {
                            seasonsAndEpisodesSection(details)
                        }

                        // Bottom shelves
                        bottomShelves(details)
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func backdropView(_ details: MediaDetails, size: CGSize) -> some View {
        ZStack {
            if let backdropPath = details.backdropPath, !backdropPath.isEmpty {
                BlocAsyncImage(id: backdropPath, size: "original", setGradientFromImage: false) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    default:
                        Color.clear
                    }
                }
                .transition(.opacity)
            }
            
            // Masking Gradients
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.1),
                    .init(color: Color.black.opacity(0.65), location: 0.5),
                    .init(color: AppTheme.Colors.background, location: 0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.7), location: 0.0),
                    .init(color: Color.black.opacity(0.4), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            
            Color.black.opacity(0.15)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func titleView(_ details: MediaDetails) -> some View {
        if let path = logoPath(details), !path.isEmpty {
            AsyncImage(url: MediaConfig.instance.logoURL(path)) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 500, maxHeight: 160, alignment: .leading)
                        .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
                default:
                    titleFallback(details.name)
                }
            }
            .frame(maxWidth: 500, maxHeight: 160, alignment: .leading)
        } else {
            titleFallback(details.name)
        }
    }

    private func titleFallback(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .shadow(color: .black.opacity(0.7), radius: 6, y: 3)
    }

    private func metadataRow(_ details: MediaDetails) -> some View {
        HStack(spacing: 20) {
            if let year = releaseYear(details) {
                Text(year)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
            }
            
            if details.runtime > 0 {
                Text("•")
                    .foregroundStyle(AppTheme.Colors.elementMuted)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                    Text("\(details.runtime)m avg")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                }
            }
            
            if details.imdbRating > 0 || details.voteAverage > 0 {
                Text("•")
                    .foregroundStyle(AppTheme.Colors.elementMuted)
                
                HStack(spacing: 12) {
                    if details.imdbRating > 0 {
                        tvosRatingTag(rating: String(format: "%.1f", details.imdbRating), label: "IMDb", color: Color(hex: "#F5C518"))
                    }
                    if details.voteAverage > 0 {
                        tvosRatingTag(rating: String(format: "%.1f", details.voteAverage), label: "TMDb", color: Color(hex: "#01B4E4"))
                    }
                }
            }
            
            if !details.genres.isEmpty {
                Text("•")
                    .foregroundStyle(AppTheme.Colors.elementMuted)
                
                Text(details.genres.prefix(3).map { $0.name }.joined(separator: ", "))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                    .lineLimit(1)
            }
        }
    }

    private func tvosRatingTag(rating: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppTheme.Colors.elementSubtle)
            Text(rating)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func actionsRow(_ details: MediaDetails) -> some View {
        HStack(spacing: 24) {
            // Play Stream Button
            Button {
                showStreamSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .bold))
                    Text("Play S\(vm.selectedSeason):E\(vm.selectedEpisode)")
                        .font(.system(size: 24, weight: .semibold))
                    
                    if hasProgress {
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 80, height: 6)
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.85))
                                .frame(width: 80 * playProgressFraction, height: 6)
                        }
                    }
                }
                .foregroundStyle(AppTheme.Colors.buttonPrimaryLabel)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.buttonPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.card)
            
            // Add/Remove Library Button
            Button {
                Task { await vm.updateInLibrary() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: vm.isInLibrary ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 24, weight: .bold))
                    Text(vm.isInLibrary ? "In Library" : "Add to Library")
                        .font(.system(size: 24, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.card)
        }
    }

    @ViewBuilder
    private func seasonsAndEpisodesSection(_ details: MediaDetails) -> some View {
        VStack(alignment: .leading, spacing: 32) {
            // Season Selector Row
            Text("Episodes")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 80)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(details.seasons, id: \.seasonNumber) { season in
                        let isSelected = season.seasonNumber == vm.selectedSeason
                        Button {
                            withAnimation(.smooth(duration: 0.25)) {
                                vm.onEpisodeSelect(season: season.seasonNumber, episode: 1)
                            }
                        } label: {
                            Text(season.name ?? "Season \(season.seasonNumber)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(isSelected ? AppTheme.Colors.buttonPrimaryLabel : .white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(isSelected ? AppTheme.Colors.buttonPrimary : Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.leading, 80)
                .padding(.trailing, 160)
            }
            .scrollClipDisabled()

            // Episodes Carousel Shelf
            if let currentSeason = details.seasons.first(where: { $0.seasonNumber == vm.selectedSeason }),
               !currentSeason.episodes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 32) {
                        ForEach(currentSeason.episodes, id: \.episodeNumber) { episode in
                            let progressKey = "\(vm.id):\(vm.selectedSeason):\(episode.episodeNumber)"
                            TVOSEpisodeCard(
                                episode: episode,
                                seasonNumber: vm.selectedSeason,
                                tmdbShowId: vm.id,
                                progress: vm.progressState[progressKey],
                                onTap: {
                                    vm.onEpisodeSelect(season: vm.selectedSeason, episode: episode.episodeNumber)
                                    showStreamSheet = true
                                },
                                onMarkWatched: { key in
                                    Task { await vm.markWatched(mediaId: key) }
                                }
                            )
                        }
                    }
                    .padding(.leading, 80)
                    .padding(.trailing, 280)
                }
                .frame(height: 380)
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder
    private func bottomShelves(_ details: MediaDetails) -> some View {
        VStack(alignment: .leading, spacing: 56) {
            // Cast list
            let castList = details.cast.filter { $0.profilePath != nil && !$0.profilePath!.isEmpty }
            if !castList.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Cast and Crew")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 32) {
                            ForEach(Array(castList.prefix(20).enumerated()), id: \.offset) { _, cast in
                                TVOSCastCard(cast: cast)
                            }
                        }
                        .padding(.leading, 80)
                        .padding(.trailing, 160)
                    }
                    .frame(height: 250)
                    .scrollClipDisabled()
                }
            }

            // Recommendations
            if !details.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("You may also like")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 32) {
                            ForEach(details.recommendations, id: \.id) { rec in
                                TVOSDetailPosterCard(media: rec.asAppMedia(preferMovie: false))
                            }
                        }
                        .padding(.leading, 80)
                        .padding(.trailing, 160)
                    }
                    .frame(height: 380)
                    .scrollClipDisabled()
                }
            }

            // Similar
            if !details.similar.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Similar Shows")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 32) {
                            ForEach(details.similar, id: \.id) { sim in
                                TVOSDetailPosterCard(media: sim.asAppMedia(preferMovie: false))
                            }
                        }
                        .padding(.leading, 80)
                        .padding(.trailing, 160)
                    }
                    .frame(height: 380)
                    .scrollClipDisabled()
                }
            }
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            LoadingSurfaceFill()
            Image(systemName: "film")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.elementMuted)
        }
        .frame(width: 320, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func logoPath(_ details: MediaDetails) -> String? {
        guard let images = details.images else { return nil }
        guard let logos = images.logos else { return nil }
        let englishLogo = logos.first {
            $0.iso639_1 == "en" && !$0.filePath.hasSuffix(".svg")
        }
        if let logo = englishLogo { return logo.filePath }
        return logos.first?.filePath
    }

    private func releaseYear(_ details: MediaDetails) -> String? {
        guard let date = details.airOrReleaseDate, !date.isEmpty else { return nil }
        return String(date.prefix(4))
    }
}

// MARK: - TVOSEpisodeCard

struct TVOSEpisodeCard: View {
    let episode: Episode
    let seasonNumber: Int
    let tmdbShowId: Int
    let progress: WatchProgress?
    let onTap: () -> Void
    let onMarkWatched: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    private var progressFraction: Double {
        guard let p = progress else { return 0 }
        return min(max(p.progress / 100.0, 0), 1)
    }
    
    private var hasProgress: Bool {
        progressFraction > 0
    }
    
    private var isWatched: Bool {
        progress?.isWatched ?? false
    }
    
    private var airDateValue: Date? {
        guard let airDate = episode.airDate, !airDate.isEmpty else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: airDate)
    }

    private var isUpcoming: Bool {
        guard let date = airDateValue else { return false }
        return date > Date()
    }

    private var runtimeLabel: String? {
        guard let rt = episode.runtime, rt > 0 else { return nil }
        let h = rt / 60
        let m = rt % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onTap) {
                // Episode thumbnail image
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: MediaConfig.instance.stillURL(episode.stillPath ?? "", width: "original")) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            ZStack {
                                LoadingSurfaceFill()
                                Image(systemName: "film")
                                    .font(.system(size: 36))
                                    .foregroundStyle(AppTheme.Colors.elementMuted)
                            }
                        }
                    }
                    .frame(width: 360, height: 202)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // In-progress Bar
                    if hasProgress {
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.35))
                                .frame(height: 6)
                            Capsule(style: .continuous)
                                .fill(Color.white)
                                .frame(width: 360 * progressFraction, height: 6)
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                    
                    // Status badge (top-right overlay): upcoming takes priority over watched
                    if isUpcoming || isWatched {
                        VStack {
                            HStack {
                                Spacer()
                                if isUpcoming {
                                    TVOSUpcomingBadge()
                                        .padding(14)
                                } else {
                                    TVOSWatchedBadge()
                                        .padding(14)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: 360, height: 202)
            }
            .buttonStyle(TVOSCardButtonStyle(isFocused: isFocused))
            .focused($isFocused)
            .contextMenu {
                Button("Mark as watched") {
                    onMarkWatched("\(tmdbShowId):\(seasonNumber):\(episode.episodeNumber)")
                }
                Button("Mark season as watched") {
                    onMarkWatched("\(tmdbShowId):\(seasonNumber)")
                }
            }
            
            // Text details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("EPISODE \(episode.episodeNumber)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isFocused ? .white : AppTheme.Colors.elementSubtle)
                    
                    if let rt = runtimeLabel {
                        Text("•")
                            .foregroundStyle(AppTheme.Colors.elementMuted)
                        Text(rt)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.elementSubtle)
                    }
                }
                
                Text(episode.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if !episode.overview.isEmpty {
                    Text(episode.overview)
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
            .frame(width: 360, alignment: .leading)
            .padding(.leading, 4)
        }
    }
}

