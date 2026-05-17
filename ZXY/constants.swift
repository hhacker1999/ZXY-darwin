//
//  constants.swift
//
//  Created by Harsh Kumar on 28/03/26.
//

import Foundation
import SwiftUI

class MediaConfig {
    var movieGenres: [Int: Genre] = [:]
    var showGenres: [Int: Genre] = [:]

    static let instance = MediaConfig()

    private init() {}

    let baseURL = "https://image.tmdb.org/t/p/"
    func posterURL(_ path: String, width: Int = 342) -> URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: "\(baseURL)w\(width)\(path)")
    }

    func backdropURL(_ path: String, width: String = "w780") -> URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: "\(baseURL)\(width)\(path)")
    }

    func logoURL(_ path: String, width: Int = 500) -> URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: "\(baseURL)w\(width)\(path)")
    }

    func stillURL(_ path: String, width: String = "w300") -> URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: "\(baseURL)\(width)\(path)")
    }

    /// URL to stream a YouTube trailer/clip through the backend proxy.
    /// The backend requires a valid profile session cookie on the request.
    func trailerStreamURL(youtubeKey: String) -> URL? {
        // guard !youtubeKey.isEmpty,
        //       let encoded = youtubeKey.addingPercentEncoding(
        //           withAllowedCharacters: .urlQueryAllowed
        //       )
        // else {
        //     return nil
        // }
        return URL(string: "\(Constants.baseUrl)/yt_stream?id=\(youtubeKey)")
    }
}

enum Constants {
    static let home = "Home"
    static let search = "Search"
    static let downloads = "Downloads"
    static let upcoming = "Upcoming"

    /// Colors
    static let bgColor = Color("bgColor")

    // static let baseUrl = "https://zxyapi.tooharsh.co.in"

    static let baseUrl = "https://zxy-staging.tooharsh.co.in"

    // static let baseUrl = "http://localhost:6969"

    static let tmdbImgBaseUrl = ""
}

enum MediaMetrics {
    static let posterWidth: CGFloat = 130
    static let posterHeight: CGFloat = 195
    static let posterRadius: CGFloat = 12

    static let castCircleSizeMobile: CGFloat = 90
    static let castCircleSizeDesktop: CGFloat = 140
    static let castItemWidthMobile: CGFloat = 100
    static let castItemWidthDesktop: CGFloat = 140
    static let castRowHeightMobile: CGFloat = 150
    static let castRowHeightDesktop: CGFloat = 210
}

class LangHelper {
    static let instance = LangHelper()

    static let langToCodes: [String: [String]] = [
        "Albanian": ["sq", "sqi", "alb"],
        "Arabic": ["ar", "ara"],
        "Armenian": ["hy", "hye", "arm"],
        "Basque": ["eu", "eus", "baq"],
        "Bengali": ["bn", "ben"],
        "Bosnian": ["bs", "bos"],
        "Bulgarian": ["bg", "bul"],
        "Burmese": ["my", "mya", "bur"],
        "Catalan": ["ca", "cat"],
        "Chinese": ["zh", "zho", "chi"],
        "Croatian": ["hr", "hrv", "scr"],
        "Czech": ["cs", "ces", "cze"],
        "Danish": ["da", "dan"],
        "Dutch": ["nl", "nld", "dut"],
        "English": ["en", "eng"],
        "Estonian": ["et", "est"],
        "Finnish": ["fi", "fin"],
        "French": ["fr", "fra", "fre"],
        "Georgian": ["ka", "kat", "geo"],
        "German": ["de", "deu", "ger"],
        "Greek": ["el", "ell", "gre"],
        "Hebrew": ["he", "heb"],
        "Hindi": ["hi", "hin"],
        "Hungarian": ["hu", "hun"],
        "Icelandic": ["is", "isl", "ice"],
        "Indonesian": ["id", "ind"],
        "Italian": ["it", "ita"],
        "Japanese": ["ja", "jpn"],
        "Korean": ["ko", "kor"],
        "Latvian": ["lv", "lav"],
        "Lithuanian": ["lt", "lit"],
        "Macedonian": ["mk", "mkd", "mac"],
        "Malay": ["ms", "msa", "may"],
        "Norwegian": ["no", "nor"],
        "Persian": ["fa", "fas", "per"],
        "Polish": ["pl", "pol"],
        "Portuguese": ["pt", "por"],
        "Romanian": ["ro", "ron", "rum"],
        "Russian": ["ru", "rus"],
        "Serbian": ["sr", "srp", "scc"],
        "Slovak": ["sk", "slk", "slo"],
        "Slovenian": ["sl", "slv"],
        "Spanish": ["es", "spa"],
        "Swahili": ["sw", "swa"],
        "Swedish": ["sv", "swe"],
        "Thai": ["th", "tha"],
        "Tibetan": ["bo", "bod", "tib"],
        "Turkish": ["tr", "tur"],
        "Ukrainian": ["uk", "ukr"],
        "Urdu": ["ur", "urd"],
        "Vietnamese": ["vi", "vie"],
        "Welsh": ["cy", "cym", "wel"],
    ]

    static var langFromCode: [String: String] = convertLangFromCode()
    private init() {}

    static func getDisplayName(_ code: String) -> String {
        let displayName = langFromCode[code.lowercased()]
        return displayName ?? code
    }

    static var iso6391List: [(String, String)] = langToCodes.map {
        (key: String, value: [String]) in (value.first!, key)
    }

    private static func convertLangFromCode() -> [String: String] {
        var res: [String: String] = [:]
        for (key, value) in langToCodes {
            for code in value {
                res[code.lowercased()] = key
            }
        }
        return res
    }
}
