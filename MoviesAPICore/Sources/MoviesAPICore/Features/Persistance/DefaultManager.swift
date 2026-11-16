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
    public var includeAdult: Bool = Defaults[.includeAdult] {
        didSet {
            Defaults[.includeAdult] = includeAdult
        }
    }
}
