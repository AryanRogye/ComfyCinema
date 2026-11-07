//
//  ContentImageStore.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/5/26.
//

import Foundation

#if os(macOS)
import AppKit
typealias SystemImage = NSImage
#elseif os(iOS)
import UIKit
typealias SystemImage = UIImage
#endif

enum ContentImageStore {
    @MainActor
    static func encode(_ image: SystemImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else {
            print("[Screenshot] Cannot encode empty image, size: \(image.size)")
            return nil
        }
#if os(macOS)
        var rect = CGRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
           let data = NSBitmapImageRep(cgImage: cgImage).representation(
               using: .jpeg, properties: [.compressionFactor: 0.85]
           ) {
            return data
        }
        print("[Screenshot] CGImage encoding failed; trying TIFF fallback. Representations: \(image.representations)")
        if let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }
        print("[Screenshot] Snapshot has no encodable bitmap, size: \(image.size)")
        return nil
#elseif os(iOS)
        return image.jpegData(compressionQuality: 0.85)
#endif
    }

    private static let directory: URL = {
        let url = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent(
            "MovieImages",
            isDirectory: true
        )

        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            print("[Screenshot] Cache directory: \(url.path)")
        } catch {
            print("[Screenshot] Cache directory creation failed at \(url.path): \(error)")
        }

        return url
    }()

    private static func url(
        forID id: Int32,
        mediaType: KTMediaType
    ) -> URL {
        directory.appendingPathComponent(
            "\(mediaType)-\(id).jpg"
        )
    }

    static func store(
        data: Data,
        forID id: Int32,
        mediaType: KTMediaType
    ) throws {
        let destination = url(forID: id, mediaType: mediaType)
        do {
            try data.write(to: destination, options: .atomic)
            print("[Screenshot] Saved \(data.count) bytes to \(destination.path)")
        } catch {
            print("[Screenshot] Save failed at \(destination.path): \(error)")
            throw error
        }
    }

    static func load(
        forID id: Int32,
        mediaType: KTMediaType
    ) -> Data? {
        let source = url(forID: id, mediaType: mediaType)
        do {
            let data = try Data(contentsOf: source)
            print("[Screenshot] Loaded \(data.count) bytes from \(source.path)")
            return data
        } catch {
            print("[Screenshot] Cache load failed at \(source.path): \(error)")
            return nil
        }
    }
}
