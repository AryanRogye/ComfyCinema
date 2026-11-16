package com.aryanrogye.movies_shared.network

import com.aryanrogye.movies_shared.models.KTRatingsAndReviews
import com.aryanrogye.movies_shared.models.KTReviewResponse
import com.aryanrogye.movies_shared.models.KTSearchResponse
import com.aryanrogye.movies_shared.models.KTSeasonInfo
import com.aryanrogye.movies_shared.models.KTMovieListResponse
import com.aryanrogye.movies_shared.models.KTNowPlayingMovieResponse
import com.aryanrogye.movies_shared.models.KTTVListResponse
import com.aryanrogye.movies_shared.models.KTTVShow
import com.aryanrogye.movies_shared.models.KTTrendingResponse
import com.aryanrogye.movies_shared.models.KTGenre
import com.aryanrogye.movies_shared.models.KTGenreResponse
import com.aryanrogye.movies_shared.models.KTMediaType
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy

interface TMDBClientProviding {
    @Throws(Exception::class)
    suspend fun ratingsAndReviewsForMovie(id: Int, token: String): KTRatingsAndReviews
    @Throws(Exception::class)
    suspend fun reviewsForMovie(id: Int, token: String, page: Int): KTReviewResponse
    @Throws(Exception::class)
    suspend fun ratingsAndReviewsForTV(id: Int, token: String): KTRatingsAndReviews
    @Throws(Exception::class)
    suspend fun reviewsForTV(id: Int, token: String, page: Int): KTReviewResponse

    @Throws(Exception::class)
    suspend fun popularTV(token: String, page: Int): KTTVListResponse
    @Throws(Exception::class)
    suspend fun popularMovies(token: String, page: Int): KTMovieListResponse
    @Throws(Exception::class)
    suspend fun topRatedMovies(token: String, page: Int): KTMovieListResponse
    @Throws(Exception::class)
    suspend fun topRatedTV(token: String, page: Int): KTTVListResponse
    @Throws(Exception::class)
    suspend fun nowPlayingMovies(token: String, page: Int): KTNowPlayingMovieResponse
    @Throws(Exception::class)
    suspend fun trending(token: String): KTTrendingResponse
    suspend fun search(query: String, token: String, includeAdult: Boolean): KTSearchResponse
    suspend fun infoOnTV(id: Int, token: String): KTTVShow
    suspend fun seasonInfo(id: Int, seasonNumber: Int, token: String): KTSeasonInfo
    @Throws(Exception::class)
    suspend fun recommendationsForMovie(id: Int, token: String, page: Int): KTMovieListResponse
    @Throws(Exception::class)
    suspend fun recommendationsForTV(id: Int, token: String, page: Int): KTTVListResponse
}

class TMDBClient: TMDBClientProviding {
    private val heroImageRequests = Semaphore(4)

    private suspend fun heroPosterPath(id: Int, mediaType: KTMediaType, token: String): String? {
        if (mediaType == KTMediaType.PERSON) return null
        return try {
            heroImageRequests.withPermit {
                val response = client.get("https://api.themoviedb.org/3/${mediaType.rawValue}/$id/images") {
                    parameter("include_image_language", "null")
                    header("accept", "application/json")
                    header("Authorization", "Bearer $token")
                }
                check(response.status.value in 200..299)
                selectHeroPoster(response.body<HeroImagesResponse>().posters)
            }
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // Optional artwork must not prevent the trending feed from loading.
            null
        }
    }


    @Throws(Exception::class)
    override suspend fun ratingsAndReviewsForMovie(id: Int, token: String): KTRatingsAndReviews {
        val response = client.get("https://api.themoviedb.org/3/movie/$id") {
            parameter("language", "en-US")
            parameter("append_to_response", "reviews")
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }
        check(response.status.value in 200..299) {
            "TMDB ratings/reviews request failed with HTTP ${response.status.value}"
        }
        return response.body()
    }

