//
//  MoviesSchema.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData

public let current_iOS_schema = MoviesSchemaV5.self
public let current_macOS_schema = MoviesSchemaV5.self

/// MoviesSchemaV2 handles both macOS and iOS
public enum MoviesSchemaV2: VersionedSchemaDeviceDetail {
    public nonisolated static var versionIdentifier: Schema.Version {
        .init(2, 0, 0)
    }

    public nonisolated static let didChangeOnPhone = true
    public nonisolated static let didChangeOnMac = true

    public static var models: [any PersistentModel.Type] {
        [Favorite.self, History.self, Collection.self, CollectionItem.self]
    }
}

/// MoviesSchemaV3 keeps iOS the exact same, but macOS gets a new `WidgetFavorites`
public enum MoviesSchemaV3: VersionedSchemaDeviceDetail {
    public nonisolated static var versionIdentifier: Schema.Version {
        .init(3, 0, 0)
    }

    public nonisolated static let didChangeOnPhone: Bool = false
    public nonisolated static let didChangeOnMac: Bool = true

    public static var models: [any PersistentModel.Type] {
#if os(iOS)
        [Favorite.self, History.self, Collection.self, CollectionItem.self]
#elseif os(macOS)
        [Favorite.self, WidgetFavorites.self, History.self, Collection.self, CollectionItem.self]
#endif
    }
}

/// MoviesSchemaV4 adds a `SearchQuery` to both iOS and macOS
public enum MoviesSchemaV4: VersionedSchemaDeviceDetail {
    public nonisolated static var versionIdentifier: Schema.Version {
        .init(4, 0, 0)
    }

    public nonisolated static let didChangeOnPhone: Bool = true
    public nonisolated static let didChangeOnMac: Bool = true

    public static var models: [any PersistentModel.Type] {
#if os(iOS)
        [Favorite.self, History.self, Collection.self, CollectionItem.self, MoviesSchemaV4.SearchQuery.self]
#elseif os(macOS)
        [Favorite.self, WidgetFavorites.self, History.self, Collection.self, CollectionItem.self, MoviesSchemaV4.SearchQuery.self]
#endif
    }

    /// Frozen copy of `SearchQuery` as it shipped in V4 (before `date` was added).
    /// Do not modify — it must match the on-disk V4 store exactly.
    @Model
    public final class SearchQuery {
        public var query: String

        public init(query: String) {
            self.query = query
        }
    }
}

/// MoviesSchemaV5 adds an optional `date` to `SearchQuery` on both iOS and macOS
public enum MoviesSchemaV5: VersionedSchemaDeviceDetail {
    public nonisolated static var versionIdentifier: Schema.Version {
        .init(5, 0, 0)
    }

    public nonisolated static let didChangeOnPhone: Bool = true
    public nonisolated static let didChangeOnMac: Bool = true

    public static var models: [any PersistentModel.Type] {
#if os(iOS)
        [Favorite.self, History.self, Collection.self, CollectionItem.self, MoviesAPIData.SearchQuery.self]
#elseif os(macOS)
        [Favorite.self, WidgetFavorites.self, History.self, Collection.self, CollectionItem.self, MoviesAPIData.SearchQuery.self]
#endif
    }
}

public enum MoviesMigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        VersionedSchemaGenerator.schemas()
    }

    public static var stages: [MigrationStage] {
        VersionedSchemaGenerator.stages()
    }
}
