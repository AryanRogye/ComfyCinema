//
//  ComfyCinemaWidgetsBundle.swift
//  ComfyCinemaWidgets
//
//  Created by Aryan Rogye on 11/9/26.
//

import WidgetKit
import SwiftUI

@main
struct ComfyCinemaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MostRecentWidget()
        FavoritesWidget()
    }
}
