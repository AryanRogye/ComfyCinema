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

    private let maxLogs = 1000

    private var fileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "logs.json")
    }

    var logs: [String] = []

    private init() {
        load()
    }

    public func add(_ value: Any) {
        logs.append(String(describing: value))

        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }

        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save logs:", error)
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            logs = Array(
                try JSONDecoder().decode([String].self, from: data)
                    .suffix(maxLogs)
            )
        } catch {
            logs = []
        }
    }

    public func clear() {
        logs.removeAll()
        save()
    }
}
