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

public enum MoviesMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            MoviesSchemaV2.self,
            MoviesSchemaV3.self
        ]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: MoviesSchemaV2.self,
                toVersion: MoviesSchemaV3.self
            )
        ]
    }
}
