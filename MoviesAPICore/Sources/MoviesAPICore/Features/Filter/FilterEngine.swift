//
//  FilterEngine.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/18/26.
//

import MoviesAPIData

enum FilterEngine {
    struct HistorySearchIntent {
        var name: String?
        var mediaType: HistoryMediaType?
        var season: Int?
        var episode: Int?
        var dateRange: DateInterval?
    }

    static let patterns = [
        // Season / episode numbers (must come first)
        #"\b(?:season|episode)\s+\d+\b"#,

        // Media keywords
        #"\b(?:movies?|tvs?|episodes?|seasons?|films?|shows?)\b"#,

        // Relative dates
        #"\b(?:today|yesterday|tomorrow)\b"#,

        // Calendar periods
        #"\b(?:last|this|next)\s+(?:week|month|year)\b"#,

        // Time ago: 3 days ago, 2 hours ago
        #"\b\d+\s*(?:seconds?|secs?|minutes?|mins?|hours?|hrs?|days?|weeks?|months?|years?)\s+ago\b"#,

        // Rolling periods: past 7 days, last 24 hours
        #"\b(?:past|last)\s+\d+\s*(?:hours?|days?|weeks?|months?)\b"#,

        // Punctuation (preserves internal apostrophes)
        #"[“”„‟\";:,!?()\[\]{}<>«»…]"#,

        // Standalone quotation marks
        #"(^|[\s])['‘’`]+|['‘’`]+(?=\s|$)"#
    ]

    public static func filter(
        searchResult: String,
        history: [History]
    ) -> [History] {
        /// we want to find out intent of the searchHistory
        /// want to know if its a date, time ago, seconds ago, mins ago, hours ago, days ago
        /// also then we want to know about the name
        /// want to know if called "movies" or "tvs" or "episodes"

        var name = searchResult
        for pattern in patterns {
            name = name.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        name = normalize(name)

        let dateResult = DateFilterEngine.dateRange(for: searchResult)

        name = dateResult?.remainingQuery ?? name
        let dateRange = dateResult?.interval

        /// Movie Keyword
        if searchResult.localizedCaseInsensitiveContains("movie") {
            return FilterEngine.filter(
                history: history,
                intent: .init(
                    name: name,
                    mediaType: .movie,
                    dateRange: dateRange
                )
            )
        }

        /// Episode Keyword
        if searchResult.localizedCaseInsensitiveContains("tvs") || searchResult.localizedCaseInsensitiveContains("episode") || searchResult.localizedCaseInsensitiveContains("season"){
            let season = extractNumber(after: "season", from: searchResult)
            let episode = extractNumber(after: "episode", from: searchResult)

            return FilterEngine.filter(
                history: history,
                intent: .init(
                    name: name,
                    mediaType: .episode,
                    season: season,
                    episode: episode,
                    dateRange: dateRange
                )
            )
        }

        return self.filter(
            history: history,
            intent: .init(
                name: name,
                dateRange: dateRange
            )
        )
    }

    private static func filter(
        history: [History],
        intent: HistorySearchIntent
    ) -> [History] {
        history.filter { item in
            if let mediaType = intent.mediaType,
               item.mediaType != mediaType {
                return false
            }

            if let season = intent.season,
               item.season != season {
                return false
            }

            if let episode = intent.episode,
               item.episode != episode {
                return false
            }

            if let name = intent.name,
               !normalize(item.name).localizedCaseInsensitiveContains(name) {
                return false
            }

            if let range = intent.dateRange,
               !range.contains(item.watchedAt) {
                return false
            }

            return true
        }
    }

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(
                of: #"['‘’ʼ""“”\-–—:;,.!?]"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract Number Helper
    private static func extractNumber(after keyword: String, from text: String) -> Int? {
        let pattern = #"\b"# + keyword + #"\s+(\d+)\b"#

        guard let range = text.range(
            of: pattern,
            options: .regularExpression
        ) else {
            return nil
        }

        let match = text[range]

        return Int(match.drop(while: { !$0.isNumber }))
    }
}
