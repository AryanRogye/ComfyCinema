//
//  RemoteServer.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/16/26.
//

#if os(macOS)

import Hummingbird
import Foundation
import Defaults
import WebKit

@Observable
final class RemoteServer: NSObject, NetServiceDelegate {

    var startServerTask: Task<Void, Never>?
    var stopServerTask : Task<Void, Never>?

    var discoveryService: NetService?
    var applicationServer: Application<RouterResponder<BasicRequestContext>>?
    var error: String?

    var onRemotePlay: ((PlayRequest) -> Void)?
    @MainActor var onPlay: (@MainActor () async throws -> Void)?
    @MainActor var onPause: (@MainActor () async throws -> Void)?
    @MainActor var onEnterFullscreen: (@MainActor () async throws -> Void)?
    @MainActor var onExitFullscreen: (@MainActor () async throws -> Void)?
    @MainActor var onForwardTenSeconds: (@MainActor () async throws -> Void)?
    @MainActor var onBackTenSeconds: (@MainActor () async throws -> Void)?
    @MainActor var onSeek: (@MainActor (Double) async throws -> Void)?

    var enableRemoteControl: Bool = Defaults[.enableRemoteControl] {
        didSet {
            Defaults[.enableRemoteControl] = enableRemoteControl

            if enableRemoteControl {
                startServer()
            } else {
                stopServer()
                error = nil
            }
        }
    }

    var remoteControlIp: String = Defaults[.remoteControlIp] {
        didSet {
            guard oldValue != remoteControlIp else { return }
            Defaults[.remoteControlIp] = remoteControlIp

            if enableRemoteControl {
                stopServer {
                    guard self.enableRemoteControl else { return }
                    self.startServer()
                }
            }
        }
    }

    var remoteControlName: String = Defaults[.remoteControlName] {
        didSet {
            guard oldValue != remoteControlName else { return }
            Defaults[.remoteControlName] = remoteControlName

            if enableRemoteControl {
                stopServer {
                    guard self.enableRemoteControl else { return }
                    self.startServer()
                }
            }
        }
    }

    /// Name advertised over Bonjour. Debug and release builds get different defaults so both
    /// can run side by side and show up as separate entries on iOS.
    var advertisedName: String {
        let custom = remoteControlName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let base = Host.current().localizedName ?? "ComfyCinema"
        #if DEBUG
        return "\(base) (Debug)"
        #else
        return base
        #endif
    }

    var remoteControlPort: Int = Defaults[.remoteControlPort] {
        didSet {
            guard oldValue != remoteControlPort else { return }
            Defaults[.remoteControlPort] = remoteControlPort

            if enableRemoteControl {
                stopServer {
                    guard self.enableRemoteControl else { return }
                    self.startServer()
                }
            }
        }
    }

    override init() {
        super.init()
        /// publish locally
        if enableRemoteControl {
            broadcastDiscovery()
            startServer()
        }
    }

    public func broadcastDiscovery() {
        discoveryService = NetService(
            domain: "local.",
            type: "_comfycinema._tcp.",
            name: advertisedName,
            port: Int32(remoteControlPort)
        )

        discoveryService?.delegate = self
        discoveryService?.publish()
    }

    public func startServer() {
        guard startServerTask == nil else { return }
        error = nil
        if discoveryService == nil {
            broadcastDiscovery()
        }
        let router = Router()

        assignRouterHandlers(router: router)

        applicationServer = Application(
            router: router,
            configuration: .init(address: .hostname(remoteControlIp, port: remoteControlPort))
        )

        guard let applicationServer else { return }

        startServerTask = Task {
            do {
                try await applicationServer.runService()
            } catch {
                self.error = "HTTP server failed: \(String(reflecting: error))"
                self.discoveryService?.stop()
                self.discoveryService = nil
                self.startServerTask = nil
            }
        }
    }

    public func stopServer(completion: @escaping () async -> Void = {}) {
        let runningTask = startServerTask

        startServerTask = nil
        // Withdraw the Bonjour advertisement so a changed port is re-published, not left stale.
        discoveryService?.stop()
        discoveryService = nil
        runningTask?.cancel()

        stopServerTask = Task {
            await runningTask?.value
            await completion()
        }
    }
}

