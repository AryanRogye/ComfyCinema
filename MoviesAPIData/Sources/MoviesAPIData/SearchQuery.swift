//
//  SearchQuery.swift
//  MoviesAPIData
//
//  Created by Aryan Rogye on 11/19/26.
//

import SwiftData

@Model
public final class SearchQuery {
    public var query: String

    public init(query: String) {
        self.query = query
    }
}
