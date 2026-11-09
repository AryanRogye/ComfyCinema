//
//  HistorySnapshot.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import MoviesAPIData
import Foundation

struct HistorySnapshot: Sendable {
    let historyId: UUID
    let resultId: Int
    let name: String
    let mediaType: HistoryMediaType
    let posterPath: String?
    let season: Int?
    let episode: Int?
    let updatedAt: Date
}
