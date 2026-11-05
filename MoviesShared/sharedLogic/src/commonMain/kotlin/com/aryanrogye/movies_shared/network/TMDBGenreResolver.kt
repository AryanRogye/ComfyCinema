package com.aryanrogye.movies_shared.network

import com.aryanrogye.movies_shared.models.KTGenre
import com.aryanrogye.movies_shared.models.KTMediaType
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Shared, in-memory English genre cache. In Swift, access through TMDBGenreResolver.shared. */
object TMDBGenreResolver {
    private val client = TMDBClient()
    private val cache = GenreCache { mediaType, token -> client.genres(mediaType, token) }

    /**
     * Resolves TMDB genre IDs in input order, preserving duplicates and skipping unknown IDs.
     * Each media type is fetched once after a successful request, for the lifetime of the app.
     * Empty input and PERSON return an empty list without making a request.
     * Failures propagate to the caller and are not cached, so subsequent calls can retry.
     */
    @Throws(Exception::class, CancellationException::class)
    suspend fun genreNames(mediaType: KTMediaType, genreIds: List<Int>, token: String): List<String> =
        cache.genreNames(mediaType, genreIds, token)
}

internal class GenreCache(
    private val fetch: suspend (KTMediaType, String) -> List<KTGenre>,
) {
    private val mutex = Mutex()
    private val genresByType = mutableMapOf<KTMediaType, Map<Int, String>>()

    suspend fun genreNames(mediaType: KTMediaType, genreIds: List<Int>, token: String): List<String> {
        if (genreIds.isEmpty() || mediaType == KTMediaType.PERSON) return emptyList()

        // Hold the lock across loading so concurrent callers share the successful result.
        val genres = mutex.withLock {
            genresByType[mediaType] ?: fetch(mediaType, token)
                .associate { it.id to it.name }
                .also { genresByType[mediaType] = it }
        }
        return genreIds.mapNotNull { genres[it] }
    }
}
