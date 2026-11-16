//
//  FavoritesWidget.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/10/26.
//

import WidgetKit
import SwiftUI

#if os(iOS)
struct FavoritesWidget: Widget {

    let kind: String = "FavoriteWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: FavoritesIntent.self,
            provider: FavoritesProvider()
        ) { entry in
            FavoritesWidgetView(entry: entry)
                .contentMargins(.zero)
                .containerBackground(.clear, for: .widget)
                .background(.clear)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}
#elseif os(macOS)
struct FavoritesWidget: Widget {

    let kind: String = "FavoriteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: FavoritesProvider()
        ) { entry in
            FavoritesWidgetView(entry: entry)
                .contentMargins(.zero)
                .containerBackground(.clear, for: .widget)
                .background(.clear)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}
#endif
