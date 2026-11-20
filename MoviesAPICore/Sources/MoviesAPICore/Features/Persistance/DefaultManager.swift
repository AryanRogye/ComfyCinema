//
//  DefaultManager.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import Foundation
import Defaults

@Observable
@MainActor
public final class DefaultManager {

    #if os(iOS)
    public var useCustomTabIcons: Bool = Defaults[.useCustomTabIcons] {
        didSet {
            Defaults[.useCustomTabIcons] = useCustomTabIcons
        }
    }
    #endif

    public var includeAdult: Bool = Defaults[.includeAdult] {
        didSet {
            Defaults[.includeAdult] = includeAdult
        }
    }
}
