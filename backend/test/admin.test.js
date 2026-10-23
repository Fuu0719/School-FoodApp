const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const adminRoutes = require('../src/admin/routes');

async function request(app, path, options = {}) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await fetch(`http://127.0.0.1:${server.address().port}${path}`, options);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('admin endpoints require the configured access token and expose no password data', async () => {
  const repository = {
    dashboard: async () => ({ users: { total: 1 } }),
    users: async () => [{ id: '1', name: '測試會員', email: 'member@example.com' }],
  };
  const app = express();
  app.use(express.json());
  app.use('/api', adminRoutes(repository, 'a-secure-admin-token-with-32-chars'));

  const denied = await request(app, '/api/admin/dashboard');
  assert.equal(denied.status, 401);

  const allowed = await request(app, '/api/admin/users', {
    headers: { Authorization: 'Bearer a-secure-admin-token-with-32-chars' },
  });
  assert.equal(allowed.status, 200);
  assert.equal(allowed.headers.get('cache-control'), 'no-store');
  const body = await allowed.json();
  assert.equal(body.items[0].email, 'member@example.com');
  assert.equal('passwordHash' in body.items[0], false);
});

test('admin merchant status only permits active and suspended', async () => {
  let update;
  const repository = { setMerchantStatus: async (id, status) => { update = { id, status }; return true; } };
  const app = express();
  app.use(express.json());
  app.use('/api', adminRoutes(repository, 'a-secure-admin-token-with-32-chars'));
  const headers = { Authorization: 'Bearer a-secure-admin-token-with-32-chars', 'Content-Type': 'application/json' };

  const invalid = await request(app, '/api/admin/merchants/1/status', {
    method: 'PUT', headers, body: JSON.stringify({ status: 'owner' }),
  });
  assert.equal(invalid.status, 400);
  const valid = await request(app, '/api/admin/merchants/1/status', {
    method: 'PUT', headers, body: JSON.stringify({ status: 'suspended' }),
  });
  assert.equal(valid.status, 200);
  assert.deepEqual(update, { id: '1', status: 'suspended' });
});
