//
//  SearchQuery.swift
//  MoviesAPIData
//
//  Created by Aryan Rogye on 11/19/26.
//

import SwiftData
import Foundation

@Model
public final class SearchQuery {
    public var query: String
    public var date: Date? = nil

    public init(query: String) {
        self.query = query
        self.date = .now
    }
}
