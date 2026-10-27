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

function statusFixture(row = { id: 7, status: 'active' }) {
  const events = [];
  const connection = {
    beginTransaction: async () => events.push('begin'),
    commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'),
    release: () => events.push('release'),
    execute: async (sql, args) => {
      events.push({ sql, args });
      if (sql.startsWith('SELECT id, status')) return [row ? [row] : []];
      return [{ affectedRows: 1 }];
    },
  };
  return { repository: new AdminRepository({ getConnection: async () => connection }), events };
}

test('merchant pause updates status and revokes every existing session atomically', async () => {
  const { repository, events } = statusFixture();
  assert.equal(await repository.setMerchantStatus('7', 'paused'), true);
  assert.ok(events.some((event) => event.sql?.startsWith('UPDATE merchants') && event.args[0] === 'paused'));
  assert.ok(events.some((event) => event.sql?.startsWith('DELETE FROM merchant_sessions')));
  assert.deepEqual(events.slice(-2), ['commit', 'release']);
});

test('unchanged active merchant succeeds without revoking sessions', async () => {
  const { repository, events } = statusFixture({ id: 7, status: 'active' });
  assert.equal(await repository.setMerchantStatus('7', 'active'), true);
  assert.equal(events.some((event) => event.sql?.startsWith('UPDATE merchants')), false);
  assert.equal(events.some((event) => event.sql?.startsWith('DELETE FROM merchant_sessions')), false);
});

test('missing merchant rolls back without attempting an update', async () => {
  const { repository, events } = statusFixture(null);
  assert.equal(await repository.setMerchantStatus('999', 'paused'), false);
  assert.deepEqual(events.slice(-2), ['rollback', 'release']);
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
