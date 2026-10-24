const assert = require('node:assert/strict');
const test = require('node:test');
const AdminRepository = require('../src/admin/repository');

test('admin report periods map to fixed server-side SQL expressions', () => {
  const repository = new AdminRepository({});
  assert.equal(repository.periodStart('day'), 'CURRENT_DATE');
  assert.match(repository.periodStart('week'), /WEEKDAY/);
  assert.match(repository.periodStart('month'), /%Y-%m-01/);
  assert.equal(repository.periodStart('untrusted input'), 'CURRENT_DATE');
});

test('merchant status treats an unchanged existing merchant as success', async () => {
  const calls = [];
  const repository = new AdminRepository({
    execute: async (sql, args) => {
      calls.push({ sql, args });
      if (sql.startsWith('UPDATE merchants')) return [{ affectedRows: 0 }];
      return [[{ id: 7 }]];
    },
  });
  assert.equal(await repository.setMerchantStatus('7', 'active'), true);
  assert.equal(calls.length, 2);
  assert.deepEqual(calls[0].args, ['active', '7']);
});

test('merchant status reports a genuinely missing merchant', async () => {
  const repository = new AdminRepository({
    execute: async (sql) => sql.startsWith('UPDATE merchants') ? [{ affectedRows: 0 }] : [[]],
  });
  assert.equal(await repository.setMerchantStatus('999', 'suspended'), false);
});

test('MySQL integration: admin dashboard, food and order reports execute', {
  skip: process.env.MYSQL_INTEGRATION !== '1',
}, async () => {
  const pool = require('../src/config/database').createDatabasePool();
  const repository = new AdminRepository(pool);
  try {
    const dashboard = await repository.dashboard('day');
    assert.equal(dashboard.period, 'day');
    assert.ok(dashboard.users && dashboard.orders && Array.isArray(dashboard.topFoods));
    const filters = { page: 1, pageSize: 25, search: '', from: '2026-01-01', to: '2026-12-31' };
    assert.ok(Array.isArray((await repository.foods(filters)).items));
    assert.ok(Array.isArray((await repository.orders(filters)).items));
  } finally {
    await pool.end();
  }
});
