const assert = require('node:assert/strict');
const { test } = require('node:test');
const { recurringTag, refreshRecurringTestFoods, startTestFoodRefresh } = require('../src/catalog/refresh_test_foods');

test('recurring test refresh only targets explicitly tagged expired active foods', async () => {
  const calls = [];
  const pool = {
    execute: async (sql, values) => {
      calls.push({ sql, values });
      return [{ affectedRows: 24 }];
    },
  };
  assert.equal(await refreshRecurringTestFoods(pool), 24);
  assert.deepEqual(calls[0].values, [recurringTag]);
  assert.match(calls[0].sql, /t\.tag = \?/);
  assert.match(calls[0].sql, /f\.status = 'active'/);
  assert.match(calls[0].sql, /f\.expires_at <= UTC_TIMESTAMP\(\)/);
});

test('automatic refresh is disabled unless explicitly enabled', async () => {
  const previous = process.env.TEST_DATA_AUTO_REFRESH;
  delete process.env.TEST_DATA_AUTO_REFRESH;
  let called = false;
  const stop = await startTestFoodRefresh({ execute: async () => { called = true; } });
  stop();
  assert.equal(called, false);
  if (previous === undefined) delete process.env.TEST_DATA_AUTO_REFRESH;
  else process.env.TEST_DATA_AUTO_REFRESH = previous;
});
