//
//  ModelConfigFetcher.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import SwiftData
import Foundation
import MoviesAPIData

@MainActor
enum ModelConfigFetcher: Sendable {
    public static func fetch() throws -> ModelContainer {

        /// Find identifier from Bundle
        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: "AppGroup"
        ) as? String else {
            fatalError("AppGroup not found")
        }
        if identifier.isEmpty {
            fatalError("AppGroup Empty")
        }

        /// Load Schema
        let schema = Schema(
            versionedSchema: MoviesSchemaV3.self
        )

        /// Load Config
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(identifier),
            cloudKitDatabase: .none
        )

        /// Return Container
        return try ModelContainer(
            for: schema,
            migrationPlan: MoviesMigrationPlan.self,
            configurations: configuration
        )
    }
}
