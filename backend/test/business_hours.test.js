const assert = require('node:assert/strict');
const { test } = require('node:test');
const { isStoreOpenAt, parseBusinessHours, taipeiClock } = require('../src/stores/business_hours');

const taipei = (value) => new Date(`${value}+08:00`);

test('business hours support daytime, closed time and overnight schedules', () => {
  assert.deepEqual(parseBusinessHours('09:00-18:00'), { open: 540, close: 1080 });
  assert.equal(isStoreOpenAt('09:00-18:00', [1], taipei('2026-09-28T12:00:00')), true);
  assert.equal(isStoreOpenAt('09:00-18:00', [1], taipei('2026-09-28T18:00:00')), false);
  assert.equal(isStoreOpenAt('22:00-02:00', [1], taipei('2026-09-28T23:00:00')), true);
  assert.equal(isStoreOpenAt('22:00-02:00', [1], taipei('2026-09-29T01:59:00')), true);
  assert.equal(isStoreOpenAt('22:00-02:00', [1], taipei('2026-09-29T02:00:00')), false);
  assert.equal(isStoreOpenAt('22:00-02:00', [2], taipei('2026-09-29T01:00:00')), false);
  assert.equal(isStoreOpenAt('00:00-23:59', [1], taipei('2026-09-28T23:59:00')), true);
  assert.deepEqual(taipeiClock(taipei('2026-09-28T23:30:00')), { weekday: 1, minutes: 1410 });
});
