//
//  EmbeddedMovieScreenshoter.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import WebKit

final class EmbeddedMovieScreenshoter {

    var screenshotTask: Task<Void, Never>?

    public func stop() {
        screenshotTask?.cancel()
        screenshotTask = nil
    }

    public func scheduleWebViewScreenshot(webView: WKWebView, for result: KTSearchResult) {
        screenshotTask?.cancel()
        let currentWKWebView = webView
        screenshotTask = Task.detached(priority: .userInitiated) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(120))
                if Task.isCancelled { return }

                Task { @MainActor in
                    self.takeScreenshot(currentWKWebView: currentWKWebView, for: result)
                }
            }
        }
    }

    private func takeScreenshot(currentWKWebView: WKWebView, for result: KTSearchResult) {
        currentWKWebView.takeSnapshot(with: nil) { image, error in
            guard let image else {
                return
            }
            guard let data = ContentImageStore.encode(image) else {
                return
            }

            try? ContentImageStore.store(
                data: data,
                forID: result.id,
                mediaType: result.mediaType
            )
        }
    }
}
