package com.aryanrogye.movies_shared.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import kotlinx.serialization.json.Json

@Serializable
enum class KTDisplayServer(val rawValue: String) {

    @SerialName("MoviesAPI")MOVIES_API("MoviesAPI"),

    @SerialName("VidFast")VID_FAST("VidFast"),

    @SerialName("VidPhantom")VID_PHANTOM("VidPhantom"),

    @SerialName("VidSrc")VID_SRC("VidSrc"),

    @SerialName("Rive Stream")RIVE_STREAM("Rive Stream"),

    @SerialName("VidSpark")VID_SPARK("VidSpark"),

    @SerialName("cdn.VidSpark")CDN_VID_SPARK("cdn.VidSpark"),

    @SerialName("VidLink")VID_LINK("VidLink"),

    @SerialName("CineSrc")CINE_SRC("CineSrc"),

    @SerialName("111movies")OneOneOneMovies("111movies"),

    @SerialName("VidNest") VID_NEST("VidNest"),

    @SerialName("VidRock") VID_ROCK("VidRock"),

    @SerialName("Vidy") VIDY("Vidy"),

    @SerialName("VidZee") VID_ZEE("VidZee"),

    @SerialName("Videasy") VIDEASY("Videasy");

    private val baseURL: String
        get() {
            return when (this) {
                MOVIES_API -> "https://moviesapi.to"
                VID_FAST -> "https://vidfast.vc"
                VID_PHANTOM -> "https://vidphantom.com"
                VID_SRC -> "https://vidsrc.sh/embed"
                RIVE_STREAM -> "https://www.rivestream.app/embed/agg"
                VID_SPARK -> "https://vidspark.to"
                CDN_VID_SPARK -> "https://cdn.vidspark.to"
                VID_LINK -> "https://vidlink.pro"
                CINE_SRC -> "https://cinesrc.st/embed"
                OneOneOneMovies -> "https://111movies.net"
                VID_NEST -> "https://vidnest.fun"
                VID_ROCK -> "https://vidrock.net"
                VIDY -> "https://www.vidy.st"
                VID_ZEE -> "https://player.vidzee.wtf/embed"
                VIDEASY -> "https://player.videasy.ws/embed"
            }
        }

    fun loadMovie(movieId: Int): String {
        return when (this) {
            RIVE_STREAM -> "$baseURL?type=movie&id=$movieId"
            else -> "$baseURL/movie/$movieId"
        }
    }

    fun loadTvShow(showId: Int, season: Int, episode: Int): String {
        return when (this) {
            CINE_SRC -> "$baseURL/tv/$showId?s=$season&e=$episode"
            RIVE_STREAM -> "$baseURL?type=tv&id=$showId&season=$season&episode=$episode"
            else -> "$baseURL/tv/$showId/$season/$episode"
        }
    }
}

object DisplayServerCodec {
    fun encode(server: KTDisplayServer): String {
        return Json.encodeToString(server)
    }

    fun decodeOrNull(json: String): KTDisplayServer? {
        return runCatching {
            Json.decodeFromString<KTDisplayServer>(json)
        }.getOrNull()
    }
}
