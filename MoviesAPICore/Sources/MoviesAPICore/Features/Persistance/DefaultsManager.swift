//
//  DefaultsManager.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import Foundation
import Defaults

@Observable
@MainActor
public final class DefaultsManager {

    #if os(iOS)
    public var useCustomTabIcons: Bool = Defaults[.useCustomTabIcons] {
        didSet {
            Defaults[.useCustomTabIcons] = useCustomTabIcons
        }
    }
    #endif

    var seasonPicker: SeasonsPicker = Defaults[.seasonPicker] {
        didSet {
            Defaults[.seasonPicker] = seasonPicker
        }
    }

    public var includeAdult: Bool = Defaults[.includeAdult] {
        didSet {
            Defaults[.includeAdult] = includeAdult
        }
    }

    #if os(macOS)
    var comfyCinemaTheme: ComfyCinemaTheme = Defaults[.comfyCinemaTheme] {
        didSet {
            Defaults[.comfyCinemaTheme] = comfyCinemaTheme
        }
    }
    #endif
}
