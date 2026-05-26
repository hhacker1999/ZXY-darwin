//
//  DiscordIPCClient.swift
//
//  macOS Discord Rich Presence IPC client.
//  Connects to Discord's local Unix socket and speaks the v1 framing protocol.
//

#if os(macOS)
import Foundation

enum DiscordActivityType {
    static let playing = 0
    static let streaming = 1
    static let listening = 2
    static let watching = 3
    static let custom = 4
    static let competing = 5
}

enum DiscordIPCError: Error, LocalizedError {
    case discordNotRunning
    case notConnected
    case handshakeFailed(String)
    case writeFailed
    case readFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .discordNotRunning:
            return "Discord is not running or Rich Presence IPC is unavailable."
        case .notConnected:
            return "Not connected to Discord IPC."
        case let .handshakeFailed(message):
            return "Discord IPC handshake failed: \(message)"
        case .writeFailed:
            return "Failed to write to Discord IPC socket."
        case .readFailed:
            return "Failed to read from Discord IPC socket."
        case .invalidResponse:
            return "Received an invalid response from Discord IPC."
        }
    }
}

private enum DiscordIPCOpcode: UInt32 {
    case handshake = 0
    case frame = 1
    case close = 2
}

/// Low-level Discord Rich Presence IPC over Discord's local Unix socket.
final class DiscordIPCClient: @unchecked Sendable {
    private let queue = DispatchQueue(label: "zxy.discord-ipc", qos: .utility)
    private var socketFD: Int32 = -1
    private var connectedClientId: String?
    private var nonceCounter = 0

    var isConnected: Bool {
        socketFD >= 0
    }

