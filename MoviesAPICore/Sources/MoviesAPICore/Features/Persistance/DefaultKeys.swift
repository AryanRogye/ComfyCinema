//
//  DefaultKeys.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import Defaults

extension Defaults.Keys {
    static let includeAdult = Key<Bool>("include_adult", default: false)

    static let hasShownCloudSavePrompt = Key<Bool>("hasShownCloudSavePrompt", default: false)
    static let enabledCloudSave = Key<Bool>("enabledCloudSave", default: false)

    #if os(iOS)
    static let useCustomTabIcons = Key<Bool>("useCustomTabIcons", default: false)
    #endif

    static let seasonPicker = Key<SeasonsPicker>("seasonPicker", default: .picker)

    #if os(macOS)
    static let enableRemoteControl = Key<Bool>("enableRemoteControl", default: false)
    static let remoteControlIp = Key<String>("remoteControlIp", default: "0.0.0.0")
    /// Bonjour name shown on iOS. Empty = automatic ("<Mac name>", plus " (Debug)" in debug builds).
    static let remoteControlName = Key<String>("remoteControlName", default: "")
    static let remoteControlPort = Key<Int>("remoteControlPort", default: 8082)
    #endif
}

enum SeasonsPicker: String, CaseIterable, Defaults.Serializable {
    case picker = "Picker"
    case showAll = "Show All"
}
