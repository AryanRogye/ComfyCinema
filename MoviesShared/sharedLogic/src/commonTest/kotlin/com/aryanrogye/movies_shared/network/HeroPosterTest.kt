package com.aryanrogye.movies_shared.network

import com.aryanrogye.movies_shared.models.KTImage
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class HeroPosterTest {
    @Test fun selectsOnlyLanguageNeutralPortraits() {
        assertEquals("/portrait.jpg", selectHeroPoster(listOf(
            KTImage("/english.jpg", "en", 1000, 1500, 10.0),
            KTImage("/wide.jpg", null, 1500, 1000, 10.0),
            KTImage("/portrait.jpg", null, 1000, 1500, 8.0),
        )))
    }

    @Test fun fallsBackWhenNoSuitableArtworkExists() {
        assertNull(selectHeroPoster(emptyList()))
        assertNull(selectHeroPoster(listOf(KTImage("/poster.jpg", "en", 1000, 1500))))
    }

    @Test fun ranksCandidatesByRatingThenVotesThenResolution() {
        assertEquals("/best.jpg", selectHeroPoster(listOf(
            KTImage("/low.jpg", null, 2000, 3000, 7.0, 20),
            KTImage("/small.jpg", null, 500, 750, 8.0, 10),
            KTImage("/best.jpg", null, 1000, 1500, 8.0, 10),
        )))
    }
}
