package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

@Serializable
data class KTMovieCollection(
    val id: Int,
    val name: String,
    val posterPath: String? = null,
    val backdropPath: String? = null,
)

@Serializable
data class KTMovieInfo(
    val id: Int,
    val title: String,
    val overview: String,
    val tagline: String? = null,
    val backdropPath: String? = null,
    val belongsToCollection: KTMovieCollection? = null,
    val budget: Int,
    val genres: List<KTGenre>,
    var release_date: String? = null,
    val popularity: Double,
    val runtime: Int? = null,
)
