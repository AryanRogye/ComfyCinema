package com.aryanrogye.movies_shared.network

import com.aryanrogye.movies_shared.models.KTRatingsAndReviews
import com.aryanrogye.movies_shared.models.KTReviewResponse
import com.aryanrogye.movies_shared.models.KTSearchResponse
import com.aryanrogye.movies_shared.models.KTPersonCombinedCredits
import com.aryanrogye.movies_shared.models.KTSeasonInfo
import com.aryanrogye.movies_shared.models.KTMovieListResponse
import com.aryanrogye.movies_shared.models.KTNowPlayingMovieResponse
import com.aryanrogye.movies_shared.models.KTTVListResponse
import com.aryanrogye.movies_shared.models.KTTVShow
import com.aryanrogye.movies_shared.models.KTTrendingResponse
import com.aryanrogye.movies_shared.models.KTGenre
import com.aryanrogye.movies_shared.models.KTGenreResponse
import com.aryanrogye.movies_shared.models.KTImagesResponse
import com.aryanrogye.movies_shared.models.KTImage
import com.aryanrogye.movies_shared.models.KTMovieListResult
import com.aryanrogye.movies_shared.models.KTTVListResult
import com.aryanrogye.movies_shared.models.KTSearchResult
import com.aryanrogye.movies_shared.models.selectLogo
import com.aryanrogye.movies_shared.models.KTMediaType
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
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
    suspend fun creditsForPerson(id: Int, token: String): KTSearchResponse
    suspend fun infoOnTV(id: Int, token: String): KTTVShow
    suspend fun seasonInfo(id: Int, seasonNumber: Int, token: String): KTSeasonInfo
    @Throws(Exception::class)
    suspend fun recommendationsForMovie(id: Int, token: String, page: Int): KTMovieListResponse
    @Throws(Exception::class)
    suspend fun recommendationsForTV(id: Int, token: String, page: Int): KTTVListResponse
}

class TMDBClient internal constructor(private val client: HttpClient): TMDBClientProviding {
    constructor(): this(createTMDBHttpClient())

    private val imageRequests = Semaphore(4)
    private val imageCacheMutex = Mutex()
    private val imageCache = linkedMapOf<Pair<KTMediaType, Int>, KTImagesResponse>()

    private suspend fun images(id: Int, mediaType: KTMediaType, token: String): KTImagesResponse? {
        if (mediaType == KTMediaType.PERSON) return null
        val key = mediaType to id
        return try {
            imageRequests.withPermit {
                imageCacheMutex.withLock { imageCache[key] }?.let { return@withPermit it }
                val response = client.get("https://api.themoviedb.org/3/${mediaType.rawValue}/$id/images") {
                    parameter("include_image_language", "en,null")
                    header("accept", "application/json")
                    header("Authorization", "Bearer $token")
                }
                check(response.status.value in 200..299)
                response.body<KTImagesResponse>().also { images ->
                    imageCacheMutex.withLock {
                        imageCache[key] = images
                        if (imageCache.size > 256) imageCache.remove(imageCache.keys.first())
                    }
                }
            }
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // Artwork is optional. Do not cache failures so a later call can retry.
            null
        }
    }

    private suspend fun movieResults(items: List<KTMovieListResult>, token: String) =
        items.parallelMap { item ->
            item.copy(
                genres = TMDBGenreResolver.genreNames(KTMediaType.MOVIE, item.genreIds, token),
                logoPath = images(item.id, KTMediaType.MOVIE, token)?.let { selectLogo(it.logos) },
            )
        }

    private suspend fun tvResults(items: List<KTTVListResult>, token: String) =
        items.parallelMap { item ->
            item.copy(
                genres = TMDBGenreResolver.genreNames(KTMediaType.TV, item.genreIds, token),
                logoPath = images(item.id, KTMediaType.TV, token)?.let { selectLogo(it.logos) },
            )
        }

