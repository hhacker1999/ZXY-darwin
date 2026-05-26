//
//  DiscordRichPresenceBloc.swift
//
//  macOS Discord Rich Presence — connects via IPC and updates activity
//  as the user browses ZXY.
//

import Foundation

enum DiscordPresenceSnapshot: Equatable {
    case idle
    case browsing(page: String)
    case viewingMovie(title: String, backdropURL: String?)
    case viewingShow(title: String, backdropURL: String?)
    case watching(title: String, season: Int?, episode: Int?, backdropURL: String?)

    var details: String? {
        switch self {
        case .idle:
            return nil
        case let .browsing(page):
            return "Browsing \(page)"
        case let .viewingMovie(title, _):
            return "Viewing \(title)"
        case let .viewingShow(title, _):
            return "Viewing \(title)"
        case let .watching(title, _, _, _):
            return "Watching \(title)"
        }
    }

    var state: String? {
        switch self {
        case .idle:
            return nil
        case .browsing:
            return "In ZXY"
        case .viewingMovie:
            return "Movie details"
        case .viewingShow:
            return "Show details"
        case let .watching(_, season, episode, _):
            if let season, let episode, season >= 0, episode >= 0 {
                return "S\(String(format: "%02d", season)):E\(String(format: "%02d", episode))"
            }
            return "Now playing"
        }
    }

    var largeImageURL: String? {
        switch self {
        case .idle, .browsing:
            return nil
        case let .viewingMovie(_, backdropURL),
             let .viewingShow(_, backdropURL),
             let .watching(_, _, _, backdropURL):
            return backdropURL
        }
    }

    var largeImageText: String {
        switch self {
        case .idle:
            return "ZXY"
        case .browsing:
            return "ZXY"
        case let .viewingMovie(title, _),
             let .viewingShow(title, _),
             let .watching(title, _, _, _):
            return title
        }
    }
}

@MainActor
@Observable
final class DiscordRichPresenceBloc {
    static let bloc = DiscordRichPresenceBloc()

    private(set) var isConnected = false
    private(set) var lastError: String?

    @ObservationIgnored
    private var currentSnapshot: DiscordPresenceSnapshot = .idle

    @ObservationIgnored
    private var activityStartTimestamp: Int?

    @ObservationIgnored
    private var updateTask: Task<Void, Never>?

    @ObservationIgnored
    private var currentTab: BaseHomeViewPages = .home

    @ObservationIgnored
    private var navigationDepth = 0

    #if os(macOS)
    @ObservationIgnored
    private let ipcClient = DiscordIPCClient()

    @ObservationIgnored
    private var reconnectAttempt = 0
    #endif

    private init() {}

    var isAvailable: Bool {
        #if os(macOS)
            return Constants.discordClientIdIsConfigured && SettingsBloc.bloc.enableDiscordRichPresence
        #else
            return false
        #endif
    }

    func handleTabSelected(_ page: BaseHomeViewPages) {
        currentTab = page
        guard navigationDepth == 0 else { return }
        setPresence(.browsing(page: page.rawValue))
    }

    func handleNavigationStack(_ routes: [Route]) {
        navigationDepth = routes.count

        guard let last = routes.last else {
            setPresence(.browsing(page: currentTab.rawValue))
            return
        }

        switch last {
        case let .mpvVideoView(args):
            let season = args.seasonNo >= 0 ? args.seasonNo : nil
            let episode = args.episodeNo >= 0 ? args.episodeNo : nil
            setPresence(
                .watching(
                    title: args.name,
                    season: season,
                    episode: episode,
                    backdropURL: Self.backdropURL(from: args.backdropPath)
                )
            )
        case .movieDetails, .seriesDetails:
            break
        default:
            break
        }
    }

    func setViewingMovie(title: String, backdropPath: String? = nil) {
        setPresence(.viewingMovie(title: title, backdropURL: Self.backdropURL(from: backdropPath)))
    }

