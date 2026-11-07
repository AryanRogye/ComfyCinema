//
//  EmbeddedMovieView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import WebKit
import ProccesInfo

@Observable
@MainActor
final class EmbeddedMovieViewModel {
    private(set) var error: String?
    var showError: Bool = false
    var estimatedProgress: Double = 0
    var isLoading: Bool = false

#if os(macOS)
    @ObservationIgnored
    weak var webView: WKWebView?

    func stopPlayback() {
        webView?.stopLoading()
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
    }

    @ObservationIgnored
    var freezeProcess: () -> Void = {}

    @ObservationIgnored
    var unfreezeProcess: () -> Void = {}
#endif

    func handleLoadFailure(_ error: Error) {
        let error = error as NSError
        if error.domain == NSURLErrorDomain,
           error.code == NSURLErrorCancelled {
            return
        }

        showError = true
        self.error = error.localizedDescription
        return
    }
}

struct TimeInfo: Codable {
    var currentTime: Double
    var duration: Double
}

struct EmbeddedMovieView: View {

    @Environment(PlaybackSession.self) var playbackSession
    @Environment(BlockingService.self) var blockingService

    let url: URL
    @Bindable var vm: EmbeddedMovieViewModel

    var allowsInlinePlayback: Bool = false

    var onTimeInfo: (TimeInfo) -> Void = { _ in }
    var iFrameLogs: (String) -> Void = { _ in }
    var videoFrameLogs: (String) -> Void = { _ in }
    var navigationLogs: (String) -> Void = { _ in }
    var memoryInfo: (Double) -> Void = { _ in }
    var cpuInfo: (Double) -> Void = { _ in }
    var threadInfo: (Int32) -> Void = { _ in }
    var onWKWebView: (WKWebView) -> Void = { _ in }

    var body: some View {
        WebView(
            vm: vm,
            playbackSession: playbackSession,
            blockingService: blockingService,
            url: url,
            allowsInlinePlayback: allowsInlinePlayback,
            onTimeInfo: onTimeInfo,
            iFrameLogs: iFrameLogs,
            videoFrameLogs: videoFrameLogs,
            navigationLogs: navigationLogs,
            memoryInfo: memoryInfo,
            cpuInfo: cpuInfo,
            threadInfo: threadInfo,
            onWKWebView: onWKWebView
        )
        .overlay(alignment: .topLeading) {
            loadingProgress
        }
        .alert(isPresented: $vm.showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(vm.error, default: "Unknown Error")")
            )
        }
    }

    @ViewBuilder
    private var loadingProgress: some View {
        if vm.isLoading {
            GeometryReader { geo in
                Capsule()
                    .fill(.yellow)
                    .frame(
                        width: geo.size.width * vm.estimatedProgress,
                        height: 3
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: vm.estimatedProgress
                    )
            }
            .frame(height: 3)
        }
    }
}

#if os(iOS)
private typealias Representable = UIViewRepresentable
#elseif os(macOS)
private typealias Representable = NSViewRepresentable
#endif

/// Bridges a `WKWebView` from `WebViewModel` into SwiftUI.
struct WebView: Representable {

    @AppStorage("PreferStandardMediaSource") private var preferStandardMediaSource = false

    @Bindable var vm: EmbeddedMovieViewModel
    @Bindable var playbackSession: PlaybackSession
    let blockingService: BlockingService
    let url: URL
    let allowsInlinePlayback: Bool
    let onTimeInfo: (TimeInfo) -> Void
    let iFrameLogs: (String) -> Void
    let videoFrameLogs: (String) -> Void
    let navigationLogs: (String) -> Void
    let memoryInfo: (Double) -> Void
    let cpuInfo: (Double) -> Void
    let threadInfo: (Int32) -> Void
    let onWKWebView: (WKWebView) -> Void

#if os(iOS)
    func makeUIView(context: Context) -> WKWebView {
        let webView = makeWebView(context: context)
        onWKWebView(webView)
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        updatePlaybackCompatibility(in: uiView)
    }
#elseif os(macOS)
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let webView = makeWebView(context: context)
        onWKWebView(webView)

        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]

        container.addSubview(webView)

        return container
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let webView = nsView.subviews
            .compactMap({ $0 as? WKWebView })
            .first else {
            return
        }

        updatePlaybackCompatibility(in: webView)
    }
