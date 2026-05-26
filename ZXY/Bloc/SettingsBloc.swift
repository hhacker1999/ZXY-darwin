//
//  SettingsBloc.swift
//
//  Mirrors `app/lib/bloc/settings_bloc.dart` — user-tunable preferences
//  (language, theme, video player, etc.) persisted via SecureStorage.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsBloc {
    static let bloc = SettingsBloc()

    static let defaultLanguage = "English"
    static let defaultSubtitleLanguage = "None"
    static let resolutions = ["2160p", "1080p", "720p"]
    static let skipDurationOptions = [5, 10, 15, 30, 45, 60]

    private enum Keys {
        static let gradient = "gradient"
        static let dynamicTheme = "dynamic"
        static let posterRatings = "poster"
        static let formattedStreams = "formatted_streams"
        static let autoSelect = "auto_select"
        static let volume = "vol"
        static let skipDuration = "skipDuration"
        static let language = "language"
        static let subtitleLanguage = "subtitle_language"
        static let resolution = "resolution"
        static let subtitleFontSize = "size"
        static let subtitleFontPadding = "padding"
        static let discordRichPresence = "discord_rich_presence"
    }

    var enableGradient: Bool = true {
        didSet { persistBool(Keys.gradient, enableGradient) }
    }

    var isDynamic: Bool = true {
        didSet { persistBool(Keys.dynamicTheme, isDynamic) }
    }

    var showPosterRatings: Bool = true {
        didSet { persistBool(Keys.posterRatings, showPosterRatings) }
    }

    var showFormattedStreams: Bool = true {
        didSet { persistBool(Keys.formattedStreams, showFormattedStreams) }
    }

    var autoSelectBestStream: Bool = true {
        didSet { persistBool(Keys.autoSelect, autoSelectBestStream) }
    }

    var volume: Double = 100 {
        didSet { persistString(Keys.volume, String(volume)) }
    }

    var skipDuration: Int = 30 {
        didSet { persistString(Keys.skipDuration, String(skipDuration)) }
    }

    var language: String = SettingsBloc.defaultLanguage {
        didSet { persistString(Keys.language, language) }
    }

    var subtitleLanguage: String = SettingsBloc.defaultSubtitleLanguage {
        didSet { persistString(Keys.subtitleLanguage, subtitleLanguage) }
    }

    var resolution: String = SettingsBloc.platformDefaultResolution {
        didSet { persistString(Keys.resolution, resolution) }
    }

    var subtitleFontSize: Double = SettingsBloc.platformDefaultSubtitleFontSize {
        didSet { persistString(Keys.subtitleFontSize, String(subtitleFontSize)) }
    }

    var subtitleFontPadding: Double = SettingsBloc.platformDefaultSubtitlePadding {
        didSet { persistString(Keys.subtitleFontPadding, String(subtitleFontPadding)) }
    }

    var enableDiscordRichPresence: Bool = SettingsBloc.platformDefaultDiscordRichPresence {
        didSet {
            persistBool(Keys.discordRichPresence, enableDiscordRichPresence)
            #if os(macOS)
                if !enableDiscordRichPresence {
                    DiscordRichPresenceBloc.bloc.shutdown()
                } else if Constants.discordClientIdIsConfigured {
                    DiscordRichPresenceBloc.bloc.handleTabSelected(.home)
                }
            #endif
        }
    }

    @ObservationIgnored
    private var hydrating = false

    private init() {}

    /// Loads persisted values from SecureStorage. Call once on app start.
    func initialise() {
        hydrating = true
        defer { hydrating = false }

        if let v = readBool(Keys.gradient) { enableGradient = v }
        if let v = readBool(Keys.dynamicTheme) { isDynamic = v }
        if let v = readBool(Keys.posterRatings) { showPosterRatings = v }
        if let v = readBool(Keys.formattedStreams) { showFormattedStreams = v }
        if let v = readBool(Keys.autoSelect) { autoSelectBestStream = v }

        if let raw = SecureStorage.getKey(key: Keys.volume),
           let v = Double(raw) { volume = v }
        if let raw = SecureStorage.getKey(key: Keys.skipDuration),
           let v = Int(raw) { skipDuration = v }

        if let v = SecureStorage.getKey(key: Keys.language) { language = v }
        if let v = SecureStorage.getKey(key: Keys.subtitleLanguage) { subtitleLanguage = v }
        if let v = SecureStorage.getKey(key: Keys.resolution) { resolution = v }

        if let raw = SecureStorage.getKey(key: Keys.subtitleFontSize),
           let v = Double(raw) { subtitleFontSize = v }
        if let raw = SecureStorage.getKey(key: Keys.subtitleFontPadding),
           let v = Double(raw) { subtitleFontPadding = v }
        if let v = readBool(Keys.discordRichPresence) { enableDiscordRichPresence = v }
    }

    private func persistBool(_ key: String, _ value: Bool) {
        guard !hydrating else { return }
        SecureStorage.saveKey(key: key, value: value ? "true" : "false")
    }

    private func persistString(_ key: String, _ value: String) {
        guard !hydrating else { return }
        SecureStorage.saveKey(key: key, value: value)
    }

    private func readBool(_ key: String) -> Bool? {
        guard let raw = SecureStorage.getKey(key: key) else { return nil }
        return raw == "true"
    }

    private static var platformDefaultResolution: String {
        #if os(macOS)
            return "2160p"
        #else
            return "1080p"
        #endif
    }

    private static var platformDefaultSubtitleFontSize: Double {
        #if os(macOS)
            return 24
        #else
            return 14
        #endif
    }

    private static var platformDefaultSubtitlePadding: Double {
        #if os(macOS)
            return 20
        #else
            return 8
        #endif
    }

    private static var platformDefaultDiscordRichPresence: Bool {
        #if os(macOS)
            return true
        #else
            return false
        #endif
    }
}
