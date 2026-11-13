//
//  TaskQueue.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/12/26.
//

@MainActor
final class TaskQueue {
    private var previousTask: Task<Void, Never>?

    func enqueue(
        _ operation: @escaping @MainActor @Sendable () async -> Void
    ) {
        let previous = previousTask

        previousTask = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }
}
