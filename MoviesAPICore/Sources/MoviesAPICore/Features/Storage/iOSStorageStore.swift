//
//  iOSStorageStore.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/3/26.
//

import Foundation

enum iOSStorageStore {
    static let libraryURL: URL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!

    public static func getLibrarySize() -> String {
        let bytes = directorySize(at: libraryURL)
        let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return formatted
    }

    private static func directorySize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: nil
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
