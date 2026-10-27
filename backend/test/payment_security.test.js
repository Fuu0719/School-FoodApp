const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const activityRoutes = require('../src/activity/routes');
const ActivityRepository = require('../src/activity/repository');
const { checkMacValue, createEcpay } = require('../src/payments/ecpay');

async function post(app, path, body) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await fetch(`http://127.0.0.1:${server.address().port}${path}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), redirect: 'manual',
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('ECPay verification requires the configured MerchantID even with a valid MAC', () => {
  const keys = ['ECPAY_MERCHANT_ID', 'ECPAY_HASH_KEY', 'ECPAY_HASH_IV', 'PUBLIC_BASE_URL'];
  const saved = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  Object.assign(process.env, {
    ECPAY_MERCHANT_ID: '3002607', ECPAY_HASH_KEY: 'pwFHCqoQZGmho4w6',
    ECPAY_HASH_IV: 'EkRm7iFT261dpevs', PUBLIC_BASE_URL: 'https://api.example.test',
  });
  try {
    const ecpay = createEcpay();
    const fields = { MerchantID: 'other', MerchantTradeNo: 'MM123', TradeAmt: '100', RtnCode: '1' };
    fields.CheckMacValue = checkMacValue(fields, process.env.ECPAY_HASH_KEY, process.env.ECPAY_HASH_IV);
    assert.equal(ecpay.verify(fields), false);
  } finally {
    for (const key of keys) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  }
});

test('payment callbacks pass a strictly parsed amount and reject malformed amounts', async () => {
  const calls = [];
  const repository = { recordPayment: async (...args) => { calls.push(args); return null; } };
  const ecpay = { enabled: true, verify: (body) => body.MerchantID === 'expected' };
  const app = express().use(express.json()).use('/api', activityRoutes(repository, (_req, _res, next) => next(), null, ecpay));
  assert.equal((await post(app, '/api/payments/ecpay/return', {
    MerchantID: 'expected', MerchantTradeNo: 'MM123', TradeAmt: '100', RtnCode: '1',
  })).status, 200);
  assert.deepEqual(calls, [['MM123', true, 100]]);
  assert.equal((await post(app, '/api/payments/ecpay/return', {
    MerchantID: 'expected', MerchantTradeNo: 'MM123', TradeAmt: '100.00', RtnCode: '1',
  })).status, 400);
  assert.equal((await post(app, '/api/payments/ecpay/return', {
    MerchantID: 'wrong', MerchantTradeNo: 'MM123', TradeAmt: '100', RtnCode: '1',
  })).status, 400);
  assert.equal(calls.length, 1);
});

test('payment callbacks report failure when the signed amount does not match the order', async () => {
  const repository = { recordPayment: async () => ({ rejected: true }) };
  const ecpay = { enabled: true, verify: () => true };
  const app = express().use(express.json()).use('/api', activityRoutes(repository, (_req, _res, next) => next(), null, ecpay));
  const body = { MerchantID: 'expected', MerchantTradeNo: 'MM123', TradeAmt: '100', RtnCode: '1' };

  const callback = await post(app, '/api/payments/ecpay/return', body);
  assert.equal(callback.status, 400);
  assert.equal(await callback.text(), '0|Order Error');
  const appResult = await post(app, '/api/payments/ecpay/result', body);
  assert.match(appResult.headers.get('location') || '', /status=failed/);
  const webResult = await post(app, '/api/payments/ecpay/web-result', body);
  assert.match(webResult.headers.get('location') || '', /payment=failed/);
});

test('recordPayment leaves a pending order unchanged when TradeAmt differs', async () => {
  const events = [];
  const connection = {
    beginTransaction: async () => events.push('begin'),
    commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'),
    release: () => events.push('release'),
    execute: async (sql) => {
      events.push(sql);
      if (sql.startsWith('SELECT id, user_id')) {
        return [[{ id: 9, userId: 4, payment_status: 'pending', totalPrice: 120 }]];
      }
      throw new Error('payment status must not be updated');
    },
  };
  const repository = new ActivityRepository({ getConnection: async () => connection });
  assert.deepEqual(await repository.recordPayment('MM123', true, 100), { rejected: true });
  assert.deepEqual(events.slice(-2), ['commit', 'release']);
});
