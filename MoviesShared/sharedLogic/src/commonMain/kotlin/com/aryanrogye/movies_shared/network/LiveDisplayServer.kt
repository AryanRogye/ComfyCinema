
enum class KTLiveDisplayServer(val rawValue: String) {
    DLIVE_STREAM("DLive Stream"),
    DLIVE_CAST("DLive Cast"),
    DLIVE_WATCH("DLive Watch"),
    DEMBED("DEmbed");

    private val baseURL: String
        get() {
            return when (this) {
                DLIVE_STREAM -> "https://dlive.sx/stream/stream-"
                DLIVE_CAST -> "https://dlive.sx/cast/stream-"
                DLIVE_WATCH -> "https://dlive.sx/watch/stream"
                DEMBED -> "https://dembed.st/premiumtv/daddy.php"
            }
        }

    fun loadLive(Id: Int): String {
        return when (this) {
            DLIVE_STREAM, DLIVE_CAST, DLIVE_WATCH -> "$baseURL$Id.php"
            DEMBED -> "$baseURL?id=$Id"
        }
    }
}
