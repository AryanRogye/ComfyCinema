import CloudKit
import Foundation
import MoviesAPIData
import Testing
@testable import MoviesAPICore

@MainActor
struct HistoryDeletionTests {
    private let deletedAt = Date(timeIntervalSince1970: 200)

    private func deletion(date: Date? = nil) -> DeletedHistory {
        DeletedHistory(
            resultId: 42, mediaType: .episode, season: 1, episode: 2,
            deletedAt: date ?? deletedAt
        )
    }

    private func episode(_ number: Int = 2, watchedAt: Date? = nil) -> History {
        History(
            resultId: 42, name: "Example", mediaType: .episode,
            season: 1, episode: number,
            watchedAt: watchedAt ?? Date(timeIntervalSince1970: 100)
        )
    }

    @Test func pendingDeletionSurvivesRestartAndUpload() throws {
        let suite = "HistoryDeletionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let original = HistoryDeletionStore(identifier: "test", defaults: defaults)
        original.record(deletion())

        let restarted = HistoryDeletionStore(identifier: "test", defaults: defaults)
        #expect(restarted.pending.count == 1)
        restarted.markUploaded(deletion())

        let uploaded = HistoryDeletionStore(identifier: "test", defaults: defaults)
        #expect(uploaded.pending.isEmpty)
        // Retained locally to protect against stale cloud query results.
        #expect(uploaded.deletions.count == 1)

        let newer = deletion(date: deletedAt.addingTimeInterval(10))
        uploaded.record(newer)
        uploaded.markUploaded(deletion())
        #expect(uploaded.pending.first?.deletedAt == newer.deletedAt)
    }

    @Test func staleCloudHistoryStaysDeletedBeforeCloudMarkerIsVisible() async throws {
        let record = try await CloudRecordResolver.createHistoryRecord(basedOn: episode())
        let merged = CloudHistoryResolver.resolve(
            from: [], with: [record], localDeletions: [deletion()]
        )
        #expect(merged.isEmpty)
    }

    @Test func cloudDeletionRemovesAllCopiesOfOnlyTheMatchingEpisode() async throws {
        let marker = try await CloudRecordResolver.createHistoryDeletion(basedOn: deletion())
        let merged = CloudHistoryResolver.resolve(
            from: [episode(), episode(), episode(3)], with: [], deleted: [marker]
        )
        #expect(merged.count == 1)
        #expect(merged.first?.episode == 3)
    }

    @Test func deliberateRewatchSurvivesOlderDeletion() {
        let merged = CloudHistoryResolver.resolve(
            from: [episode(watchedAt: deletedAt.addingTimeInterval(1))],
            with: [], localDeletions: [deletion()]
        )
        #expect(merged.count == 1)
    }

    @Test func movieDeletionDoesNotDeleteSeriesWithSameID() {
        let movie = History(resultId: 42, name: "Movie", mediaType: .movie,
                            watchedAt: Date(timeIntervalSince1970: 100))
        let marker = DeletedHistory(resultId: 42, mediaType: .movie,
                                    season: nil, episode: nil, deletedAt: deletedAt)
        let merged = CloudHistoryResolver.resolve(
            from: [movie, episode()], with: [], localDeletions: [marker]
        )
        #expect(merged.count == 1)
        #expect(merged.first?.mediaType == .episode)
    }
}
