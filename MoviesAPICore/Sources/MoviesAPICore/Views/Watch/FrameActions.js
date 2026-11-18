// Injected into EVERY frame (forMainFrameOnly: false).
// The native side calls `await window.comfyFrameAction('play')` in the main frame; the call is
// relayed through postMessage to all nested frames, and the first frame that handles it wins.
(() => {
    if (window.comfyFrameAction) return;

    const TAG = '__comfyFrameAction';
    const REPLY = '__comfyFrameReply';
    const sleep = ms => new Promise(r => setTimeout(r, ms));

    // ---------- helpers ----------

    function findVideo() {
        const videos = Array.from(document.querySelectorAll('video'));
        // Prefer a playing video, then the longest finite media timeline.
        videos.sort((a, b) => Number(a.paused) - Number(b.paused) ||
            (Number.isFinite(b.duration) ? b.duration : 0) -
            (Number.isFinite(a.duration) ? a.duration : 0));
        return videos[0];
    }

    function isVisible(el) {
        const r = el.getBoundingClientRect();
        if (r.width < 2 || r.height < 2) return false;
        const s = getComputedStyle(el);
        return s.visibility !== 'hidden' && s.display !== 'none' && s.opacity !== '0';
    }

    function fireClick(el) {
        const r = el.getBoundingClientRect();
        const x = r.left + r.width / 2, y = r.top + r.height / 2;
        const opts = { bubbles: true, cancelable: true, composed: true, view: window,
                       clientX: x, clientY: y, button: 0 };
        for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click']) {
            const Ctor = type.startsWith('pointer') ? PointerEvent : MouseEvent;
            el.dispatchEvent(new Ctor(type, opts));
        }
    }

    const PLAY_SELECTORS = [
        '.vjs-big-play-button', '.jw-icon-display', '.jw-display-icon-container',
        '.plyr__control--overlaid', '.ytp-large-play-button', '.vds-play-button',
        '.fp-play', '.play-button', '.big-play-button', '#play-button', '#player-button',
        'button[aria-label*="play" i]', '[role="button"][aria-label*="play" i]',
        '[title="Play" i]', '[class*="play-btn" i]', '[class*="playbtn" i]',
        '[class*="play-button" i]', '[class*="PlayButton"]', '[class*="big-play" i]',
        '[id*="play" i]:not(video)'
    ];

    // Click the player's own play control, or, failing that, the center of the frame.
    function clickPlayControl() {
        for (const sel of PLAY_SELECTORS) {
            let el;
            try { el = Array.from(document.querySelectorAll(sel)).find(isVisible); } catch { continue; }
            if (el) { fireClick(el); return true; }
        }
        // Only blind-click the center in leaf frames (no nested iframes), so we never
        // click through a page that merely hosts the player.
        if (document.querySelector('iframe') || window.innerWidth < 150 || window.innerHeight < 100) {
            return false;
        }
        const target = document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2);
        if (!target || target === document.documentElement) return false;
        fireClick(target);
        return true;
    }

    function clickPauseControl() {
        const sels = ['.vjs-play-control.vjs-playing', '.jw-icon-playback', '.plyr__control[data-plyr="play"]',
                      'button[aria-label*="pause" i]', '[title="Pause" i]'];
        for (const sel of sels) {
            let el;
            try { el = Array.from(document.querySelectorAll(sel)).find(isVisible); } catch { continue; }
            if (el) { fireClick(el); return true; }
        }
        return false;
    }

    // ---------- per-frame actions: return { handled, ok, error? } ----------

    async function play() {
        let video = findVideo();
        if (video && !video.paused && !video.ended) return { handled: true, ok: true };

        if (video) {
            try { await video.play(); } catch { /* blocked without a user gesture; fall through */ }
            await sleep(250);
            if (!video.paused) return { handled: true, ok: true };
        }

        // Paused behind an overlay, or no <video> yet (poster + big play button).
        if (!clickPlayControl()) {
            return video ? { handled: true, ok: false, error: 'Could not start playback' }
                         : { handled: false };
        }
        for (let i = 0; i < 12; i++) {           // up to ~3s for the stream to start
            await sleep(250);
            video = findVideo();
            if (video && !video.paused) return { handled: true, ok: true };
        }
        return { handled: true, ok: false, error: 'Clicked play but video did not start' };
    }

    async function pause() {
        const video = findVideo();
        if (!video) return { handled: false };
        if (video.paused) return { handled: true, ok: true };
        video.pause();
        await sleep(150);
        if (video.paused) return { handled: true, ok: true };
        if (clickPauseControl()) { await sleep(250); if (video.paused) return { handled: true, ok: true }; }
        return { handled: true, ok: false, error: 'Could not pause' };
    }

    async function enterFullscreen() {
        const video = findVideo();
        if (!video) return { handled: false };
        if (document.fullscreenElement || video.webkitDisplayingFullscreen) return { handled: true, ok: true };
        const attempts = [
            () => video.requestFullscreen && video.requestFullscreen(),
            () => document.documentElement.requestFullscreen && document.documentElement.requestFullscreen(),
            () => video.webkitEnterFullscreen && video.webkitEnterFullscreen(),
        ];
        for (const attempt of attempts) {
            try { await attempt(); } catch { continue; }
            await sleep(150);
            if (document.fullscreenElement || video.webkitDisplayingFullscreen) return { handled: true, ok: true };
        }
        // Last resort: the player's own fullscreen button.
        const btn = Array.from(document.querySelectorAll(
            'button[aria-label*="full" i], [title*="full" i], .vjs-fullscreen-control, .jw-icon-fullscreen, [data-plyr="fullscreen"]'
        )).find(isVisible);
        if (btn) { fireClick(btn); await sleep(300); return { handled: true, ok: true }; }
        return { handled: true, ok: false, error: 'Fullscreen is unavailable' };
    }

    async function exitFullscreen() {
        const video = findVideo();
        if (document.fullscreenElement && document.exitFullscreen) {
            try { await document.exitFullscreen(); } catch (e) { return { handled: true, ok: false, error: String(e?.message || e) }; }
            return { handled: true, ok: true };
        }
        if (video && video.webkitDisplayingFullscreen && video.webkitExitFullscreen) {
            video.webkitExitFullscreen();
            return { handled: true, ok: true };
        }
        return { handled: false };
    }

    // Probe only: reports whether this frame has a video.
    async function hasVideo() { return findVideo() ? { handled: true, ok: true } : { handled: false }; }

    // Moves the playhead to `target` seconds. Returns false if the video can't be seeked there.
    function seekTo(video, target) {
        const d = video.duration;
        if (!Number.isFinite(target) || target < 0) return false;
        if (Number.isFinite(d) && target > d) return false;
        video.currentTime = target;
        return true;
    }

    async function skip(delta) {
        const video = findVideo();
        if (!video) return { handled: false };
        const d = video.duration;
        let target = video.currentTime + delta;
        target = Math.max(0, Number.isFinite(d) ? Math.min(target, d) : target);
        return seekTo(video, target) ? { handled: true, ok: true }
                                     : { handled: true, ok: false, error: 'Could not skip' };
    }

    const skipForward  = () => skip(10);
    const skipBackward = () => skip(-10);

    // arg: time in seconds (number or numeric string). Invalid times do nothing.
    async function seek(arg) {
        const video = findVideo();
        if (!video) return { handled: false };
        const raw = typeof arg === 'string' ? arg.trim() : arg;
        const seconds = (raw === '' || raw === null || raw === undefined) ? NaN : Number(raw);
        return seekTo(video, seconds) ? { handled: true, ok: true }
                                      : { handled: true, ok: false, error: 'Invalid seek time' };
    }

    const ACTIONS = { play, pause, enterFullscreen, exitFullscreen, hasVideo,
                      skipForward, skipBackward, seek };

    async function runLocal(action, arg) {
        const fn = ACTIONS[action];
        if (!fn) return { handled: true, ok: false, error: 'Unknown action' };
        try { return await fn(arg); }
        catch (e) { return { handled: true, ok: false, error: String(e?.message || e) }; }
    }

    // ---------- cross-frame relay ----------

    let nextId = 0;

    // Runs the action here and in every nested frame. Resolves with the best result.
    function runEverywhere(action, deadline, arg) {
        return new Promise(resolve => {
            const id = `${Date.now()}-${Math.random()}-${nextId++}`;
            const iframes = Array.from(document.querySelectorAll('iframe')).filter(f => f.contentWindow);
            const frames = iframes.map(f => f.contentWindow);
            let best = null, pending = frames.length + 1, done = false;

            const consider = r => {
                if (!r || !r.handled) return;
                if (!best || (r.ok && !best.ok)) best = r;
            };
            const finish = () => {
                if (done) return;
                done = true;
                window.removeEventListener('message', onMessage);
                resolve(best || { handled: false });
            };
            const settle = r => {
                consider(r);
                pending--;
                if ((best && best.ok) || pending <= 0) finish();
            };
            const onMessage = e => {
                const d = e.data;
                if (!d || !d[REPLY] || d.id !== id) return;
                const r = d.result;
                if (r && r.handled) {
                    // Remember which direct child iframe contains the video (never sent back up).
                    const idx = frames.indexOf(e.source);
                    if (idx >= 0) r.viaFrame = iframes[idx];
                }
                settle(r);
            };

            window.addEventListener('message', onMessage);
            for (const w of frames) {
                try { w.postMessage({ [TAG]: true, id, action, arg, deadline }, '*'); }
                catch { pending--; }
            }
            runLocal(action, arg).then(settle);
            setTimeout(finish, Math.max(300, deadline - Date.now()));
        });
    }

    window.addEventListener('message', async e => {
        const d = e.data;
        if (!d || !d[TAG] || !e.source) return;
        const result = await runEverywhere(d.action, d.deadline - 100, d.arg);
        const { handled, ok, error } = result;
        try { e.source.postMessage({ [REPLY]: true, id: d.id, result: { handled, ok, error } }, '*'); } catch {}
    });

    // Fullscreen needs user activation, which the native call has only in THIS frame and which
    // does not survive postMessage. So request fullscreen on the <iframe> element that hosts the
    // video from here, where the gesture is still valid.
    async function enterFullscreenFromTop() {
        if (document.fullscreenElement) return { ok: true };
        const probe = await runEverywhere('hasVideo', Date.now() + 2000);
        const target = probe.viaFrame;
        if (!target) return null;                       // video is in this frame: normal path
        for (const req of ['requestFullscreen', 'webkitRequestFullscreen']) {
            if (!target[req]) continue;
            try { await target[req](); } catch { continue; }
            await sleep(150);
            if (document.fullscreenElement || document.webkitFullscreenElement) return { ok: true };
        }
        return null;                                    // fall back to the in-frame attempts
    }

    // Entry point used by the native side (main frame).
    window.comfyFrameAction = async function(action, arg) {
        if (!ACTIONS[action]) return { ok: false, error: 'Unknown action' };
        if (action === 'enterFullscreen') {
            const r = await enterFullscreenFromTop();
            if (r) return r;
        }
        const result = await runEverywhere(action, Date.now() + 6000, arg);
        if (!result.handled) return { ok: false, error: 'No video found in any frame' };
        return result.ok ? { ok: true } : { ok: false, error: result.error || 'Action failed' };
    };
})();
