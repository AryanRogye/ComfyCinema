package com.aryanrogye.movies_shared.network

import com.aryanrogye.movies_shared.models.KTImage
import com.aryanrogye.movies_shared.models.selectLogo
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LogoTest {
    @Test fun prefersEnglishPNGsThenRatingVotesAndResolution() {
        assertEquals("/best.png", selectLogo(listOf(
            KTImage("/neutral.png", null, 1000, 400, 10.0),
            KTImage("/foreign.png", "fr", 1000, 400, 10.0),
            KTImage("/vector.svg", "en", 1000, 400, 10.0),
            KTImage("/small.png", "en", 500, 200, 8.0, 10),
            KTImage("/best.png", "en", 1000, 400, 8.0, 10),
            KTImage("/fewer-votes.png", "en", 2000, 800, 8.0, 1),
        )))
        assertEquals("/neutral.png", selectLogo(listOf(KTImage("/neutral.png", null, 500, 200))))
        assertNull(selectLogo(emptyList()))
        assertNull(selectLogo(listOf(KTImage("/foreign.png", "fr", 500, 200))))
    }

    @Test fun populatesEveryPosterEndpointAndReusesImages() = runTest {
        val imageRequests = mutableListOf<String>()
        val http = mockClient { request ->
            val path = request.url.encodedPath
            val body = when {
                path.endsWith("/images") -> {
                    assertEquals("en,null", request.url.parameters["include_image_language"])
                    imageRequests += path
                    artwork(if (path.contains("/movie/")) "movie" else "tv")
                }
                path == "/3/search/multi" -> """{"results":[$searchMovie,$searchTV,{"id":7,"media_type":"person","name":"Actor"}]}"""
                path.endsWith("/combined_credits") -> """{"cast":[$searchMovie,$searchTV],"crew":[]}"""
                path == "/3/tv/7" -> """{"id":7,"name":"Show","overview":"","number_of_episodes":1,"number_of_seasons":1,"seasons":[{"id":99,"name":"Season 1","season_number":1,"episode_count":1,"poster_path":"/season.jpg"}]}"""
                path == "/3/tv/7/season/1" -> """{"id":99,"name":"Season 1","overview":"","season_number":1,"poster_path":"/season.jpg","episodes":[]}"""
                path == "/3/trending/all/day" -> """{"page":1,"total_pages":1,"total_results":2,"results":[$trendingMovie,$trendingTV]}"""
                path == "/3/movie/now_playing" -> """{"dates":{"minimum":"2026-01-01","maximum":"2026-12-31"},${movieList.drop(1)}"""
                path.contains("/movie/") -> movieList
                else -> tvList
            }
            HttpStatusCode.OK to body
        }
        try {
            val client = TMDBClient(http)
            assertEquals("/movie.png", client.popularMovies("token", 1).results.first().logoPath)
            assertEquals("/movie.png", client.topRatedMovies("token", 1).results.first().logoPath)
            assertEquals("/movie.png", client.nowPlayingMovies("token", 1).results.first().logoPath)
            assertEquals("/movie.png", client.recommendationsForMovie(7, "token", 1).results.first().logoPath)
            assertEquals("/tv.png", client.popularTV("token", 1).results.first().logoPath)
            assertEquals("/tv.png", client.topRatedTV("token", 1).results.first().logoPath)
            assertEquals("/tv.png", client.recommendationsForTV(7, "token", 1).results.first().logoPath)
            val trending = client.trending("token").results
            assertEquals(listOf("/movie.png", "/tv.png"), trending.map { it.logoPath })
            assertTrue(trending.all { it.heroPosterPath == "/hero.jpg" && it.posterPath == "/poster.jpg" })
            val search = client.search("title", "token", false).results
            assertEquals(listOf("/movie.png", "/tv.png", null), search.map { it.logoPath })
            assertEquals(listOf("/movie.png", "/tv.png"), client.creditsForPerson(7, "token").results.map { it.logoPath })
            val show = client.infoOnTV(7, "token")
            assertEquals("/tv.png", show.logoPath)
            assertEquals("/tv.png", show.seasons.first().logoPath)
            assertEquals("/tv.png", client.seasonInfo(7, 1, "token").logoPath)
            assertEquals(setOf("/3/movie/7/images", "/3/tv/7/images"), imageRequests.toSet())
            assertEquals(2, imageRequests.size)
        } finally {
            http.close()
        }
    }

    @Test fun artworkFailurePreservesPosterAndCanRetry() = runTest {
        var attempts = 0
        val http = mockClient { request ->
            if (request.url.encodedPath.endsWith("/images")) {
                attempts++
                if (attempts == 1) HttpStatusCode.InternalServerError to "{}"
                else HttpStatusCode.OK to artwork("movie")
            } else HttpStatusCode.OK to """{"results":[$searchMovie]}"""
        }
        try {
            val client = TMDBClient(http)
            val first = client.search("title", "token", false).results.first()
            assertEquals("/poster.jpg", first.posterPath)
            assertNull(first.logoPath)
            assertEquals("/movie.png", client.search("title", "token", false).results.first().logoPath)
            assertEquals(2, attempts)
        } finally {
            http.close()
        }
    }

    @Test fun artworkCancellationPropagates() = runTest {
        val http = mockClient { request ->
            if (request.url.encodedPath.endsWith("/images")) throw CancellationException("Cancelled")
            HttpStatusCode.OK to """{"results":[$searchMovie]}"""
        }
        try {
            assertFailsWith<CancellationException> { TMDBClient(http).search("title", "token", false) }
        } finally {
            http.close()
        }
    }

    @OptIn(ExperimentalSerializationApi::class)
    private fun mockClient(response: (HttpRequestData) -> Pair<HttpStatusCode, String>) = HttpClient(MockEngine { request ->
        val (status, body) = response(request)
        respond(body, status, headersOf("Content-Type", "application/json"))
    }) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true; namingStrategy = JsonNamingStrategy.SnakeCase })
        }
    }

    private fun artwork(type: String) = """{"logos":[{"file_path":"/$type.png","iso_639_1":"en","width":500,"height":200}],"posters":[{"file_path":"/hero.jpg","iso_639_1":null,"width":1000,"height":1500}]}"""
    private val movie = """{"id":7,"original_language":"en","original_title":"Movie","title":"Movie","popularity":1.0,"vote_average":8.0,"vote_count":10,"poster_path":"/poster.jpg"}"""
    private val tv = """{"id":7,"original_language":"en","original_name":"Show","name":"Show","popularity":1.0,"vote_average":8.0,"vote_count":10,"poster_path":"/poster.jpg"}"""
    private val movieList = """{"page":1,"total_pages":1,"total_results":1,"results":[$movie]}"""
    private val tvList = """{"page":1,"total_pages":1,"total_results":1,"results":[$tv]}"""
    private val searchMovie = """{"id":7,"media_type":"movie","title":"Movie","poster_path":"/poster.jpg"}"""
    private val searchTV = """{"id":7,"media_type":"tv","name":"Show","poster_path":"/poster.jpg"}"""
    private val trendingMovie = """{"media_type":"movie",${movie.drop(1)}"""
    private val trendingTV = """{"media_type":"tv",${tv.drop(1)}"""
}
