/* Build the LG catalog from the shared source; adult live content is never packaged. */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const source = JSON.parse(fs.readFileSync(path.join(__dirname, '../../MoviesAPIClient/LiveTV.json'), 'utf8'));
const LiveTV = source.LiveTV.filter(section => section.name.trim().toLowerCase() !== 'adult')
  .map(section => ({ ...section, channels: section.channels.filter(channel => !channel.isAdult) }))
  .filter(section => section.channels.length);
fs.writeFileSync(path.join(__dirname, '../LiveTV.json'), JSON.stringify({ LiveTV }, null, 2) + '\n');
console.log('LG Live TV: ' + LiveTV.length + ' categories, ' + LiveTV.reduce((sum, s) => sum + s.channels.length, 0) + ' channels.');
