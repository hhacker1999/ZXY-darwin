import Foundation

/// Parse Torrent Title — Swift port of https://github.com/MunifTanjim/go-ptt (v0.14.1).
public enum PTT {
    public static let version = "0.14.1"

    public static func parse(_ title: String) -> Result {
        runParse(title, handlers: handlers)
    }

    public static func getPartialParser(fieldNames: [String]) -> (String) -> Result {
        let selected = Set(fieldNames)
        let subset = handlers.filter { selected.contains($0.field) }
        return { runParse($0, handlers: subset) }
    }

    public final class Result {
        public var audio: [String] = []
        public var bitDepth = ""
        public var channels: [String] = []
        public var codec = ""
        public var commentary = false
        public var complete = false
        public var container = ""
        public var convert = false
        public var date = ""
        public var documentary = false
        public var dubbed = false
        public var edition = ""
        public var episodeCode = ""
        public var episodes: [Int] = []
        public var extended = false
        public var `extension` = ""
        public var group = ""
        public var hdr: [String] = []
        public var hardcoded = false
        public var languages: [String] = []
        public var network = ""
        public var proper = false
        public var quality = ""
        public var region = ""
        public var releaseTypes: [String] = []
        public var remastered = false
        public var repack = false
        public var resolution = ""
        public var retail = false
        public var seasons: [Int] = []
        public var site = ""
        public var size = ""
        public var subbed = false
        public var threeD = ""
        public var title = ""
        public var uncensored = false
        public var unrated = false
        public var upscaled = false
        public var volumes: [Int] = []
        public var year = ""
        public var error: Error?
        var isNormalized = false

        @discardableResult
        public func normalize() -> Result {
            if error != nil { return self }
            if !isNormalized {
                audio = normalizeAudio(audio)
                codec = normalizeCodec(codec)
                releaseTypes = normalizeReleaseTypes(releaseTypes)
                resolution = normalizeResolution(resolution)
                isNormalized = true
            }
            return self
        }
    }
}

// MARK: - Engine

private let valueSetFields: Set<String> = ["audio", "channels", "hdr", "languages", "releaseTypes"]

private final class ValueSet {
    private var seen = Set<String>()
    private(set) var values: [String] = []

    @discardableResult
    func append(_ v: String) -> ValueSet {
        if !seen.contains(v) {
            seen.insert(v)
            values.append(v)
        }
        return self
    }

    func exists(_ v: String) -> Bool { seen.contains(v) }
}

private final class ParseMeta {
    var mIndex = 0
    var mValue = ""
    var value: Any?
    var remove = false
    var processed = false
}

private struct Handler {
    var field: String
    var pattern: NSRegularExpression?
    var validateMatch: ((String, [Int]) -> Bool)?
    var transform: ((String, ParseMeta, inout [String: ParseMeta]) -> Void)?
    var process: ((String, ParseMeta, inout [String: ParseMeta]) -> ParseMeta)?
    var remove = false
    var keepMatching = false
    var skipIfFirst = false
    var skipIfBefore: [String] = []
    var skipFromTitle = false
    var matchGroup = 0
    var valueGroup = 0
}

private func re(_ pattern: String) -> NSRegularExpression {
    if let compiled = try? NSRegularExpression(pattern: pattern, options: []) {
        return compiled
    }
    let rewritten = rewriteGoRegexForICU(pattern)
    if rewritten != pattern, let compiled = try? NSRegularExpression(pattern: rewritten, options: []) {
        return compiled
    }
    preconditionFailure("Invalid PTT regex: \(pattern)")
}

private func rewriteGoRegexForICU(_ pattern: String) -> String {
    pattern.replacingOccurrences(of: #"[^[\]]"#, with: #"[^\[\]]"#)
}

private func utf16ToUtf8(_ s: String, _ utf16Offset: Int) -> Int {
    if utf16Offset <= 0 { return 0 }
    let utf16 = s.utf16
    let clamped = min(utf16Offset, utf16.count)
    let i = utf16.index(utf16.startIndex, offsetBy: clamped)
    guard let si = String.Index(i, within: s) else { return s.utf8.count }
    return s.utf8.distance(from: s.utf8.startIndex, to: si)
}

private func utf8Slice(_ s: String, _ start: Int, _ end: Int) -> String {
    let bytes = Array(s.utf8)
    let lo = max(0, min(start, bytes.count))
    let hi = max(lo, min(end, bytes.count))
    return String(bytes: bytes[lo..<hi], encoding: .utf8) ?? ""
}

private func utf8Count(_ s: String) -> Int { s.utf8.count }

private func replaceFirst(_ s: String, _ part: String) -> String {
    guard !part.isEmpty, let r = s.range(of: part) else { return s }
    return s.replacingCharacters(in: r, with: "")
}

private func firstMatchIndices(_ regex: NSRegularExpression, in title: String) -> [Int]? {
    let nsLen = (title as NSString).length
    guard nsLen > 0 || regex.numberOfCaptureGroups >= 0 else { return nil }
    guard let m = regex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: nsLen)) else {
        return nil
    }
    var idxs: [Int] = []
    idxs.reserveCapacity(m.numberOfRanges * 2)
    for i in 0..<m.numberOfRanges {
        let r = m.range(at: i)
        if r.location == NSNotFound {
            idxs.append(-1)
            idxs.append(-1)
        } else {
            idxs.append(utf16ToUtf8(title, r.location))
            idxs.append(utf16ToUtf8(title, r.location + r.length))
        }
    }
    return idxs
}

private func runParse(_ rawTitle: String, handlers: [Handler]) -> PTT.Result {
    let r = PTT.Result()
    var title = whitespacesRegex.stringByReplacingMatches(
        in: rawTitle, options: [], range: NSRange(location: 0, length: (rawTitle as NSString).length), withTemplate: " "
    )
    title = underscoresRegex.stringByReplacingMatches(
        in: title, options: [], range: NSRange(location: 0, length: (title as NSString).length), withTemplate: " "
    )
    var result: [String: ParseMeta] = [:]
    var endOfTitle = utf8Count(title)

    for handler in handlers {
        let field = handler.field
        var skipFromTitle = handler.skipFromTitle
        var m = result[field]
        var mFound = m != nil

        if let pattern = handler.pattern {
            if mFound && !handler.keepMatching { continue }
            guard let idxs = firstMatchIndices(pattern, in: title), idxs.count >= 2, idxs[0] >= 0 else {
                continue
            }
            if let validate = handler.validateMatch, !validate(title, idxs) { continue }

            var shouldSkip = false
            if handler.skipIfFirst {
                var hasOther = false
                var hasBefore = false
                for (f, fm) in result where f != field {
                    hasOther = true
                    if idxs[0] >= fm.mIndex {
                        hasBefore = true
                        break
                    }
                }
                shouldSkip = hasOther && !hasBefore
            }
            if shouldSkip { continue }

            if !handler.skipIfBefore.isEmpty {
                for skipField in handler.skipIfBefore {
                    if let fm = result[skipField], idxs[0] < fm.mIndex {
                        shouldSkip = true
                        break
                    }
                }
                if shouldSkip { continue }
            }

            let rawMatchedPart = utf8Slice(title, idxs[0], idxs[1])
            var matchedPart = rawMatchedPart
            if idxs.count > 2 {
                if handler.valueGroup == 0 {
                    if idxs[2] >= 0 && idxs[3] >= 0 {
                        matchedPart = utf8Slice(title, idxs[2], idxs[3])
                    }
                } else if idxs.count > handler.valueGroup * 2 {
                    let a = idxs[handler.valueGroup * 2]
                    let b = idxs[handler.valueGroup * 2 + 1]
                    if a >= 0 && b >= 0 {
                        matchedPart = utf8Slice(title, a, b)
                    }
                }
            }

            let before = beforeTitleRegex.firstMatch(
                in: title, options: [], range: NSRange(location: 0, length: (title as NSString).length)
            )
            if let before {
                let prefix = (title as NSString).substring(with: before.range)
                if prefix.contains(rawMatchedPart) { skipFromTitle = true }
            }

            if !mFound {
                let meta = ParseMeta()
                if valueSetFields.contains(field) {
                    meta.value = ValueSet()
                }
                mFound = true
                result[field] = meta
                m = meta
            }
            let meta = m!
            meta.mIndex = idxs[0]
            meta.mValue = rawMatchedPart
            if !valueSetFields.contains(field) {
                meta.value = matchedPart
            }
            if handler.matchGroup != 0, idxs.count > handler.matchGroup * 2 {
                let a = idxs[handler.matchGroup * 2]
                let b = idxs[handler.matchGroup * 2 + 1]
                if a >= 0 && b >= 0 {
                    meta.mIndex = a
                    meta.mValue = utf8Slice(title, a, b)
                }
            }
        }

        if let process = handler.process {
            if mFound, let existing = m {
                m = process(title, existing, &result)
            } else {
                let created = process(title, ParseMeta(), &result)
                if created.value != nil {
                    result[field] = created
                    mFound = true
                }
                m = created
            }
        }

        guard let meta = m else { continue }

        if meta.value != nil, let transform = handler.transform {
            transform(title, meta, &result)
        }

        if meta.value == nil {
            result.removeValue(forKey: field)
            mFound = false
        }

        if !mFound || (meta.processed && !handler.keepMatching && !valueSetFields.contains(field)) {
            continue
        }

        if handler.remove || meta.remove {
            meta.remove = true
            title = utf8Slice(title, 0, meta.mIndex) + utf8Slice(title, meta.mIndex + utf8Count(meta.mValue), utf8Count(title))
        }

        if !skipFromTitle && meta.mIndex != 0 && meta.mIndex < endOfTitle {
            endOfTitle = meta.mIndex
        }
        if meta.remove && skipFromTitle && meta.mIndex < endOfTitle {
            endOfTitle -= utf8Count(meta.mValue)
        }
        meta.remove = false
        meta.processed = true
    }

    for (field, fieldMeta) in result {
        applyField(field, fieldMeta.value, to: r)
    }
    let capEnd = max(min(endOfTitle, utf8Count(title)), 0)
    r.title = cleanTitle(utf8Slice(title, 0, capEnd))
    return r
}

private func applyField(_ field: String, _ v: Any?, to r: PTT.Result) {
    switch field {
    case "audio": r.audio = stringList(v)
    case "bitDepth": r.bitDepth = v as? String ?? ""
    case "channels": r.channels = stringList(v)
    case "codec": r.codec = v as? String ?? ""
    case "commentary": r.commentary = v as? Bool ?? false
    case "complete": r.complete = v as? Bool ?? false
    case "container": r.container = v as? String ?? ""
    case "convert": r.convert = v as? Bool ?? false
    case "date": r.date = v as? String ?? ""
    case "documentary": r.documentary = v as? Bool ?? false
    case "dubbed": r.dubbed = v as? Bool ?? false
    case "edition": r.edition = v as? String ?? ""
    case "episodeCode": r.episodeCode = v as? String ?? ""
    case "episodes": r.episodes = v as? [Int] ?? []
    case "extended": r.extended = v as? Bool ?? false
    case "extension": r.`extension` = v as? String ?? ""
    case "group": r.group = v as? String ?? ""
    case "hardcoded": r.hardcoded = v as? Bool ?? false
    case "hdr": r.hdr = stringList(v)
    case "languages": r.languages = stringList(v)
    case "network": r.network = v as? String ?? ""
    case "proper": r.proper = v as? Bool ?? false
    case "region": r.region = v as? String ?? ""
    case "remastered": r.remastered = v as? Bool ?? false
    case "repack": r.repack = v as? Bool ?? false
    case "resolution": r.resolution = v as? String ?? ""
    case "retail": r.retail = v as? Bool ?? false
    case "seasons": r.seasons = v as? [Int] ?? []
    case "size": r.size = v as? String ?? ""
    case "site": r.site = v as? String ?? ""
    case "quality": r.quality = v as? String ?? ""
    case "releaseTypes": r.releaseTypes = stringList(v)
    case "subbed": r.subbed = v as? Bool ?? false
    case "threeD": r.threeD = v as? String ?? ""
    case "uncensored": r.uncensored = v as? Bool ?? false
    case "unrated": r.unrated = v as? Bool ?? false
    case "upscaled": r.upscaled = v as? Bool ?? false
    case "volumes": r.volumes = v as? [Int] ?? []
    case "year": r.year = v as? String ?? ""
    default: break
    }
}

