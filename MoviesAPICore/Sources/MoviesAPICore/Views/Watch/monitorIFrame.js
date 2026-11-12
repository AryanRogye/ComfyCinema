// Observe timing without seeking, reloading, or changing the provider's player.
(() => {
  if (window.__moviesIFrameMonitor) return;
  window.__moviesIFrameMonitor = true;

  let lastReportAt = -Infinity;
  function report(currentTime, duration, source) {
    if (typeof currentTime !== "number" || !Number.isFinite(currentTime) || currentTime < 0 ||
        typeof duration !== "number" || !Number.isFinite(duration) || duration <= 0 ||
        currentTime > duration) return;
    const now = Date.now();
    if (now - lastReportAt < 1000) return;
    lastReportAt = now;
    try {
      window.webkit?.messageHandlers?.iframeDebug?.postMessage({
        currentTime, duration, source,
        timestamp: new Date(now).toISOString(),
        frame: location.origin + location.pathname
      });
    } catch { /* Monitoring must not interrupt playback. */ }
  }

  window.addEventListener("message", (event) => {
    let message;
    try {
      message = typeof event.data === "string" ? JSON.parse(event.data) : event.data;
      // Some players encode their inner payload separately.
      if (typeof message?.data === "string") {
        message = { ...message, data: JSON.parse(message.data) };
      }
    } catch { return; }

    if (message?.player_progress !== undefined && message?.player_duration !== undefined) {
      report(message.player_progress, message.player_duration, "postMessage");
    } else if (message?.data?.currentTime !== undefined && message?.data?.duration !== undefined) {
      report(message.data.currentTime, message.data.duration, "postMessage");
    } else if (message?.currentTime !== undefined && message?.duration !== undefined) {
      report(message.currentTime, message.duration, "postMessage");
    }
  });

  // This script runs in every frame, so no cross-origin DOM access is needed.
  // Prefer an actively playing video, then the longest finite media timeline.
  function sampleVideo() {
    const videos = Array.from(document.querySelectorAll("video"))
      .filter(video => Number.isFinite(video.duration) && video.duration > 0);
    videos.sort((a, b) => Number(a.paused) - Number(b.paused) || b.duration - a.duration);
    const video = videos[0];
    if (video) report(video.currentTime, video.duration, "videoElement");
  }
  sampleVideo();
  setInterval(sampleVideo, 1000);
})();
