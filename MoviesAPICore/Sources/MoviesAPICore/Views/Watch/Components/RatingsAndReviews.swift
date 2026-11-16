//
//  RatingsAndReviews.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

struct RatingsAndReviews: View {
    @Environment(TMDBManager.self) private var tmdbManager
    let result: KTSearchResult
    let type: KTMediaType

    @State private var details: KTRatingsAndReviews?
    @State private var reviews: [KTReview] = []
    @State private var page: Int32 = 0
    @State private var totalPages: Int32 = 0
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let details {
                Label("TMDB Rating", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                if details.voteCount > 0 {
                    Text("\(details.voteAverage, specifier: "%.1f")/10 · \(details.voteCount) votes")
                } else {
                    Text("No ratings yet.")
                        .foregroundStyle(.secondary)
                }

                Text("Reviews (\(details.reviews.totalResults))")
                    .font(.headline)
                if reviews.isEmpty {
                    Text("No written reviews available in English.")
                        .foregroundStyle(.secondary)
                }
                ForEach(reviews, id: \.id) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(review.author).font(.headline)
                            Spacer()
                            if let rating = review.authorDetails.rating {
                                Label("\(rating.doubleValue, specifier: "%.1f")/10", systemImage: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                        // Treat user-written reviews as plain text, without rendering links or HTML.
                        Text(verbatim: review.content)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if isLoading {
                ProgressView("Loading ratings & reviews…")
            }
            if let error {
                Text(error).foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await load(initial: details == nil) }
                }
                .disabled(isLoading)
            } else if details != nil && page < totalPages {
                Button("Load More Reviews") {
                    Task { await load(initial: false) }
                }
                .disabled(isLoading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical)
        .task(id: "\(type)-\(result.id)") {
            details = nil
            reviews = []
            page = 0
            totalPages = 0
            await load(initial: true)
        }
    }

    @MainActor
    private func load(initial: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let response: KTReviewResponse
            if initial {
                let fetched: KTRatingsAndReviews
                if type == .tv {
                    fetched = try await tmdbManager.ratingsAndReviewsForTV(for: result.id)
                } else {
                    fetched = try await tmdbManager.ratingsAndReviewsForMovie(for: result.id)
                }
                try Task.checkCancellation()
                details = fetched
                response = fetched.reviews
            } else {
                if type == .tv {
                    response = try await tmdbManager.reviewsForTV(for: result.id, page: page + 1)
                } else {
                    response = try await tmdbManager.reviewsForMovie(for: result.id, page: page + 1)
                }


                try Task.checkCancellation()
            }
            var seen = Set(reviews.map(\.id))
            reviews.append(contentsOf: response.results.filter { seen.insert($0.id).inserted })
            page = response.page
            totalPages = response.totalPages
        } catch {
            guard !Task.isCancelled else { return }
            self.error = "Couldn’t load TMDB ratings & reviews. Please try again."
        }
    }
}
