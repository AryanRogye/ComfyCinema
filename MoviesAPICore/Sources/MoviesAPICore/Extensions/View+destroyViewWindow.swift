#if os(macOS)
//
//  View+destroyViewWindow.swift
//  ComfyMark
//
//  Created by Aryan Rogye on 8/31/25.
//


import SwiftUI

fileprivate struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        /// The NSView Destroys itself
        let v = WindowAccessorView()
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

fileprivate class WindowAccessorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.styleMask = [.borderless]
        window.setContentSize(.zero)
        window.orderOut(nil)
        window.close()
    }
}

extension View {
    public func destroyViewWindow() -> some View {
        self
            .background(WindowAccessor())
    }
}
#endif
