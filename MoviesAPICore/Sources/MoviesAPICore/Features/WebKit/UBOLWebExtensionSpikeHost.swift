import Foundation
import WebKit

/// Development host for the uBO Lite Safari WebExtension on this branch.
@MainActor
final class UBOLWebExtensionSpikeHost: NSObject, WKWebExtensionControllerDelegate, WKWebExtensionWindow {
    static let shared = UBOLWebExtensionSpikeHost()

    private let controller = WKWebExtensionController()
    private var extensionContext: WKWebExtensionContext?
    private var openTabs: [UBOLWebExtensionSpikeTab] = []
    private weak var activeWebView: WKWebView?

    private override init() {
        super.init()
        controller.delegate = self
        Task { await loadExtension() }
    }

    func configure(_ configuration: WKWebViewConfiguration) {
        configuration.webExtensionController = controller
    }

    func register(_ webView: WKWebView) {
        guard !openTabs.contains(where: { $0.webView === webView }) else { return }
        let tab = UBOLWebExtensionSpikeTab(webView: webView, window: self)
        openTabs.append(tab)
        controller.didOpenTab(tab)
        if activeWebView == nil { activate(webView) }
    }

    func activate(_ webView: WKWebView) {
        guard let tab = openTabs.first(where: { $0.webView === webView }) else { return }
        let previous = openTabs.first(where: { $0.webView === activeWebView })
        activeWebView = webView
        controller.didActivateTab(tab, previousActiveTab: previous)
    }

    func close(_ webView: WKWebView) {
        guard let index = openTabs.firstIndex(where: { $0.webView === webView }) else { return }
        let tab = openTabs.remove(at: index)
        controller.didCloseTab(tab, windowIsClosing: false)
        if activeWebView === webView { activeWebView = openTabs.first?.webView }
    }

    private func loadExtension() async {
        guard let bundledURL = Bundle.main.resourceURL?.appendingPathComponent("uBOLite", isDirectory: true) else {
            print("uBO Lite spike failed: app resource URL is unavailable")
            return
        }
        do {
            let extensionURL = try await Task.detached(priority: .utility) {
                let fileManager = FileManager.default
                let supportURL = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let appURL = supportURL.appendingPathComponent("ComfyPortal", isDirectory: true)
                let destinationURL = appURL.appendingPathComponent("uBOLite", isDirectory: true)
                let manifest = try Data(contentsOf: bundledURL.appendingPathComponent("manifest.json"))
                let installedManifestURL = destinationURL.appendingPathComponent(".installed-manifest")
                if let installedManifest = try? Data(contentsOf: installedManifestURL),
                   installedManifest == manifest {
                    return destinationURL
                }
                try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: bundledURL, to: destinationURL)
                try manifest.write(to: installedManifestURL, options: .atomic)
                return destinationURL
            }.value
            guard !Task.isCancelled else { return }
            let webExtension = try await WKWebExtension(resourceBaseURL: extensionURL)
            guard !Task.isCancelled else { return }
            let context = WKWebExtensionContext(for: webExtension)
            let expiration = Date.distantFuture
            context.grantedPermissions = Dictionary(
                uniqueKeysWithValues: webExtension.requestedPermissions.map { ($0, expiration) }
            )
            context.grantedPermissionMatchPatterns = Dictionary(
                uniqueKeysWithValues: webExtension.requestedPermissionMatchPatterns.map { ($0, expiration) }
            )
            try controller.load(context)
            extensionContext = context
            print("uBO Lite spike loaded: \(webExtension.displayName ?? "unknown")")
            for error in webExtension.errors + context.errors {
                print("uBO Lite spike warning: \(error.localizedDescription)")
            }
        } catch {
            print("uBO Lite spike failed: \(error.localizedDescription)")
        }
    }

    func webExtensionController(
        _ controller: WKWebExtensionController,
        openWindowsFor extensionContext: WKWebExtensionContext
    ) -> [any WKWebExtensionWindow] {
        openTabs.isEmpty ? [] : [self]
    }

    func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] {
        openTabs.filter { $0.webView != nil }
    }

    func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? {
        openTabs.first(where: { $0.webView === activeWebView }) ?? openTabs.first
    }
}

@MainActor
private final class UBOLWebExtensionSpikeTab: NSObject, WKWebExtensionTab {
    weak var webView: WKWebView?
    weak var window: UBOLWebExtensionSpikeHost?

    init(webView: WKWebView, window: UBOLWebExtensionSpikeHost) {
        self.webView = webView
        self.window = window
    }

    func webView(for context: WKWebExtensionContext) -> WKWebView? { webView }
    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? { window }
}
