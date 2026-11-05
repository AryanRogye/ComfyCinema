package com.aryanrogye.movies_shared

import com.aryanrogye.movies_shared.models.KTGenre
import com.aryanrogye.movies_shared.models.KTMediaType
import com.aryanrogye.movies_shared.network.GenreCache
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class GenreCacheTest {
    @Test
    fun concurrentCallsShareCacheAndPreserveInputOrder() = runTest {
        var requests = 0
        val cache = GenreCache { _, _ ->
            requests++
            delay(10)
            listOf(KTGenre(28, "Action"), KTGenre(35, "Comedy"))
        }
        val results = List(10) {
            async { cache.genreNames(KTMediaType.MOVIE, listOf(35, -1, 28, 35), "token") }
        }.awaitAll()
        assertEquals(1, requests)
        results.forEach { assertEquals(listOf("Comedy", "Action", "Comedy"), it) }
        cache.genreNames(KTMediaType.MOVIE, listOf(28), "another-token")
        assertEquals(1, requests)
    }

    @Test
    fun movieAndTVHaveSeparateCaches() = runTest {
        var requests = 0
        val cache = GenreCache { type, _ ->
            requests++
            listOf(KTGenre(1, type.rawValue))
        }
        repeat(2) {
            assertEquals(listOf("movie"), cache.genreNames(KTMediaType.MOVIE, listOf(1), "token"))
            assertEquals(listOf("tv"), cache.genreNames(KTMediaType.TV, listOf(1), "token"))
        }
        assertEquals(2, requests)
    }

    @Test
    fun failedLoadsCanRetry() = runTest {
        var requests = 0
        val cache = GenreCache { _, _ ->
            requests++
            if (requests == 1) error("Network unavailable")
            listOf(KTGenre(28, "Action"))
        }
        assertFailsWith<IllegalStateException> {
            cache.genreNames(KTMediaType.MOVIE, listOf(28), "token")
        }
        assertEquals(listOf("Action"), cache.genreNames(KTMediaType.MOVIE, listOf(28), "token"))
        assertEquals(2, requests)
    }

    @Test
    fun personAndEmptyInputDoNotFetch() = runTest {
        val cache = GenreCache { _, _ -> error("Unexpected request") }
        assertEquals(emptyList(), cache.genreNames(KTMediaType.PERSON, listOf(28), "token"))
        assertEquals(emptyList(), cache.genreNames(KTMediaType.MOVIE, emptyList(), "token"))
    }
}
