package com.aryanrogye.movies_shared

import com.aryanrogye.movies_shared.models.KTRatingsAndReviews
import com.aryanrogye.movies_shared.models.KTReviewResponse
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalSerializationApi::class)
class RatingsAndReviewsTest {
    private val json = Json {
        ignoreUnknownKeys = true
        namingStrategy = JsonNamingStrategy.SnakeCase
    }

    @Test
    fun decodesAppendedReviewsForMovieAndTVDetails() {
        for (titleField in listOf("title", "name")) {
            val details = json.decodeFromString<KTRatingsAndReviews>("""
                {"id":123,"$titleField":"Example","vote_average":8.4,"vote_count":42,
                 "reviews":{"page":1,"total_pages":2,"total_results":3,"results":[
                   {"id":"rated","author":"Alice","content":"Great!",
                    "author_details":{"rating":9.0,"username":"alice"}},
                   {"id":"unrated","author":"Bob","content":"My review",
                    "author_details":{"rating":null}}
                 ]}}
            """.trimIndent())
            assertEquals(8.4, details.voteAverage)
            assertEquals(42, details.voteCount)
            assertEquals(2, details.reviews.totalPages)
            assertEquals(9.0, details.reviews.results.first().authorDetails.rating)
            assertNull(details.reviews.results.last().authorDetails.rating)
        }
    }

    @Test
    fun handlesUnratedTitlesAndEmptyReviewPages() {
        val details = json.decodeFromString<KTRatingsAndReviews>("""{"id":123}""")
        assertEquals(0, details.voteCount)
        assertTrue(details.reviews.results.isEmpty())
        val page = json.decodeFromString<KTReviewResponse>("""
            {"id":123,"page":1,"results":[],"total_pages":0,"total_results":0}
        """.trimIndent())
        assertTrue(page.results.isEmpty())
        assertEquals(0, page.totalPages)
    }
}
