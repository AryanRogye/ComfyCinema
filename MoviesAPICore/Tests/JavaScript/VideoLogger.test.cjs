const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(`${__dirname}/../../Sources/MoviesAPICore/Views/Watch/VideoLogger.js`, 'utf8');

test('captures errors, replaced players and backward jumps without controlling playback', () => {
    const messages = [], events = {}, timers = [], videoEvents = {};
    const video = { currentTime: 33, duration: 100, paused: false, seeking: false,
        readyState: 4, networkState: 1, buffered: { length: 0 }, error: null,
        addEventListener: (name, callback) => { videoEvents[name] = callback; } };
    let videos = [video];
    const context = vm.createContext({
        window: { webkit: { messageHandlers: { videoLogger: { postMessage: x => messages.push(x) } } },
            addEventListener: (name, callback) => { events[name] = callback; } },
        location: { origin: 'https://player.test', pathname: '/embed' },
        document: { querySelectorAll: () => videos },
        console: { warn() {}, error() {} }, setInterval: callback => timers.push(callback)
    });
    vm.runInContext(source, context);
    vm.runInContext(source, context);
    assert.equal(timers.length, 1, 'installation is idempotent');
    video.currentTime = 0;
    videoEvents.timeupdate();
    assert.equal(messages.at(-1).type, 'VIDEO_BACKWARD_JUMP');
    assert.equal(messages.at(-1).previousTime, 33);
    video.error = { code: 3, message: 'decode failure' };
    videoEvents.error();
    assert.equal(messages.at(-1).error.code, 3);
    events.unhandledrejection({ reason: 'failed segment' });
    assert.equal(messages.at(-1).type, 'UNHANDLED_REJECTION');
    vm.runInContext("console.error('provider error')", context);
    assert.equal(messages.at(-1).type, 'CONSOLE_ERROR');
    context.largeObject = { toJSON() { throw new Error('must not serialize provider objects'); } };
    vm.runInContext("console.error(largeObject)", context);
    assert.equal(messages.at(-1).message, '[object omitted]');
    vm.runInContext("console.error('x'.repeat(100000))", context);
    assert.equal(messages.at(-1).message.length, 2000);
    videos = [{ ...video, addEventListener() {} }];
    timers[0]();
    assert.equal(messages.at(-1).videoID, 2);
    for (let i = 0; i < 100; i++) events.unhandledrejection({ reason: 'noisy provider' });
    assert.equal(messages.length, 40, 'bridge traffic is bounded');
});
