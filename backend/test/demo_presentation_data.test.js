const assert = require('node:assert/strict');
const { test } = require('node:test');
const { demoMerchantEmails, refreshDemoData } = require('../scripts/manage_demo_presentation_data');

test('demo refresh is limited by explicit merchant allowlist and recurring tag', async () => {
  const calls = [];
  const pool = { execute: async (sql, args) => {
    calls.push({ sql, args });
    return [{ affectedRows: 12 }];
  } };
  assert.equal(await refreshDemoData(pool), 12);
  assert.match(calls[0].sql, /m\.email IN/);
  assert.match(calls[0].sql, /t\.tag = \?/);
  assert.match(calls[0].sql, /f\.deleted_at IS NULL/);
  assert.equal(calls[0].args.length, demoMerchantEmails.length + 1);
  assert.equal(new Set(calls[0].args.slice(1)).size, demoMerchantEmails.length);
});
