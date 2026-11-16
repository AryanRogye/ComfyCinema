//
//  EmbeddedMovie+Scripting.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import WebKit

extension WebView.Coordinator: WKScriptMessageHandler {

    private func addUserScriptIfNeeded(_ script: WKUserScript, to controller: WKUserContentController) {
        // Reused WebViews retain their scripts. Rebind message handlers below,
        // but install each watcher only once without removing popup scripts.
        guard !controller.userScripts.contains(where: {
            $0.source == script.source &&
            $0.injectionTime == script.injectionTime &&
            $0.isForMainFrameOnly == script.isForMainFrameOnly
        }) else { return }
        controller.addUserScript(script)
    }

    internal func attachScripts(to webView: WKWebView) {
        attachIFrameMonitor(to: webView)

        attachIFrameLogger(to: webView)

        attachVideoLogger(to: webView)
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "videoLogger":
            let now = ProcessInfo.processInfo.systemUptime
            if now - diagnosticWindowStart >= 10 {
                diagnosticWindowStart = now
                diagnosticCount = 0
            }
            guard diagnosticCount < 20 else { return }
            diagnosticCount += 1
            guard let dictionary = message.body as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: dictionary),
                  let string = prettyPrintJSON(data) else { return }
            // TVDetailView retains at most 200 entries: at most ~1.6 MB of UTF-8
            // payload, plus String/collection overhead. Truncation may cut JSON.
            let capped = String(decoding: string.utf8.prefix(8_000), as: UTF8.self)
            videoFrameLogs(capped + (string.utf8.count > 8_000 ? "\n[truncated]" : ""))

        case "iframeLog":
            guard let dictionary = message.body as? [String: Any] else {
                print("Couldnt convert message body into dictionary")
                return
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary) else {
                print("Coudlnt convert dictionary into json data")
                return
            }

            if let string = prettyPrintJSON(jsonData) {
                //                print(string)
                iFrameLogs(string)
            }

        case "iframeDebug":

            guard let dictionary = message.body as? [String: Any] else {
                print("Couldnt convert message body into dictionary")
                return
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary) else {
                print("Coudlnt convert dictionary into json data")
                return
            }

            iFrameLogs(String(data: jsonData, encoding: .utf8) ?? "Unable To Decode message.body")

            do {
                let timeInfo = try JSONDecoder().decode(TimeInfo.self, from: jsonData)
                onTimeInfo(timeInfo)
            } catch {
                print("Error Converting iframeDebug body into `TimeInfo`: \(error.localizedDescription)")
            }
        default:
            break
        }
    }

    func prettyPrintJSON(_ jsonData: Data) -> String? {
        guard
            var outer = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                else {
            return nil
        }

        // Parse nested JSON string
        if let dataString = outer["data"] as? String,
           let data = dataString.data(using: .utf8),
           let inner = try? JSONSerialization.jsonObject(with: data) {
            outer["data"] = inner
        }

        guard
            let prettyData = try? JSONSerialization.data(
                withJSONObject: outer,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let pretty = String(data: prettyData, encoding: .utf8)
                else {
            return nil
        }

        return pretty
    }
}

extension WebView.Coordinator {
    private func attachIFrameMonitor(to webView: WKWebView) {
        guard let monitorUrl = Bundle.module.url(
            forResource: "monitorIFrame",
            withExtension: "js"
        ) else {
            print("Couldnt find monitorIFrame.js")
            return
        }
        guard let monitorText = try? String(contentsOf: monitorUrl, encoding: .utf8) else {
            print("Couldnt convert monitorIFrame.js to text")
            return
        }

        let monitorScript = WKUserScript(
            source: monitorText,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        addUserScriptIfNeeded(monitorScript, to: webView.configuration.userContentController)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "iframeDebug")
        webView.configuration.userContentController.add(self, name: "iframeDebug")
    }

    private func attachIFrameLogger(to webView: WKWebView) {
        guard let iFrameLoggerUrl = Bundle.module.url(
            forResource: "IFrameLogger",
            withExtension: "js"
        ) else {
            print("Couldnt Find IFrameLogger.js")
            return
        }
        guard let iFrameLoggerText = try? String(contentsOf: iFrameLoggerUrl, encoding: .utf8) else {
            print("Couldnt convert IFrameLogger.js to text")
            return
        }

        let loggerScript = WKUserScript(
            source: iFrameLoggerText,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        addUserScriptIfNeeded(loggerScript, to: webView.configuration.userContentController)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "iframeLog")
        webView.configuration.userContentController.add(self, name: "iframeLog")
    }

    private func attachVideoLogger(to webView: WKWebView) {
        guard let videoLoggerUrl = Bundle.module.url(
            forResource: "VideoLogger",
            withExtension: "js"
        ) else {
            print("Couldnt Find VideoLogger.js")
            return
        }
        guard let videoLoggerText = try? String(contentsOf: videoLoggerUrl, encoding: .utf8) else {
            print("Couldnt convert VideoLogger.js to text")
            return
        }

        let videoLoggerScript = WKUserScript(
            source: videoLoggerText,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        )

        addUserScriptIfNeeded(videoLoggerScript, to: webView.configuration.userContentController)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "videoLogger")
        webView.configuration.userContentController.add(self, name: "videoLogger")
    }
}