    func connect(clientId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.connectSync(clientId: clientId)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func disconnect() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.closeSocket()
                continuation.resume()
            }
        }
    }

    func setActivity(
        pid: Int32,
        activityType: Int = DiscordActivityType.watching,
        details: String?,
        state: String?,
        startTimestamp: Int? = nil,
        endTimestamp: Int? = nil,
        largeImageKey: String? = nil,
        largeImageText: String? = nil,
        smallImageKey: String? = nil,
        smallImageText: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.setActivitySync(
                        pid: pid,
                        activityType: activityType,
                        details: details,
                        state: state,
                        startTimestamp: startTimestamp,
                        endTimestamp: endTimestamp,
                        largeImageKey: largeImageKey,
                        largeImageText: largeImageText,
                        smallImageKey: smallImageKey,
                        smallImageText: smallImageText
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func clearActivity(pid: Int32) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.clearActivitySync(pid: pid)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Sync IPC

    private func ipcSocketCandidates(for index: Int) -> [String] {
        var candidates: [String] = []
        var seen = Set<String>()

        func addPath(_ rawPrefix: String?) {
            guard let rawPrefix, !rawPrefix.isEmpty else { return }
            let prefix = rawPrefix.hasSuffix("/") ? rawPrefix : "\(rawPrefix)/"
            let path = "\(prefix)discord-ipc-\(index)"
            guard seen.insert(path).inserted else { return }
            candidates.append(path)
        }

        let env = ProcessInfo.processInfo.environment
        addPath(env["XDG_RUNTIME_DIR"])
        addPath(env["TMPDIR"])
        addPath(env["TMP"])
        addPath(env["TEMP"])
        addPath(NSTemporaryDirectory())
        addPath("/tmp")
        addPath("/private/tmp")

        let globPatterns = [
            "/var/folders/*/T/discord-ipc-\(index)",
            "/var/folders/*/*/T/discord-ipc-\(index)",
        ]
        for pattern in globPatterns {
            var globResult = glob_t()
            if glob(pattern, GLOB_TILDE, nil, &globResult) == 0 {
                defer { globfree(&globResult) }
                for offset in 0 ..< Int(globResult.gl_pathc) {
                    if let cPath = globResult.gl_pathv[offset] {
                        let path = String(cString: cPath)
                        guard seen.insert(path).inserted else { continue }
                        candidates.append(path)
                    }
                }
            }
        }

        return candidates
    }

    private func connectSync(clientId: String) throws {
        closeSocket()

        var lastError: Error = DiscordIPCError.discordNotRunning
        for index in 0 ... 9 {
            for path in ipcSocketCandidates(for: index) {
                let fd = socket(AF_UNIX, SOCK_STREAM, 0)
                guard fd >= 0 else { continue }

                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                let maxPathLen = MemoryLayout.size(ofValue: addr.sun_path)
                path.withCString { cString in
                    withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
                        sunPath.withMemoryRebound(to: CChar.self, capacity: maxPathLen) { dest in
                            strlcpy(dest, cString, maxPathLen)
                        }
                    }
                }

                let connectResult = withUnsafePointer(to: &addr) { addrPtr in
                    addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
                    }
                }

                if connectResult != 0 {
                    close(fd)
                    lastError = DiscordIPCError.discordNotRunning
                    continue
                }

                socketFD = fd
                break
            }

            guard socketFD >= 0 else { continue }

            do {
                let handshakePayload: [String: Any] = [
                    "v": 1,
                    "client_id": clientId,
                ]
                try writeFrame(opcode: .handshake, payload: handshakePayload)

                let response = try readFrame()
                guard response.opcode == DiscordIPCOpcode.frame.rawValue else {
                    throw DiscordIPCError.handshakeFailed("Unexpected opcode \(response.opcode)")
                }

                guard
                    let json = try JSONSerialization.jsonObject(with: response.payload) as? [String: Any],
                    let event = json["evt"] as? String
                else {
                    throw DiscordIPCError.invalidResponse
                }

                if event == "ERROR" {
                    let message = (json["data"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                    throw DiscordIPCError.handshakeFailed(message)
                }

                guard event == "READY" else {
                    throw DiscordIPCError.handshakeFailed("Unexpected event \(event)")
                }

                connectedClientId = clientId
                return
            } catch {
                closeSocket()
                lastError = error
            }
        }

        throw lastError
    }

    private func setActivitySync(
        pid: Int32,
        activityType: Int,
        details: String?,
        state: String?,
        startTimestamp: Int?,
        endTimestamp: Int?,
        largeImageKey: String?,
        largeImageText: String?,
        smallImageKey: String?,
        smallImageText: String?
    ) throws {
        guard isConnected else { throw DiscordIPCError.notConnected }

        var activity: [String: Any] = [
            "type": activityType,
        ]

        if let details, !details.isEmpty {
            activity["details"] = String(details.prefix(128))
        }
        if let state, !state.isEmpty {
            activity["state"] = String(state.prefix(128))
        }

        var timestamps: [String: Int] = [:]
        if let startTimestamp {
            timestamps["start"] = startTimestamp
        }
        if let endTimestamp {
            timestamps["end"] = endTimestamp
        }
        if !timestamps.isEmpty {
            activity["timestamps"] = timestamps
        }

        var assets: [String: String] = [:]
        if let largeImageKey, !largeImageKey.isEmpty {
            assets["large_image"] = largeImageKey
        }
        if let largeImageText, !largeImageText.isEmpty {
            assets["large_text"] = String(largeImageText.prefix(128))
        }
        if let smallImageKey, !smallImageKey.isEmpty {
            assets["small_image"] = smallImageKey
        }
        if let smallImageText, !smallImageText.isEmpty {
            assets["small_text"] = String(smallImageText.prefix(128))
        }
        if !assets.isEmpty {
            activity["assets"] = assets
        }

        try sendCommand(
            cmd: "SET_ACTIVITY",
            args: [
                "pid": pid,
                "activity": activity,
            ]
        )
    }

    private func clearActivitySync(pid: Int32) throws {
        guard isConnected else { throw DiscordIPCError.notConnected }

        try sendCommand(
            cmd: "SET_ACTIVITY",
            args: [
                "pid": pid,
                "activity": NSNull(),
            ]
        )
    }

    private func sendCommand(cmd: String, args: [String: Any]) throws {
        nonceCounter += 1
        let payload: [String: Any] = [
            "cmd": cmd,
            "args": args,
            "nonce": "\(nonceCounter)",
        ]
        try writeFrame(opcode: .frame, payload: payload)

        let response = try readFrame()
        guard response.opcode == DiscordIPCOpcode.frame.rawValue else {
            throw DiscordIPCError.invalidResponse
        }

        guard
            let json = try JSONSerialization.jsonObject(with: response.payload) as? [String: Any]
        else {
            throw DiscordIPCError.invalidResponse
        }

        if json["evt"] as? String == "ERROR" {
            let message = (json["data"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            throw DiscordIPCError.handshakeFailed(message)
        }
    }

    private func writeFrame(opcode: DiscordIPCOpcode, payload: [String: Any]) throws {
        guard isConnected else { throw DiscordIPCError.notConnected }

        let body = try JSONSerialization.data(withJSONObject: payload)
        var header = Data(count: 8)
        header.replaceSubrange(0 ..< 4, with: withUnsafeBytes(of: opcode.rawValue.littleEndian) { Data($0) })
        header.replaceSubrange(4 ..< 8, with: withUnsafeBytes(of: UInt32(body.count).littleEndian) { Data($0) })

        var packet = header
        packet.append(body)

        let written = packet.withUnsafeBytes { buffer in
            write(socketFD, buffer.baseAddress, buffer.count)
        }
        guard written == packet.count else {
            closeSocket()
            throw DiscordIPCError.writeFailed
        }
    }

    private func readFrame() throws -> (opcode: UInt32, payload: Data) {
        guard isConnected else { throw DiscordIPCError.notConnected }

        var header = [UInt8](repeating: 0, count: 8)
        try readExact(into: &header, count: 8)

        let opcode = UInt32(littleEndian: header.withUnsafeBytes { $0.load(as: UInt32.self) })
        let length = UInt32(littleEndian: header.withUnsafeBytes { raw in
            raw.load(fromByteOffset: 4, as: UInt32.self)
        })

        guard length > 0, length <= 1_048_576 else {
            throw DiscordIPCError.invalidResponse
        }

        var payload = [UInt8](repeating: 0, count: Int(length))
        try readExact(into: &payload, count: Int(length))

        return (opcode, Data(payload))
    }

    private func readExact(into buffer: inout [UInt8], count: Int) throws {
        var offset = 0
        while offset < count {
            let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
                read(socketFD, rawBuffer.baseAddress!.advanced(by: offset), count - offset)
            }
            if bytesRead <= 0 {
                closeSocket()
                throw DiscordIPCError.readFailed
            }
            offset += bytesRead
        }
    }

    private func closeSocket() {
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
        connectedClientId = nil
    }
}
#endif
