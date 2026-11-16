//
//  View+resizeWindow.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

#if os(macOS)

import SwiftUI
import AppKit

extension View {
    public func resizeWindow(
        width: CGFloat,
        height: CGFloat,
        _ windowCompletionHandler: @escaping (NSWindow) -> Void = { _ in }
    ) -> some View {
        self
            .background {
                ResizeWindowRepresentable(width: width, height: height, onWindow: windowCompletionHandler)
            }
    }
}

private struct ResizeWindowRepresentable: NSViewRepresentable {

    let width: CGFloat
    let height: CGFloat
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> ResizeWindowView {
        return ResizeWindowView(width: width, height: height, onWindow: onWindow)
    }
    func updateNSView(_ nsView: ResizeWindowView, context: Context) {}
}

private final class ResizeWindowView: NSView {

    let width: CGFloat
    let height: CGFloat
    let onWindow: (NSWindow) -> Void

    init(
        width: CGFloat,
        height: CGFloat,
        onWindow: @escaping (NSWindow) -> Void
    ) {
        self.width = width
        self.height = height
        self.onWindow = onWindow
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("Fatal Error: Not Yet Implemented")
    }

    override func viewDidMoveToWindow() {
        guard let window else { return }
        let frame = window.frame
        window.setFrame(NSRect(x: frame.minX, y: frame.maxY - height, width: width, height: height), display: true)
        onWindow(window)
    }
}

#endif
