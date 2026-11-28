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

    let volumeManager = VolumeManager()

    var onRemotePlay: ((PlayRequest) -> Void)?
    @MainActor var onPlay: (@MainActor () async throws -> Void)?
    @MainActor var onPause: (@MainActor () async throws -> Void)?
    @MainActor var onEnterFullscreen: (@MainActor () async throws -> Void)?
    @MainActor var onExitFullscreen: (@MainActor () async throws -> Void)?
    @MainActor var onForwardTenSeconds: (@MainActor () async throws -> Void)?
    @MainActor var onBackTenSeconds: (@MainActor () async throws -> Void)?
    @MainActor var onSeek: (@MainActor (Double) async throws -> Void)?
    @MainActor var onSetServer: (@MainActor (KTDisplayServer) async throws -> Void)?
    @MainActor var onGetServer: (@MainActor () async throws -> KTDisplayServer)?
    @MainActor var onClientConnected: (@MainActor () async throws -> Void)?
    @MainActor var onBackPlayer: (@MainActor () async throws -> Void)?

    /// The web view currently playing, so a new remote play request can shut it down natively.
    @ObservationIgnored @MainActor weak var activeWebView: WKWebView?

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
    public func clearClosures(
        avoidingKTDisplayServer: Bool = false
    ) {
        onPlay = nil
        onPause = nil
        onEnterFullscreen = nil
        onExitFullscreen = nil
        onForwardTenSeconds = nil
        onBackTenSeconds = nil
        onSeek = nil
        if !avoidingKTDisplayServer {
            onSetServer = nil
            onGetServer = nil
            onBackPlayer = nil
        }
    }

    @MainActor
    public func attachKTDisplayServerFunctions(
        onSetServer: @escaping (KTDisplayServer) -> Void,
        onGetServer: @escaping () -> KTDisplayServer
    ) {
        self.onSetServer = onSetServer
        self.onGetServer = onGetServer
    }

    @MainActor
    public func attachOnBackServerFunction(
        onBackPlayer: @escaping () -> Void
    ) {
        self.onBackPlayer = onBackPlayer
    }

    @MainActor
    public func attachWebViewFunctions(_ webView: WKWebView) {
        activeWebView = webView
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

    /// Pauses the active player, leaves fullscreen/PiP, and waits until WebKit has
    /// actually finished leaving fullscreen. Exiting via JavaScript only *requests*
    /// the exit; on macOS the video lives in WebKit's own fullscreen window until
    /// the animation ends, so tearing down earlier leaves it playing there.
    @MainActor
    private func stopActivePlayback() async {
        guard let webView = activeWebView else { return }
        await webView.pauseAllMediaPlayback()
        await webView.closeAllMediaPresentations()

        let deadline = ContinuousClock.now + .seconds(3)
        while webView.fullscreenState != .notInFullscreen, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
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
    private func performSetServer(_ server: KTDisplayServer) async throws -> String {
        guard let action = onSetServer else {
            throw HTTPError(.serviceUnavailable, message: "Set Server action unavailable")
        }
        try await action(server)
        return "Set Server action requested"
    }

    @MainActor
    private func performClientConnected() async throws -> String {
        guard let action = onClientConnected else {
            throw HTTPError(.serviceUnavailable, message: "On client connected unavailable")
        }
        try await action()
        return "On Client Connected action requested"
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

    @MainActor
    private func performBackOnPlayer() async {
        try? await onBackPlayer?()
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

        router.get("/volume") { [weak self] _, _ in
            guard let self = self else {
                throw HTTPError(.serviceUnavailable, message: "Volume retrieval unavailable")
            }
            await volumeManager.getCurrentSystemVolume()
            return "\(volumeManager.currentVolume)"
        }

        router.post("/volume/set") { [weak self] request, context in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Set volume action unavailable")
            }
            let amount: Float = try await request.decode(as: Float.self, context: context)
            volumeManager.setVolume(amount)
            return "Volume set to \(volumeManager.currentVolume)"
        }

        router.post("client/connected") { [weak self] _, _ in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Client connected unavailable")
            }
            return try await self.performClientConnected()
        }

        router.post("display/set") { [weak self] request, context in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Set server action unavailable")
            }
            let body = try await request.body.collect(upTo: 1024)
            let json = String(buffer: body)

            guard let server = DisplayServerCodec.shared.decodeOrNull(json: json) else {
                throw HTTPError(.badRequest, message: "Invalid display server")
            }

            return try await self.performSetServer(server)
        }

        router.get("display") { [weak self] request, context in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Get server action unavailable")
            }
            if let server = try await self.onGetServer?() {
                return "\(server)"
            }
            return "No server set"
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

            /// Stop the current video and wait for fullscreen to fully close before navigating away
            await self.stopActivePlayback()
            await performBackOnPlayer()

            onRemotePlay?(request)
            return "Play request received"
        }
    }
}

#endif
