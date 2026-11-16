//
//  EmbeddedMovieViewModel.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/11/26.
//

import WebKit
import Foundation

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
