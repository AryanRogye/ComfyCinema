//
//  MoviesSchema.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftData

@MainActor
public enum MoviesSchemaV2: @preconcurrency VersionedSchema {
    @MainActor public static var versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [Favorite.self, History.self, Collection.self, CollectionItem.self]
    }
}

@MainActor
public enum MoviesSchemaV3: @preconcurrency VersionedSchema {
    @MainActor public static var versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
#if os(iOS)
        [Favorite.self, History.self, Collection.self, CollectionItem.self]
#elseif os(macOS)
        [Favorite.self, WidgetFavorites.self, History.self, Collection.self, CollectionItem.self]
#endif
    }
}

@MainActor
public enum MoviesSchemaV4: @preconcurrency VersionedSchema {
    @MainActor public static var versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
#if os(iOS)
        [Favorite.self, History.self, Collection.self, CollectionItem.self, SearchQuery.self]
#elseif os(macOS)
        [Favorite.self, WidgetFavorites.self, History.self, Collection.self, CollectionItem.self, SearchQuery.self]
#endif
    }
}

public enum MoviesMigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
#if os(iOS)
        [
            MoviesSchemaV2.self,
            MoviesSchemaV4.self
        ]
#elseif os(macOS)
        [
            MoviesSchemaV2.self,
            MoviesSchemaV3.self,
            MoviesSchemaV4.self
        ]
#endif
    }

    public static var stages: [MigrationStage] {
#if os(iOS)
        [
            .lightweight(
                fromVersion: MoviesSchemaV2.self,
                toVersion: MoviesSchemaV4.self
            )
        ]
#elseif os(macOS)
        [
            .lightweight(
                fromVersion: MoviesSchemaV2.self,
                toVersion: MoviesSchemaV3.self
            ),
            .lightweight(
                fromVersion: MoviesSchemaV3.self,
                toVersion: MoviesSchemaV4.self
            )
        ]
#endif
    }
}
