//
//  RemoteServer.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/16/26.
//

#if os(macOS)

import Hummingbird
import Foundation

@Observable
final class RemoteServer: NSObject, NetServiceDelegate {

    var startServerTask: Task<Void, Never>?
    var stopServerTask : Task<Void, Never>?

    var discoveryService: NetService
    var applicationServer: Application<RouterResponder<BasicRequestContext>>?
    var error: String?

    var onRemotePlay: ((PlayRequest) -> Void)?
    @MainActor var onPlay: (@MainActor () async throws -> Void)?
    @MainActor var onPause: (@MainActor () async throws -> Void)?
    @MainActor var onEnterFullscreen: (@MainActor () async throws -> Void)?
    @MainActor var onExitFullscreen: (@MainActor () async throws -> Void)?

    override init() {
        /// publish locally
        discoveryService = NetService(
            domain: "local.",
            type: "_comfycinema._tcp.",
            name: Host.current().localizedName ?? "ComfyCinema",
            port: 8082
        )
        super.init()

        discoveryService.delegate = self
        discoveryService.publish()
        startServer()
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour published:", sender.name)
    }

    func netService(
        _ sender: NetService,
        didNotPublish errorDict: [String: NSNumber]
    ) {
        print("Bonjour failed:", errorDict)
    }

    public func startServer() {
        guard startServerTask == nil else { return }
        let router = Router()

        router.get("/health") { request, context in
            return "ComfyCinema Remote Server"
        }

        router.post("/remote/player/play") { [weak self] _, _ in
            guard let self = self else {
                throw HTTPError(.serviceUnavailable, message: "Play action unavailable")
            }
            return try await self.performPlayAction()
        }

        router.post("/remote/pause") { [weak self] _, _ in
            guard let self = self else {
                throw HTTPError(.serviceUnavailable, message: "Pause action unavailable")
            }
            return try await self.performPauseAction()
        }

        router.post("/remote/player/fullscreen/enter") { [weak self] _, _ in
            guard let self = self else {
                throw HTTPError(.serviceUnavailable, message: "Enter fullscreen action unavailable")
            }
            return try await self.performEnterFullscreenAction()
        }

        router.post("/remote/player/fullscreen/exit") { [weak self] _, _ in
            guard let self = self else {
                throw HTTPError(.serviceUnavailable, message: "Exit fullscreen action unavailable")
            }
            return try await self.performExitFullscreenAction()
        }

        router.post("/remote/play") { [weak self] request, context in
            guard let self else { return "RemoteServer not available" }
            let request: PlayRequest = try await request.decode(as: PlayRequest.self, context: context)
            onRemotePlay?(request)
            return "Play request received"
        }

        applicationServer = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: 8082))
        )

        guard let applicationServer else { return }

        startServerTask = Task {
            do {
                try await applicationServer.runService()
            } catch {
                self.error = "HTTP server failed: \(String(reflecting: error))"
            }
        }
    }

    @MainActor
    private func performPlayAction() async throws -> String {
        guard let action = onPlay else {
            throw HTTPError(.serviceUnavailable, message: "Play action unavailable")
        }
        try await action()
        return "Play action requested"
    }

    @MainActor
    private func performPauseAction() async throws -> String {
        guard let action = onPause else {
            throw HTTPError(.serviceUnavailable, message: "Pause action unavailable")
        }
        try await action()
        return "Pause action requested"
    }

    @MainActor
    private func performEnterFullscreenAction() async throws -> String {
        guard let action = onEnterFullscreen else {
            throw HTTPError(.serviceUnavailable, message: "Enter fullscreen action unavailable")
        }
        try await action()
        return "Enter fullscreen action requested"
    }

    @MainActor
    private func performExitFullscreenAction() async throws -> String {
        guard let action = onExitFullscreen else {
            throw HTTPError(.serviceUnavailable, message: "Exit fullscreen action unavailable")
        }
        try await action()
        return "Exit fullscreen action requested"
    }

    public func stopServer(completion: @escaping () async -> Void = {}) {
        let runningTask = startServerTask

        startServerTask = nil
        runningTask?.cancel()

        stopServerTask = Task {
            await runningTask?.value
            await completion()
        }
    }
}

#endif