#endif

    private func makeWebView(context: Context) -> WKWebView {

        if let webView = playbackSession.webView {
            blockingService.attachNetworkFilters(to: webView)
            context.coordinator.attach(to: webView)
            updatePlaybackCompatibility(in: webView)
            return webView
        }

        let config = WKWebViewConfiguration()
#if os(iOS)
        // Live providers render their player inside the page.
        config.allowsInlineMediaPlayback = allowsInlinePlayback
        config.allowsPictureInPictureMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = false
#else
        config.preferences.isElementFullscreenEnabled = true
#endif
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
#if os(iOS)
        if allowsInlinePlayback {
            config.userContentController.addUserScript(WKUserScript(
                source: Self.liveMediaSourceScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            ))
        }
#endif
        synchronizePlaybackCompatibility(in: config.userContentController)
        blockingService.attachPopupBlocking(to: config)

        let wv = WKWebView(frame: .zero, configuration: config)
#if DEBUG
        wv.isInspectable = true
#endif
        wv.allowsBackForwardNavigationGestures = false

#if os(iOS)
        wv.isOpaque = true
        wv.layer.drawsAsynchronously = true
        wv.layer.shouldRasterize = false
        wv.scrollView.decelerationRate = .normal
#elseif os(macOS)
        wv.layer?.drawsAsynchronously = true
        wv.layer?.shouldRasterize = false
#endif

        blockingService.attachNetworkFilters(to: wv)
        context.coordinator.attach(to: wv)

#if os(iOS)
        playbackSession.webView = wv
#elseif os(macOS)
        vm.webView = wv
#endif
        let playbackURL = allowsInlinePlayback ? LiveTVPlaybackURL.resolve(url) : url
        wv.load(playbackURL)

        SettingLogs.shared.add("WebView: \(url.absoluteString)")
        return wv
    }

#if os(iOS)
    /// This live provider's JW player detects only MediaSource on iPhone and
    /// otherwise bypasses its custom HLS loader. Use the managed implementation
    /// when standard MSE is absent. Managed playback requires disabling AirPlay
    /// without an alternative source; scope that change to this provider's videos.
    private static let liveMediaSourceScript = """
    (() => {
        if (location.hostname !== 'dembed.st') return;
        if (typeof window.MediaSource !== 'undefined' || typeof window.ManagedMediaSource !== 'function') return;
        Object.defineProperty(window, 'MediaSource', { value: window.ManagedMediaSource, configurable: true });
        const createElement = Document.prototype.createElement;
        Document.prototype.createElement = function (...args) {
            const element = Reflect.apply(createElement, this, args);
            if (element instanceof HTMLVideoElement) {
                element.disableRemotePlayback = true;
                element.playsInline = true;
            }
            return element;
        };
    })();
    """
