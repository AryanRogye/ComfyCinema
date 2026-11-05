package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

@Serializable
data class KTGenre(
    val id: Int,
    val name: String,
)

@Serializable
data class KTGenreResponse(
    val genres: List<KTGenre>,
)
