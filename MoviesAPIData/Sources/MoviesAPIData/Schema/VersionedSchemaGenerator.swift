//
//  VersionedSchemaGenerator.swift
//  MoviesAPIData
//
//  Created by Aryan Rogye on 11/21/26.
//

import SwiftData

enum VersionedSchemaGenerator {
    private static let deviceSchemas: [any VersionedSchemaDeviceDetail.Type] = [
        MoviesSchemaV2.self,
        MoviesSchemaV3.self,
        MoviesSchemaV4.self
    ]

    /// Returns the schema versions that changed on the current platform.
    static func schemas() -> [any VersionedSchema.Type] {
        #if os(iOS)
        return deviceSchemas.filter { $0.didChangeOnPhone }
        #elseif os(macOS)
        return deviceSchemas.filter { $0.didChangeOnMac }
        #endif
    }

    static func stages() -> [MigrationStage] {
        let schemas = schemas()

        guard schemas.count >= 2 else { return [] }
        var stages: [MigrationStage] = []

        for index in 0..<(schemas.count - 1) {
            let from: any VersionedSchema.Type = schemas[index]
            let to: any VersionedSchema.Type = schemas[index + 1]

            stages.append(
                .lightweight(
                    fromVersion: from,
                    toVersion: to
                )
            )
        }

        return stages
    }
}
