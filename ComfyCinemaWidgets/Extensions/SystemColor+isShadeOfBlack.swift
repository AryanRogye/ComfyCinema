//
//  SystemColor+isShadeOfBlack.swift
//  ComfyCinema
//
//  Created by Aryan Rogye on 7/10/25.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SwiftUI

extension Color {
    func isDark(threshold: CGFloat = 0.6) -> Bool {
#if os(macOS)
        NSColor(self).isDark(threshold: threshold)
#elseif os(iOS)
        UIColor(self).isDark(threshold: threshold)
#endif
    }
}

#if os(macOS)
extension NSColor {
    func isDark(threshold: CGFloat = 0.6) -> Bool {
        guard let color = usingColorSpace(.sRGB) else {
            return false
        }

        let luminance =
        0.2126 * color.redComponent +
        0.7152 * color.greenComponent +
        0.0722 * color.blueComponent

        return luminance <= threshold
    }
}
#elseif os(iOS)
extension UIColor {
    func isDark(threshold: CGFloat = 0.6) -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return false
        }

        let luminance =
        0.2126 * red +
        0.7152 * green +
        0.0722 * blue

        return luminance <= threshold
    }
}
#endif