    func setViewingShow(title: String, backdropPath: String? = nil) {
        setPresence(.viewingShow(title: title, backdropURL: Self.backdropURL(from: backdropPath)))
    }

    func setWatching(title: String, season: Int? = nil, episode: Int? = nil, backdropPath: String? = nil) {
        setPresence(
            .watching(
                title: title,
                season: season,
                episode: episode,
                backdropURL: Self.backdropURL(from: backdropPath)
            )
        )
    }

    func setBrowsing(page: String) {
        setPresence(.browsing(page: page))
    }

    func clearPresence() {
        setPresence(.idle)
    }

    func shutdown() {
        updateTask?.cancel()
        updateTask = nil

        #if os(macOS)
            Task {
                if ipcClient.isConnected {
                    let pid = Int32(ProcessInfo.processInfo.processIdentifier)
                    try? await ipcClient.clearActivity(pid: pid)
                    await ipcClient.disconnect()
                }
                await MainActor.run {
                    isConnected = false
                    currentSnapshot = .idle
                    activityStartTimestamp = nil
                }
            }
        #endif
    }

    // MARK: - Private

    private func setPresence(_ snapshot: DiscordPresenceSnapshot) {
        let contentChanged = snapshot != currentSnapshot
        let shouldRetry = !isConnected && snapshot != .idle && isAvailable

        guard contentChanged || shouldRetry else { return }

        if contentChanged,
           snapshot.details != currentSnapshot.details
           || snapshot.state != currentSnapshot.state
           || snapshot.largeImageURL != currentSnapshot.largeImageURL
        {
            activityStartTimestamp = Int(Date().timeIntervalSince1970)
        }

        currentSnapshot = snapshot

        guard isAvailable else { return }

        updateTask?.cancel()
        updateTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await self?.applySnapshot(snapshot)
        }
    }

    private func applySnapshot(_ snapshot: DiscordPresenceSnapshot) async {
        #if os(macOS)
            guard snapshot == currentSnapshot else { return }

            if snapshot == .idle {
                await disconnectIfNeeded()
                return
            }

            do {
                try await ensureConnected()
                let pid = Int32(ProcessInfo.processInfo.processIdentifier)
                let largeImage = snapshot.largeImageURL
                    ?? (Constants.discordLargeImageKey.isEmpty ? nil : Constants.discordLargeImageKey)
                try await ipcClient.setActivity(
                    pid: pid,
                    activityType: DiscordActivityType.watching,
                    details: snapshot.details,
                    state: snapshot.state,
                    startTimestamp: activityStartTimestamp,
                    largeImageKey: largeImage,
                    largeImageText: snapshot.largeImageText
                )
                isConnected = true
                lastError = nil
                reconnectAttempt = 0
            } catch {
                isConnected = false
                lastError = error.localizedDescription
                await ipcClient.disconnect()

                reconnectAttempt += 1
                guard reconnectAttempt <= 3 else { return }

                try? await Task.sleep(for: .seconds(min(reconnectAttempt, 3)))
                guard !Task.isCancelled else { return }
                await applySnapshot(snapshot)
            }
        #endif
    }

    #if os(macOS)
        private func ensureConnected() async throws {
            guard Constants.discordClientIdIsConfigured else {
                throw DiscordIPCError.handshakeFailed("Discord Client ID is not configured.")
            }

            if ipcClient.isConnected {
                return
            }

            try await ipcClient.connect(clientId: Constants.discordClientId)
            isConnected = true
        }

        private func disconnectIfNeeded() async {
            guard ipcClient.isConnected else {
                isConnected = false
                activityStartTimestamp = nil
                return
            }

            let pid = Int32(ProcessInfo.processInfo.processIdentifier)
            try? await ipcClient.clearActivity(pid: pid)
            await ipcClient.disconnect()
            isConnected = false
            activityStartTimestamp = nil
        }
    #endif

    private static func backdropURL(from path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return MediaConfig.instance.backdropURL(path, width: "w780")?.absoluteString
    }
}