    private suspend fun searchResults(items: List<KTSearchResult>, token: String) =
        items.parallelMap { item ->
            val artwork = images(item.id, item.mediaType, token)
            item.copy(
                logoPath = artwork?.let { selectLogo(it.logos) },
                heroPosterPath = artwork?.let { selectHeroPoster(it.posters) },
            )
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

    @Throws(Exception::class)
    override suspend fun popularTV(token: String, page: Int): KTTVListResponse {
        val response = client.get("https://api.themoviedb.org/3/tv/popular?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTTVListResponse>()
        return result.copy(results = tvResults(result.results, token))
    }

    @Throws(Exception::class)
    override suspend fun popularMovies(token: String, page: Int): KTMovieListResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/popular?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTMovieListResponse>()
        return result.copy(results = movieResults(result.results, token))
    }

    @Throws(Exception::class)
    override suspend fun topRatedMovies(token: String, page: Int): KTMovieListResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/top_rated?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTMovieListResponse>()
        return result.copy(results = movieResults(result.results, token))
    }

    @Throws(Exception::class)
    override suspend fun topRatedTV(token: String, page: Int): KTTVListResponse {
        val response = client.get("https://api.themoviedb.org/3/tv/top_rated?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTTVListResponse>()
        return result.copy(results = tvResults(result.results, token))
    }

    @Throws(Exception::class)
    override suspend fun nowPlayingMovies(token: String, page: Int): KTNowPlayingMovieResponse {
        val response = client.get("https://api.themoviedb.org/3/movie/now_playing?language=en-US&page=$page") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTNowPlayingMovieResponse>()
        return result.copy(results = movieResults(result.results, token))
    }

    @Throws(Exception::class)
    override suspend fun trending(token: String): KTTrendingResponse {
        val response = client.get("https://api.themoviedb.org/3/trending/all/day?language=en-US") {
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val trending = response.body<KTTrendingResponse>()
        return trending.copy(results = trending.results.parallelMap { item ->
            val artwork = images(item.id, item.mediaType, token)
            item.copy(
                genreType = TMDBGenreResolver.genreNames(item.mediaType, item.genreIds, token),
                heroPosterPath = artwork?.let { selectHeroPoster(it.posters) },
                logoPath = artwork?.let { selectLogo(it.logos) },
            )
        })
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

        val result = response.body<KTSearchResponse>()
        return result.copy(results = searchResults(result.results, token))
    }

    override suspend fun creditsForPerson(id: Int, token: String): KTSearchResponse {
        val response = client.get("https://api.themoviedb.org/3/person/$id/combined_credits") {
            parameter("language", "en-US")
            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val credits = response.body<KTPersonCombinedCredits>()

        return KTSearchResponse(
            results = searchResults(credits.cast, token)
        )
    }

    override suspend fun infoOnTV(id: Int, token: String): KTTVShow {
        val response = client.get("https://api.themoviedb.org/3/tv/$id") {
            parameter("language", "en-US")

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTTVShow>()
        val logoPath = images(id, KTMediaType.TV, token)?.let { selectLogo(it.logos) }
        return result.copy(
            logoPath = logoPath,
            seasons = result.seasons.map { it.copy(logoPath = logoPath) },
        )
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
        return result.copy(results = movieResults(result.results, token))
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
        return result.copy(results = tvResults(result.results, token))
    }

    override suspend fun seasonInfo(id: Int, seasonNumber: Int, token: String): KTSeasonInfo {
        val response = client.get("https://api.themoviedb.org/3/tv/$id/season/$seasonNumber") {
            parameter("language", "en-US")

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        val result = response.body<KTSeasonInfo>()
        // Seasons use their parent show's title logo, not the season's ID.
        return result.copy(logoPath = images(id, KTMediaType.TV, token)?.let { selectLogo(it.logos) })
    }
}


@OptIn(ExperimentalSerializationApi::class)
private fun createTMDBHttpClient() = HttpClient {
    install(ContentNegotiation) {
        json(Json {
            ignoreUnknownKeys = true
            namingStrategy = JsonNamingStrategy.SnakeCase
        })
    }
}

private suspend fun <T, R> List<T>.parallelMap(transform: suspend (T) -> R): List<R> =
    coroutineScope { map { async { transform(it) } }.awaitAll() }

// No-language is a best-effort signal, not a guarantee that artwork contains no text.
internal fun selectHeroPoster(posters: List<KTImage>): String? = posters
    .filter { it.language == null && it.width > 0 && it.height > it.width && it.filePath.isNotBlank() }
    .sortedWith(compareByDescending<KTImage> { it.voteAverage }
        .thenByDescending { it.voteCount }
        .thenByDescending { it.width })
    .firstOrNull()?.filePath
