//
//  ShowAllHistoryForItemView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/18/26.
//

import SwiftUI
import MoviesAPIData
import SwiftData

struct ShowAllHistoryForItemView: View {

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \History.watchedAt, order: .reverse)
    var history: [History]

    let item: History
    let onOpen: (History) -> Void

    private var matchingHistory: [History] {
        history.filter {
            $0.resultId == item.resultId &&
            $0.mediaType == item.mediaType
        }
    }

    private var lastWatched: Date? {
        matchingHistory.first?.watchedAt
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {

                    /// show summary here
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            summaryStat(
                                title: "History Entries",
                                value: "\(matchingHistory.count)",
                                icon: "clock.arrow.circlepath"
                            )

                            summaryStat(
                                title: "Last Watched",
                                value: lastWatched?.formatted(
                                    .dateTime.month(.abbreviated).day()
                                ) ?? "Never",
                                icon: "calendar"
                            )
                        }

                        HStack {
                            Text("Watch Activity")
                                .font(.headline)

                            Spacer()

                            Text("Most Recent First")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(matchingHistory, id: \.id) { entry in
                        Button {
                            dismiss()
                            onOpen(entry)
                        } label: {
                            HistoryRow(
                                history: entry,
                                isResolving: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .contentMargins(.top, 12, for: .scrollContent)
            .navigationTitle(item.name)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func summaryStat(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
    }
}
