//
//  DeletedHistory.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/12/26.
//

import MoviesAPIData

struct DeletedHistory {
    let resultId: Int
    let mediaType: HistoryMediaType
    let season: Int?
    let episode: Int?
    let deletedAt: Date

    init(resultId: Int, mediaType: HistoryMediaType, season: Int?, episode: Int?, deletedAt: Date) {
        self.resultId = resultId
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
        self.deletedAt = deletedAt
    }

    init(history: History) {
        self.resultId = history.resultId
        self.mediaType = history.mediaType
        self.season = history.season
        self.episode = history.episode
        self.deletedAt = .now
    }
}
