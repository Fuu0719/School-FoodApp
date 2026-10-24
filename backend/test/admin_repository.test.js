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
