'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '..');
function harness() {
  const element = { innerHTML: '', addEventListener() {}, querySelector() { return null; }, querySelectorAll() { return []; } };
  const storage = {};
  const context = { window: { addEventListener() {} }, document: { getElementById() { return element; }, addEventListener() {}, activeElement: { tagName: 'BODY' }, body: {} }, localStorage: { getItem() { return '{}'; }, setItem(k,v) { storage[k] = v; } }, URLSearchParams, console, fetch: async () => ({ ok: true, json: async () => JSON.parse(fs.readFileSync(path.join(root, 'LiveTV.json'))) }) };
  vm.createContext(context);
  const code = fs.readFileSync(path.join(root, 'app.js'), 'utf8').replace('  render(); loadHome();', '  window.test = { state, data, loadLive, livePage, liveUrl, livePlayer, handleAction, back, historyStats, serverUrl, metadata, recommendations };');
  vm.runInContext(code, context);
  return context.window.test;
}
test('packaged catalog matches current shared catalog with adult sections and channels excluded', () => {
  const source = JSON.parse(fs.readFileSync(path.join(root, '../MoviesAPIClient/LiveTV.json')));
  const expected = source.LiveTV.filter(s => s.name.trim().toLowerCase() !== 'adult').map(s => ({ ...s, channels: s.channels.filter(c => !c.isAdult) })).filter(s => s.channels.length);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, 'LiveTV.json'))).LiveTV, expected);
});
test('live browsing works without TMDB, filters channels, opens playback and returns via Back', async () => {
  const app = harness();
  await app.loadLive();
  assert.equal(app.state.liveSections.length, 19);
  app.data.adult = true;
  assert.ok(!app.livePage().includes('data-value="Adult"'));
  const channel = app.state.liveSections[0].channels[0];
  app.state.liveQuery = 'no such channel exists';
  assert.ok(app.livePage().includes('No channels found.'));
  app.handleAction('live-channel', String(channel.id));
  assert.equal(app.state.screen, 'live');
  const urls = [ ['DLive Stream', `https://dlive.sx/stream/stream-${channel.id}.php`], ['DLive Cast', `https://dlive.sx/cast/stream-${channel.id}.php`], ['DLive Watch', `https://dlive.sx/watch/stream${channel.id}.php`], ['DEmbed', `https://dembed.st/premiumtv/daddy.php?id=${channel.id}`] ];
  for (const [name, url] of urls) { app.handleAction('live-server', name); assert.equal(app.liveUrl(), url); assert.ok(app.livePlayer().includes(url)); }
  app.back();
  assert.equal(app.state.screen, 'main');
  assert.equal(app.state.tab, 'Live TV');
  assert.equal(app.state.channel, null);
});
test('history stats group episodes by show and escape show titles', () => {
  const app = harness();
  app.data.history = [{ id: 1, title: '<Show>', season: 1 }, { id: 1, title: '<Show>', season: 2 }, { id: 2, title: 'Movie', season: null }];
  const html = app.historyStats();
  assert.ok(html.includes('<strong>1</strong> Movies'));
  assert.ok(html.includes('<strong>2</strong> Episodes'));
  assert.ok(html.includes('<strong>1</strong> Shows'));
  assert.ok(html.includes('&lt;Show&gt; (2)'));
});
test('existing special movie and TV server URLs remain compatible', () => {
  const app = harness();
  app.state.detail = { id: 42, media_type: 'tv' }; app.state.season = 2; app.state.episode = { episode_number: 3 };
  app.data.server = 'CineSrc'; assert.equal(app.serverUrl(), 'https://cinesrc.st/embed/tv/42?s=2&e=3');
  app.data.server = 'Rive Stream'; assert.equal(app.serverUrl(), 'https://www.rivestream.app/embed/agg?type=tv&id=42&season=2&episode=3');
  app.state.detail.media_type = 'movie'; assert.equal(app.serverUrl(), 'https://www.rivestream.app/embed/agg?type=movie&id=42');
});
