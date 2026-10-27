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

function cookieFrom(response) {
  return (response.headers.get('set-cookie') || '').split(';', 1)[0];
}

test('admin uses account login, short-lived session and exposes no password data', async () => {
  const repository = {
    dashboard: async () => ({ users: { total: 1 } }),
    users: async () => ({ items: [{ id: '1', name: '測試會員', email: 'member@example.com' }] }),
  };
  const app = await fixture(repository);
  assert.equal((await request(app, '/api/admin/dashboard')).status, 401);
  assert.equal((await login(app, 'wrong-password-value')).status, 401);
  const signedIn = await login(app);
  assert.equal(signedIn.status, 200);
  assert.equal(signedIn.headers.get('cache-control'), 'no-store');
  assert.match(signedIn.headers.get('set-cookie') || '', /mealmind_admin=[a-f0-9]{64}/);
  assert.match(signedIn.headers.get('set-cookie') || '', /HttpOnly; Secure; SameSite=Strict/);
  assert.doesNotMatch(signedIn.headers.get('set-cookie') || '', /Max-Age=/);
  const loginBody = await signedIn.json();
  assert.equal('token' in loginBody, false);
  assert.match(loginBody.expiresAt, /^\d{4}-\d{2}-\d{2}T/);
  const cookie = cookieFrom(signedIn);
  const allowed = await request(app, '/api/admin/users', { headers: { Cookie: cookie } });
  assert.equal(allowed.status, 200);
  const body = await allowed.json();
  assert.equal(body.items[0].email, 'member@example.com');
  assert.equal('passwordHash' in body.items[0], false);
  const cookieAllowed = await request(app, '/api/admin/users', {
    headers: { Cookie: cookie },
  });
  assert.equal(cookieAllowed.status, 200);
  assert.equal((await request(app, '/api/admin/auth/logout', {
    method: 'POST', headers: { Cookie: cookie },
  })).status, 200);
  assert.equal((await request(app, '/api/admin/dashboard', {
    headers: { Cookie: cookie },
  })).status, 401);
});

test('admin merchant status only permits active and paused', async () => {
  let update;
  const app = await fixture({ setMerchantStatus: async (id, status) => { update = { id, status }; return true; } });
  const headers = { Cookie: cookieFrom(await login(app)), 'Content-Type': 'application/json' };
  const invalid = await request(app, '/api/admin/merchants/1/status', {
    method: 'PUT', headers, body: JSON.stringify({ status: 'owner' }),
  });
  assert.equal(invalid.status, 400);
  const valid = await request(app, '/api/admin/merchants/1/status', {
    method: 'PUT', headers, body: JSON.stringify({ status: 'paused' }),
  });
  assert.equal(valid.status, 200);
  assert.deepEqual(update, { id: '1', status: 'paused' });
});

test('admin dashboard accepts only supported summary periods', async () => {
  const received = [];
  const app = await fixture({
    dashboard: async (period) => { received.push(['dashboard', period]); return { period }; },
  });
  const headers = { Cookie: cookieFrom(await login(app)) };
  await request(app, '/api/admin/dashboard?period=week', { headers });
  await request(app, '/api/admin/dashboard?period=DROP%20TABLE', { headers });
  assert.deepEqual(received, [['dashboard', 'week'], ['dashboard', 'day']]);
});

test('admin lists validate and pass pagination, search and dates', async () => {
  let received;
  const app = await fixture({ users: async (filters) => { received = filters; return { items: [], pagination: {} }; } });
  const headers = { Cookie: cookieFrom(await login(app)) };
  const valid = await request(app, '/api/admin/users?page=2&pageSize=50&search=test&from=2026-10-01&to=2026-10-24', { headers });
  assert.equal(valid.status, 200);
  assert.deepEqual(received, { page: 2, pageSize: 50, search: 'test', from: '2026-10-01', to: '2026-10-24' });
  assert.equal((await request(app, '/api/admin/users?pageSize=500', { headers })).status, 400);
  assert.equal((await request(app, '/api/admin/users?from=2026-11-01&to=2026-10-01', { headers })).status, 400);
});