extension RemoteServer {
    @MainActor
    public func clearClosures() {
        onPlay = nil
        onPause = nil
        onEnterFullscreen = nil
        onExitFullscreen = nil
        onForwardTenSeconds = nil
        onBackTenSeconds = nil
        onSeek = nil
    }
    @MainActor
    public func attachWebViewFunctions(_ webView: WKWebView) {
        onPlay = {
            let _ = try await webView.callAsyncJavaScript(
                "return window.comfyFrameAction(action)",
                arguments: [
                    "action": "play",
                ],
                in: nil,
                contentWorld: .page
            )
        }
        onPause = {
            let _ = try await webView.callAsyncJavaScript(
                "return window.comfyFrameAction(action)",
                arguments: [
                    "action": "pause",
                ],
                in: nil,
                contentWorld: .page
            )
        }
        onEnterFullscreen = {
            let _ = try await webView.callAsyncJavaScript(
                "return window.comfyFrameAction(action)",
                arguments: [
                    "action": "enterFullscreen",
                ],
                in: nil,
                contentWorld: .page
            )
        }
        onExitFullscreen = {
            let _ = try await webView.callAsyncJavaScript(
                "return window.comfyFrameAction(action)",
                arguments: [
                    "action": "exitFullscreen",
                ],
                in: nil,
                contentWorld: .page
            )
        }
        onForwardTenSeconds = {
            let _ = try await webView.callAsyncJavaScript(
                "return window.comfyFrameAction(action)",
                arguments: [
                    "action": "skipForward",
                ],
                in: nil,
                contentWorld: .page
            )
        }
        onBackTenSeconds = {
            let _ = try await webView.callAsyncJavaScript(
                "return window.comfyFrameAction(action)",
                arguments: [
                    "action": "skipBackward",
                ],
                in: nil,
                contentWorld: .page
            )
        }
        onSeek = { time in
            let _ = try await webView.callAsyncJavaScript(
                "return window.comfyFrameAction(action, arg)",
                arguments: [
                    "action": "seek",
                    "arg": time
                ],
                in: nil,
                contentWorld: .page
            )
        }
    }
}

extension RemoteServer {
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

    @MainActor
    private func performForwardTenSeconds() async throws -> String {
        guard let action = onForwardTenSeconds else {
            throw HTTPError(.serviceUnavailable, message: "Forward 10 seconds action unavailable")
        }
        try await action()
        return "Forward 10 seconds action requested"
    }
    @MainActor
    private func performBackwardTenSeconds() async throws -> String {
        guard let action = onBackTenSeconds else {
            throw HTTPError(.serviceUnavailable, message: "Backward 10 seconds action unavailable")
        }
        try await action()
        return "Backward 10 seconds action requested"
    }

}

extension RemoteServer {
    public func assignRouterHandlers(router: Router<BasicRequestContext>) {
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

        router.post("/remote/player/forwardTenSeconds") { [weak self] _, _ in
            guard let self = self else {
                throw HTTPError(.serviceUnavailable, message: "Forward 10 seconds action unavailable")
            }
            return try await self.performForwardTenSeconds()
        }

        router.post("/remote/player/backwardTenSeconds") { [weak self] _, _ in
            guard let self = self else {
                throw HTTPError(.serviceUnavailable, message: "Backward 10 seconds action unavailable")
            }
            return try await self.performBackwardTenSeconds()
        }

        router.post("/remote/player/seek") { [weak self] request, context in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Seek unavailable")
            }
            let amount: Double = try await request.decode(as: Double.self, context: context)
            try await onSeek?(amount)
            return "Seek request received"
        }

        router.post("/remote/play") { [weak self] request, context in
            guard let self else { return "RemoteServer not available" }
            let request: PlayRequest = try await request.decode(as: PlayRequest.self, context: context)
            onRemotePlay?(request)
            return "Play request received"
        }
    }
}

#endif