private func stringList(_ v: Any?) -> [String] {
    if let vs = v as? ValueSet { return vs.values }
    if let s = v as? [String] { return s }
    return []
}

private let nonEnglishChars = #"\p{Hiragana}\p{Katakana}\p{Han}\p{Cyrillic}"#
private let russianCastRegex = re(#"(\([^)]*[\p{Cyrillic}][^)]*\))$|(?:\/.*?)(\(.*\))$"#)
private let altTitlesRegex = re(#"[^/|(]*["# + nonEnglishChars + #"][^/|]*[/|]|[/|][^/|(]*["# + nonEnglishChars + #"][^/|]*"#)
private let notOnlyNonEnglishRegex = re(#"(?:[a-zA-Z][^"# + nonEnglishChars + #"]+)(["# + nonEnglishChars + #"].*["# + nonEnglishChars + #"])|(["# + nonEnglishChars + #"].*["# + nonEnglishChars + #"])(?:[^"# + nonEnglishChars + #"]+[a-zA-Z])"#)
private let notAllowedSymbolsAtStartAndEndRegex = re(#"^[^\w"# + nonEnglishChars + ##"#\[【★]+|[ \-:/\\\[|{(#$&^]+$"##)
private let remainingNotAllowedSymbolsAtStartAndEndRegex = re(#"^[^\w"# + nonEnglishChars + ##"#]+|[\\[\\]({} ]+$"##)
private let movieIndicatorRegex = re(#"(?i)[\[(]movie[)\]]"#)
private let releaseGroupMarkingAtStartRegex = re(#"^[\[【★].*[\]】★][ .]?(.+)"#)
private let releaseGroupMarkingAtEndRegex = re(#"(.+)[ .]?[\[【★].*[\]】★]$"#)
private let beforeTitleRegex = re(#"^\[([^[\]]+)]"#)
private let nonDigitRegex = re(#"\D"#)
private let nonDigitsRegex = re(#"\D+"#)
private let nonAlphasRegex = re(#"\W+"#)
private let underscoresRegex = re(#"_+"#)
private let whitespacesRegex = re(#"\s+"#)
private let redundantSymbolsAtEnd = re(#"[ \-:./\\]+$"#)

private func replaceAll(_ regex: NSRegularExpression, in s: String, with template: String) -> String {
    regex.stringByReplacingMatches(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length), withTemplate: template)
}

private func cleanTitle(_ rawTitle: String) -> String {
    var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    title = title.replacingOccurrences(of: "_", with: " ")
    title = replaceAll(movieIndicatorRegex, in: title, with: "")
    title = replaceAll(notAllowedSymbolsAtStartAndEndRegex, in: title, with: "")
    let ns = title as NSString
    let matches = russianCastRegex.matches(in: title, options: [], range: NSRange(location: 0, length: ns.length))
    for match in matches {
        for i in 1..<match.numberOfRanges {
            let range = match.range(at: i)
            if range.location != NSNotFound {
                let part = ns.substring(with: range)
                title = replaceFirst(title, part)
            }
        }
    }
    title = replaceAll(releaseGroupMarkingAtStartRegex, in: title, with: "$1")
    title = replaceAll(releaseGroupMarkingAtEndRegex, in: title, with: "$1")
    title = replaceAll(altTitlesRegex, in: title, with: "")
    if let only = notOnlyNonEnglishRegex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: (title as NSString).length)) {
        for i in 1..<only.numberOfRanges {
            let range = only.range(at: i)
            if range.location != NSNotFound {
                title = replaceFirst(title, (title as NSString).substring(with: range))
            }
        }
    }
    title = replaceAll(remainingNotAllowedSymbolsAtStartAndEndRegex, in: title, with: "")
    if !title.contains(" ") && title.contains(".") {
        title = title.replacingOccurrences(of: ".", with: " ")
    }
    for pair in [["{", "}"], ["[", "]"], ["(", ")"]] {
        if title.components(separatedBy: pair[0]).count - 1 != title.components(separatedBy: pair[1]).count - 1 {
            title = title.replacingOccurrences(of: pair[0], with: "").replacingOccurrences(of: pair[1], with: "")
        }
    }
    title = replaceAll(redundantSymbolsAtEnd, in: title, with: "")
    title = replaceAll(whitespacesRegex, in: title, with: " ")
    return title.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func normalizeAudio(_ audio: [String]) -> [String] {
    var changed = false
    var next = audio
    for i in next.indices {
        switch next[i] {
        case "AC3": next[i] = "DD"; changed = true
        case "EAC3": next[i] = "DDP"; changed = true
        default: break
        }
    }
    guard changed else { return audio }
    var seen = Set<String>()
    var out: [String] = []
    for item in next where !seen.contains(item) {
        seen.insert(item)
        out.append(item)
    }
    return out
}

private func normalizeCodec(_ codec: String) -> String {
    switch codec.lowercased() {
    case "avc", "h264", "x264": return "AVC"
    case "hevc", "h265", "x265": return "HEVC"
    case "mpeg2": return "MPEG-2"
    case "divx", "dvix": return "DivX"
    case "xvid": return "Xvid"
    default: return codec
    }
}

private func normalizeReleaseTypes(_ rtypes: [String]) -> [String] {
    rtypes.map {
        switch $0 {
        case "OAV": return "OVA"
        case "ODA": return "OAD"
        default: return $0
        }
    }
}

private func normalizeResolution(_ resolution: String) -> String {
    switch resolution.lowercased() {
    case "2160p": return "4k"
    case "1440p": return "2k"
    default: return resolution
    }
}

// MARK: - Validators / transformers

private func validateOr(_ validators: [(String, [Int]) -> Bool]) -> (String, [Int]) -> Bool {
    { input, idxs in validators.contains { $0(input, idxs) } }
}

private func validateAnd(_ validators: [(String, [Int]) -> Bool]) -> (String, [Int]) -> Bool {
    { input, idxs in validators.allSatisfy { $0(input, idxs) } }
}

private func validateNotAtStart(_ input: String, _ match: [Int]) -> Bool { match[0] != 0 }
private func validateNotAtEnd(_ input: String, _ match: [Int]) -> Bool { match[1] != utf8Count(input) }

private func validateLookbehind(_ pattern: String, flags: String, polarity: Bool) -> (String, [Int]) -> Bool {
    let prefix = flags.isEmpty ? "" : "(?\(flags))"
    let regex = re(prefix + pattern + "$")
    return { input, match in
        let rv = utf8Slice(input, 0, match[0])
        let ok = regex.firstMatch(in: rv, options: [], range: NSRange(location: 0, length: (rv as NSString).length)) != nil
        return polarity ? ok : !ok
    }
}

private func validateLookahead(_ pattern: String, flags: String, polarity: Bool) -> (String, [Int]) -> Bool {
    let prefix = flags.isEmpty ? "" : "(?\(flags))"
    let regex = re(prefix + "^" + pattern)
    return { input, match in
        let rv = utf8Slice(input, match[1], utf8Count(input))
        let ok = regex.firstMatch(in: rv, options: [], range: NSRange(location: 0, length: (rv as NSString).length)) != nil
        return polarity ? ok : !ok
    }
}

private func validateNotMatch(_ regex: NSRegularExpression) -> (String, [Int]) -> Bool {
    { input, match in
        let rv = utf8Slice(input, match[0], match[1])
        return regex.firstMatch(in: rv, options: [], range: NSRange(location: 0, length: (rv as NSString).length)) == nil
    }
}

private func validateMatch(_ regex: NSRegularExpression) -> (String, [Int]) -> Bool {
    { input, match in
        let rv = utf8Slice(input, match[0], match[1])
        return regex.firstMatch(in: rv, options: [], range: NSRange(location: 0, length: (rv as NSString).length)) != nil
    }
}

private func validateMatchedGroupsAreSame(_ indices: Int...) -> (String, [Int]) -> Bool {
    { input, match in
        guard let firstIdx = indices.first, match.count > firstIdx * 2 + 1 else { return false }
        let first = utf8Slice(input, match[firstIdx * 2], match[firstIdx * 2 + 1])
        for index in indices.dropFirst() {
            let other = utf8Slice(input, match[index * 2], match[index * 2 + 1])
            if other != first { return false }
        }
        return true
    }
}

private func toValue(_ value: String) -> (String, ParseMeta, inout [String: ParseMeta]) -> Void {
    { _, m, _ in m.value = value }
}

private func toLowercase(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    if let v = m.value as? String { m.value = v.lowercased() }
}

private func toUppercase(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    if let v = m.value as? String { m.value = v.uppercased() }
}

private func toTrimmed(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    if let v = m.value as? String { m.value = v.trimmingCharacters(in: .whitespacesAndNewlines) }
}

private func toBoolean(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    m.value = true
}

private func toWithSuffix(_ suffix: String) -> (String, ParseMeta, inout [String: ParseMeta]) -> Void {
    { _, m, _ in
        if let v = m.value as? String { m.value = v + suffix } else { m.value = "" }
    }
}

private let cleanDateRegex = re(#"(\d+)(?:st|nd|rd|th)"#)
private let cleanMonthRegex = re(#"(?i)(?:feb(?:ruary)?|jan(?:uary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sept?(?:ember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"#)
private let dateSeparatorRegex = re(#"[.\-/\\]"#)

private func toCleanDate(_ m: ParseMeta) {
    if let v = m.value as? String {
        m.value = replaceAll(cleanDateRegex, in: v, with: "$1")
    }
}

private func toCleanMonth(_ m: ParseMeta) {
    if let v = m.value as? String {
        let ns = v as NSString
        let matches = cleanMonthRegex.matches(in: v, options: [], range: NSRange(location: 0, length: ns.length))
        var result = v
        for match in matches.reversed() {
            let str = ns.substring(with: match.range)
            let prefix = String(str.prefix(3))
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: prefix)
            }
        }
        m.value = result
    }
}

private func parseGoDate(_ value: String, layout: String) -> String {
    let normalized = replaceAll(dateSeparatorRegex, in: value, with: " ")
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    switch layout {
    case "2006 01 02": formatter.dateFormat = "yyyy MM dd"
    case "02 01 2006": formatter.dateFormat = "dd MM yyyy"
    case "01 02 2006": formatter.dateFormat = "MM dd yyyy"
    case "01 02 06": formatter.dateFormat = "MM dd yy"
    case "02 01 06": formatter.dateFormat = "dd MM yy"
    case "_2 Jan 2006":
        formatter.dateFormat = "d MMM yyyy"
        if let d = formatter.date(from: normalized.trimmingCharacters(in: .whitespaces)) {
            return isoDate(d)
        }
        formatter.dateFormat = "dd MMM yyyy"
    case "_2 Jan 06":
        formatter.dateFormat = "d MMM yy"
        if let d = formatter.date(from: normalized.trimmingCharacters(in: .whitespaces)) {
            return isoDate(d)
        }
        formatter.dateFormat = "dd MMM yy"
    case "20060102": formatter.dateFormat = "yyyyMMdd"
    default: formatter.dateFormat = layout
    }
    guard let d = formatter.date(from: normalized.trimmingCharacters(in: .whitespaces)) else { return "" }
    return isoDate(d)
}

private func isoDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: d)
}

private func toDate(_ layout: String) -> (String, ParseMeta, inout [String: ParseMeta]) -> Void {
    { _, m, _ in
        if let v = m.value as? String {
            m.value = parseGoDate(v, layout: layout)
        } else {
            m.value = ""
        }
    }
}

private let toDateYMD = toDate("2006 01 02")
private let toDateDMY = toDate("02 01 2006")
private let toDateMDY = toDate("01 02 2006")
private let toDateMDYY = toDate("01 02 06")
private let toDateDMYY = toDate("02 01 06")
private let toDateCompact = toDate("20060102")

private func transformDateDayMonthYear(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) {
    toCleanDate(m)
    toCleanMonth(m)
    toDate("_2 Jan 2006")(title, m, &result)
}

private func transformDateDayMonthYY(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) {
    toCleanDate(m)
    toCleanMonth(m)
    toDate("_2 Jan 06")(title, m, &result)
}

private func toYear(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    guard let vstr = m.value as? String else {
        m.value = ""
        return
    }
    let goParts = splitNonDigits(vstr)
    if goParts.count == 1 {
        m.value = goParts[0]
        return
    }
    let start = goParts[0]
    let end = goParts[1]
    guard let endYearRaw = Int(end) else {
        m.value = start
        return
    }
    guard let startYear = Int(start) else {
        m.value = ""
        return
    }
    var endYear = endYearRaw
    if endYear < 100 {
        endYear = endYear + startYear - startYear % 100
    }
    if endYear <= startYear {
        m.value = ""
        return
    }
    m.value = "\(startYear)-\(endYear)"
}

private func splitNonDigits(_ v: String) -> [String] {
    let ns = v as NSString
    let matches = nonDigitsRegex.matches(in: v, options: [], range: NSRange(location: 0, length: ns.length))
    if matches.isEmpty { return [v] }
    var parts: [String] = []
    var last = 0
    for match in matches {
        if match.range.location > last {
            parts.append(ns.substring(with: NSRange(location: last, length: match.range.location - last)))
        }
        last = match.range.location + match.range.length
    }
    if last < ns.length {
        parts.append(ns.substring(from: last))
    }
    return parts.filter { !$0.isEmpty }
}

private func transformYearRangeComplete(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) {
    toYear(title, m, &result)
    if result["complete"] == nil, let s = m.value as? String, s.contains("-") {
        let cm = ParseMeta()
        cm.mIndex = m.mIndex
        cm.mValue = m.mValue
        cm.value = true
        result["complete"] = cm
    }
}

private func toIntRange(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    guard let v = m.value as? String else {
        m.value = nil
        return
    }
    let replaced = replaceAll(nonDigitsRegex, in: v, with: " ").trimmingCharacters(in: .whitespaces)
    let parts = replaced.split(separator: " ").map(String.init)
    var nums = parts.map { Int($0) ?? 0 }
    if nums.count == 2, nums[0] < nums[1] {
        nums = Array(nums[0]...nums[1])
    }
    for i in nums.indices where i != nums.count - 1 {
        if nums[i] + 1 != nums[i + 1] {
            m.value = nil
            return
        }
    }
    m.value = nums
}

private func toIntRangeTill(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    guard let v = m.value as? String else {
        m.value = nil
        return
    }
    let replaced = replaceAll(nonDigitsRegex, in: v, with: " ").trimmingCharacters(in: .whitespaces)
    let parts = replaced.split(separator: " ").map(String.init)
    if parts.isEmpty {
        m.value = nil
        return
    }
    if let num = Int(parts[0]) {
        m.value = Array(1...num)
    }
}

private func toIntArray(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    if let v = m.value as? String, let num = Int(v) {
        m.value = [num]
        return
    }
    m.value = [Int]()
}

private func toValueSet(_ v: String) -> (String, ParseMeta, inout [String: ParseMeta]) -> Void {
    { _, m, _ in
        if let val = m.value as? ValueSet {
            m.value = val.append(v)
        }
    }
}

private func transformReleaseTypesMulti(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    guard let val = m.value as? ValueSet else { return }
    for part in splitNonAlphas(m.mValue) where !part.isEmpty {
        val.append(part.uppercased())
    }
    m.value = val
}

private func splitNonAlphas(_ v: String) -> [String] {
    let ns = v as NSString
    let matches = nonAlphasRegex.matches(in: v, options: [], range: NSRange(location: 0, length: ns.length))
    if matches.isEmpty { return [v] }
    var parts: [String] = []
    var last = 0
    for match in matches {
        if match.range.location > last {
            parts.append(ns.substring(with: NSRange(location: last, length: match.range.location - last)))
        }
        last = match.range.location + match.range.length
    }
    if last < ns.length {
        parts.append(ns.substring(from: last))
    }
    return parts
}

private func transformReleaseTypesSingle(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    if let val = m.value as? ValueSet {
        m.value = val.append(m.mValue.uppercased())
    }
}

private func transformValueSetLowercaseMatch(_ title: String, _ m: ParseMeta, _: inout [String: ParseMeta]) {
    if let val = m.value as? ValueSet {
        m.value = val.append(m.mValue.lowercased())
    }
}

private func removeFromValue(_ regex: NSRegularExpression) -> (String, ParseMeta, inout [String: ParseMeta]) -> ParseMeta {
    { _, m, _ in
        if let v = m.value as? String, !v.isEmpty {
            m.value = replaceAll(regex, in: v, with: "")
        }
        return m
    }
}

private func validateYearCaptureIsFourDigits(_ input: String, _ match: [Int]) -> Bool {
    if match[0] < 2 { return false }
    guard match.count > 3, match[2] >= 0 else { return false }
    return utf8Slice(input, match[2], match[3]).count == 4
}

private func validateYearNotBareFourCharTitle(_ input: String, _ match: [Int]) -> Bool {
    let mValue = utf8Slice(input, match[0], match[1])
    if mValue.count == 4 { return match[0] != 0 }
    let trimmed = mValue.trimmingCharacters(in: CharacterSet(charactersIn: "()[]"))
    return trimmed.count == 4
}

private func validateNotRipSuffix(_ input: String, _ match: [Int]) -> Bool {
    !utf8Slice(input, match[0], match[1]).lowercased().hasSuffix("rip")
}

private func validateNotXHPrefix(_ input: String, _ match: [Int]) -> Bool {
    let reXH = re(#"(?i)\b[xh]\b"#)
    let prefix = utf8Slice(input, 0, match[0])
    return reXH.firstMatch(in: prefix, options: [], range: NSRange(location: 0, length: (prefix as NSString).length)) == nil
}

private func processEditionRemastered(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    if let v = m.value as? String, v == "Remastered", result["remastered"] == nil {
        let extra = ParseMeta()
        extra.mIndex = m.mIndex
        extra.mValue = m.mValue
        extra.value = true
        result["remastered"] = extra
    }
    return m
}

private let groupUntilRe = re(#"(?i)- ?([^\-. \[]+[^\-. \[)\]E\d][^\-. \[)\]]*)(?:\[[\w.-]+])?"#)
private let groupUntilNeg = re(#"(?i)- ?(?:\d+$|S\d+|\d+x|ep?\d+|[^\[\]]+]$)"#)

private func processGroupRegexUntilValid(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    let validator = validateAnd([
        validateNotMatch(groupUntilNeg),
        validateLookahead(#"(?:[ .]\w{2,4}$|$)"#, flags: "i", polarity: true),
    ])
    var offset = 0
    let total = utf8Count(title)
    while offset < total {
        let slice = utf8Slice(title, offset, total)
        guard var idxs = firstMatchIndices(groupUntilRe, in: slice) else { return m }
        for i in idxs.indices where idxs[i] >= 0 {
            idxs[i] += offset
        }
        if validator(title, idxs) {
            m.mIndex = idxs[0]
            m.mValue = utf8Slice(title, idxs[0], idxs[1])
            if idxs.count >= 4, idxs[2] >= 0, idxs[3] >= 0 {
                m.value = utf8Slice(title, idxs[2], idxs[3])
            } else {
                m.value = m.mValue
            }
            return m
        }
        offset = idxs[1]
        if offset == idxs[0] { offset += 1 }
    }
    return m
}

private let volumesAfterYearRe = re(#"(?i)\bvol(?:ume)?[. -]*(\d{1,3})"#)

private func processVolumesAfterYear(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    var startIndex = 0
    if let yr = result["year"] {
        startIndex = min(yr.mIndex, utf8Count(title))
    }
    let slice = utf8Slice(title, startIndex, utf8Count(title))
    guard let mIdxs = firstMatchIndices(volumesAfterYearRe, in: slice), mIdxs.count >= 4, mIdxs[2] >= 0 else {
        return m
    }
    let mStr = utf8Slice(title, startIndex + mIdxs[2], startIndex + mIdxs[3])
    if let num = Int(mStr) {
        m.mIndex = mIdxs[0]
        m.mValue = utf8Slice(title, startIndex + mIdxs[0], startIndex + mIdxs[1])
        m.value = [num]
        m.remove = true
    }
    return m
}

private let btRe = re(#"(?i)(?:movie\W*|film\W*|^)?(?:[ .]+-[ .]+|[(\[][ .]*)(\d{1,4})(?:a|b|v\d|\.\d)?(?:\W|$)(?:movie|film|\d+)?"#)
private let btReNegBefore = re(#"(?i)(?:movie\W*|film\W*)(?:[ .]+-[ .]+|[(\[][ .]*)(\d{1,4})"#)
private let btReNegAfter = re(#"(?i)(?:movie|film)|(\d{1,4})(?:a|b|v\d|\.\d)(?:\W)(?:\d+)"#)
private let mtRe = re(#"(?i)^(?:[(\[-][ .]?)?(\d{1,4})(?:a|b|v\d)?(?:\Wmovie|\Wfilm|-\d)?(?:\W|$)"#)
private let mtReNegAfter = re(#"(?i)(\d{1,4})(?:a|b|v\d)?(?:\Wmovie|\Wfilm|-\d)"#)
private let commonResolutionNeg = re(#"\[(?:480|720|1080)\]"#)
private let commonFPSNeg = re(#"(?i)\d+(?:fps|帧率?)"#)

private func matches(_ regex: NSRegularExpression, _ s: String) -> Bool {
    regex.firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) != nil
}

private func processEpisodesFallback(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    if m.value != nil { return m }
    var startIndex = 0
    for component in ["year", "seasons"] {
        if let cm = result[component], cm.mIndex > 0, startIndex == 0 || cm.mIndex < startIndex {
            startIndex = cm.mIndex
        }
    }
    var endIndex = utf8Count(title)
    for component in ["resolution", "quality", "codec", "audio"] {
        if let cm = result[component], cm.mIndex > 0, cm.mIndex < endIndex {
            endIndex = cm.mIndex
        }
    }
    let beginningTitle = utf8Slice(title, 0, endIndex)
    startIndex = min(startIndex, utf8Count(title))
    let middleTitle = utf8Slice(title, startIndex, max(endIndex, startIndex))
    var mIdxs = firstMatchIndices(btRe, in: beginningTitle)
    var mStr = ""
    if let idxs = mIdxs, idxs.count >= 2 {
        mStr = utf8Slice(beginningTitle, idxs[0], idxs[1])
        if idxs[0] == 0 || matches(btReNegBefore, mStr) || matches(btReNegAfter, mStr) || matches(commonResolutionNeg, mStr) || matches(commonFPSNeg, mStr) {
            mIdxs = nil
            mStr = ""
        } else if idxs.count > 2 {
            mStr = utf8Slice(beginningTitle, idxs[2], idxs[3])
        }
    }
    if mStr.isEmpty {
        mIdxs = firstMatchIndices(mtRe, in: middleTitle)
        if let idxs = mIdxs, idxs.count > 3 {
            let after = utf8Slice(middleTitle, idxs[2], utf8Count(middleTitle))
            if matches(mtReNegAfter, after) || matches(commonResolutionNeg, mStr) {
                mIdxs = nil
                mStr = ""
            } else {
                mStr = utf8Slice(middleTitle, idxs[2], idxs[3])
            }
        }
    }
    if !mStr.isEmpty {
        mStr = replaceAll(nonDigitRegex, in: mStr, with: "")
        if let ep = Int(mStr) {
            let loc = (title as NSString).range(of: mStr).location
            m.mIndex = loc == NSNotFound ? 0 : utf16ToUtf8(title, loc)
            m.mValue = mStr
            m.value = [ep]
        }
    }
    return m
}

private let capituloRe = re(#"(?i)capitulo|ao"#)
private let dubladoRe = re(#"(?i)dublado"#)

private func processLanguagesPortuguese(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    m.mIndex = 0
    m.mValue = ""
    let vs = m.value as? ValueSet
    if let vs, vs.exists("pt") || vs.exists("es") { return m }
    let em = result["episodes"]
    if (em != nil && !(em!.mValue.isEmpty) && matches(capituloRe, em!.mValue)) || matches(dubladoRe, title) {
        let set = vs ?? ValueSet()
        m.value = set.append("pt")
    }
    return m
}

private func processSubbedFromLanguages(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    guard let lm = result["languages"], let s = lm.value as? ValueSet, s.exists("multi subs") else { return m }
    m.value = true
    return m
}

private func processDubbedFromLanguages(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    guard let lm = result["languages"], let s = lm.value as? ValueSet else { return m }
    if s.exists("multi audio") || s.exists("dual audio") {
        m.value = true
    }
    return m
}

private let groupBracketRe = re(#"^\[.+]$"#)

private func processGroupFalsePositive(_ title: String, _ m: ParseMeta, _ result: inout [String: ParseMeta]) -> ParseMeta {
    if !m.mValue.isEmpty && matches(groupBracketRe, m.mValue) {
        let endIndex = m.mIndex + utf8Count(m.mValue)
        for (_, km) in result {
            if km.mIndex > 0 && km.mIndex < endIndex {
                m.value = ""
                return m
            }
        }
    }
    m.mIndex = 0
    m.mValue = ""
    return m
}
// handlers: 393
private let handlers: [Handler] = [
        Handler(
            field: "title",
            pattern: re(#"(?i)360.Degrees.of.Vision.The.Byakugan'?s.Blind.Spot"#),
            remove: true
        ),
        Handler(
            field: "title",
            pattern: re(#"(?i)\b(?:INTERNAL|HFR)\b"#),
            remove: true
        ),
        Handler(
            field: "ppv",
            pattern: re(#"(?i)\bPPV\b"#),
            remove: true,
            skipFromTitle: true
        ),
        Handler(
            field: "ppv",
            pattern: re(#"(?i)\b\W?Fight.?Nights?\W?\b"#),
            skipFromTitle: true
        ),
        Handler(
            field: "site",
            pattern: re(#"(?i)^(www?[., ][\w-]+[. ][\w-]+(?:[. ][\w-]+)?)\s+-\s*"#),
            remove: true,
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "site",
            pattern: re(#"(?i)^((?:www?[\.,])?[\w-]+\.[\w-]+(?:\.[\w-]+)*?)\s+-\s*"#),
            keepMatching: true
        ),
        Handler(
            field: "site",
            pattern: re(#"(?i)\bwww[., ][\w-]+[., ](?:rodeo|hair)\b"#),
            remove: true,
            skipFromTitle: true
        ),
        Handler(
            field: "episodeCode",
            pattern: re(#"([\[(]([a-z0-9]{8}|[A-Z0-9]{8})[\])])(?:\.[a-zA-Z0-9]{1,5}$|$)"#),
            transform: toUppercase,
            remove: true,
            matchGroup: 1,
            valueGroup: 2
        ),
        Handler(
            field: "episodeCode",
            pattern: re(#"\[([A-Z0-9]{8})]"#),
            validateMatch: validateMatch(re(#"(?:[A-Z]+\d|\d+[A-Z])"#)),
            transform: toUppercase,
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)\b(?:4k|2160p|1080p|720p|480p)\b.+\b(4k|2160p|1080p|720p|480p)\b"#),
            transform: toLowercase,
            remove: true,
            matchGroup: 1
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)\b[(\[]?4k[)\]]?\b"#),
            transform: toValue(#"4k"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)21600?[pi]"#),
            transform: toValue(#"4k"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)[(\[]?3840x\d{4}[)\]]?"#),
            transform: toValue(#"4k"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)[(\[]?1920x\d{3,4}[)\]]?"#),
            transform: toValue(#"1080p"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)[(\[]?1280x\d{3}[)\]]?"#),
            transform: toValue(#"720p"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)[(\[]?\d{3,4}x(\d{3,4})[)\]]?"#),
            transform: toWithSuffix(#"p"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)(480|720|1080)0[pi]"#),
            transform: toWithSuffix(#"p"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)(?:BD|HD|M)(720|1080|2160)"#),
            transform: toWithSuffix(#"p"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)(480|576|720|1080|2160)[pi]"#),
            transform: toWithSuffix(#"p"#),
            remove: true
        ),
        Handler(
            field: "resolution",
            pattern: re(#"(?i)(?:^|\D)(\d{3,4})[pi]"#),
            transform: toWithSuffix(#"p"#),
            remove: true
        ),
        Handler(
            field: "date",
            pattern: re(#"(?:\W|^)([(\[]?((?:19[6-9]|20[012])[0-9]([. \-/\\])(?:0[1-9]|1[012])([. \-/\\])(?:0[1-9]|[12][0-9]|3[01]))[)\]]?)(?:\W|$)"#),
            validateMatch: validateMatchedGroupsAreSame(3, 4),
            transform: toDateYMD,
            remove: true,
            matchGroup: 1,
            valueGroup: 2
        ),
        Handler(
            field: "date",
            pattern: re(#"(?:\W|^)[(\[]?((?:0[1-9]|[12][0-9]|3[01])([. \-/\\])(?:0[1-9]|1[012])([. \-/\\])(?:19[6-9]|20[012])[0-9])[)\]]?(?:\W|$)"#),
            validateMatch: validateMatchedGroupsAreSame(2, 3),
            transform: toDateDMY,
            remove: true
        ),
        Handler(
            field: "date",
            pattern: re(#"(?:\W)[(\[]?((?:0[1-9]|1[012])([. \-/\\])(?:0[1-9]|[12][0-9]|3[01])([. \-/\\])(?:19[6-9]|20[012])[0-9])[)\]]?(?:\W|$)"#),
            validateMatch: validateMatchedGroupsAreSame(2, 3),
            transform: toDateMDY,
            remove: true
        ),
        Handler(
            field: "date",
            pattern: re(#"(?:\W)[(\[]?((?:0[1-9]|1[012])([. \-/\\])(?:0[1-9]|[12][0-9]|3[01])([. \-/\\])(?:[0][1-9]|[0126789][0-9]))[)\]]?(?:\W|$)"#),
            validateMatch: validateMatchedGroupsAreSame(2, 3),
            transform: toDateMDYY,
            remove: true
        ),
        Handler(
            field: "date",
            pattern: re(#"(?:\W)[(\[]?((?:0[1-9]|[12][0-9]|3[01])([. \-/\\])(?:0[1-9]|1[012])([. \-/\\])(?:[0][1-9]|[0126789][0-9]))[)\]]?(?:\W|$)"#),
            validateMatch: validateMatchedGroupsAreSame(2, 3),
            transform: toDateDMYY,
            remove: true,
            matchGroup: 1
        ),
        Handler(
            field: "date",
            pattern: re(#"(?i)(?:\W|^)[(\[]?((?:0?[1-9]|[12][0-9]|3[01])[. ]?(?:st|nd|rd|th)?([. \-/\\])(?:feb(?:ruary)?|jan(?:uary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sept?(?:ember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)([. \-/\\])(?:19[7-9]|20[012])[0-9])[)\]]?(?:\W|$)"#),
            validateMatch: validateMatchedGroupsAreSame(2, 3),
            transform: transformDateDayMonthYear,
            remove: true
        ),
        Handler(
            field: "date",
            pattern: re(#"(?i)(?:\W|^)[(\[]?((?:0?[1-9]|[12][0-9]|3[01])[. ]?(?:st|nd|rd|th)?([. \-/\\])(?:feb(?:ruary)?|jan(?:uary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sept?(?:ember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)([. \-/\\])(?:0[1-9]|[0126789][0-9]))[)\]]?(?:\W|$)"#),
            validateMatch: validateMatchedGroupsAreSame(2, 3),
            transform: transformDateDayMonthYY,
            remove: true
        ),
        Handler(
            field: "date",
            pattern: re(#"(?:\W|^)[(\[]?(20[012][0-9](?:0[1-9]|1[012])(?:0[1-9]|[12][0-9]|3[01]))[)\]]?(?:\W|$)"#),
            transform: toDateCompact,
            remove: true
        ),
        Handler(
            field: "year",
            pattern: re(#"[ .]?([(\[*]?((?:19\d|20[012])\d[ .]?-[ .]?(?:19\d|20[012])\d)[*)\]]?)[ .]?"#),
            transform: transformYearRangeComplete,
            remove: true,
            matchGroup: 1,
            valueGroup: 2
        ),
        Handler(
            field: "year",
            pattern: re(#"[(\[*][ .]?((?:19\d|20[012])\d[ .]?-[ .]?\d{2})(?:\s?[*)\]])?"#),
            transform: transformYearRangeComplete,
            remove: true
        ),
        Handler(
            field: "year",
            pattern: re(#"[(\[*]?\b(20[0-9]{2}|2100)[*\])]?"#),
            validateMatch: validateLookahead(#"(?:\D*\d{4}\b)"#, flags: #""#, polarity: false),
            transform: toYear,
            remove: true
        ),
        Handler(
            field: "year",
            pattern: re(#"(?i)(?:[(\[*]|.)((?:\d|[SE]|Cap[. ]?)?(?:19\d|20[012])\d(?:\d|kbps)?)[*)\]]?"#),
            validateMatch: validateYearCaptureIsFourDigits,
            transform: toYear,
            remove: true,
            matchGroup: 1
        ),
        Handler(
            field: "year",
            pattern: re(#"^[(\[]?((?:19\d|20[012])\d)(?:\d|kbps)?[)\]]?"#),
            validateMatch: validateYearNotBareFourCharTitle,
            transform: toYear,
            remove: true
        ),
        Handler(
            field: "extended",
            pattern: re(#"EXTENDED"#),
            transform: toBoolean
        ),
        Handler(
            field: "extended",
            pattern: re(#"(?i)- Extended"#),
            transform: toBoolean
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\b\d{2,3}(?:th)?[\.\s\-\+_\/(),]Anniversary[\.\s\-\+_\/(),](?:Edition|Ed)?\b"#),
            transform: toValue(#"Anniversary Edition"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\bUltimate[\.\s\-\+_\/(),]Edition\b"#),
            transform: toValue(#"Ultimate Edition"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\bExtended[\.\s\-\+_\/(),]Director'?s\b"#),
            transform: toValue(#"Director's Cut"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\b(?:custom.?)?Extended\b"#),
            transform: toValue(#"Extended Edition"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\bDirector'?s.?Cut\b"#),
            transform: toValue(#"Director's Cut"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\bCollector'?s\b"#),
            transform: toValue(#"Collector's Edition"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\bTheatrical\b"#),
            transform: toValue(#"Theatrical"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\buncut(?:.gems)?\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:.gems)"#)),
            transform: toValue(#"Uncut"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\bIMAX\b"#),
            transform: toValue(#"IMAX"#),
            remove: true,
            skipFromTitle: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\b\.Diamond\.\b"#),
            transform: toValue(#"Diamond Edition"#),
            remove: true
        ),
        Handler(
            field: "edition",
            pattern: re(#"(?i)\bRemaster(?:ed)?\b|\b[\[(]?REKONSTRUKCJA[\])]?\b"#),
            transform: toValue(#"Remastered"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "edition",
            process: processEditionRemastered
        ),
        Handler(
            field: "releaseTypes",
            pattern: re(#"(?i)\b((?:OAD|OAV|ODA|ONA|OVA)\b(?:[+&]\b(?:OAD|OAV|ODA|ONA|OVA)\b)?)"#),
            transform: transformReleaseTypesMulti,
            remove: true,
            matchGroup: 1
        ),
        Handler(
            field: "releaseTypes",
            pattern: re(#"(?i)\b(OAD|OAV|ODA|ONA|OVA)(?:[ .-]*\d{1,3})?(?:v\d)?"#),
            transform: transformReleaseTypesSingle,
            remove: true,
            matchGroup: 1
        ),
        Handler(
            field: "upscaled",
            pattern: re(#"(?i)\b(?:AI.?)?(Upscal(ed?|ing)|Enhanced?)\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "upscaled",
            pattern: re(#"(?i)\b(?:iris2|regrade|ups(?:uhd|fhd|hd|4k)?)\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "upscaled",
            pattern: re(#"(?i)\b\.AI\.\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "convert",
            pattern: re(#"\bCONVERT\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "hardcoded",
            pattern: re(#"\bHC|HARDCODED\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "proper",
            pattern: re(#"(?i)\b(?:REAL.)?PROPER\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "repack",
            pattern: re(#"\b(?i)REPACK|RERIP\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "retail",
            pattern: re(#"(?i)\bRetail\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "documentary",
            pattern: re(#"(?i)\bDOCU(?:menta?ry)?\b"#),
            transform: toBoolean,
            skipFromTitle: true
        ),
        Handler(
            field: "unrated",
            pattern: re(#"(?i)\bunrated\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "uncensored",
            pattern: re(#"(?i)\buncensored\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "commentary",
            pattern: re(#"(?i)\bcommentary\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "region",
            pattern: re(#"R\dJ?\b"#),
            remove: true,
            skipIfFirst: true
        ),
        Handler(
            field: "region",
            pattern: re(#"\b(PAL|NTSC|SECAM)\b"#),
            transform: toUppercase,
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:H[DQ][ .-]*)?CAM(?:H[DQ])?(?:[ .-]*Rip)?\b"#),
            transform: toValue(#"CAM"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:H[DQ][ .-]*)?S[ .-]+print"#),
            transform: toValue(#"CAM"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:HD[ .-]*)?T(?:ELE)?S(?:YNC)?(?:Rip)?\b"#),
            transform: toValue(#"TeleSync"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"\b(?:HD[ .-]*)?T(?:ELE)?C(?:INE)?(?:Rip)?\b"#),
            transform: toValue(#"TeleCine"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:DVD?|BD|BR|HD)?[ .-]*Scr(?:eener)?\b"#),
            transform: toValue(#"SCR"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bP(?:RE)?-?(HD|DVD)(?:Rip)?\b"#),
            transform: toValue(#"SCR"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(Blu[ .-]*Ray)\b(?:.*remux)"#),
            transform: toValue(#"BluRay REMUX"#),
            remove: true,
            matchGroup: 1
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)(?:BD|BR|UHD)[- ]?remux"#),
            transform: toValue(#"BluRay REMUX"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)(?:remux.*)\bBlu[ .-]*Ray\b"#),
            transform: toValue(#"BluRay REMUX"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bremux\b"#),
            transform: toValue(#"REMUX"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bBlu[ .-]*Ray\b(?:[ .-]*Rip)?"#),
            validateMatch: validateNotRipSuffix,
            transform: toValue(#"BluRay"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bUHD[ .-]*Rip\b"#),
            transform: toValue(#"UHDRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bHD[ .-]*Rip\b"#),
            transform: toValue(#"HDRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bMicro[ .-]*HD\b"#),
            transform: toValue(#"HDRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:BR|Blu[ .-]*Ray)[ .-]*Rip\b"#),
            transform: toValue(#"BRRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bBD[ .-]*Rip\b|\bBDR\b|\bBD-RM\b|[\[(]BD[\]) .,-]"#),
            transform: toValue(#"BDRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:HD[ .-]*)?DVD[ .-]*Rip\b"#),
            transform: toValue(#"DVDRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bVHS[ .-]*Rip\b"#),
            transform: toValue(#"DVDRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bDVD(?:R\d?)?\b"#),
            transform: toValue(#"DVD"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bVHS\b"#),
            transform: toValue(#"DVD"#),
            remove: true,
            skipIfFirst: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bPPVRip\b"#),
            transform: toValue(#"PPVRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bHD.?TV.?Rip\b"#),
            transform: toValue(#"HDTVRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bDVB[ .-]*(?:Rip)?\b"#),
            transform: toValue(#"HDTV"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bSAT[ .-]*Rips?\b"#),
            transform: toValue(#"SATRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bTVRips?\b"#),
            transform: toValue(#"TVRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bR5\b"#),
            transform: toValue(#"R5"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bWEB[ .-]*Rip\b"#),
            transform: toValue(#"WEBRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bWEB[ .-]?DL[ .-]?Rip\b"#),
            transform: toValue(#"WEB-DLRip"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bWEB[ .-]*(DL|.BDrip|.DLRIP)\b"#),
            transform: toValue(#"WEB-DL"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:DL|WEB|BD|BR)MUX\b"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"\b(DivX|XviD)\b"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\b(?:\w.)?WEB\b|\bWEB(?:(?:[ \.\-\(\],]+\d))?\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:\w.)WEB\b|\bWEB(?:(?:[ \.\-\(\],]+\d))\b"#)),
            transform: toValue(#"WEB"#),
            remove: true,
            skipFromTitle: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bPDTV\b"#),
            transform: toValue(#"PDTV"#),
            remove: true
        ),
        Handler(
            field: "quality",
            pattern: re(#"(?i)\bHD(?:.?TV)?\b"#),
            transform: toValue(#"HDTV"#),
            remove: true
        ),
        Handler(
            field: "bitDepth",
            pattern: re(#"(?i)(?:8|10|12)[-.]?bit\b"#),
            transform: toLowercase,
            remove: true
        ),
        Handler(
            field: "bitDepth",
            pattern: re(#"(?i)\bhevc\s?10\b"#),
            transform: toValue(#"10bit"#)
        ),
        Handler(
            field: "bitDepth",
            pattern: re(#"(?i)\bhdr10(?:\+|plus)?\b"#),
            transform: toValue(#"10bit"#)
        ),
        Handler(
            field: "bitDepth",
            pattern: re(#"(?i)\bhi10\b"#),
            transform: toValue(#"10bit"#)
        ),
        Handler(
            field: "bitDepth",
            process: removeFromValue(re(#"[ -]"#))
        ),
        Handler(
            field: "hdr",
            pattern: re(#"(?i)\bDV\b|dolby.?vision|\bDoVi\b"#),
            transform: toValueSet(#"DV"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "hdr",
            pattern: re(#"(?i)HDR10(?:\+|plus)"#),
            transform: toValueSet(#"HDR10+"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "hdr",
            pattern: re(#"(?i)\bHDR(?:10)?\b"#),
            transform: toValueSet(#"HDR"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "hdr",
            pattern: re(#"(?i)\bSDR\b"#),
            transform: toValueSet(#"SDR"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\b(3D)\b.*\b(Half-?SBS|H[-\\/]?SBS)\b"#),
            transform: toValue(#"3D HSBS"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\bHalf.Side.?By.?Side\b"#),
            transform: toValue(#"3D HSBS"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\b(3D)\b.*\b(Full-?SBS|SBS)\b"#),
            transform: toValue(#"3D SBS"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\bSide.?By.?Side\b"#),
            transform: toValue(#"3D SBS"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\b(3D)\b.*\b(Half-?OU|H[-\\/]?OU)\b"#),
            transform: toValue(#"3D HOU"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\bHalf.?Over.?Under\b"#),
            transform: toValue(#"3D HOU"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\b(3D)\b.*\b(OU)\b"#),
            transform: toValue(#"3D OU"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\bOver.?Under\b"#),
            transform: toValue(#"3D OU"#)
        ),
        Handler(
            field: "threeD",
            pattern: re(#"(?i)\b((?:BD)?3D)\b"#),
            transform: toValue(#"3D"#),
            skipIfFirst: true
        ),
        Handler(
            field: "codec",
            pattern: re(#"(?i)\b[xh][-. ]?26[45]"#),
            transform: toLowercase,
            remove: true
        ),
        Handler(
            field: "codec",
            pattern: re(#"(?i)\bhevc(?:\s?10)?\b"#),
            transform: toValue(#"hevc"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "codec",
            pattern: re(#"(?i)\b(?:dvix|mpeg2|divx|xvid|avc)\b"#),
            transform: toLowercase,
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "codec",
            process: removeFromValue(re(#"[ .-]"#))
        ),
        Handler(
            field: "channels",
            pattern: re(#"(?i)5[.\s]1(?:ch|-S\d+)?\b"#),
            transform: toValueSet(#"5.1"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "channels",
            pattern: re(#"(?i)\b(?:x[2-4]|5[\W]1(?:x[2-4])?)\b"#),
            transform: toValueSet(#"5.1"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "channels",
            pattern: re(#"(?i)\b7[.\- ]1(?:.?ch(?:annel)?)?\b"#),
            transform: toValueSet(#"7.1"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "channels",
            pattern: re(#"(?i)(?:\b|AAC|DDP)\+?(2[.\s]0)(?:x[2-4])?\b"#),
            transform: toValueSet(#"2.0"#),
            remove: true,
            keepMatching: true,
            matchGroup: 1
        ),
        Handler(
            field: "channels",
            pattern: re(#"(?i)\b2\.0\b"#),
            transform: toValueSet(#"2.0"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "channels",
            pattern: re(#"(?i)\bstereo\b"#),
            transform: toValueSet(#"stereo"#),
            keepMatching: true
        ),
        Handler(
            field: "channels",
            pattern: re(#"(?i)\bmono\b"#),
            transform: toValueSet(#"mono"#),
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\b(?:.+HR)?(?:DTS.?HD.?Ma(?:ster)?|DTS.?X)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:.+HR)"#)),
            transform: toValueSet(#"DTS Lossless"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\bDTS(?:(?:.?HD.?Ma(?:ster)?|.X))?.?(?:HD.?HR|HD)?\b"#),
            validateMatch: validateNotMatch(re(#"(?i)DTS(?:.?HD.?Ma(?:ster)?|.X)"#)),
            transform: toValueSet(#"DTS Lossy"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\b(?:Dolby.?)?Atmos\b"#),
            transform: toValueSet(#"Atmos"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\b(?:True[ .-]?HD|\.True\.)\b"#),
            transform: toValueSet(#"TrueHD"#),
            remove: true,
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"\bTRUE\b"#),
            transform: toValueSet(#"TrueHD"#),
            remove: true,
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\bFLAC(?:\d\.\d)?(?:x\d+)?\b"#),
            transform: toValueSet(#"FLAC"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\bDD2?[+p]|DD Plus|Dolby Digital Plus|DDP5[ ._]1"#),
            transform: toValueSet(#"DDP"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)E-?AC-?3(?:-S\d+)?"#),
            transform: toValueSet(#"EAC3"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\b(DD|Dolby.?Digital|DolbyD)\b"#),
            transform: toValueSet(#"DD"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\b(AC-?3(?:x2)?(?:-S\d+)?)\b"#),
            transform: toValueSet(#"AC3"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"\bQ?AAC(?:[. ]?2[. ]0|x2)?\b"#),
            transform: toValueSet(#"AAC"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\bL?PCM\b"#),
            transform: toValueSet(#"PCM"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\bOPUS(?:\b|\d)(?:.*[ ._-](?:\d{3,4}p))?"#),
            validateMatch: validateNotMatch(re(#"(?i)OPUS(?:\b|\d)(?:.*[ ._-](?:\d{3,4}p))"#)),
            transform: toValueSet(#"OPUS"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\b(?:H[DQ])?.?(?:Clean.?Aud(?:io)?)\b"#),
            transform: toValueSet(#"HQ"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "channels",
            pattern: re(#"\[([257][.-][01])]"#),
            transform: transformValueSetLowercaseMatch,
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "group",
            process: processGroupRegexUntilValid,
            remove: true
        ),
        Handler(
            field: "container",
            pattern: re(#"(?i)\.?[\[(]?\b(MKV|AVI|MP4|WMV|MPG|MPEG)\b[\])]?"#),
            transform: toLowercase
        ),
        Handler(
            field: "volumes",
            pattern: re(#"(?i)\bvol(?:s|umes?)?[. -]*(?:\d{1,3}[., +/\\&-]+)+\d{1,3}\b"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "volumes",
            process: processVolumesAfterYear
        ),
        Handler(
            field: "country",
            pattern: re(#"\b(US|UK|AU|NZ)\b"#)
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(temporadas?|completa)\b"#),
            transform: toValueSet(#"es"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:INT[EÉ]GRALE?)\b"#),
            transform: toValueSet(#"fr"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:Saison)\b"#),
            transform: toValueSet(#"fr"#),
            keepMatching: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\b(?:INTEGRALE?|INTÉGRALE?)\b"#),
            transform: toBoolean,
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)(?:\bthe\W)?(?:\bcomplete|collection|dvd)?\b[ .]?\bbox[ .-]?set\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)(?:\bthe\W)?(?:\bcomplete|collection|dvd)?\b[ .]?\bmini[ .-]?series\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)(?:\bthe\W)?(?:\bcomplete|full|\ball)\b.*\b(?:series|seasons|collection|episodes|set|pack|movies)\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\b(?:series|seasons|movies?)\b.*\b(?:complete|collection)\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)(?:\bthe\W)?\bultimate\b[ .]\bcollection\b"#),
            transform: toBoolean,
            keepMatching: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\bcollection\b.*\b(?:set|pack|movies)\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\bcollection(?:(\s\[|\s\())"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\bkolekcja\b(?:\Wfilm(?:y|ów|ow)?)?"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)duology|trilogy|quadr[oi]logy|tetralogy|pentalogy|hexalogy|heptalogy|anthology"#),
            transform: toBoolean,
            keepMatching: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\bcompleta\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\bsaga\b"#),
            transform: toBoolean,
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)\b\[Complete\]\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"(?i)(?:A.?|The.?)?\bComplete\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:A.?|The.?)\bComplete"#)),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "complete",
            pattern: re(#"\bCOMPLETE\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:complete\W|seasons?\W|\W|^)((?:s\d{1,2}[., +/\\&-]+)+s\d{1,2}\b)"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:complete\W|seasons?\W|\W|^)[(\[]?(s\d{2,}-\d{2,}\b)[)\]]?"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:complete\W|seasons?\W|\W|^)[(\[]?(s[1-9]-[2-9]\b)[)\]]?"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)\d+ª(?:.+)?(?:a.?)?\d+ª(?:(?:.+)?(?:temporadas?))"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete\W)?(?:seasons?|[Сс]езони?|sezon|temporadas?|stagioni)[. ]?[-:]?[. ]?[(\[]?((?:\d{1,2} ?(?:[,/\\&]+ ?)+)+\d{1,2}\b)[)\]]?"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete\W)?(?:seasons|[Сс]езони?|sezon|temporadas?|stagioni)[. ]?[-:]?[. ]?[(\[]?((?:\d{1,2}[. -]+)+0?[1-9]\d?\b)[)\]]?"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete\W)?season[. ]?[(\[]?((?:\d{1,2}[. -]+)+[1-9]\d?\b)[)\]]?(?:.*\.\w{2,4}$)?"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:.*\.\w{2,4}$)"#)),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete\W)?\bseasons?\b[. -]?(\d{1,2}[. -]?(?:to|thru|and|\+|:)[. -]?\d{1,2})\b"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)\bseason\b[ .-]?(\d{1,2}[ .-]?(?:to|thru|and|\+)[ .-]?\bseason\b[ .-]?\d{1,2})"#),
            transform: toIntRange
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(\d{1,2})(?:-?й)?[. _]?(?:[Сс]езон|sez(?:on)?)(?:\P{L}?\D|$)"#),
            transform: toIntArray,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete\W)?(?:saison|seizoen|sezon(?:SO?)?|stagione|season|series|temp(?:orada)?):?[. ]?(\d{1,2})"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)[Сс]езон:?[. _]?№?(\d{1,2})(?:\d)?"#),
            validateMatch: validateNotMatch(re(#"(?i)\d{3}"#)),
            transform: toIntArray,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:\D|^)(\d{1,2})Â?[°ºªa]?[. ]*temporada"#),
            transform: toIntArray,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)t(\d{1,3})(?:[ex]+|$)"#),
            transform: toIntArray,
            remove: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete)?(?:\W|^)so?([01]?[0-5]?[1-9])(?:[\Wex]|\d{2}\b)"#),
            transform: toIntArray,
            keepMatching: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:so?|t)(\d{1,4})[. ]?[xх-]?[. ]?(?:e|x|х|ep|-|\.)[. ]?\d{1,4}(?:[abc]|v0?[1-4]|\D|$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete\W)?(?:\W|^)(\d{1,2})[. ]?(?:st|nd|rd|th)[. ]*season"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?:\D|^)(\d{1,2})[Xxх]\d{1,3}(?:\D|$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"\bSn([1-9])(?:\D|$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"[\[(](\d{1,2})\.\d{1,3}[)\]]"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"-\s?(\d{1,2})\.\d{2,3}\s?-"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"^(\d{1,2})\.\d{2,3} - "#),
            transform: toIntArray,
            skipIfBefore: ["year", "source", "resolution"]
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?:^|\/)(?:20-20)?(\d{1,2})-\d{2}\b(?:-\d)?"#),
            validateMatch: validateNotMatch(re(#"^(?:20-20)|(\d{1,2})-\d{2}\b(?:-\d)"#)),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"[^\w-](\d{1,2})-\d{2}(?:\.\w{2,4}$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?:\bEp?(?:isode)? ?\d+\b.*)?\b(\d{2})[ ._]\d{2}(?:.F)?\.\w{2,4}$"#),
            validateMatch: validateNotMatch(re(#"(?:\bEp?(?:isode)? ?\d+\b.*)"#)),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)\bEp(?:isode)?\W+(\d{1,2})\.\d{1,3}\b"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:(?:\bthe\W)?\bcomplete)?(?:[a-z])?\bs(\d{1,3})(?:[\Wex]|\d{2}\b|$)"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:[a-z])\bs\d{1,3}"#)),
            transform: toIntArray,
            keepMatching: true
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)\bSeasons?\b.*\b(\d{1,2}-\d{1,2})\b"#),
            transform: toIntRange
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)(?:\W|^)(\d{1,2})(?:e|ep)\d{1,3}(?:\W|$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "seasons",
            pattern: re(#"(?i)[\[\(]ТВ-(\d{1,2})[\)\]]"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:[\W\d]|^)e[ .]?[(\[]?(\d{1,3}(?:[à .-]*(?:[&+]|e){1,2}[ .]?\d{1,3})+)(?:\W|$)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:[\W\d]|^)ep[ .]?[(\[]?(\d{1,3}(?:[ .-]*(?:[&+]|ep){1,2}[ .]?\d{1,3})+)(?:\W|$)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:[\W\d]|^)\d+[xх][ .]?[(\[]?(\d{1,3}(?:[ .]?[xх][ .]?\d{1,3})+)(?:\W|$)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:[\W\d]|^)(?:episodes?|[Сс]ерии:?)[ .]?[(\[]?(\d{1,3}(?:[ .+]*[&+][ .]?\d{1,3})+)(?:\W|$)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)[(\[]?(?:\D|^)(\d{1,3}[ .]?ao[ .]?\d{1,3})[)\]]?(?:\W|$)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:[\W\d]|^)(?:e|eps?|episodes?|[Сс]ерии:?|\d+[xх])[ .]*[(\[]?(\d{1,3}(?:-\d{1,3})+)(?:\W|$)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\bs\d{1,2}[ .]*-[ .]*\b(\d{1,3}(?:[ .]*~[ .]*\d{1,3})+)\b"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:so?|t)\d{1,4}[. ]?[xх-]?[. ]?(?:e|x|х|ep)[. ]?(\d{1,4})(?:[abc]|v0?[1-4]|\D|$)"#),
            transform: toIntArray,
            remove: true
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:so?|t)\d{1,2}\s?[-.]\s?(\d{1,4})(?:[abc]|v0?[1-4]|\D|$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\b(?:so?|t)\d{2}(\d{2})\b"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:\W|^)(\d{1,3}(?:[ .]*~[ .]*\d{1,3})+)(?:\W|$)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)-\s(\d{1,3}[ .]*-[ .]*\d{1,3})(?:-\d*)?(?:\W|$)"#),
            validateMatch: validateNotMatch(re(#"(?i)-\s(\d{1,3}[ .]*-[ .]*\d{1,3})(?:-\d*)"#)),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)s\d{1,2}\s?\((\d{1,3}[ .]*-[ .]*\d{1,3})\)"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?:^|\/)(?:20-20)?\d{1,2}-(\d{2})\b(?:-\d)?"#),
            validateMatch: validateNotMatch(re(#"^(?:20-20)|\d{1,2}-(\d{2})\b(?:-\d)"#)),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?:\d-)?\b\d{1,2}-(\d{2})(?:\.\w{2,4}$)"#),
            validateMatch: validateNotMatch(re(#"(?:\d-)\b\d{1,2}-(\d{2})"#)),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:^\[.+].+)([. ]+-[. ]*(\d{1,4})[. ]+)(?:\W)"#),
            transform: toIntArray,
            matchGroup: 1,
            valueGroup: 2
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:(?:seasons?|[Сс]езони?)\P{L}*)?(?:[ .(\[-]|^)(\d{1,3}(?:[ .]?[,&+~][ .]?\d{1,3})+)(?:[ .)\]-]|$)"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:(?:seasons?|[Сс]езони?)\P{L}*)"#)),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:(?:seasons?|[Сс]езони?)\P{L}*)?(?:20-20)?(?:[ .(\[-]|^)(\d{1,4}(?:-\d{1,4})+)(?:[ .)(\]]|[+-]\D|$)"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:(?:seasons?|[Сс]езони?)\P{L}*|^)(?:20-20)"#)),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\bEp(?:isode)?\W+\d{1,2}\.(\d{1,3})\b"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)Ep.\d+.-.\d+"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(\d{1,3})[. ]?(?:of|из|iz)[. ]?\d{1,3}"#),
            validateMatch: validateAnd([validateLookbehind(#"(?:\D|^)"#, flags: #"i"#, polarity: true), validateLookahead(#"(?:\D|$)"#, flags: #"i"#, polarity: true)]),
            transform: toIntRangeTill
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:\b[ée]p?(?:isode)?|[Ээ]пизод|[Сс]ер(?:ии|ия|\.)?|caa?p(?:itulo)?|epis[oó]dio)[. ]?[-:#№]?[. ]?(\d{1,4})(?:[abc]|v0?[1-4]|\W|$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\b(\d{1,3})(?:-?я)?[ ._-]*(?:ser(?:i?[iyj]a|\b)|[Сс]ер(?:ии|ия|\.)?)"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:\D|^)\d{1,2}[. ]?[Xxх][. ]?(\d{1,3})(?:[abc]|v0?[1-4]|\D|$)"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)[\[(]\d{1,2}\.(\d{1,3})[)\]]"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"\b[Ss](?:eason\W?)?\d{1,2}[ .](\d{1,2})\b"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)-\s?\d{1,2}\.(\d{2,3})\s?-"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"^\d{1,2}\.(\d{2,3}) - "#),
            transform: toIntArray,
            skipIfBefore: ["year", "source", "resolution"]
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\b\d{2}[ ._-](\d{2})(?:.F)?\.\w{2,4}$"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:^)?\[(\d{2,3})](?:(?:\.\w{2,4})?$)?"#),
            validateMatch: validateAnd([validateNotAtStart, validateNotAtEnd, validateNotMatch(re(#"(?i)(?:720|1080)|\[(\d{2,3})](?:(?:\.\w{2,4})$)"#))]),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\bodc[. ]+(\d{1,3})\b"#),
            transform: toIntArray
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\b264\b|\b265\b"#),
            validateMatch: validateNotXHPrefix,
            transform: toIntArray,
            remove: true
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)(?:\W|^)(?:\d+)?(?:e|ep)(\d{1,3})(?:\W|$)"#),
            transform: toIntArray,
            remove: true
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)\d+.-.\d+TV"#),
            transform: toIntRange,
            remove: true
        ),
        Handler(
            field: "episodes",
            pattern: re(#"(?i)season\s*\d{1,2}\s*(\d{1,4}\s*-\s*\d{1,4})"#),
            transform: toIntRange
        ),
        Handler(
            field: "episodes",
            process: processEpisodesFallback
        ),
        Handler(
            field: "subbed",
            pattern: re(#"(?i)\bSUB(?:FRENCH)\b|\b(?:DAN|E|FIN|PL|SLO|SWE)SUBS?\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bmulti(?:ple)?[ .-]*(?:su?$|sub\w*|dub\w*)\b|msub"#),
            transform: toValueSet(#"multi subs"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bmulti(?:ple)?[ .-]*(?:lang(?:uages?)?|audio|VF2)?\b"#),
            transform: toValueSet(#"multi audio"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\btri(?:ple)?[ .-]*(?:audio|dub\w*)\b"#),
            transform: toValueSet(#"multi audio"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bdual[ .-]*(?:au?$|[aá]udio|line)\b"#),
            transform: toValueSet(#"dual audio"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bdual\b(?:[ .-]*sub)?"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:[ .-]*sub)"#)),
            transform: toValueSet(#"dual audio"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bengl?(?:sub[A-Z]*)?\b"#),
            transform: toValueSet(#"en"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\beng?sub[A-Z]*\b"#),
            transform: toValueSet(#"en"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bing(?:l[eéê]s)?\b"#),
            transform: toValueSet(#"en"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\besub\b"#),
            transform: toValueSet(#"en"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\benglish\W+(?:subs?|sdh|hi)\b"#),
            transform: toValueSet(#"en"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bEN\b"#),
            transform: toValueSet(#"en"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\benglish?\b"#),
            transform: toValueSet(#"en"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:JP|JAP|JPN)\b"#),
            transform: toValueSet(#"ja"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)(japanese|japon[eê]s)\b"#),
            transform: toValueSet(#"ja"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:KOR|kor[ .-]?sub)\b"#),
            transform: toValueSet(#"ko"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)(korean|coreano)\b"#),
            transform: toValueSet(#"ko"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:traditional\W*chinese|chinese\W*traditional)(?:\Wchi)?\b"#),
            transform: toValueSet(#"zh-tw"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bzh-hant\b"#),
            transform: toValueSet(#"zh-tw"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:mand[ae]rin|ch[sn])\b"#),
            transform: toValueSet(#"zh"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)(?:shang-?)?\bCH(?:I|T)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)shang-?"#)),
            transform: toValueSet(#"zh"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)(chinese|chin[eê]s|chi)\b"#),
            transform: toValueSet(#"zh"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bzh-hans\b"#),
            transform: toValueSet(#"zh"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bFR(?:a|e|anc[eê]s|VF[FQIB2]?)\b"#),
            transform: toValueSet(#"fr"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"\b(?:TRUE|SUB).?FRENCH\b|\bFRENCH\b|\bFre?\b"#),
            transform: toValueSet(#"fr"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"\b\[?(?:VF[FQRIB2]?\]?\b|(?:VOST)?FR2?)\b"#),
            transform: toValueSet(#"fr"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bVOST(?:FR?|A)?\b"#),
            transform: toValueSet(#"fr"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bspanish\W?latin|american\W*(?:spa|esp?)"#),
            transform: toValueSet(#"es-419"#),
            remove: true,
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:audio.)?lat(?:in?|ino)?\b"#),
            transform: toValueSet(#"es-419"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:audio.)?(?:ESP?|spa|(?:en[ .]+)?espa[nñ]ola?|castellano)\b"#),
            transform: toValueSet(#"es"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bes"#),
            validateMatch: validateLookahead(#"(?:\.(?:ass|ssa|srt|sub|idx)$)"#, flags: #"i"#, polarity: true),
            transform: toValueSet(#"es"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bspanish\W+subs?\b"#),
            transform: toValueSet(#"es"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(spanish|espanhol)\b"#),
            transform: toValueSet(#"es"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b[\.\s\[]?Sp[\.\s\]]?\b"#),
            transform: toValueSet(#"es"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:p[rt]|en|port)[. (\\/-]*BR\b"#),
            transform: toValueSet(#"pt"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bbr(?:a|azil|azilian)\W+(?:pt|por)\b"#),
            transform: toValueSet(#"pt"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:leg(?:endado|endas?)?|dub(?:lado)?|portugu[eèê]se?)[. -]*BR\b"#),
            transform: toValueSet(#"pt"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bleg(?:endado|endas?)\b"#),
            transform: toValueSet(#"pt"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bportugu[eèê]s[ea]?\b"#),
            transform: toValueSet(#"pt"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bPT[. -]*(?:PT|ENG?|sub(?:s|titles?))\b"#),
            transform: toValueSet(#"pt"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bpt"#),
            validateMatch: validateLookahead(#"(?:\.(?:ass|ssa|srt|sub|idx)$)"#, flags: #"i"#, polarity: true),
            transform: toValueSet(#"pt"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bPT\b"#),
            transform: toValueSet(#"pt"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bpor\b"#),
            transform: toValueSet(#"pt"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bITA\b"#),
            transform: toValueSet(#"it"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"\bI[tT]\b"#),
            validateMatch: validateAnd([validateLookbehind(#"(?:w{3}\.\w+\.)"#, flags: #"i"#, polarity: false), validateLookahead(#"(?:[ .,/-]+(?:[A-Z]{2}[ .,/-]+){2,})"#, flags: #"i"#, polarity: true)]),
            transform: toValueSet(#"it"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bit"#),
            validateMatch: validateLookahead(#"(?:\.(?:ass|ssa|srt|sub|idx)$)"#, flags: #"i"#, polarity: true),
            transform: toValueSet(#"it"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bitaliano?\b"#),
            transform: toValueSet(#"it"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bgreek[ .-]*(?:audio|lang(?:uage)?|subs?(?:titles?)?)?\b"#),
            transform: toValueSet(#"el"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:GER|DEU)\b"#),
            transform: toValueSet(#"de"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bde\b"#),
            validateMatch: validateLookahead(#"(?:[ .,/-]+(?:[A-Z]{2}[ .,/-]+){2,})"#, flags: #"i"#, polarity: true),
            transform: toValueSet(#"de"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bde\b"#),
            validateMatch: validateLookbehind(#"(?:[ .,/-]+(?:[A-Z]{2}[ .,/-]+){2,})"#, flags: #"i"#, polarity: true),
            transform: toValueSet(#"de"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bde\b"#),
            validateMatch: validateAnd([validateLookbehind(#"(?:[ .,/-]+[A-Z]{2}[ .,/-]+)"#, flags: #"i"#, polarity: true), validateLookahead(#"(?:[ .,/-]+[A-Z]{2}[ .,/-]+)"#, flags: #"i"#, polarity: true)]),
            transform: toValueSet(#"de"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bde"#),
            validateMatch: validateLookahead(#"(?:\.(?:ass|ssa|srt|sub|idx)$)"#, flags: #"i"#, polarity: true),
            transform: toValueSet(#"de"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(german|alem[aã]o)\b"#),
            transform: toValueSet(#"de"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bRUS?\b"#),
            transform: toValueSet(#"ru"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)(russian|russo)\b"#),
            transform: toValueSet(#"ru"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bUKR\b"#),
            transform: toValueSet(#"uk"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bukrainian\b"#),
            transform: toValueSet(#"uk"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bhin(?:di)?\b"#),
            transform: toValueSet(#"hi"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?tel(?:\W*aviv)?|telugu)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:(?:w{3}\.\w+\.)tel)|(?:tel(?:\W*aviv))"#)),
            transform: toValueSet(#"te"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bt[aâ]m(?:il)?\b"#),
            transform: toValueSet(#"ta"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?MAL(?:ay)?|malayalam)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:(?:w{3}\.\w+\.)MAL)\b"#)),
            transform: toValueSet(#"ml"#),
            remove: true,
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?KAN(?:nada)?|kannada)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:(?:w{3}\.\w+\.)KAN)\b"#)),
            transform: toValueSet(#"kn"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?MAR(?:a(?:thi)?)?|marathi)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:(?:w{3}\.\w+\.)MAR)\b"#)),
            transform: toValueSet(#"mr"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?GUJ(?:arati)?|gujarati)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:(?:w{3}\.\w+\.)GUJ)\b"#)),
            transform: toValueSet(#"gu"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?PUN(?:jabi)?|punjabi)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:(?:w{3}\.\w+\.)PUN)\b"#)),
            transform: toValueSet(#"pa"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?BEN(?:.\bThe|and|of\b)?(?:gali)?|bengali)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:(?:w{3}\.\w+\.)BEN)|(?:BEN)(?:.\bThe|and|of\b)\b"#)),
            transform: toValueSet(#"bn"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:YTS\.)?LT\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:YTS\.)"#)),
            transform: toValueSet(#"lt"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\blithuanian\b"#),
            transform: toValueSet(#"lt"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\blatvian\b"#),
            transform: toValueSet(#"lv"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bestonian\b"#),
            transform: toValueSet(#"et"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:PLDUB|Dub(?:bing.?)?PL|Lek(?:tor.?)?PL|Film.Polski)\b"#),
            transform: toValueSet(#"pl"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:Napisy.PL|PLSUB(?:BED)?)\b"#),
            transform: toValueSet(#"pl"#),
            remove: true,
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?PL|pol)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:w{3}\.\w+\.)"#)),
            transform: toValueSet(#"pl"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(polish|polon[eê]s|polaco)\b"#),
            transform: toValueSet(#"pl"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bCZ[EH]?\b"#),
            transform: toValueSet(#"cs"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bczech\b"#),
            transform: toValueSet(#"cs"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bslo(?:vak|vakian|subs|[\]_)]?\.\w{2,4}$)\b"#),
            transform: toValueSet(#"sk"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bHU\b"#),
            transform: toValueSet(#"hu"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bHUN(?:garian)?\b"#),
            transform: toValueSet(#"hu"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bROM(?:anian)?\b"#),
            transform: toValueSet(#"ro"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bRO(?:[ .,/-]*(?:[A-Z]{2}[ .,/-]+)*sub)"#),
            transform: toValueSet(#"ro"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bbul(?:garian)?\b"#),
            transform: toValueSet(#"bg"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:srp|serbian)\b"#),
            transform: toValueSet(#"sr"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:HRV|croatian)\b"#),
            transform: toValueSet(#"hr"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bHR(?:[ .,/-]*(?:[A-Z]{2}[ .,/-]+)*sub\w*)\b"#),
            transform: toValueSet(#"hr"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bslovenian\b"#),
            transform: toValueSet(#"sl"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?NL|dut|holand[eê]s)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:w{3}\.\w+\.)NL"#)),
            transform: toValueSet(#"nl"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bdutch\b"#),
            transform: toValueSet(#"nl"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bflemish\b"#),
            transform: toValueSet(#"nl"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:DK|danska|dansub|nordic)\b"#),
            transform: toValueSet(#"da"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(danish|dinamarqu[eê]s)\b"#),
            transform: toValueSet(#"da"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bdan\b(?:.*\.(?:srt|vtt|ssa|ass|sub|idx)$)"#),
            transform: toValueSet(#"da"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.|Sci-)?FI|finsk|finsub|nordic)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:w{3}\.\w+\.|Sci-)FI"#)),
            transform: toValueSet(#"fi"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bfinnish\b"#),
            transform: toValueSet(#"fi"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:(?:w{3}\.\w+\.)?SE|swe|swesubs?|sv(?:ensk)?|nordic)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)(?:w{3}\.\w+\.)SE"#)),
            transform: toValueSet(#"sv"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(swedish|sueco)\b"#),
            transform: toValueSet(#"sv"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:NOR|norsk|norsub|nordic)\b"#),
            transform: toValueSet(#"no"#),
            keepMatching: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(norwegian|noruegu[eê]s|bokm[aå]l|nob|nor(?:[\]_)]?\.\w{2,4}$))\b"#),
            transform: toValueSet(#"no"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:arabic|[aá]rabe|ara)\b"#),
            transform: toValueSet(#"ar"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\barab.*(?:audio|lang(?:uage)?|sub(?:s|titles?)?)\b"#),
            transform: toValueSet(#"ar"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bar(?:\.(?:ass|ssa|srt|sub|idx)$)"#),
            transform: toValueSet(#"ar"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:turkish|tur(?:co)?)\b"#),
            transform: toValueSet(#"tr"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(TİVİBU|tivibu|bitturk(?:\.net)?|turktorrent)\b"#),
            transform: toValueSet(#"tr"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bvietnamese\b|\bvie(?:[\]_)]?\.\w{2,4}$)"#),
            transform: toValueSet(#"vi"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bind(?:onesian)?\b"#),
            transform: toValueSet(#"id"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(thai|tailand[eê]s)\b"#),
            transform: toValueSet(#"th"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"\b(THA|tha)\b"#),
            transform: toValueSet(#"th"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(?:malay|may(?:[\]_)]?\.\w{2,4}$)|(?:subs?\([a-z,]+)may)\b"#),
            transform: toValueSet(#"ms"#),
            keepMatching: true,
            skipIfFirst: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\bheb(?:rew|raico)?\b"#),
            transform: toValueSet(#"he"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)\b(persian|persa)\b"#),
            transform: toValueSet(#"fa"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{3040}-\x{30ff}]+"#),
            transform: toValueSet(#"ja"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{3400}-\x{4dbf}]+"#),
            transform: toValueSet(#"zh"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{4e00}-\x{9fff}]+"#),
            transform: toValueSet(#"zh"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{f900}-\x{faff}]+"#),
            transform: toValueSet(#"zh"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{ff66}-\x{ff9f}]+"#),
            transform: toValueSet(#"ja"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0400}-\x{04ff}]+"#),
            transform: toValueSet(#"ru"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0600}-\x{06ff}]+"#),
            transform: toValueSet(#"ar"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0750}-\x{077f}]+"#),
            transform: toValueSet(#"ar"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0c80}-\x{0cff}]+"#),
            transform: toValueSet(#"kn"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0d00}-\x{0d7f}]+"#),
            transform: toValueSet(#"ml"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0e00}-\x{0e7f}]+"#),
            transform: toValueSet(#"th"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0900}-\x{097f}]+"#),
            transform: toValueSet(#"hi"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0980}-\x{09ff}]+"#),
            transform: toValueSet(#"bn"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            pattern: re(#"(?i)[\x{0a00}-\x{0a7f}]+"#),
            transform: toValueSet(#"gu"#),
            keepMatching: true,
            skipFromTitle: true
        ),
        Handler(
            field: "languages",
            process: processLanguagesPortuguese
        ),
        Handler(
            field: "subbed",
            pattern: re(#"(?i)\b(?:Official.*?|Dual-?)?sub(?:s|bed)?\b"#),
            transform: toBoolean,
            remove: true,
            skipIfFirst: true
        ),
        Handler(
            field: "subbed",
            process: processSubbedFromLanguages
        ),
        Handler(
            field: "dubbed",
            pattern: re(#"(?i)\b(?:fan\s?dub)\b"#),
            transform: toBoolean,
            remove: true,
            skipFromTitle: true
        ),
        Handler(
            field: "dubbed",
            pattern: re(#"(?i)\b(?:Fan.*)?(?:DUBBED|dublado|dubbing|DUBS?)\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "dubbed",
            pattern: re(#"(?i)\b(?:.*\bsub(?:s|bed)?\b)?(?:[ _\-\[(\.])?(dual|multi)(?:[ _\-\[(\.])?(?:audio)\b"#),
            validateMatch: validateNotMatch(re(#"(?i)\b(?:.*\bsub(s|bed)?\b)"#)),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "dubbed",
            pattern: re(#"(?i)\bMULTi\b"#),
            transform: toBoolean,
            remove: true
        ),
        Handler(
            field: "dubbed",
            pattern: re(#"(?i)\b(?:DUBBED|dublado|dubbing|DUBS?)\b"#),
            transform: toBoolean
        ),
        Handler(
            field: "dubbed",
            process: processDubbedFromLanguages
        ),
        Handler(
            field: "size",
            pattern: re(#"(?i)\b(\d+(\.\d+)?\s?(MB|GB|TB))\b"#),
            remove: true
        ),
        Handler(
            field: "site",
            pattern: re(#"(?i)(\[([^\[\].]+\.[^\].]+)\])(?:\.\w{2,4}$|\s)"#),
            transform: toTrimmed,
            remove: true,
            matchGroup: 1,
            valueGroup: 2
        ),
        Handler(
            field: "site",
            pattern: re(#"(?i)[\[{(](www.\w*.\w+)[)}\]]"#),
            remove: true,
            skipFromTitle: true
        ),
        Handler(
            field: "site",
            pattern: re(#"(?i)\b(?:www?.?)?(?:\w+\-)?\w+\.(?:com|org|net|ms|tv|mx|co|party|vip|nu|pics)\b"#),
            remove: true,
            skipFromTitle: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bATVP?\b"#),
            transform: toValue(#"Apple TV"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bAMZN\b"#),
            transform: toValue(#"Amazon"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bNF|Netflix\b"#),
            transform: toValue(#"Netflix"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bNICK(?:elodeon)?\b"#),
            transform: toValue(#"Nickelodeon"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bDSNY?P?\b"#),
            transform: toValue(#"Disney"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bH(MAX|BO)\b"#),
            transform: toValue(#"HBO"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bHULU\b"#),
            transform: toValue(#"Hulu"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bCBS\b"#),
            transform: toValue(#"CBS"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bNBC\b"#),
            transform: toValue(#"NBC"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bAMC\b"#),
            transform: toValue(#"AMC"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bPBS\b"#),
            transform: toValue(#"PBS"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\b(Crunchyroll|[. -]CR[. -])\b"#),
            transform: toValue(#"Crunchyroll"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"\bVICE\b"#),
            transform: toValue(#"VICE"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bSony\b"#),
            transform: toValue(#"Sony"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bHallmark\b"#),
            transform: toValue(#"Hallmark"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bAdult.?Swim\b"#),
            transform: toValue(#"Adult Swim"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bAnimal.?Planet|ANPL\b"#),
            transform: toValue(#"Animal Planet"#),
            remove: true
        ),
        Handler(
            field: "network",
            pattern: re(#"(?i)\bCartoon.?Network(?:.TOONAMI.BROADCAST)?\b"#),
            transform: toValue(#"Cartoon Network"#),
            remove: true
        ),
        Handler(
            field: "group",
            pattern: re(#"\b(INFLATE|DEFLATE)\b"#),
            remove: true
        ),
        Handler(
            field: "group",
            pattern: re(#"(?i)\b(?:Erai-raws|Erai-raws\.com)\b"#),
            transform: toValue(#"Erai-raws"#),
            remove: true
        ),
        Handler(
            field: "group",
            pattern: re(#"^\[([^\[\]]+)]"#)
        ),
        Handler(
            field: "group",
            pattern: re(#"\(([\w-]+)\)(?:$|\.\w{2,4}$)"#)
        ),
        Handler(
            field: "group",
            process: processGroupFalsePositive
        ),
        Handler(
            field: "extension",
            pattern: re(#"(?i)\.(3g2|3gp|avi|flv|mkv|mk3d|mov|mp2|mp4|m4v|mpe|mpeg|mpg|mpv|webm|wmv|ogm|divx|ts|m2ts|iso|vob|sub|idx|ttxt|txt|smi|srt|ssa|ass|vtt|nfo|html)$"#),
            transform: toLowercase
        ),
        Handler(
            field: "audio",
            pattern: re(#"(?i)\bMP3\b"#),
            transform: toValueSet(#"MP3"#),
            remove: true,
            keepMatching: true
        )
]
