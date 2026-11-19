//
//  RemoteClient.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/16/26.
//

#if os(iOS)

import Foundation

struct ConnectedServer {
    let server: ResolvedServer
    let url: URL
}

struct StoredServer: Codable {
    let name: String
    let hostname: String
    let port: Int
}

enum RemoteClientError: LocalizedError {
    case cantMakeHealthRequest
    case cantMakePlayRequest
    case wrongPlayRequestArgument
    case playRequestFailed(Int, String)
    case cantMakePlayerAction
    case playerActionFailed(Int)

    var errorDescription: String? {
        switch self {
        case .cantMakeHealthRequest:
            "Cant Make Health Request"
        case .cantMakePlayRequest:
            "Cant Make Play Request"
        case .wrongPlayRequestArgument:
            "Wrong Play Request Argument"
        case .playRequestFailed(let status, let location):
            "Play request failed in (\(location)): (HTTP \(status))."
        case .cantMakePlayerAction:
            "Connect to a remote device first."
        case .playerActionFailed(let status):
            "Player action failed (HTTP \(status))."
        }
    }
}

@Observable
@MainActor
final class RemoteClient {
    let remoteServerResolver = RemoteServerResolver()

    private(set) var connectedServer: ConnectedServer?
    private(set) var error: Error?

    var discoveredDevices: [ResolvedServer] {
        return remoteServerResolver.discoveredDevices
    }

    private var alwaysConnect: StoredServer?

    static let alwaysConnectKey = "alwaysConnectResolvedServer"

    init() {
        setAlwaysConnect()
        observeDevices()
    }

    public func connect(to server: ResolvedServer) throws {
        guard let hostname = server.hostname,
              let port = server.port,
              let url = URL(string: "http://\(hostname):\(port)/")
        else {
            throw URLError(.badURL)
        }

        connectedServer = ConnectedServer(server: server, url: url)
        sendHealthRequest()
        sendJustJoined()
    }

    public func setAlwaysConnect(to server: ResolvedServer) {
        guard let hostname = server.hostname else { return }
        guard let port = server.port else { return }
        let storedServer = StoredServer(
            name: server.service.name,
            hostname: hostname,
            port: port
        )

        guard let data = try? JSONEncoder().encode(storedServer) else {
            return
        }

        UserDefaults.standard.set(data, forKey: Self.alwaysConnectKey)
        setAlwaysConnect()
    }

    private func setAlwaysConnect() {
        guard let data = UserDefaults.standard.data(
            forKey: Self.alwaysConnectKey
        ) else {
            return
        }

        alwaysConnect = try? JSONDecoder().decode(StoredServer.self, from: data)
    }
}

extension RemoteClient {
    public func observeDevices() {
        withObservationTracking {
            _ = remoteServerResolver.discoveredDevices
        } onChange: { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                if let alwaysConnect = self.alwaysConnect,
                   self.connectedServer?.server.matches(with: alwaysConnect) != true {
                    for device in self.discoveredDevices {
                        if device.matches(with: alwaysConnect) {
                            try? self.connect(to: device)
                            break
                        }
                    }
                }
                self.observeDevices()
            }
        }

    }
}

extension RemoteClient {

    public func sendJustJoined() {
        Task {
            try? await sendPlayerAction(path: "client/connected")
        }
    }

    public func sendPause() async throws {
        try await sendPlayerAction(path: "remote/pause")
    }

    public func sendPlay() async throws {
        try await sendPlayerAction(path: "remote/player/play")
    }

    public func sendFullscreen() async throws {
        try await sendPlayerAction(path: "remote/player/fullscreen/enter")
    }

    public func sendExitFullscreen() async throws {
        try await sendPlayerAction(path: "remote/player/fullscreen/exit")
    }

    public func forwardTenSeconds() async throws {
        try await sendPlayerAction(path: "remote/player/forwardTenSeconds")
    }

    public func backwardTenSeconds() async throws {
        try await sendPlayerAction(path: "remote/player/backwardTenSeconds")
    }

    public func getVolume() async throws -> Float {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "volume"))
        urlRequest.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode, "Getting Volume")
        }

        guard let body = String(data: data, encoding: .utf8),
              let volume = Float(body.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw URLError(.cannotParseResponse)
        }

        return volume
    }

    public func getServer() async throws -> KTDisplayServer? {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "display"))
        urlRequest.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode, "Getting Server")
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        if body == "No server set" { return nil }

        return KTDisplayServer.from(body)
    }

    public func setServer(entry: KTDisplayServer) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "display/set"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let json = DisplayServerCodec.shared.encode(server: entry)
        urlRequest.httpBody = Data(json.utf8)

        if Task.isCancelled { return }

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        if Task.isCancelled { return }

        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if Task.isCancelled { return }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode, "Set Server")
        }
    }

    public func setVolume(to value: Float) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "volume/set"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(value)

        if Task.isCancelled { return }

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        if Task.isCancelled { return }

        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if Task.isCancelled { return }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode, "Set Volume")
        }
    }

    public func seek(to time: Double) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "remote/player/seek"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(time)

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode, "Seek To \(time)")
        }
    }

    private func sendPlayerAction(path: String) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }
        var request = URLRequest(url: connectedServer.url.appending(path: path))
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playerActionFailed(response.statusCode)
        }
    }

    public func sendPlayRequest(
        id: Int,
        name: String,
        mediaType: KTMediaType,
        season: Int? = nil,
        episode: Int? = nil
    ) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayRequest
        }

        let mtype: PlayRequest.MediaType
        switch mediaType {
        case .movie:
            mtype = .movie
        case .tv:
            mtype = .tv
        default:
            throw RemoteClientError.wrongPlayRequestArgument
        }

        let request = PlayRequest(
            id: id,
            name: name,
            mediaType: mtype,
            season: season,
            episode: episode
        )

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "remote/play"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode, "Send Play Request")
        }
    }

    public func sendHealthRequest() {
        guard let connectedServer else {
            self.error = RemoteClientError.cantMakeHealthRequest
            return
        }
        let healthUrl = connectedServer.url.appending(path: "health")
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: healthUrl)
                guard let response = response as? HTTPURLResponse,
                      response.statusCode == 200
                        else {
                    throw URLError(.badServerResponse)
                }

                print(String(decoding: data, as: UTF8.self))
            } catch {
                self.error = error
            }
        }
    }
}

private extension KTDisplayServer {
    /// `GET /display` returns the Kotlin enum name (e.g. "MOVIES_API"), while the
    /// UI uses `rawValue` (e.g. "MoviesAPI"). Accept either.
    static func from(_ string: String) -> KTDisplayServer? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.first { $0.rawValue == trimmed || $0.name == trimmed }
    }
}

#endif
