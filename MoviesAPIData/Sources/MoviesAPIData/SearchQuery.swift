//
//  SearchQuery.swift
//  MoviesAPIData
//
//  Created by Aryan Rogye on 11/19/26.
//

import SwiftData

@Model
final class SearchQuery {
    var query: String

    init(query: String) {
        self.query = query
    }
}
