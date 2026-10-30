// Passive diagnostics in each player frame. Never seek, reload, or retry playback.
(() => {
    if (window.__moviesPlaybackDiagnostics) return;
    window.__moviesPlaybackDiagnostics = true;

    // Limit bridge traffic from noisy provider scripts, including console loops.
    let windowStart = Date.now();
    let count = 0;
    function report(type, details = {}) {
        try {
            if (Date.now() - windowStart >= 10000) {
                windowStart = Date.now();
                count = 0;
            }
            if (++count > 40) return;
            window.webkit?.messageHandlers?.videoLogger?.postMessage({
                timestamp: new Date().toISOString(), type,
                frame: location.origin + location.pathname, ...details
            });
        } catch { /* Diagnostics must never interfere with the provider. */ }
    }
    function describe(value) {
        try {
            return (value instanceof Error ? `${value.name}: ${value.message}\n${value.stack || ''}`
                : typeof value === 'string' ? value
                : value === null ? 'null'
                : typeof value === 'object' ? '[object omitted]' : String(value)).slice(0, 2000);
        } catch { return '[unserializable value]'; }
    }
    window.addEventListener('error', event => {
        report('JAVASCRIPT_ERROR', {
            message: String(event.message || 'Resource failed to load').slice(0, 4000),
            file: event.filename, line: event.lineno, column: event.colno,
            stack: event.error ? describe(event.error) : undefined
        });
    }, true);
    window.addEventListener('unhandledrejection', event => {
        report('UNHANDLED_REJECTION', { message: describe(event.reason) });
    });
    for (const level of ['warn', 'error']) {
        const original = console[level];
        console[level] = function (...args) {
            report(`CONSOLE_${level.toUpperCase()}`, { message: args.slice(0, 8).map(describe).join(' ') });
            return Reflect.apply(original, this, args);
        };
    }

    const attached = new WeakSet();
    let nextID = 0;
    function attach(video) {
        if (attached.has(video)) return;
        attached.add(video);
        const videoID = ++nextID;
        let previousTime = video.currentTime;
        function snapshot(type, extra = {}) {
            const buffered = [];
            for (let i = 0; i < Math.min(video.buffered.length, 10); i++) {
                buffered.push([video.buffered.start(i), video.buffered.end(i)]);
            }
            report(type, {
                videoID, currentTime: video.currentTime,
                duration: Number.isFinite(video.duration) ? video.duration : null,
                paused: video.paused, seeking: video.seeking,
                readyState: video.readyState, networkState: video.networkState,
                buffered, error: video.error ? { code: video.error.code, message: video.error.message } : null,
                ...extra
            });
        }
        for (const name of ['loadstart', 'loadedmetadata', 'playing', 'pause', 'waiting',
                            'stalled', 'error', 'emptied', 'abort', 'ended', 'seeking', 'seeked']) {
            video.addEventListener(name, () => snapshot(`VIDEO_${name.toUpperCase()}`));
        }
        video.addEventListener('timeupdate', () => {
            const current = video.currentTime;
            // This may also be an intentional user seek; record evidence, not a diagnosis.
            if (previousTime - current > 5) snapshot('VIDEO_BACKWARD_JUMP', { previousTime });
            previousTime = current;
        });
        snapshot('VIDEO_ATTACHED');
    }
    function scan() { document.querySelectorAll('video').forEach(attach); }
    // Discovers dynamically inserted and replaced players without scanning on every DOM mutation.
    scan();
    setInterval(scan, 1000);
    report('DIAGNOSTICS_READY');
})();
