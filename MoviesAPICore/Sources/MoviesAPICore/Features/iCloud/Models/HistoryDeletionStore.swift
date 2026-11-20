import Foundation

/// Keeps deletion markers across failed uploads and app restarts.
@MainActor
final class HistoryDeletionStore {
    private struct Entry: Codable {
        let deletion: DeletedHistory
        var needsUpload: Bool
    }

    private let defaults: UserDefaults
    private let key: String
    private var entries: [String: Entry]

    init(identifier: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.key = "historyDeletions.\(identifier)"
        self.entries = defaults.data(forKey: key).flatMap {
            try? JSONDecoder().decode([String: Entry].self, from: $0)
        } ?? [:]
    }

    var deletions: [DeletedHistory] { entries.values.map(\.deletion) }
    var pending: [DeletedHistory] {
        entries.values.filter(\.needsUpload).map(\.deletion)
    }

    func record(_ deletion: DeletedHistory) {
        entries[deletion.recordName] = Entry(deletion: deletion, needsUpload: true)
        persist()
    }

    func markUploaded(_ deletion: DeletedHistory) {
        // A second deletion may have arrived while the first was uploading.
        guard entries[deletion.recordName]?.deletion.deletedAt == deletion.deletedAt else { return }
        entries[deletion.recordName]?.needsUpload = false
        persist()
    }

    private func persist() {
        // Entry contains only Codable value types.
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
