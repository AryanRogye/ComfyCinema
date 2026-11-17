// Install in each player frame; await window.comfyFrameAction('play') in the target frame.
(() => {
    if (window.comfyFrameAction) return;

    function findVideo() {
        const videos = Array.from(document.querySelectorAll('video'));
        // Prefer a playing video, then the longest finite media timeline.
        videos.sort((a, b) => Number(a.paused) - Number(b.paused) ||
            (Number.isFinite(b.duration) ? b.duration : 0) -
            (Number.isFinite(a.duration) ? a.duration : 0));
        return videos[0];
    }

    window.comfyFrameAction = async function(action) {
        const video = findVideo();
        if (!video) return { ok: false, error: 'No video in this frame' };

        try {
            switch (action) {
            case 'play':
                await video.play();
                break;
            case 'pause':
                video.pause();
                break;
            case 'enterFullscreen':
                if (document.fullscreenElement || video.webkitDisplayingFullscreen) break;
                if (video.requestFullscreen) await video.requestFullscreen();
                else if (video.webkitEnterFullscreen) video.webkitEnterFullscreen();
                else return { ok: false, error: 'Fullscreen is unavailable' };
                break;
            case 'exitFullscreen':
                if (document.fullscreenElement && document.exitFullscreen) {
                    await document.exitFullscreen();
                } else if (video.webkitDisplayingFullscreen && video.webkitExitFullscreen) {
                    video.webkitExitFullscreen();
                }
                break;
            default:
                return { ok: false, error: 'Unknown action' };
            }
            return { ok: true };
        } catch (error) {
            // Playback and fullscreen can be denied by browser or frame policies.
            return { ok: false, error: String(error?.message || error) };
        }
    };
})();
