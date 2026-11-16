const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(`${__dirname}/../../Sources/MoviesAPICore/Views/Watch/monitorIFrame.js`, 'utf8');
function setup() {
    const messages = [], timers = [], events = {};
    let now = 10000, videos = [];
    class Clock extends Date { static now() { return now; } }
    const context = vm.createContext({
        Date: Clock,
        window: { addEventListener: (name, callback) => { events[name] = callback; },
            webkit: { messageHandlers: { iframeDebug: { postMessage: value => messages.push(value) } } } },
        document: { querySelectorAll: () => videos },
        location: { origin: 'https://player.test', pathname: '/embed' },
        setInterval: callback => timers.push(callback)
    });
    vm.runInContext(source, context);
    return { context, messages, timers, events,
        advance() { now += 1000; }, setVideos(value) { videos = value; } };
}
test('discovers dynamic video timing without provider messages and throttles updates', () => {
    const h = setup();
    vm.runInContext(source, h.context);
    assert.equal(h.timers.length, 1);
    h.setVideos([{ currentTime: 125, duration: 3600, paused: false }]);
    h.timers[0]();
    assert.equal(h.messages[0].currentTime, 125);
    assert.equal(h.messages[0].source, 'videoElement');
    h.timers[0]();
    assert.equal(h.messages.length, 1);
    h.advance();
    h.setVideos([{ currentTime: 200, duration: 3600, paused: false }]);
    h.timers[0]();
    assert.equal(h.messages.at(-1).currentTime, 200);
});
test('accepts existing provider shapes and separately encoded payloads', () => {
    const h = setup();
    for (const data of [
        { player_progress: 20, player_duration: 100 },
        { currentTime: 20, duration: 100 },
        { data: { currentTime: 20, duration: 100 } },
        JSON.stringify({ type: 'PLAYER_EVENT', data: JSON.stringify({ currentTime: 20, duration: 100 }) })
    ]) {
        h.events.message({ data });
        assert.equal(h.messages.at(-1).currentTime, 20);
        h.advance();
    }
    assert.equal(h.messages.length, 4);
});
test('ignores malformed and invalid timing rather than forwarding it to Swift', () => {
    const h = setup();
    for (const data of ['bad JSON', null, { currentTime: -1, duration: 10 },
        { currentTime: 2, duration: Infinity }, { currentTime: 2 },
        { currentTime: '2', duration: 10 }, { currentTime: 20, duration: 10 }]) {
        h.events.message({ data });
    }
    h.setVideos([{ currentTime: 2, duration: NaN }]);
    h.timers[0]();
    assert.equal(h.messages.length, 0);
});