#endif

    /// Works around slow or stalled seeks in provider players that prefer
    /// WebKit's ManagedMediaSource over ordinary MediaSource.
    /// In a standalone MoviesAPI test, seeking Star Wars (1977) to one hour
    /// remained stuck for over 60 seconds with only the opening video buffered.
    /// Hiding ManagedMediaSource let the player's HLS.js feature detection fall
    /// back to ordinary MediaSource; the same seek then completed in 1.38 seconds.
    /// This changes the player's streaming path while keeping playback in WebKit.
    /// It does not establish whether the underlying defect is in WebKit or the
    /// provider's player integration, nor guarantee a fix for startup failures.
    /// A player's API selection can look like this (simplified):
    /// ```javascript
    /// const StreamingAPI = window.ManagedMediaSource ?? window.MediaSource;
    /// const stream = new StreamingAPI();
    /// ```
    /// The precise requirement is to hide ManagedMediaSource before the player
    /// selects or caches that constructor. Hiding it afterward does not replace
    /// a cached constructor or an already-created stream. Use .atDocumentStart
    /// to run before provider initialization, in the .page world so the provider
    /// sees the change, and in every frame so embedded players see it too.
    /// The toolbar setting controls this workaround for all providers on both platforms.
    /// Disable it for providers that need ManagedMediaSource. Changes reload the player.
    private static let standardMediaSourceScript = """
    Object.defineProperty(window, "ManagedMediaSource", {
        value: undefined,
        configurable: true
    });
    """

    /// Replace only this workaround's script, preserving popup blocking and watchers.
    @discardableResult
    private func synchronizePlaybackCompatibility(in controller: WKUserContentController) -> Bool {
        // WebKit's bridged array can change when removeAllUserScripts runs.
        // Materialize an independent snapshot before removing/readding scripts.
        let scripts = controller.userScripts.map { $0 }
        let isEnabled = scripts.contains { $0.source == Self.standardMediaSourceScript }
        guard isEnabled != preferStandardMediaSource else { return false }

        if preferStandardMediaSource {
            controller.addUserScript(WKUserScript(
                source: Self.standardMediaSourceScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            ))
        } else {
            controller.removeAllUserScripts()
            for script in scripts where script.source != Self.standardMediaSourceScript {
                controller.addUserScript(script)
            }
        }
        return true
    }

    private func updatePlaybackCompatibility(in webView: WKWebView) {
        guard synchronizePlaybackCompatibility(in: webView.configuration.userContentController) else { return }
        // Changing the global cannot replace an existing stream; rebuild the page.
        webView.reload()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            vm: vm,
            url: url,
            onTimeInfo: onTimeInfo,
            iFrameLogs: iFrameLogs,
            videoFrameLogs: videoFrameLogs,
            navigationLogs: navigationLogs,
            memoryInfo: memoryInfo,
            cpuInfo: cpuInfo,
            threadInfo: threadInfo
        )
    }

    // MARK: – Web View Delegates

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        let url: URL
        private var videoFrame: WKFrameInfo?
        // Aggregate limit across every iframe, independent of provider-side throttling.
        internal var diagnosticWindowStart = ProcessInfo.processInfo.systemUptime
        internal var diagnosticCount = 0
        internal var vm: EmbeddedMovieViewModel
        let onTimeInfo: (TimeInfo) -> Void
        let iFrameLogs: (String) -> Void
        let videoFrameLogs: (String) -> Void
        let navigationLogs: (String) -> Void
        let memoryInfo: (Double) -> Void
        let cpuInfo: (Double) -> Void
        let threadInfo: (Int32) -> Void
        var pid: pid_t?

        private var kvoTokens: [NSKeyValueObservation] = []

#if os(macOS)
        var perfMonitor: Task<Void, Never>?

        deinit {
            perfMonitor?.cancel()
            perfMonitor = nil
        }
#endif

        init(
            vm: EmbeddedMovieViewModel,
            url: URL,
            onTimeInfo: @escaping (TimeInfo) -> Void,
            iFrameLogs: @escaping (String) -> Void,
            videoFrameLogs: @escaping (String) -> Void,
            navigationLogs: @escaping (String) -> Void,
            memoryInfo: @escaping (Double) -> Void,
            cpuInfo: @escaping (Double) -> Void,
            threadInfo: @escaping (Int32) -> Void

        ) {
            self.vm = vm
            self.url = url
            self.onTimeInfo = onTimeInfo
            self.iFrameLogs = iFrameLogs
            self.videoFrameLogs = videoFrameLogs
            self.navigationLogs = navigationLogs
            self.memoryInfo = memoryInfo
            self.cpuInfo = cpuInfo
            self.threadInfo = threadInfo
            super.init()
        }

        func attach(to webView: WKWebView) {
            webView.navigationDelegate = self
            webView.uiDelegate = self
            kvoTokens.removeAll()
            startObservation(with: webView)
            attachWatcher(to: webView)
            beginMonitoringPID()

//            findProcessMethods(webView)

#if os(macOS)
            vm.freezeProcess = { [weak self] in
                guard let self else { return }
                guard let pid else { return }
                freeze_process(pid)
            }

            vm.unfreezeProcess = { [weak self] in
                guard let self else { return }
                guard let pid else { return }
                resume_process(pid)
                webView.layer?.setNeedsLayout()
            }
#endif
        }
    }
}

