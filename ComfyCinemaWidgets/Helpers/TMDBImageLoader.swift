//
//  TMDBImageLoader.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import Foundation
import SwiftUI

enum TMDBImageLoader {
    public static func loadImage(
        from posterPath: String?
    ) async throws -> SystemImage? {
        guard let posterPath else { return nil }
        guard let url = URL(    string: "https://image.tmdb.org/t/p/w500\(posterPath)") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        print("Poster response:", response)
        print("Poster bytes:", data.count)

#if os(macOS)
        return NSImage(data: data)
#else
        return UIImage(data: data)
#endif
    }
}
