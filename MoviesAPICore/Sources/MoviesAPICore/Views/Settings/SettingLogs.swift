//
//  SettingLogs.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/3/26.
//

import Foundation

@Observable
@MainActor
final class SettingLogs {
    static let shared = SettingLogs()
    var logs: [String] = []

    public func add(_ value: Any) {
        logs.append(String(describing: value))
        if logs.count > 1000 { logs.removeFirst(logs.count - 1000) }
    }
}