// MARK: - WKWebView Conformance
extension WebView.Coordinator {
    /// Apply the same restriction if WebKit delivers a new-window request
    /// directly to the UI delegate. Never load arbitrary scripted pop-ups.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        navigationLogs(
            "Attempted To Navigate To \(navigationAction.request.url?.absoluteString ?? "Unknown URL")"
        )
        return nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "about", "blob", "data"].contains(scheme) else {
            // Provider ads can try to navigate child frames to app-store or
            // custom URL schemes. Cancel before WebKit raises unsupported URL.
            decisionHandler(.cancel)
            return
        }

        let liveHosts: Set<String> = ["dlive.sx", "thedaddy.pk", "dembed.st"]
        if let originalHost = self.url.host?.lowercased(), liveHosts.contains(originalHost),
           let targetHost = navigationAction.targetFrame?.request.url?.host?.lowercased(),
           liveHosts.contains(targetHost),
           ["http", "https"].contains(scheme),
           !liveHosts.contains(url.host?.lowercased() ?? "") {
            // Keep the published host/player frames from being replaced by ad
            // destinations. New child frames and media subresources are separate.
            decisionHandler(.cancel)
            return
        }

        guard navigationAction.targetFrame?.isMainFrame == true else {
            decisionHandler(.allow)
            return
        }

        SettingLogs.shared.add("➡️ NAVIGATION: \(url.absoluteString)")

        // Teardown documents navigate through about:blank.
        if url.absoluteString == "about:blank" {
            decisionHandler(.allow)
            return
        }

        if let allowedHost = url.host() {
            if url.host?.lowercased() == allowedHost {
                decisionHandler(.allow)
            } else {
                print("🚫 BLOCKED REDIRECT:", url.absoluteString)
                decisionHandler(.cancel)
            }
        } else {
            decisionHandler(.cancel)
        }
    }

    /// Errors
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationLogs("[\(Date().ISO8601Format())] Navigation failed: \(error as NSError)")
        Task { @MainActor in
            vm.handleLoadFailure(error)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationLogs("[\(Date().ISO8601Format())] Navigation failed: \(error as NSError)")
        Task { @MainActor in
            vm.handleLoadFailure(error)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        navigationLogs("[\(Date().ISO8601Format())] Web content process terminated")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        navigationLogs("[\(Date().ISO8601Format())] Navigation started: \(webView.url?.absoluteString ?? "unknown")")
    }

    /// Navigation Did Finish
    /// - Tag: WKNavigationDelegate_didFinishNavigation
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            vm.showError = false
            loadPID(for: webView)
            loadStartTimeForPID()
        }
    }
}

// MARK: - Observation
extension WebView.Coordinator {
    internal func startObservation(with webView: WKWebView) {
        kvoTokens.append(
            webView.observe(\.isLoading, options: .new) { [weak self] _, change in
                guard let self else { return }
                let val = change.newValue ?? false
                Task { @MainActor in self.vm.isLoading = val }
            }
        )
        kvoTokens.append(
            webView.observe(\.estimatedProgress, options: .new) { [weak self] _, change in
                guard let self else { return }
                let val = change.newValue ?? 0
                Task { @MainActor in self.vm.estimatedProgress = val }
            }
        )
    }
}

// MARK: - Dismantle
extension WebView {
#if os(macOS)
    static func dismantleNSView(
        _ nsView: NSView,
        coordinator: WebView.Coordinator
    ) {
        guard let webView = nsView.subviews
            .compactMap({ $0 as? WKWebView })
            .first else {
            return
        }

        Self.dismantleView(webView, coordinator: coordinator)
    }
#elseif os(iOS)
    static func dismantleUIView(_ uiView: WKWebView, coordinator: WebView.Coordinator) {
        Self.dismantleView(uiView, coordinator: coordinator)
    }
#endif

    private static func dismantleView(_ view: WKWebView, coordinator: WebView.Coordinator) {
        // Split changes can mount a new wrapper around the same WKWebView
        // before SwiftUI dismantles the old one. Only its current owner may
        // remove delegates, message handlers, or the active video styling.
        guard view.navigationDelegate === coordinator else { return }
#if os(macOS)
        coordinator.perfMonitor?.cancel()
#endif
        view.stopLoading()
        view.loadHTMLString("", baseURL: nil)
        view.navigationDelegate = nil
        view.uiDelegate = nil

        view.configuration.userContentController.removeScriptMessageHandler(forName: "iframeDebug")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "iframeLog")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "videoLogger")
    }
}
