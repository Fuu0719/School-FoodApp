const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const adminRoutes = require('../src/admin/routes');
const { hashPassword } = require('../src/auth/passwords');

async function request(app, path, options = {}) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try { return await fetch(`http://127.0.0.1:${server.address().port}${path}`, options); }
  finally { await new Promise((resolve) => server.close(resolve)); }
}

async function fixture(repository = {}) {
  const app = express();
  app.use(express.json());
  app.use('/api', adminRoutes(repository, {
    email: 'admin@mealmind-app.online',
    passwordHash: await hashPassword('correct-horse-battery-staple'),
  }));
  return app;
}

async function login(app, password = 'correct-horse-battery-staple') {
  return request(app, '/api/admin/auth/login', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@mealmind-app.online', password }),
  });
}

test('admin uses account login, short-lived session and exposes no password data', async () => {
  const repository = {
    dashboard: async () => ({ users: { total: 1 } }),
    users: async () => [{ id: '1', name: '測試會員', email: 'member@example.com' }],
  };
  const app = await fixture(repository);
  assert.equal((await request(app, '/api/admin/dashboard')).status, 401);
  assert.equal((await login(app, 'wrong-password-value')).status, 401);
  const signedIn = await login(app);
  assert.equal(signedIn.status, 200);
  assert.equal(signedIn.headers.get('cache-control'), 'no-store');
  const { token } = await signedIn.json();
  assert.match(token, /^[a-f0-9]{64}$/);
  const allowed = await request(app, '/api/admin/users', { headers: { Authorization: `Bearer ${token}` } });
  assert.equal(allowed.status, 200);
  const body = await allowed.json();
  assert.equal(body.items[0].email, 'member@example.com');
  assert.equal('passwordHash' in body.items[0], false);
  assert.equal((await request(app, '/api/admin/auth/logout', {
    method: 'POST', headers: { Authorization: `Bearer ${token}` },
  })).status, 200);
  assert.equal((await request(app, '/api/admin/dashboard', {
    headers: { Authorization: `Bearer ${token}` },
  })).status, 401);
});

test('admin merchant status only permits active and suspended', async () => {
  let update;
  const app = await fixture({ setMerchantStatus: async (id, status) => { update = { id, status }; return true; } });
  const { token } = await (await login(app)).json();
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
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
