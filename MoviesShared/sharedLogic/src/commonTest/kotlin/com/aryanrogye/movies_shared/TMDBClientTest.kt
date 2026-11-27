package com.aryanrogye.movies_shared

import com.aryanrogye.movies_shared.network.TMDBClient
import com.aryanrogye.movies_shared.models.KTMediaType
import com.aryanrogye.movies_shared.models.KTSearchResult
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

class TMDBClientTest {

    private val client = TMDBClient()

    @Test
    fun searchReturnsLabRats() = runTest {
        val result = client.search(
            "Lab Rats",
            requireToken(),
            includeAdult = false,
        )

        val labRats = result.results.firstOrNull {
            it.mediaType == KTMediaType.TV && it.name == "Lab Rats"
        }

        assertNotNull(labRats, "Expected the Lab Rats TV series in the search results.")
        assertTrue(labRats.id > 0)
        assertFalse(labRats.overview.isNullOrBlank())
    }

    @Test
    fun popularTVReturnsRequestedPage() = runTest {
        val result = client.popularTV(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.any { it.genres.isNotEmpty() })
        assertTrue(result.results.all { it.id > 0 && it.name.isNotBlank() })
    }

    @Test
    fun popularMoviesReturnsRequestedPage() = runTest {
        val result = client.popularMovies(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.any { it.genres.isNotEmpty() })
        assertTrue(result.results.all { it.id > 0 && it.title.isNotBlank() })
    }

    @Test
    fun topRatedMoviesReturnsRequestedPage() = runTest {
        val result = client.topRatedMovies(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.title.isNotBlank() })
        assertTrue(result.results.all { it.voteAverage >= 0.0 })
    }

    @Test
    fun topRatedTVReturnsRequestedPage() = runTest {
        val result = client.topRatedTV(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.name.isNotBlank() })
        assertTrue(result.results.all { it.voteAverage >= 0.0 })
    }

    @Test
    fun nowPlayingMoviesReturnsDatesAndRequestedPage() = runTest {
        val result = client.nowPlayingMovies(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.dates.minimum.isNotBlank())
        assertTrue(result.dates.maximum.isNotBlank())
        assertTrue(result.dates.minimum <= result.dates.maximum)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.title.isNotBlank() })
    }

    @Test
    fun trendingReturnsTypedMedia() = runTest {
        val result = client.trending(requireToken())

        assertTrue(result.page > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.any { it.genreType.isNotEmpty() })
        assertTrue(result.results.all { it.genreType.all(String::isNotBlank) })
        assertTrue(result.results.all { item ->
            item.id > 0 && (item.title?.isNotBlank() == true || item.name?.isNotBlank() == true)
        })
    }

    @Test
    fun movieInfoReturnsGenreIdsAndNames() = runTest {
        val movie = client.infoOnMovie(id = 11, token = requireToken())

        assertEquals(11, movie.id)
        assertTrue(movie.genres.any { it.id == 12 && it.name == "Adventure" })
    }

    @Test
    fun collectionInfoReturnsStarWarsCollection() = runTest {
        val collection = client.collectionInfo(collectionId = STAR_WARS_COLLECTION_ID, token = requireToken())

        assertEquals(STAR_WARS_COLLECTION_ID, collection.id)
        assertEquals("Star Wars Collection", collection.name)
        assertTrue(collection.original_language.isNotBlank())
        assertTrue(collection.original_name.isNotBlank())
        assertFalse(collection.overview.isBlank())
        assertFalse(collection.poster_path.isNullOrBlank())
        assertFalse(collection.backdrop_path.isNullOrBlank())
    }

    @Test
    fun collectionInfoReturnsMovieParts() = runTest {
        val collection = client.collectionInfo(collectionId = STAR_WARS_COLLECTION_ID, token = requireToken())

        assertTrue(collection.parts.isNotEmpty())
        assertTrue(collection.parts.all { it.id > 0 && !(it.title ?: it.name).isNullOrBlank() })
        assertTrue(collection.parts.all { it.media_type == KTMediaType.MOVIE })
        assertEquals(
            collection.parts.size,
            collection.parts.map { it.id }.toSet().size,
            "Expected each collection part to appear once.",
        )
        // Star Wars (1977) is TMDB movie 11.
        assertTrue(collection.parts.any { it.id == 11 })
    }

    @Test
    fun movieInfoCollectionMatchesCollectionInfo() = runTest {
        val token = requireToken()
        val movie = client.infoOnMovie(id = 11, token = token)
        val belongsTo = assertNotNull(
            movie.belongsToCollection,
            "Expected Star Wars (1977) to belong to a collection.",
        )

        val collection = client.collectionInfo(collectionId = belongsTo.id, token = token)

        assertEquals(belongsTo.id, collection.id)
        assertEquals(belongsTo.name, collection.name)
        assertTrue(collection.parts.any { it.id == movie.id })
    }

    @Test
    fun tvInfoReturnsLabRatsDetails() = runTest {
        val token = requireToken()
        val labRats = findLabRats(token)
        val result = client.infoOnTV(labRats.id, token)

        assertEquals(labRats.id, result.id)
        assertEquals("Lab Rats", result.name)
        assertTrue(result.numberOfSeasons > 0)
        assertTrue(result.numberOfEpisodes > 0)
        assertTrue(result.seasons.isNotEmpty())
    }

    @Test
    fun seasonInfoReturnsEpisodes() = runTest {
        val token = requireToken()
        val labRats = findLabRats(token)
        val result = client.seasonInfo(
            id = labRats.id,
            seasonNumber = 1,
            token = token,
        )

        assertEquals(1, result.seasonNumber)
        assertTrue(result.episodes.isNotEmpty())
        assertTrue(result.episodes.all { it.seasonNumber == 1 && it.episodeNumber > 0 })
    }

    private fun requireToken(): String {
        val token = testEnvironmentVariable("TMDB_API_READ_ACCESS_TOKEN")
        assertFalse(
            token.isNullOrBlank(),
            "Set TMDB_API_READ_ACCESS_TOKEN in local.properties, Gradle properties, or the environment.",
        )
        return requireNotNull(token).trim()
    }

    private suspend fun findLabRats(token: String): KTSearchResult {
        val result = client.search("Lab Rats", token, includeAdult = false)
        return assertNotNull(
            result.results.firstOrNull {
                it.mediaType == KTMediaType.TV && it.name == "Lab Rats"
            },
            "Expected the Lab Rats TV series in the search results.",
        )
    }

    private companion object {
        const val STAR_WARS_COLLECTION_ID = 10
    }
}

internal expect fun testEnvironmentVariable(name: String): String?
