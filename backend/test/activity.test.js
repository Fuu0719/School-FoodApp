const assert = require('node:assert/strict');
const { test } = require('node:test');
const { randomBytes, randomUUID } = require('node:crypto');
const express = require('express');
const authRoutes = require('../src/auth/routes');
const ActivityRepository = require('../src/activity/repository');
const { tokenHash } = require('../src/auth/passwords');

async function serve(t, app) {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return async (path, method = 'GET', body, token, key) => {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api${path}`, {
      method, headers: { 'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}), ...(key ? { 'Idempotency-Key': key } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  };
}

test('activity endpoints authenticate every read and write and bind the session owner', async (t) => {
  const a = 'a'.repeat(64);
  const b = 'b'.repeat(64);
  const calls = [];
  const repository = {};
  for (const name of ['favorites', 'favorite', 'history', 'view', 'clearHistory', 'orders', 'order', 'checkout']) {
    repository[name] = async (...args) => {
      calls.push({ name, args });
      return name === 'checkout' ? { replayed: false, order: { id: '1' } } : [];
    };
  }
  const users = { session: async (hash) => hash === tokenHash(a) ? { id: '11' }
    : hash === tokenHash(b) ? { id: '22' } : null };
  const app = express().use(express.json()).use('/api', authRoutes(users, repository));
  app.use((error, req, res, next) => res.status(error.statusCode || 500).json({ message: error.message }));
  const call = await serve(t, app);
  const endpoints = [['/me/favorites', 'GET'], ['/me/favorites/1', 'PUT'], ['/me/favorites/1', 'DELETE'],
    ['/me/history', 'GET'], ['/me/history', 'POST'], ['/me/history', 'DELETE'],
    ['/me/orders', 'GET'], ['/me/orders/1', 'GET'], ['/me/orders', 'POST']];
  for (const [url, method] of endpoints) assert.equal((await call(url, method)).status, 401);
  assert.equal((await call('/me/orders', 'GET', undefined, 'c'.repeat(64))).status, 401);
  assert.equal(calls.length, 0);
  await call('/me/favorites/1', 'PUT', { userId: '22' }, a);
  await call('/me/history', 'POST', { userId: '11', foodId: '2' }, b);
  await call('/me/orders', 'POST', { userId: '22', totalPrice: 1, items: [{ foodId: '3', quantity: 2, price: 1 }] }, a, randomUUID());
  assert.deepEqual(calls[0], { name: 'favorite', args: ['11', '1', true] });
  assert.deepEqual(calls[1], { name: 'view', args: ['22', '2'] });
  assert.equal(calls[2].args[0], '11');
  assert.deepEqual(calls[2].args[2], [{ foodId: '3', quantity: 2 }]);
  for (const items of [[], [{ foodId: 'mock-food', quantity: 1 }], [{ foodId: '1', quantity: 0 }],
    [{ foodId: '1', quantity: 1.1 }], [{ foodId: '1', quantity: 100 }],
    [{ foodId: '1', quantity: 1 }, { foodId: '1', quantity: 2 }], Array(51).fill({ foodId: '1', quantity: 1 })]) {
    assert.equal((await call('/me/orders', 'POST', { items }, a, randomUUID())).status, 400);
  }
  assert.equal((await call('/me/orders', 'POST', { items: [{ foodId: '1', quantity: 1 }] }, a)).status, 400);
  assert.equal((await call('/me/favorites/18446744073709551616', 'PUT', {}, a)).status, 400);
  assert.equal((await call('/me/orders?before=invalid', 'GET', undefined, a)).status, 400);
  assert.equal(calls.length, 3);
});

test('activity transaction rolls back and releases its connection on any write failure', async () => {
  const events = [];
  const connection = {
    beginTransaction: async () => events.push('begin'),
    commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'),
    release: () => events.push('release'),
    execute: async (sql, args) => {
      assert.equal(sql.includes('12345'), false);
      assert.equal(args[0], '12345');
      if (sql.startsWith('SELECT id FROM users')) return [[{ id: '12345' }]];
      throw new Error('simulated failure');
    },
  };
  await assert.rejects(new ActivityRepository({ getConnection: async () => connection }).favorite('12345', '1', false), /simulated failure/);
  assert.deepEqual(events, ['begin', 'rollback', 'release']);
});

test('MySQL integration: member activity isolation, persistence, snapshots and concurrent checkout', {
  skip: process.env.MYSQL_INTEGRATION !== '1',
}, async (t) => {
  require('dotenv').config();
  const pool = require('../src/config/database').createDatabasePool();
  const userIds = [];
  let merchantId;
  let storeId;
  t.after(async () => {
    try {
      for (const id of userIds) await pool.execute('DELETE FROM users WHERE id = ?', [id]);
      if (storeId) await pool.execute('DELETE FROM stores WHERE id = ?', [storeId]);
      if (merchantId) await pool.execute('DELETE FROM merchants WHERE id = ?', [merchantId]);
    } finally { await pool.end(); }
  });
  await require('../src/activity/check_schema')(pool);
  const UserRepository = require('../src/auth/user_repository');
  const users = new UserRepository(pool);
  const tokens = [];
  for (let i = 0; i < 2; i++) {
    const user = await users.create({ name: 'Activity integration fixture', email: `activity-${randomUUID()}@example.com`, passwordHash: 'disabled-test-login' });
    userIds.push(user.id);
    const token = randomBytes(32).toString('hex');
    await users.createSession(user.id, tokenHash(token), new Date(Date.now() + 600000));
    tokens.push(token);
  }
  const [merchant] = await pool.execute(`INSERT INTO merchants (business_name, email, password_hash, status)
    VALUES ('Activity test fixture', ?, 'disabled-test-login', 'active')`, [`activity-${randomUUID()}@example.com`]);
  merchantId = merchant.insertId;
  const [store] = await pool.execute(`INSERT INTO stores (merchant_id, name, address, business_hours)
    VALUES (?, 'Test store', 'Integration fixture only', '00:00-24:00')`, [merchantId]);
  storeId = store.insertId;
  for (let day = 1; day <= 7; day++) await pool.execute('INSERT INTO store_business_weekdays VALUES (?, ?)', [storeId, day]);
  const foods = [];
  for (let i = 0; i < 2; i++) {
    const [food] = await pool.execute(`INSERT INTO foods (store_id, name, category, price, original_price,
      stock_count, status, calories) VALUES (?, 'Test meal', 'meal', 100, 120, 10, 'active', 400)`, [storeId]);
    foods.push(String(food.insertId));
  }
  const createApp = require('../src/app');
  const call = await serve(t, createApp({ userRepository: users }));
  const [a, b] = tokens;
  const catalog = await call(`/foods?storeId=${storeId}`);
  assert.equal(catalog.status, 200);
  assert.deepEqual(catalog.body.items.map((food) => food.id), foods);
  assert.equal(catalog.body.items[0].calories, 400);
  assert.equal(catalog.body.items[0].businessWeekdays.length, 7);
  assert.equal(catalog.body.items[0].distanceMeters, null);
  assert.equal((await call(`/foods/${foods[0]}`)).body.storeId, String(storeId));
  assert.equal((await call(`/stores/${storeId}`)).body.id, String(storeId));
  await pool.execute("UPDATE foods SET status = 'draft' WHERE id = ?", [foods[0]]);
  assert.equal((await call(`/foods/${foods[0]}`)).status, 404);
  assert.equal((await call(`/foods?storeId=${storeId}`)).body.items.length, 1);
  await pool.execute("UPDATE foods SET status = 'active', expires_at = '2000-01-01 00:00:00' WHERE id = ?", [foods[0]]);
  assert.equal((await call(`/foods/${foods[0]}`)).status, 404);
  await pool.execute('UPDATE foods SET expires_at = NULL WHERE id = ?', [foods[0]]);
  await pool.execute("UPDATE merchants SET status = 'paused' WHERE id = ?", [merchantId]);
  assert.equal((await call(`/foods?storeId=${storeId}`)).body.items.length, 0);
  assert.equal((await call(`/stores/${storeId}`)).status, 404);
  await pool.execute("UPDATE merchants SET status = 'active' WHERE id = ?", [merchantId]);
  assert.equal((await call(`/me/favorites/${foods[0]}`, 'PUT', { userId: userIds[1] }, a)).status, 200);
  await call(`/me/favorites/${foods[0]}`, 'PUT', {}, a);
  assert.equal((await call('/me/favorites', 'GET', undefined, a)).body.items.length, 1);
  assert.equal((await call('/me/favorites', 'GET', undefined, b)).body.items.length, 0);
  for (let i = 0; i < 2; i++) await call('/me/history', 'POST', { foodId: foods[0] }, a);
  assert.equal((await call('/me/history', 'GET', undefined, a)).body.items.length, 1);
  assert.equal((await call('/me/history', 'GET', undefined, b)).body.items.length, 0);
  const key = randomUUID();
  const body = { items: [{ foodId: foods[0], quantity: 2 }], totalPrice: 1, userId: userIds[1] };
  const parallel = await Promise.all([call('/me/orders', 'POST', body, a, key), call('/me/orders', 'POST', body, a, key)]);
  assert.deepEqual(parallel.map((r) => r.status).sort(), [200, 201]);
  const order = parallel[0].body.order;
  assert.equal(order.totalPrice, 200);
  assert.equal(order.paymentStatus, 'pending');
  assert.equal(parallel[1].body.order.id, order.id);
  let [stock] = await pool.execute('SELECT stock_count FROM foods WHERE id = ?', [foods[0]]);
  assert.equal(stock[0].stock_count, 8);
  assert.equal((await call(`/me/orders/${order.id}`, 'GET', undefined, b)).status, 404);
  assert.equal((await call('/me/orders', 'GET', undefined, b)).body.items.length, 0);
  assert.equal((await call('/me/orders', 'POST', { items: [{ foodId: foods[0], quantity: 1 }] }, a, key)).status, 409);
  await pool.execute("UPDATE foods SET name = 'Changed', price = 999 WHERE id = ?", [foods[0]]);
  const restarted = await serve(t, createApp({ userRepository: new UserRepository(pool) }));
  const stored = (await restarted(`/me/orders/${order.id}`, 'GET', undefined, a)).body;
  assert.equal(stored.items[0].foodSnapshot.name, 'Test meal');
  assert.equal(stored.items[0].unitPrice, 100);
  assert.equal(stored.items[0].originalUnitPrice, 120);
  assert.equal((await restarted('/me/favorites', 'GET', undefined, a)).body.items.length, 1);
  assert.equal((await restarted('/me/history', 'GET', undefined, a)).body.items.length, 1);
  assert.equal((await call('/me/orders', 'POST', { items: [{ foodId: foods[0], quantity: 1 },
    { foodId: foods[1], quantity: 99 }] }, a, randomUUID())).status, 409);
  [stock] = await pool.execute('SELECT stock_count FROM foods WHERE id = ?', [foods[0]]);
  assert.equal(stock[0].stock_count, 8);
  await pool.execute('UPDATE foods SET stock_count = 1 WHERE id = ?', [foods[1]]);
  const competition = await Promise.all(tokens.map((token) => call('/me/orders', 'POST',
    { items: [{ foodId: foods[1], quantity: 1 }] }, token, randomUUID())));
  assert.deepEqual(competition.map((r) => r.status).sort(), [201, 409]);
  [stock] = await pool.execute('SELECT stock_count, status FROM foods WHERE id = ?', [foods[1]]);
  assert.equal(stock[0].stock_count, 0);
  assert.equal(stock[0].status, 'sold_out');
  await call('/me/history', 'DELETE', {}, b);
  assert.equal((await call('/me/history', 'GET', undefined, a)).body.items.length, 1);
  await call('/me/history', 'DELETE', {}, a);
  assert.equal((await call('/me/history', 'GET', undefined, a)).body.items.length, 0);
  await call(`/me/favorites/${foods[0]}`, 'DELETE', {}, a);
  assert.equal((await call('/me/favorites', 'GET', undefined, a)).body.items.length, 0);
});
