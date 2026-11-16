//
//  SystemImage.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

#if os(macOS)
import AppKit
typealias SystemImage = NSImage
#elseif os(iOS)
import UIKit
typealias SystemImage = UIImage
#endif
