//
//  MoreInfoButton.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

enum MoreInfoSelectable {
    case movie(MovieSelectedOption)
    case tv(TVSelectedOption)

    var rawValue: String {
        switch self {
        case .movie(let option):
            return option.rawValue
        case .tv(let option):
            return option.rawValue
        }
    }
}

struct MoreInfoButton: View {

    let selected: MoreInfoSelectable
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            onSelect()
        }) {
            Text(selected.rawValue)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(height: 30)
                .padding(.horizontal)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected
                            ? .yellow.opacity(0.16)
                            : .white.opacity(0.06)
                        )
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isSelected
                                    ? .yellow.opacity(0.6)
                                    : .white.opacity(0.06),
                                    style: .init(lineWidth: 1)
                                )
                        }
                        .shadow(
                            color: isSelected
                            ? .yellow
                            : .white,
                            radius: 8
                        )
                }
        }
        .buttonStyle(.plain)

    }
}
