package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

@Serializable
data class KTTVShow(
    val id: Int,
    val name: String,
    val overview: String,
    val backdropPath: String? = null,
    val numberOfEpisodes: Int,
    val numberOfSeasons: Int,
    val seasons: List<KTSeason>,
    @Transient
    val logoPath: String? = null,
)

@Serializable
data class KTSeason(
    val id: Int,
    val name: String,
    val seasonNumber: Int,
    val episodeCount: Int,
    val posterPath: String? = null,
    @Transient
    val logoPath: String? = null,
)