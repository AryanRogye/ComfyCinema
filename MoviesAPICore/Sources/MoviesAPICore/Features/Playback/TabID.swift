//
//  TabID.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftUI

public enum TabID: String, Hashable, CaseIterable {
    case home = "Home"
    case library = "Library"
    case history = "History"
#if os(iOS)
    case remote = "Remote"
#endif
    case settings = "Settings"
    case search = "Search"

    public var icon: String {
        switch self {
        case .home:
            "house"
        case .library:
            "books.vertical.fill"
#if os(iOS)
        case .remote:
            "av.remote"
#endif
        case .history:
            "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .settings:
            "gear"
        case .search:
            "magnifyingglass"
        }
    }

    public var image: String {
        switch self {
        case .home:
            "HomeIcon"
        case .library:
            "LibraryIcon"
        case .history:
            "HistoryIcon"
        case .remote:
            "RemoteIcon"
        case .settings:
            "SettingsIcon"
        case .search:
            "SearchIcon"
        }
    }

    var label: some View {
        Label {
            Text(self.rawValue)
        } icon: {
            Image(self.image, bundle: .module)
        }
    }
}