    @Throws(Exception::class)
    override suspend fun reviewsForMovie(id: Int, token: String, page: Int): KTReviewResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/$id/reviews") {
            parameter("language", "en-US")
            parameter("page", page)
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }
        check(response.status.value in 200..299) {
            "TMDB ratings/reviews request failed with HTTP ${response.status.value}"
        }
        return response.body()
    }

    @Throws(Exception::class)
    override suspend fun ratingsAndReviewsForTV(id: Int, token: String): KTRatingsAndReviews {
        val response = client.get("https://api.themoviedb.org/3/tv/$id") {
            parameter("language", "en-US")
            parameter("append_to_response", "reviews")
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }
        check(response.status.value in 200..299) {
            "TMDB ratings/reviews request failed with HTTP ${response.status.value}"
        }
        return response.body()
    }

    @Throws(Exception::class)
    override suspend fun reviewsForTV(id: Int, token: String, page: Int): KTReviewResponse {
        val response = client.get("https://api.themoviedb.org/3/tv/$id/reviews") {
            parameter("language", "en-US")
            parameter("page", page)
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }
        check(response.status.value in 200..299) {
            "TMDB ratings/reviews request failed with HTTP ${response.status.value}"
        }
        return response.body()
    }

    internal suspend fun genres(mediaType: KTMediaType, token: String): List<KTGenre> {
        require(mediaType != KTMediaType.PERSON) { "People do not have genres." }
        val response = client.get("https://api.themoviedb.org/3/genre/${mediaType.rawValue}/list") {
            parameter("language", "en-US")
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }
        check(response.status.value in 200..299) {
            "TMDB genre request failed with HTTP ${response.status.value}"
        }
        return response.body<KTGenreResponse>().genres
    }

    @OptIn(ExperimentalSerializationApi::class)
    private val client = HttpClient {
        install(ContentNegotiation) {
            json(
                Json {
                    ignoreUnknownKeys = true
                    namingStrategy = JsonNamingStrategy.SnakeCase
                }
            )
        }
    }

    @Throws(Exception::class)
    override suspend fun popularTV(token: String, page: Int): KTTVListResponse {
        val response = client.get("https://api.themoviedb.org/3/tv/popular?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTTVListResponse>()
        return result.copy(results = result.results.map { item ->
            item.copy(genres = TMDBGenreResolver.genreNames(KTMediaType.TV, item.genreIds, token))
        })
    }

    @Throws(Exception::class)
    override suspend fun popularMovies(token: String, page: Int): KTMovieListResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/popular?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTMovieListResponse>()
        return result.copy(results = result.results.map { item ->
            item.copy(genres = TMDBGenreResolver.genreNames(KTMediaType.MOVIE, item.genreIds, token))
        })
    }

    @Throws(Exception::class)
    override suspend fun topRatedMovies(token: String, page: Int): KTMovieListResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/top_rated?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTMovieListResponse>()
        return result.copy(results = result.results.map { item ->
            item.copy(genres = TMDBGenreResolver.genreNames(KTMediaType.MOVIE, item.genreIds, token))
        })
    }

    @Throws(Exception::class)
    override suspend fun topRatedTV(token: String, page: Int): KTTVListResponse {
        val response = client.get("https://api.themoviedb.org/3/tv/top_rated?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTTVListResponse>()
        return result.copy(results = result.results.map { item ->
            item.copy(genres = TMDBGenreResolver.genreNames(KTMediaType.TV, item.genreIds, token))
        })
    }

    @Throws(Exception::class)
    override suspend fun nowPlayingMovies(token: String, page: Int): KTNowPlayingMovieResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/now_playing?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTNowPlayingMovieResponse>()
        return result.copy(results = result.results.map { item ->
            item.copy(genres = TMDBGenreResolver.genreNames(KTMediaType.MOVIE, item.genreIds, token))
        })
    }

    @Throws(Exception::class)
    override suspend fun trending(token: String): KTTrendingResponse {
        val response = client.get("https://api.themoviedb.org/3/trending/all/day?language=en-US") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val trending = response.body<KTTrendingResponse>()
        return coroutineScope {
            trending.copy(results = trending.results.map { item ->
                async {
                    item.copy(
                        genreType = TMDBGenreResolver.genreNames(item.mediaType, item.genreIds, token),
                        heroPosterPath = heroPosterPath(item.id, item.mediaType, token),
                    )
                }
            }.awaitAll())
        }
    }

    override suspend fun search(query: String, token: String, includeAdult: Boolean): KTSearchResponse {
        val response = client.get("https://api.themoviedb.org/3/search/multi") {
            parameter("query", query)
            parameter("include_adult", includeAdult)
            parameter("language", "en-US")
            parameter("page", 1)

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        return response.body()
    }

    override suspend fun infoOnTV(id: Int, token: String): KTTVShow {
        val response = client.get("https://api.themoviedb.org/3/tv/$id") {
            parameter("language", "en-US")

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        return response.body()
    }

    @Throws(Exception::class)
    override suspend fun recommendationsForMovie(id: Int, token: String, page: Int): KTMovieListResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/$id/recommendations") {
            parameter("language", "en-US")
            parameter("page", page)

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTMovieListResponse>()
        return result.copy(results = result.results.map { item ->
            item.copy(genres = TMDBGenreResolver.genreNames(KTMediaType.MOVIE, item.genreIds, token))
        })
    }

    @Throws(Exception::class)
    override suspend fun recommendationsForTV(id: Int, token: String, page: Int): KTTVListResponse {
        val response = client.get("https://api.themoviedb.org/3/tv/$id/recommendations") {
            parameter("language", "en-US")
            parameter("page", page)

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTTVListResponse>()
        return result.copy(results = result.results.map { item ->
            item.copy(genres = TMDBGenreResolver.genreNames(KTMediaType.TV, item.genreIds, token))
        })
    }

    override suspend fun seasonInfo(id: Int, seasonNumber: Int, token: String): KTSeasonInfo {
        val response = client.get("https://api.themoviedb.org/3/tv/$id/season/$seasonNumber") {
            parameter("language", "en-US")

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        return response.body()
    }
}


@Serializable
internal data class HeroImagesResponse(val posters: List<HeroPosterImage> = emptyList())

@Serializable
internal data class HeroPosterImage(
    val filePath: String,
    @SerialName("iso_639_1") val language: String? = null,
    val width: Int = 0,
    val height: Int = 0,
    val voteAverage: Double = 0.0,
    val voteCount: Int = 0,
)

// No-language is a best-effort signal, not a guarantee that artwork contains no text.
internal fun selectHeroPoster(posters: List<HeroPosterImage>): String? = posters
    .filter { it.language == null && it.width > 0 && it.height > it.width && it.filePath.isNotBlank() }
    .sortedWith(compareByDescending<HeroPosterImage> { it.voteAverage }
        .thenByDescending { it.voteCount }
        .thenByDescending { it.width })
    .firstOrNull()?.filePath
