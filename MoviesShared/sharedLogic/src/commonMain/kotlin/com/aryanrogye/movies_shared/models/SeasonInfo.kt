package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

@Serializable
data class KTSeasonInfo(
    val id: Int,
    val airDate: String? = null,
    val name: String,
    val overview: String,
    val posterPath: String? = null,
    val seasonNumber: Int,
    val episodes: List<KTEpisode>
)

@Serializable
data class KTEpisode(
    val id: Int,
    val name: String,
    val overview: String,
    val episodeNumber: Int,
    val seasonNumber: Int,
    val airDate: String? = null,
    val runtime: Int? = null,
    val stillPath: String? = null,
    val guestStars: List<KTGuestStar> = emptyList()
)

@Serializable
data class KTGuestStar(
    val id: Int,
    val name: String,
    val character: String,
    val creditId: String,
    val order: Int,
    val profilePath: String? = null
)
