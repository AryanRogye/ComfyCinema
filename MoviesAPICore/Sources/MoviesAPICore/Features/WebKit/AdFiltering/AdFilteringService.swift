//
//  AdFilteringService.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

final class AdFilteringService {
    init() {
        
    }

    public func getJavascript() -> String? {
        guard let url = Bundle.module.url(
            forResource: "AdFiltering",
            withExtension: "js"
        ) else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }
}
