package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

/** Response of TMDB's `/movie/{id}/credits` and `/tv/{id}/season/{s}/episode/{e}/credits`. */
@Serializable
data class KTCredits(
    val id: Int? = null,
    val cast: List<KTCastMember> = emptyList(),
)

@Serializable
data class KTCastMember(
    val id: Int,
    val name: String,
    val character: String? = null,
    val creditId: String? = null,
    val knownForDepartment: String? = null,
    val profilePath: String? = null,
    val order: Int? = null,
)
