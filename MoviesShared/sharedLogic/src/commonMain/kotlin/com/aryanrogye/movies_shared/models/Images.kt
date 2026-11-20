package com.aryanrogye.movies_shared.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class KTImagesResponse(
    val id: Int = 0,
    val backdrops: List<KTImage> = emptyList(),
    val logos: List<KTImage> = emptyList(),
    val posters: List<KTImage> = emptyList(),
)

@Serializable
data class KTImage(
    val filePath: String,
    @SerialName("iso_639_1") val language: String? = null,
    val width: Int = 0,
    val height: Int = 0,
    val voteAverage: Double = 0.0,
    val voteCount: Int = 0,
    val aspectRatio: Double = 0.0,
)

/** English PNG title artwork, with language-neutral PNGs as a fallback. */
internal fun selectLogo(logos: List<KTImage>): String? = logos
    .filter {
        (it.language == "en" || it.language == null) &&
            it.filePath.endsWith(".png", ignoreCase = true) && it.width > 0 && it.height > 0
    }
    .sortedWith(compareByDescending<KTImage> { it.language == "en" }
        .thenByDescending { it.voteAverage }
        .thenByDescending { it.voteCount }
        .thenByDescending { it.width })
    .firstOrNull()?.filePath
