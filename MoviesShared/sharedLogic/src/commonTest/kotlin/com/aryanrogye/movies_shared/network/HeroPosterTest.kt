package com.aryanrogye.movies_shared.network

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class HeroPosterTest {
    @Test fun selectsOnlyLanguageNeutralPortraits() {
        assertEquals("/portrait.jpg", selectHeroPoster(listOf(
            HeroPosterImage("/english.jpg", "en", 1000, 1500, 10.0),
            HeroPosterImage("/wide.jpg", null, 1500, 1000, 10.0),
            HeroPosterImage("/portrait.jpg", null, 1000, 1500, 8.0),
        )))
    }

    @Test fun fallsBackWhenNoSuitableArtworkExists() {
        assertNull(selectHeroPoster(emptyList()))
        assertNull(selectHeroPoster(listOf(HeroPosterImage("/poster.jpg", "en", 1000, 1500))))
    }

    @Test fun ranksCandidatesByRatingThenVotesThenResolution() {
        assertEquals("/best.jpg", selectHeroPoster(listOf(
            HeroPosterImage("/low.jpg", null, 2000, 3000, 7.0, 20),
            HeroPosterImage("/small.jpg", null, 500, 750, 8.0, 10),
            HeroPosterImage("/best.jpg", null, 1000, 1500, 8.0, 10),
        )))
    }
}
