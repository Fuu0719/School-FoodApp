const assert = require('node:assert/strict');
const { test } = require('node:test');
const express = require('express');
const CatalogRepository = require('../src/catalog/repository');
const { recommendationReason } = require('../src/catalog/repository');
const catalogRoutes = require('../src/catalog/routes');

test('catalogue query validates filters, uses cursors, and never falls back to mock IDs', async (t) => {
  const calls = [];
  const repository = {
    list: async (filters) => { calls.push(filters); return { items: [], nextCursor: null }; },
    food: async () => null, store: async () => null,
  };
  const app = express().use('/api', catalogRoutes(repository));
  app.use((error, req, res, next) => res.status(error.statusCode || 500).json({ message: error.message }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const call = (path) => fetch(`http://127.0.0.1:${server.address().port}/api${path}`);
  const result = await call('/foods?maxPrice=0&maxDistanceMeters=1000&openToday=true&tags=A,B,A&after=123');
  assert.equal(result.status, 200);
  assert.deepEqual(await result.json(), { items: [], nextCursor: null });
  assert.deepEqual(calls[0], { after: '123', maxPrice: 0, maxDistanceMeters: 1000,
    openToday: true, expiringOnly: false, tags: ['A', 'B'] });
  for (const query of ['maxPrice=-1', 'maxPrice=1.5', 'maxPrice=1000001', 'after=food-001',
    'after=18446744073709551616', 'openToday=yes', 'keyword[a]=bad', 'tags=A&tags=B']) {
    assert.equal((await call(`/foods?${query}`)).status, 400, query);
  }
  assert.equal(calls.length, 1);
  assert.equal((await call('/foods/food-001')).status, 400);
  assert.equal((await call('/foods/1')).status, 404);
  assert.equal((await call('/stores/1')).status, 404);
  assert.equal((await call('/recommendations')).status, 501);
});

test('catalogue SQL binds keyword and tags, escapes LIKE wildcards and maps only public fields', async () => {
  const calls = [];
  const secret = "x%' OR 1=1 --";
  const pool = { execute: async (sql, values) => {
    calls.push({ sql, values });
    if (sql.includes('SELECT f.*')) {
      return [Array.from({ length: 51 }, (_, i) => ({ id: String(i + 1), store_id: '42',
        name: 'Meal', store_name: 'Store', price: 100, distance_meters: null,
        eco_priority_score: '0.5', is_expiring_soon: 0, password_hash: 'must-not-be-exposed' }))];
    }
    if (sql.includes('FROM food_tags')) return [[{ food_id: '1', tag: 'Protein' }]];
    if (sql.includes('FROM food_ingredients')) return [[{ food_id: '1', ingredient: 'Rice' }]];
    if (sql.includes('FROM store_business_weekdays')) return [[{ store_id: '42', weekday: 1 }]];
    throw new Error('Unexpected query');
  } };
  const result = await new CatalogRepository(pool).list({ after: '0', keyword: secret,
    tags: [secret], maxPrice: 100, maxDistanceMeters: 1000, openToday: true, expiringOnly: true });
  assert.equal(result.items.length, 50);
  assert.equal(result.nextCursor, '50');
  assert.equal(calls.length, 4);
  assert.equal(calls[0].sql.includes(secret), false);
  assert.ok(calls[0].values.includes(`%x!%' OR 1=1 --%`));
  assert.ok(calls[0].values.includes(secret));
  assert.match(calls[0].sql, /f.status = 'active'/);
  assert.match(calls[0].sql, /m.status = 'active'/);
  assert.match(calls[0].sql, /f.stock_count > 0/);
  assert.match(calls[0].sql, /UTC_TIMESTAMP/);
  assert.match(calls[0].sql, /LIMIT 51/);
  assert.equal(result.items[0].id, '1');
  assert.equal(result.items[0].storeId, '42');
  assert.equal(result.items[0].distanceMeters, null);
  assert.equal(result.items[0].ecoPriorityScore, 0.5);
  assert.deepEqual(result.items[0].tags, ['Protein']);
  assert.deepEqual(result.items[0].businessWeekdays, [1]);
  assert.equal(JSON.stringify(result).includes('must-not-be-exposed'), false);
});

test('empty database returns an empty catalogue without additional queries', async () => {
  let calls = 0;
  const repository = new CatalogRepository({ execute: async () => { calls++; return [[]]; } });
  assert.deepEqual(await repository.list({ after: '0', tags: [] }), { items: [], nextCursor: null });
  assert.equal(calls, 1);
  assert.equal(await repository.food('1'), null);
  assert.equal(await repository.store('1'), null);
});

test('catalogue always provides a useful recommendation reason', () => {
  assert.equal(recommendationReason({ recommendation_reason: '  自訂理由  ' }), '自訂理由');
  assert.match(recommendationReason({ recommendation_reason: '', is_expiring_soon: 1 }), /即期優惠/);
  assert.match(recommendationReason({ protein_grams: 25 }), /蛋白質/);
  assert.match(recommendationReason({ protein_grams: 5, calories: 350 }), /熱量/);
  assert.match(recommendationReason({ protein_grams: 5, calories: 600, distance_meters: 800 }), /距離/);
  assert.match(recommendationReason({ protein_grams: 5, calories: 600, distance_meters: 2000, category: '便當' }), /便當/);
});
