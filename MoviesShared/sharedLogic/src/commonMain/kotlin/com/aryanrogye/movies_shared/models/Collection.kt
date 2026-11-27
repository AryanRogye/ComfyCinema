package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

@Serializable
data class KTCollectionPart(
    val adult: Boolean,
    val backdrop_path: String? = null,
    val id: Int,
    val name: String? = null,
    val title: String? = null,
    val original_title: String? = null,
    val original_name: String? = null,
    val overview: String,
    val poster_path: String? = null,
    val media_type: KTMediaType,
    val original_language: String,
    val release_date: String? = null,
)

@Serializable
data class KTCollectionResponse(
    val id: Int,
    val name: String,
    val original_language: String,
    val original_name: String,
    val overview: String,
    val poster_path: String? = null,
    val backdrop_path: String? = null,
    val parts: List<KTCollectionPart>,
)
