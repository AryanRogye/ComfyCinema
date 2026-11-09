//
//  SystemColor.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

#if os(macOS)
import AppKit
typealias SystemColor = NSColor
#elseif os(iOS)
import UIKit
typealias SystemColor = UIColor
#endif
