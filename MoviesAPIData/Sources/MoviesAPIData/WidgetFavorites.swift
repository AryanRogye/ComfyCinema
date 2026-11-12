//
//  WidgetFavorites.swift
//  MoviesAPIData
//
//  Created by Aryan Rogye on 11/10/26.
//

#if os(macOS)
import SwiftData

@Model
public final class WidgetFavorites {
    public var favorite1ID: Int?
    public var favorite2ID: Int?
    public var favorite3ID: Int?
    public var favorite4ID: Int?

    public init(
        favorite1ID: Int? = nil,
        favorite2ID: Int? = nil,
        favorite3ID: Int? = nil,
        favorite4ID: Int? = nil
    ) {
        self.favorite1ID = favorite1ID
        self.favorite2ID = favorite2ID
        self.favorite3ID = favorite3ID
        self.favorite4ID = favorite4ID
    }
}
#endif
