const assert = require('node:assert/strict');
const { test } = require('node:test');
const { randomUUID, randomBytes } = require('node:crypto');
const express = require('express');
const routes = require('../src/merchant/routes');
const MerchantRepository = require('../src/merchant/repository');
const { product, registration, storeInput } = require('../src/merchant/validation');
const { hashPassword, tokenHash } = require('../src/auth/passwords');

const fixture = (storeId = '10') => ({ storeId, name: '測試餐點', category: '便當', price: 80, originalPrice: 100,
  stockCount: 3, imageUrl: '', calories: 400, weightGrams: 300, proteinGrams: 20, fatGrams: 10, carbsGrams: 60,
  expiresAt: new Date(Date.now() + 86400000).toISOString(), isExpiringSoon: true, tags: ['高蛋白'], ingredients: ['米'] });
async function serve(t, app) {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return async (path, method = 'GET', body, token, key) => {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api${path}`, {
      method, headers: { 'content-type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(key ? { 'Idempotency-Key': key } : {}) }, body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  };
}
function app(repository) {
  const server = express().use(express.json()).use('/api/merchant', routes(repository));
  server.use((error, req, res, next) => res.status(error.statusCode || 500).json({ message: error.statusCode ? error.message : 'server error' }));
  return server;
}

const signup = (email = 'owner@example.test') => ({ email, password: 'Merchant-test-password!',
  businessName: '自行註冊商家', storeName: '第一間門市', address: '測試地址', businessHours: '09:00-20:00',
  contactPhone: '', businessWeekdays: [1, 2, 3, 4, 5] });

test('account-only registration and authenticated 24-hour store creation', async (t) => {
  const data = { email: 'owner@example.test', password: 'Merchant-test-password!', businessName: 'owner' };
  assert.equal(registration(data).storeName, undefined);
  const input = { storeName: 'branch', address: 'address', opensAt: '22:00', closesAt: '02:30', businessWeekdays: [2, 1, 2] };
  assert.equal(storeInput(input).businessHours, '22:00-02:30');
  assert.deepEqual(storeInput(input).businessWeekdays, [1, 2]);
  for (const change of [{ opensAt: '24:00' }, { closesAt: '12:60' }, { closesAt: '22:00' }, { businessWeekdays: [] }]) {
    assert.throws(() => storeInput({ ...input, ...change }), { statusCode: 400 });
  }
  const token = 'a'.repeat(64);
  const call = await serve(t, app({
    session: async (hash) => hash === tokenHash(token) ? { id: '7' } : null,
    createStore: async (id, data) => {
      assert.equal(id, '7'); assert.equal(data.merchantId, undefined);
      return { id, stores: [{ id: '8', ...data }] };
    },
  }));
  assert.equal((await call('/merchant/stores', 'POST', input)).status, 401);
  assert.equal((await call('/merchant/stores', 'POST', { ...input, merchantId: '999' }, token)).status, 201);
});

test('merchant self-registration validates fields and cannot assign existing stores or elevated roles', async (t) => {
  let saved;
  let hash;
  const sessions = new Map();
  const repo = {
    register: async (data, passwordHash) => {
      if (saved) throw Object.assign(new Error('duplicate'), { code: 'ER_DUP_ENTRY' });
      saved = data; hash = passwordHash;
    },
    credentials: async () => ({ id: '1', password_hash: hash, status: 'active' }),
    account: async () => ({ id: '1', businessName: saved.businessName, email: saved.email, stores: [{ id: 'new-store' }] }),
    createSession: async (id, hash) => sessions.set(hash, { id }),
    session: async (hash) => sessions.get(hash),
  };
  const call = await serve(t, app(repo));
  const response = await call('/merchant/auth/register', 'POST', { ...signup('OWNER@example.test'), status: 'pending', role: 'admin', merchantId: '99', storeId: '999' });
  assert.equal(response.status, 201);
  assert.equal(response.body.token, undefined);
  assert.equal(saved.email, 'owner@example.test');
  for (const key of ['role', 'status', 'storeId', 'merchantId']) assert.equal(saved[key], undefined);
  assert.notEqual(hash, saved.password);
  const login = await call('/merchant/auth/login', 'POST', signup());
  assert.equal(login.status, 200);
  assert.equal((await call('/merchant/me', 'GET', undefined, login.body.token)).status, 200);
  assert.equal((await call('/merchant/auth/register', 'POST', signup())).status, 409);
  for (const change of [{ businessWeekdays: [] }, { businessWeekdays: [0] }, { businessWeekdays: [1.5] },
    { businessWeekdays: Array(8).fill(1) }, { businessName: '' }, { storeName: '' }, { address: '' },
    { businessHours: '' }, { email: 'invalid' }, { password: 'short' }]) {
    assert.equal((await call('/merchant/auth/register', 'POST', { ...signup(), ...change })).status, 400);
  }
  assert.deepEqual(registration({ ...signup(), businessWeekdays: [2, 1, 2] }).businessWeekdays, [1, 2]);
});

test('registration rate limit rejects repeated requests before hashing', async (t) => {
  const call = await serve(t, app({}));
  for (let i = 0; i < 30; i++) assert.equal((await call('/merchant/auth/register', 'POST', {})).status, 400);
  assert.equal((await call('/merchant/auth/register', 'POST', {})).status, 429);
});

test('store deletion requires merchant identity and validates the store ID', async (t) => {
  const token = 'a'.repeat(64);
  const calls = [];
  const call = await serve(t, app({
    session: async (hash) => hash === tokenHash(token) ? { id: '7' } : null,
    deleteStore: async (...args) => { calls.push(args); return { id: '7', stores: [] }; },
  }));
  assert.equal((await call('/merchant/stores/8', 'DELETE')).status, 401);
  assert.equal((await call('/merchant/stores/invalid', 'DELETE', {}, token)).status, 400);
  assert.equal((await call('/merchant/stores/8', 'DELETE', { merchantId: '999' }, token)).status, 200);
  assert.deepEqual(calls, [['7', '8']]);
});

test('category options are authenticated and scoped to the session owner across all products', async (t) => {
  const token = 'a'.repeat(64);
  const call = await serve(t, app({
    session: async (hash) => hash === tokenHash(token) ? { id: '7' } : null,
    categories: async (id) => { assert.equal(id, '7'); return { items: ['熱湯'] }; },
  }));
  assert.equal((await call('/merchant/categories')).status, 401);
  assert.deepEqual((await call('/merchant/categories?merchantId=999', 'GET', undefined, token)).body, { items: ['熱湯'] });
  const repo = new MerchantRepository({ execute: async (sql, args) => {
    assert.deepEqual(args, ['7']);
    assert.match(sql, /SELECT DISTINCT f.category/);
    assert.match(sql, /s.merchant_id = \? AND s.deleted_at IS NULL/);
    assert.doesNotMatch(sql, /LIMIT/);
    return [[{ category: '熱湯' }]];
  } });
  assert.deepEqual(await repo.categories('7'), { items: ['熱湯'] });
});

test('store deletion is atomic, owner scoped, repeatable and preserves order rows', async () => {
  for (const mode of ['ok', 'missing', 'deleted', 'failure']) {
    const events = [];
    const connection = {
      beginTransaction: async () => events.push('begin'), commit: async () => events.push('commit'),
      rollback: async () => events.push('rollback'), release: () => events.push('release'),
      execute: async (sql, args) => {
        if (sql.startsWith('SELECT status FROM merchants')) return [[{ status: 'active' }]];
        if (sql.startsWith('SELECT id, deleted_at FROM stores')) {
          assert.deepEqual(args, ['7', '8']); assert.match(sql, /FOR UPDATE$/);
          return [mode === 'missing' ? [] : [{ id: '8', deleted_at: mode === 'deleted' ? new Date() : null }]];
        }
        if (sql.startsWith('UPDATE foods')) {
          assert.deepEqual(args, ['8']); assert.match(sql, /WHERE store_id = \?$/);
          events.push('pause products'); return [{}];
        }
        if (sql.startsWith('UPDATE stores')) {
          assert.deepEqual(args, ['8']);
          if (mode === 'failure') throw new Error('store write failed');
          events.push('delete store'); return [{}];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    };
    const repo = new MerchantRepository({ getConnection: async () => connection });
    repo.account = async (id, db) => { assert.equal(id, '7'); assert.equal(db, connection); return { id, stores: [] }; };
    if (mode === 'missing' || mode === 'failure') {
      await assert.rejects(repo.deleteStore('7', '8'), mode === 'missing' ? { statusCode: 404 } : /store write failed/);
      assert.deepEqual(events.slice(-2), ['rollback', 'release']);
      if (mode === 'missing') assert.equal(events.includes('pause products'), false);
    } else {
      assert.deepEqual(await repo.deleteStore('7', '8'), { id: '7', stores: [] });
      assert.deepEqual(events, mode === 'deleted' ? ['begin', 'commit', 'release'] :
        ['begin', 'pause products', 'delete store', 'commit', 'release']);
    }
  }
});

test('registration creates active merchant and a new owned store atomically', async () => {
  for (const failDay of [false, true]) {
    const events = [];
    const connection = {
      beginTransaction: async () => events.push('begin'), commit: async () => events.push('commit'),
      rollback: async () => events.push('rollback'), release: () => events.push('release'),
      execute: async (sql, args) => {
        if (sql.includes('INSERT INTO merchants')) {
          assert.match(sql, /'active'/); assert.equal(args[2], 'encoded-hash'); events.push('merchant'); return [{ insertId: 12 }];
        }
        if (sql.includes('INSERT INTO stores')) {
          assert.equal(args[0], 12); events.push('store'); return [{ insertId: 34 }];
        }
        assert.equal(args[0], 34);
        if (failDay) throw new Error('day write failed');
        return [{}];
      },
    };
    const repo = new MerchantRepository({ getConnection: async () => connection });
    if (failDay) {
      await assert.rejects(repo.register(registration(signup()), 'encoded-hash'), /day write failed/);
      assert.deepEqual(events, ['begin', 'merchant', 'store', 'rollback', 'release']);
    } else {
      assert.deepEqual(await repo.register(registration(signup()), 'encoded-hash'), { merchantId: '12', storeId: '34', status: 'active' });
      assert.deepEqual(events, ['begin', 'merchant', 'store', 'commit', 'release']);
    }
  }
});

test('merchant product validation rejects forged values, malformed dates and unsafe image schemes', () => {
  const valid = fixture();
  assert.equal(product({ ...valid, merchantId: 'other', ecoPriorityScore: 1, status: 'active' }).status, undefined);
  assert.equal(product({ ...valid, category: '  自訂湯品  ' }).category, '自訂湯品');
  for (const category of ['', '  ', 'x'.repeat(41), 'a\nb', 'a\u0000b']) {
    assert.throws(() => product({ ...valid, category }), { statusCode: 400 });
  }
  for (const change of [{ storeId: '18446744073709551616' }, { price: -1 }, { stockCount: 1.2 },
    { originalPrice: 1 }, { isExpiringSoon: true, expiresAt: null }, { expiresAt: '2026-02-30T12:00:00.000Z' },
    { expiresAt: '2026-09-10 12:00' }, { imageUrl: 'javascript:alert(1)' }, { imageUrl: 'http://example.test/a.jpg' },
    { imageUrl: 'https://user:secret@example.test/a.jpg' }, { tags: ['x'.repeat(41)] }, { name: '' }, { proteinGrams: -1 }]) {
    assert.throws(() => product({ ...valid, ...change }), { statusCode: 400 });
  }
});

test('merchant sessions are independent, revocable and never expose hashes', async (t) => {
  const hash = await hashPassword('Merchant-test-password!');
  const sessions = new Map();
  let active = true;
  const repository = {
    credentials: async (email) => email === 'owner@example.test' ? { id: '1', password_hash: hash, status: active ? 'active' : 'paused' } : null,
    account: async () => ({ id: '1', businessName: '店家', email: 'owner@example.test', stores: [] }),
    createSession: async (id, hash, expiresAt) => sessions.set(hash, { id, expiresAt }),
    session: async (hash) => active && sessions.has(hash) ? { id: '1' } : null,
    revoke: async (hash) => sessions.delete(hash),
  };
  const call = await serve(t, app(repository));
  assert.equal((await call('/merchant/me', 'GET', undefined, 'member-demo-token')).status, 401);
  const body = { email: 'owner@example.test', password: 'Merchant-test-password!' };
  assert.equal((await call('/merchant/auth/login', 'POST', { ...body, password: 'incorrect-password' })).status, 401);
  const login = await call('/merchant/auth/login', 'POST', body);
  assert.equal(login.status, 200);
  assert.equal(JSON.stringify(login.body).includes('password'), false);
  assert.equal(sessions.has(login.body.token), false);
  assert.equal(sessions.has(tokenHash(login.body.token)), true);
  assert.equal((await call('/merchant/me', 'GET', undefined, login.body.token)).status, 200);
  await call('/merchant/auth/logout', 'POST', {}, login.body.token);
  assert.equal((await call('/merchant/me', 'GET', undefined, login.body.token)).status, 401);
  active = false;
  assert.equal((await call('/merchant/auth/login', 'POST', body)).status, 401);
});

test('merchant write routes require merchant session and ignore client identity and publication fields', async (t) => {
  const token = 'a'.repeat(64);
  const calls = [];
  const repo = { session: async (hash) => hash === tokenHash(token) ? { id: '9' } : null };
  for (const method of ['create', 'update', 'status', 'get', 'list']) {
    repo[method] = async (...args) => { calls.push({ method, args }); return { replayed: false, product: { id: '1' } }; };
  }
  const call = await serve(t, app(repo));
  for (const [path, method] of [['/products', 'GET'], ['/products', 'POST'], ['/products/1', 'GET'],
    ['/products/1', 'PUT'], ['/products/1/status', 'PUT']]) {
    assert.equal((await call(`/merchant${path}`, method, method === 'GET' ? undefined : {})).status, 401);
  }
  assert.equal(calls.length, 0);
  const data = fixture();
  assert.equal((await call('/merchant/products', 'POST', { ...data, merchantId: '2', status: 'active' }, token, randomUUID())).status, 201);
  assert.equal(calls[0].args[0], '9');
  assert.equal(calls[0].args[2].status, undefined);
  assert.equal((await call('/merchant/products/1/status', 'PUT', { status: 'active', revision: 0, merchantId: '2' }, token)).status, 200);
  assert.deepEqual(calls[1].args, ['9', '1', 0, 'active']);
  assert.equal((await call('/merchant/products/1/status', 'PUT', { status: 'sold_out', revision: 0 }, token)).status, 400);
  assert.equal((await call('/merchant/products', 'POST', data, token)).status, 400);
});

test('merchant transaction rolls back all writes and releases connection', async () => {
  const events = [];
  const connection = {
    beginTransaction: async () => events.push('begin'), commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'), release: () => events.push('release'),
    execute: async () => [[{ status: 'active' }]],
  };
  const repository = new MerchantRepository({ getConnection: async () => connection });
  await assert.rejects(repository.transaction('1', async () => { throw new Error('failed tags'); }), /failed tags/);
  assert.deepEqual(events, ['begin', 'rollback', 'release']);
});

test('merchant updates lock owned products and reject stale revision, active edits and invalid publication', async () => {
  const repository = new MerchantRepository({});
  let current = { storeId: '10', revision: 1, status: 'draft', stockCount: 0, expiresAt: null };
  repository.transaction = async (_, fn) => fn({ execute: async () => { throw new Error('Unexpected write'); } });
  repository.get = async (merchantId, foodId, connection, lock) => { assert.equal(lock, true); return current; };
  await assert.rejects(repository.update('1', '2', 0, fixture()), { statusCode: 409 });
  current = { ...current, status: 'active' };
  await assert.rejects(repository.update('1', '2', 1, fixture()), { statusCode: 409 });
  await assert.rejects(repository.status('1', '2', 1, 'active'), { statusCode: 409 });
  current = { ...current, stockCount: 1, expiresAt: '2000-01-01T00:00:00Z' };
  await assert.rejects(repository.status('1', '2', 1, 'active'), { statusCode: 409 });
});

test('draft relation failure rolls back product and request mapping; ownership is checked before inserts', async () => {
  for (const ownsStore of [true, false]) {
    const events = [];
    const connection = {
      beginTransaction: async () => events.push('begin'), commit: async () => events.push('commit'),
      rollback: async () => events.push('rollback'), release: () => events.push('release'),
      execute: async (sql, args) => {
        if (sql.startsWith('SELECT status FROM merchants')) return [[{ status: 'active' }]];
        if (sql.startsWith('SELECT id FROM stores')) {
          assert.deepEqual(args, ['1', '10']);
          return [ownsStore ? [{ id: '10' }] : []];
        }
        if (sql.includes('SELECT food_id, request_hash')) return [[]];
        if (sql.startsWith('INSERT INTO foods')) { events.push('insert product'); return [{ insertId: 7 }]; }
        if (sql.startsWith('DELETE FROM')) return [{}];
        if (sql.startsWith('INSERT INTO food_tags')) throw new Error('tag insert failed');
        throw new Error('unexpected SQL');
      },
    };
    const repository = new MerchantRepository({ getConnection: async () => connection });
    await assert.rejects(repository.create('1', randomUUID(), product(fixture())), ownsStore ? /tag insert failed/ : { statusCode: 404 });
    assert.deepEqual(events, ownsStore ? ['begin', 'insert product', 'rollback', 'release'] : ['begin', 'rollback', 'release']);
  }
});

test('MySQL integration: merchant ownership, draft replay, publication, edit conflicts and independent tokens', {
  skip: process.env.MYSQL_INTEGRATION !== '1',
}, async (t) => {
  require('dotenv').config();
  const pool = require('../src/config/database').createDatabasePool();
  const merchants = [];
  let userId;
  t.after(async () => {
    try {
      if (userId) await pool.execute('DELETE FROM users WHERE id = ?', [userId]);
      for (const id of merchants) await pool.execute('DELETE FROM merchants WHERE id = ?', [id]);
    } finally { await pool.end(); }
  });
  await require('../src/merchant/check_schema')(pool);
  const repo = new MerchantRepository(pool);
  const tokens = [];
  const stores = [];
  for (let index = 0; index < 2; index++) {
    const [merchant] = await pool.execute(`INSERT INTO merchants (business_name, email, password_hash, status)
      VALUES ('Merchant integration fixture', ?, 'disabled-test-login', 'active')`, [`merchant-${randomUUID()}@example.test`]);
    merchants.push(merchant.insertId);
    const [store] = await pool.execute(`INSERT INTO stores (merchant_id, name, address, business_hours)
      VALUES (?, 'Test store', 'Fixture only', '00:00-24:00')`, [merchant.insertId]);
    stores.push(String(store.insertId));
    for (let day = 1; day <= 7; day++) await pool.execute('INSERT INTO store_business_weekdays VALUES (?, ?)', [store.insertId, day]);
    const token = randomBytes(32).toString('hex');
    tokens.push(token);
    await repo.createSession(merchant.insertId, tokenHash(token), new Date(Date.now() + 600000));
  }
  const UserRepository = require('../src/auth/user_repository');
  const users = new UserRepository(pool);
  const userEmail = `member-${randomUUID()}@example.test`;
  userId = (await users.create({ name: 'Merchant test member', email: userEmail, passwordHash: 'disabled-test-login' })).id;
  assert.equal((await users.get(userId)).heightCm, null);
  assert.equal((await users.get(userId)).weightKg, null);
  const memberToken = randomBytes(32).toString('hex');
  await users.createSession(userId, tokenHash(memberToken), new Date(Date.now() + 600000));
  const createApp = require('../src/app');
  const call = await serve(t, createApp({ userRepository: users }));
  const { storeName, address, businessHours, businessWeekdays, ...accountOnly } = signup(userEmail);
  const registered = await call('/merchant/auth/register', 'POST', accountOnly);
  const record = await repo.credentials(userEmail);
  if (record) merchants.push(record.id);
  assert.equal(registered.status, 201);
  assert.equal(record.status, 'active');
  assert.notEqual(record.password_hash, signup().password);
  const login = await call('/merchant/auth/login', 'POST', signup(userEmail));
  assert.equal(login.status, 200);
  assert.equal(login.body.merchant.stores.length, 0);
  const storeData = { storeName, address, businessWeekdays, opensAt: '09:00', closesAt: '20:00', merchantId: '999' };
  assert.equal((await call('/merchant/stores', 'POST', storeData, memberToken)).status, 401);
  const createdStore = await call('/merchant/stores', 'POST', storeData, login.body.token);
  assert.equal(createdStore.status, 201);
  const firstStore = createdStore.body.stores[0].id;
  assert.equal((await call('/merchant/stores', 'POST', storeData, login.body.token)).status, 409);
  assert.equal((await call('/merchant/stores', 'POST', { ...storeData, storeName: 'Second branch' }, login.body.token)).body.stores.length, 2);
  const [days] = await pool.execute('SELECT weekday FROM store_business_weekdays WHERE store_id = ? ORDER BY weekday', [firstStore]);
  assert.deepEqual(days.map((d) => d.weekday), [1, 2, 3, 4, 5]);
  assert.equal((await call('/merchant/auth/register', 'POST', signup(userEmail))).status, 409);
  assert.equal((await call('/me', 'GET', undefined, login.body.token)).status, 401);
  assert.equal((await call('/merchant/products', 'POST', fixture(firstStore), login.body.token, randomUUID())).status, 201);
  assert.equal((await call('/merchant/me', 'GET', undefined, memberToken)).status, 401);
  assert.equal((await call('/me', 'GET', undefined, tokens[0])).status, 401);
  const data = fixture(stores[0]);
  const key = randomUUID();
  assert.equal((await call('/merchant/products', 'POST', data, tokens[1], key)).status, 404);
  const concurrent = await Promise.all([call('/merchant/products', 'POST', data, tokens[0], key), call('/merchant/products', 'POST', data, tokens[0], key)]);
  assert.deepEqual(concurrent.map((r) => r.status).sort(), [200, 201]);
  const draft = concurrent[0].body.product;
  assert.equal(draft.status, 'draft');
  assert.equal(concurrent[1].body.product.id, draft.id);
  assert.equal((await call(`/foods/${draft.id}`)).status, 404);
  assert.equal((await call(`/merchant/products/${draft.id}`, 'GET', undefined, tokens[1])).status, 404);
  assert.equal((await call(`/merchant/products/${draft.id}/status`, 'PUT', { revision: 0, status: 'active' }, tokens[1])).status, 404);
  assert.equal((await call('/merchant/products', 'POST', { ...data, price: 79 }, tokens[0], key)).status, 409);
  let changed = await call(`/merchant/products/${draft.id}/status`, 'PUT', { revision: 0, status: 'active' }, tokens[0]);
  assert.equal(changed.status, 200);
  assert.equal(changed.body.revision, 1);
  assert.equal((await call(`/foods/${draft.id}`)).body.price, 80);
  assert.equal((await call(`/merchant/products/${draft.id}`, 'PUT', { ...data, revision: 1 }, tokens[0])).status, 409);
  changed = await call(`/merchant/products/${draft.id}/status`, 'PUT', { revision: 1, status: 'paused' }, tokens[0]);
  assert.equal(changed.status, 200);
  assert.equal((await call(`/foods/${draft.id}`)).status, 404);
  assert.equal((await call(`/merchant/products/${draft.id}`, 'PUT', { ...data, revision: 1 }, tokens[0])).status, 409);
  changed = await call(`/merchant/products/${draft.id}`, 'PUT', { ...data, price: 70, revision: 2 }, tokens[0]);
  assert.equal(changed.status, 200);
  assert.equal(changed.body.price, 70);
  assert.equal(changed.body.status, 'draft');
  const restarted = await serve(t, createApp({ userRepository: new UserRepository(pool) }));
  assert.equal((await restarted(`/merchant/products/${draft.id}`, 'GET', undefined, tokens[0])).body.price, 70);
  const ActivityRepository = require('../src/activity/repository');
  const activity = new ActivityRepository(pool);
  const CatalogRepository = require('../src/catalog/repository');
  const catalog = new CatalogRepository(pool);
  await repo.status(merchants[0], draft.id, 3, 'active');
  await activity.favorite(userId, draft.id, true);
  await activity.view(userId, draft.id);
  const orderKey = randomUUID();
  const orderItems = [{ foodId: draft.id, quantity: 1 }];
  const purchased = await activity.checkout(userId, orderKey, orderItems);
  const extraDraft = await repo.create(merchants[0], randomUUID(), product(data));
  const custom = await repo.create(merchants[0], randomUUID(), product({ ...data, category: '自訂湯品' }));
  for (let i = 0; i < 21; i++) await repo.create(merchants[0], randomUUID(), product(data));
  const unaffected = await repo.create(merchants[1], randomUUID(), product({ ...fixture(stores[1]), category: '其他商家分類' }));
  assert.equal((await repo.list(merchants[0], '18446744073709551615')).items.some((p) => p.id === custom.product.id), false);
  const categoryResponse = await restarted('/merchant/categories', 'GET', undefined, tokens[0]);
  assert.equal(categoryResponse.status, 200);
  assert.equal(categoryResponse.body.items.includes('自訂湯品'), true);
  assert.equal(categoryResponse.body.items.includes('其他商家分類'), false);
  assert.equal((await call(`/merchant/stores/${stores[0]}`, 'DELETE', {}, memberToken)).status, 401);
  assert.equal((await call(`/merchant/stores/${stores[0]}`, 'DELETE', {}, tokens[1])).status, 404);
  const removed = await call(`/merchant/stores/${stores[0]}`, 'DELETE', {}, tokens[0]);
  assert.equal(removed.status, 200);
  assert.equal(removed.body.stores.length, 0);
  assert.deepEqual(await repo.categories(merchants[0]), { items: [] });
  assert.equal((await call(`/merchant/stores/${stores[0]}`, 'DELETE', {}, tokens[0])).status, 200);
  for (const id of [draft.id, extraDraft.product.id]) {
    await assert.rejects(repo.get(merchants[0], id), { statusCode: 404 });
    await assert.rejects(repo.status(merchants[0], id, 0, 'active'), { statusCode: 404 });
    assert.equal(await catalog.food(id), null);
  }
  assert.equal(await catalog.store(stores[0]), null);
  assert.equal((await repo.list(merchants[0], '18446744073709551615')).items.length, 0);
  assert.equal((await repo.get(merchants[1], unaffected.product.id)).id, unaffected.product.id);
  assert.equal((await repo.account(merchants[1])).stores.length, 1);
  await assert.rejects(repo.create(merchants[0], randomUUID(), product(data)), { statusCode: 404 });
  await assert.rejects(activity.checkout(userId, randomUUID(), orderItems), { statusCode: 409 });
  await assert.rejects(activity.favorite(userId, draft.id, true), { statusCode: 404 });
  assert.deepEqual(await activity.favorites(userId, '18446744073709551615'), []);
  assert.deepEqual(await activity.history(userId), []);
  assert.deepEqual(await activity.order(userId, purchased.order.id), purchased.order);
  assert.equal((await activity.checkout(userId, orderKey, orderItems)).replayed, true);
  const recreated = await repo.createStore(merchants[0], {
    storeName: 'Test store', address: 'Fixture only', businessHours: '09:00-18:00', contactPhone: '', businessWeekdays: [1],
  });
  assert.equal(recreated.stores.length, 1);
  assert.notEqual(recreated.stores[0].id, stores[0]);
  await pool.execute("UPDATE merchants SET status = 'paused' WHERE id = ?", [merchants[0]]);
  assert.equal((await restarted('/merchant/me', 'GET', undefined, tokens[0])).status, 401);
  await repo.revoke(tokenHash(tokens[1]));
  assert.equal(await repo.session(tokenHash(tokens[1])), null);
});
