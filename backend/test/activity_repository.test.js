const assert = require('node:assert/strict');
const { test } = require('node:test');
const ActivityRepository = require('../src/activity/repository');

test('startup schema check requires the correct unique member request index', async () => {
  const check = require('../src/activity/check_schema');
  const indexes = [
    { Non_unique: 0, Seq_in_index: 2, Column_name: 'client_request_id' },
    { Non_unique: 0, Seq_in_index: 1, Column_name: 'user_id' },
  ];
  const pool = { query: async (sql) => [sql.startsWith('SHOW INDEX') ? indexes : []] };
  await check(pool);
  indexes[1].Column_name = 'id';
  await assert.rejects(check(pool), { code: 'ACTIVITY_SCHEMA_MISSING' });
});

function fixture({ failure, previous, closed = false, expired = false, deleted = false, stock = 10 } = {}) {
  const events = [];
  const writes = [];
  const food = { id: '1', store_id: '2', name: 'Original meal', store_name: 'Original store',
    merchant_status: 'active', store_deleted_at: deleted ? new Date() : null, status: 'active', price: 100, original_price: 120,
    stock_count: stock, is_expiring_soon: 1, eco_priority_score: '0.5',
    expires_at: expired ? new Date(0) : null, calories: 400 };
  const connection = {
    beginTransaction: async () => events.push('begin'),
    commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'),
    release: () => events.push('release'),
    execute: async (sql, args) => {
      if (sql.startsWith('SELECT id FROM users')) { assert.equal(args[0], '7'); return [[{ id: '7' }]]; }
      if (sql.startsWith('SELECT id, request_hash')) return [previous ? [previous] : []];
      if (sql.includes('FROM foods f')) { assert.match(sql, /ORDER BY f.id FOR UPDATE/); return [[food]]; }
      if (sql.startsWith('SELECT weekday')) return [closed ? [] : [{ weekday: args[1] }]];
      if (sql.startsWith('INSERT INTO purchase_orders')) { writes.push({ sql, args }); return [{ insertId: '42' }]; }
      if (sql.startsWith('INSERT INTO purchase_order_items')) {
        writes.push({ sql, args });
        if (failure) throw new Error('item insert failed');
        return [{ affectedRows: 1 }];
      }
      if (sql.startsWith('UPDATE foods')) { writes.push({ sql, args }); return [{ affectedRows: 1 }]; }
      if (sql.includes('FROM purchase_orders WHERE user_id')) {
        assert.deepEqual(args, ['7', '42']);
        return [[{ id: '42', totalPrice: 200 }]];
      }
      if (sql.includes('FROM purchase_order_items')) return [[{ foodId: '1', quantity: 2, foodSnapshot: '{"name":"Original meal"}' }]];
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };
  return { repository: new ActivityRepository({ getConnection: async () => connection }), events, writes };
}

test('checkout computes totals and immutable snapshots from locked database food rows', async () => {
  const { repository, events, writes } = fixture();
  const result = await repository.checkout('7', 'request-key', [{ foodId: '1', quantity: 2 }]);
  assert.equal(result.replayed, false);
  assert.deepEqual(writes[0].args.slice(0, 6), ['7', 2, 200, 26, 40, 'request-key']);
  assert.equal(writes[1].args[3], 100);
  const snapshot = JSON.parse(writes[1].args[6]);
  assert.equal(snapshot.name, 'Original meal');
  assert.equal(snapshot.calories, 400);
  assert.deepEqual(writes[2].args, [2, 2, '1']);
  assert.deepEqual(events, ['begin', 'commit', 'release']);
});

test('order item failure rolls back the header instead of leaving a partial order', async () => {
  const { repository, events, writes } = fixture({ failure: true });
  await assert.rejects(repository.checkout('7', 'request-key', [{ foodId: '1', quantity: 2 }]), /item insert failed/);
  assert.equal(writes.length, 2);
  assert.deepEqual(events, ['begin', 'rollback', 'release']);
});

for (const [name, options] of [['deleted store', { deleted: true }], ['closed store', { closed: true }], ['expired food', { expired: true }],
  ['insufficient stock', { stock: 1 }]]) {
  test(`checkout rejects ${name} before inserting an order`, async () => {
    const { repository, events, writes } = fixture(options);
    await assert.rejects(repository.checkout('7', 'request-key', [{ foodId: '1', quantity: 2 }]), { statusCode: 409 });
    assert.equal(writes.length, 0);
    assert.deepEqual(events, ['begin', 'rollback', 'release']);
  });
}

test('same request key with a different payload is rejected without writes', async () => {
  const { repository, writes } = fixture({ previous: { id: '42', request_hash: 'different' } });
  await assert.rejects(repository.checkout('7', 'request-key', [{ foodId: '1', quantity: 2 }]), { statusCode: 409 });
  assert.equal(writes.length, 0);
});

test('same request key and payload returns the existing order without a second stock update', async () => {
  const { createHash } = require('node:crypto');
  const items = [{ foodId: '1', quantity: 2 }];
  const request_hash = createHash('sha256').update(JSON.stringify(items)).digest('hex');
  const { repository, writes } = fixture({ previous: { id: '42', request_hash } });
  const result = await repository.checkout('7', 'request-key', items);
  assert.equal(result.replayed, true);
  assert.equal(result.order.id, '42');
  assert.equal(writes.length, 0);
});
