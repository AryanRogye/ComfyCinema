//
//  AppRouter.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/3/26.
//

import Foundation

@Observable
@MainActor
public final class AppRouter {

    var selectedTab: TabID = .home
    /// Used for history intent
    var selectedHistory: History?

    var searchTriggered: KTSearchResult? = nil

    public init() {}

}
