//
//  CloudIdentifierCreator.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/12/26.
//

import MoviesAPIData

/// Function handles getting a stable identifier name to avoid clashes for a `CKRecord`
enum CloudIdentifierCreator {
    public static func createIdentifierToAvoidClashes(
        base: String,
        resultId: Int,
        mediaType: HistoryMediaType,
        season: Int?,
        episode: Int?,
    ) throws -> String {

        /// Avoid duplicate
        let recordName: String

        switch mediaType {
        case .movie:
            recordName = "\(base)movie-\(resultId)"

        case .episode:
            guard let season = season,
                  let episode = episode else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }

            recordName = "\(base)episode-\(resultId)-s\(season)-e\(episode)"
        }

        return recordName
    }

}
