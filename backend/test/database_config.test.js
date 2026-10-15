const test = require('node:test');
const assert = require('node:assert/strict');
const { createDatabasePool } = require('../src/config/database');

test('database timestamps are parsed in the Taiwan timezone', async () => {
  const pool = createDatabasePool();
  try {
    assert.equal(pool.pool.config.connectionConfig.timezone, '+08:00');
  } finally {
    await pool.end();
  }
});
