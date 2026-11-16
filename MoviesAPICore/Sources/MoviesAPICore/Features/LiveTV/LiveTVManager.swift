//
//  LiveTVManager.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import Foundation

enum LiveTVError: LocalizedError {
    case cantFindLiveTVJson

    var errorDescription: String? {
        switch self {
        case .cantFindLiveTVJson:
            "Cant Find LiveTV.json"
        }
    }
}

struct LiveTVContainer: Codable {
    let LiveTV: [LiveTVSection]
}

struct LiveTVSection: Codable, Identifiable, Hashable {
    var id: String { name }

    let name: String
    let channels: [LiveTVChannel]
}

struct LiveTVChannel: Codable, Identifiable, Hashable {
    let name: String
    let id: Int
    let logo: String
    let isAdult: Bool
}

@Observable
@MainActor
final class LiveTVManager {


    var sections: [LiveTVSection] {
        guard !includeAdult else {
            return sectionInternal
        }

        return sectionInternal.compactMap { section in
            let channels = section.channels.filter { !$0.isAdult }

            guard !channels.isEmpty else {
                return nil
            }

            return LiveTVSection(
                name: section.name,
                channels: channels
            )
        }
    }

    private let defaultManager: DefaultManager
    private let json: URL
    private var sectionInternal: [LiveTVSection] = []

    private var includeAdult: Bool {
        defaultManager.includeAdult
    }

    init(defaultManager: DefaultManager) throws {
        guard let json = Bundle.main.url(
            forResource: "LiveTV",
            withExtension: "json"
        ) else {
            throw LiveTVError.cantFindLiveTVJson
        }

        self.json = json
        self.defaultManager = defaultManager
        try sync()
    }

    public func sync() throws {
        let data = try Data(contentsOf: json)
        let container = try JSONDecoder().decode(
            LiveTVContainer.self,
            from: data
        )
        let sections = container.LiveTV

        self.sectionInternal =
        sections.filter { $0.name != "Adult" } +
        sections.filter { $0.name == "Adult" }
    }
}
