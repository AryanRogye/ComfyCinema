//
//  AppRouter.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/3/26.
//

import Foundation
import MoviesAPIData

@Observable
@MainActor
public final class AppRouter {

    public var selectedTab: TabID = .home
    /// Used for history intent
    var selectedHistory: History?
    /// Set by the remote server. MacOSRoot resets navigation, then forwards it to `routedRemoteRequest`.
    var remoteRequest: PlayRequest?
    /// Navigation is already reset; the home view consumes this one.
    var routedRemoteRequest: PlayRequest?

    var searchTriggered: KTSearchResult? = nil

    public var clickedWidgetWithFavoriteID: Int?
    public var clickedWidgetWithResultID: String?

    public init() {}

}
