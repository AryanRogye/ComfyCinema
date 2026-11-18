//
//  TabID.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/17/26.
//

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
}
