//
//  BlockingService.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation
import WebKit

@Observable
@MainActor
public final class BlockingService {
    let networkFilteringService = NetworkFilteringService()
    let popupFilteringService = PopupFilteringService()
    let adFilteringService = AdFilteringService()

    public var isCompilingNetworkFiltering: Bool = false
    public var appliedNetworkFiltering = false
    public var hasAttemptedNetworkFiltering = false
    public var networkFilterError: String? = nil
    private var networkFilterTask: Task<Void, Never>?
    private let filteredControllers = NSHashTable<WKUserContentController>.weakObjects()
    private let pendingControllers = NSHashTable<WKUserContentController>.weakObjects()

    public var appliedPopupBlocking = false
    public var popupBlockingError: String? = nil

    public private(set) var isNetworkFilteringReady = false

    public init() {
        preloadNetworkFilters()
    }

    public func attachPopupBlocking(to config: WKWebViewConfiguration) {
        do {
            let javascript = try popupFilteringService.getJavascript()
            let script = WKUserScript(
                source: javascript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false,
                in: .defaultClient
            )
            config.userContentController.addUserScript(script)

            appliedPopupBlocking = true
        } catch {
            self.popupBlockingError = error.localizedDescription
            appliedPopupBlocking = false
        }

        // Cosmetic filtering is independent of loading the popup rules.
        if let adBlocking = adFilteringService.getJavascript() {
            let blockingScript = WKUserScript(
                source: adBlocking,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: .page
            )
            config.userContentController.addUserScript(blockingScript)
            print("Added Ad Blocking Script")
        } else {
            print("Cant Find Javascript For Ad Blocking")
        }
    }

    public func preloadNetworkFilters() {
        networkFilterTask = Task {
            isCompilingNetworkFiltering = true

            defer {
                isCompilingNetworkFiltering = false
                networkFilterTask = nil
            }

            do {
                _ = try await networkFilteringService.compileNetworkRules()
                try Task.checkCancellation()

                isNetworkFilteringReady = true
                networkFilterError = nil
            } catch is CancellationError {
                return
            } catch {
                isNetworkFilteringReady = false
                networkFilterError = error.localizedDescription
            }
        }
    }

    public func attachNetworkFilters(to webView: WKWebView) {
        let controller = webView.configuration.userContentController
        if filteredControllers.contains(controller) || pendingControllers.contains(controller) {
            return
        }

        /// Check Cache first
        if let cachedRuleList = networkFilteringService.ruleList {
            controller.add(cachedRuleList)
            filteredControllers.add(controller)
            appliedNetworkFiltering = true
            hasAttemptedNetworkFiltering = true
            isNetworkFilteringReady = true
            networkFilterError = nil
            return
        }

        isCompilingNetworkFiltering = true
        networkFilterError = nil

        // Multiple grid players may attach concurrently; compiling is already
        // coalesced by NetworkFilteringService. Never cancel another tile.
        pendingControllers.add(controller)
        Task { [weak controller] in
            defer {
                if let controller { self.pendingControllers.remove(controller) }
                self.isCompilingNetworkFiltering = self.pendingControllers.count > 0
            }
            do {
                let ruleList = try await networkFilteringService.compileNetworkRules()
                try Task.checkCancellation()
                guard let controller else { return }
                controller.add(ruleList)
                self.filteredControllers.add(controller)
                appliedNetworkFiltering = true
                hasAttemptedNetworkFiltering = true
                isNetworkFilteringReady = true
            } catch is CancellationError {
                /// Ignore
                return
            } catch {
                /// Ignore Error
                /// we dont want to block the users flow
                networkFilterError = error.localizedDescription
                hasAttemptedNetworkFiltering = true
                isNetworkFilteringReady = false
            }
        }
    }

}
