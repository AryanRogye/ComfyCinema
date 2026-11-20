package com.aryanrogye.movies_shared.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

@Serializable
data class KTPersonCombinedCredits(
    val cast: List<KTSearchResult>,
    val crew: List<KTSearchResult>,
)

@Serializable
enum class KTMediaType(val rawValue: String) {
    @SerialName("tv")
    TV("tv"),

    @SerialName("movie")
    MOVIE("movie"),

    @SerialName("person")
    PERSON("person")
}

@Serializable
data class KTSearchResult(
    val id: Int,
    val mediaType: KTMediaType,
    val title: String? = null,
    val name: String? = null,
    val posterPath: String? = null,
    val profile_path: String? = null,
    val overview: String? = null,
    val releaseDate: String? = null,
    val firstAirDate: String? = null,
    @Transient
    val logoPath: String? = null,
    @Transient
    val heroPosterPath: String? = null,
)

@Serializable
data class KTSearchResponse(
    val results: List<KTSearchResult>
)
