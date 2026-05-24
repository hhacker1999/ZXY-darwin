import SwiftUI

struct MovieViewTVOS: View {
    @Bindable var vm: MovieViewModel
    @State private var showStreamSheet = false
    
    private var playProgressFraction: Double {
        min(max(vm.progress / 100.0, 0), 1)
    }

    private var hasProgress: Bool {
        vm.progress > 0
    }

    var body: some View {
        ZStack {
            switch vm.movieState {
            case .initial, .loading:
                TVOSBackdrop()
                ProgressView()
                    .controlSize(.large)
            case .error(let err):
                TVOSBackdrop()
                VStack(spacing: 32) {
                    Text("Error loading movie details")
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
            if case .loaded(let details) = vm.movieState {
                StreamSheet(
                    state: vm.streamsState,
                    episodeNo: -1,
                    seasonNo: -1,
                    media: MediaDetails(from: details)
                )
                .streamSheetPresentationChrome()
            }
        }
        .task {
            await vm.initialise()
        }
        .onDisappear {
            vm.streamTask?.cancel()
        }
        .onChange(of: Router.router.mainRouteState) { old, _ in
            guard let oldRoute = old.last else {
                return
            }
            if case .mpvVideoView(let args) = oldRoute {
                if args.mediaId == "\(vm.id)" {
                    Task {
                        await vm.fetchMovieProgress(loadOverlay: true)
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
                        
                        // Bottom scrollable content
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
            
            if let runtime = runtimeLabel(details) {
                Text("•")
                    .foregroundStyle(AppTheme.Colors.elementMuted)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.Colors.elementMuted)
                    Text(runtime)
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
                    Text(hasProgress ? "Resume" : "Play")
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

            // Mark Movie Watched Button
            if !vm.isWatched {
                Button {
                    Task { await vm.markWatched() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24, weight: .bold))
                        Text("Mark watched")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.card)
            } else {
                TVOSWatchedBadge()
                    .padding(.horizontal, 24)
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

            // Collection parts
            if let collection = details.collection, !collection.parts.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text(collection.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 32) {
                            ForEach(collection.parts, id: \.id) { part in
                                TVOSDetailPosterCard(media: part.asAppMedia(preferMovie: true))
                            }
                        }
                        .padding(.leading, 80)
                        .padding(.trailing, 160)
                    }
                    .frame(height: 380)
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
                                TVOSDetailPosterCard(media: rec.asAppMedia(preferMovie: true))
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
                    Text("Similar Movies")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 32) {
                            ForEach(details.similar, id: \.id) { sim in
                                TVOSDetailPosterCard(media: sim.asAppMedia(preferMovie: true))
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

    private func runtimeLabel(_ details: MediaDetails) -> String? {
        let rt = details.runtime
        guard rt > 0 else { return nil }
        let h = rt / 60
        let m = rt % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// MARK: - TVOSDetailPosterCard

struct TVOSDetailPosterCard: View {
    let media: AppMedia
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                MediaShelfNavigation.openDetails(for: media)
            } label: {
                AsyncImage(url: MediaConfig.instance.posterURL(media.posterPath)) { phase in
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
                .frame(width: 200, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(TVOSCardButtonStyle(isFocused: isFocused))
            .focused($isFocused)
            
            Text(media.title.isEmpty ? media.name : media.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isFocused ? .white : AppTheme.Colors.elementSubtle)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)
                .padding(.leading, 4)
        }
    }
}

// MARK: - TVOSCastCard

struct TVOSCastCard: View {
    let cast: Cast
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {}) {
                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w185\(cast.profilePath ?? "")")) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        ZStack {
                            LoadingSurfaceFill()
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.Colors.elementMuted)
                        }
                    }
                }
                .frame(width: 130, height: 130)
                .clipShape(Circle())
            }
            .buttonStyle(TVOSCastButtonStyle(isFocused: isFocused))
            .focused($isFocused)
            
            VStack(spacing: 4) {
                Text(cast.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFocused ? .white : AppTheme.Colors.elementWhite)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                if let character = cast.character ?? cast.job {
                    Text(character)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.elementSubtle)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 160)
        }
    }
}
