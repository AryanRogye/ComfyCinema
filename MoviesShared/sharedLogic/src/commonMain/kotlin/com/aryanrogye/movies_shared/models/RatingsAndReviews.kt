package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

@Serializable
data class KTRatingsAndReviews(
    val id: Int,
    val voteAverage: Double = 0.0,
    val voteCount: Int = 0,
    val reviews: KTReviewResponse = KTReviewResponse(),
)

@Serializable
data class KTReviewResponse(
    val page: Int = 1,
    val results: List<KTReview> = emptyList(),
    val totalPages: Int = 0,
    val totalResults: Int = 0,
)

@Serializable
data class KTReview(
    val id: String,
    val author: String,
    val content: String,
    val authorDetails: KTReviewAuthor = KTReviewAuthor(),
)

@Serializable
data class KTReviewAuthor(
    val rating: Double? = null,
)
