const assert = require('node:assert/strict');
const { test } = require('node:test');
const { randomUUID } = require('node:crypto');
const createApp = require('../src/app');
const { hashPassword, verifyPassword, tokenHash } = require('../src/auth/passwords');

class MemoryUsers {
  users = new Map();
  passwords = new Map();
  sessions = new Map();
  async create({ name, email, passwordHash }) {
    if ([...this.users.values()].some((u) => u.email === email)) {
      throw Object.assign(new Error('duplicate'), { code: 'ER_DUP_ENTRY' });
    }
    const id = String(this.users.size + 1);
    const user = { id, name, email, phone: '', heightCm: 170, weightKg: 65,
      healthGoal: 'maintain', dietaryTags: [], budgetMax: 150, distanceLimitMeters: 1000 };
    this.users.set(id, user);
    this.passwords.set(id, passwordHash);
    return user;
  }
  async credentials(email) {
    const user = [...this.users.values()].find((u) => u.email === email);
    return user && { id: user.id, password_hash: this.passwords.get(user.id) };
  }
  async get(id) { return this.users.get(String(id)); }
  async update(id, values) {
    const updated = { ...await this.get(id), ...values };
    this.users.set(String(id), updated);
    return updated;
  }
  async createSession(id, hash, expiresAt) { this.sessions.set(hash, { id, expiresAt }); }
  async session(hash) {
    const session = this.sessions.get(hash);
    return session && session.expiresAt > new Date() ? this.get(session.id) : null;
  }
  async revoke(hash) { this.sessions.delete(hash); }
}

async function serve(t, repository) {
  const server = createApp({ userRepository: repository }).listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return async (path, method = 'GET', body, token) => {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api${path}`, {
      method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  };
}

async function memberFlow(t, repository, email) {
  const call = await serve(t, repository);
  const password = 'TestPass123!';
  const registration = { name: '會員測試', email, password };
  assert.equal((await call('/auth/register', 'POST', registration)).status, 201);
  assert.equal((await call('/auth/register', 'POST', { ...registration, email: email.toUpperCase() })).status, 409);
  const record = await repository.credentials(email);
  assert.notEqual(record.password_hash, password);
  assert.equal(await verifyPassword(password, record.password_hash), true);
  assert.equal((await call('/auth/login', 'POST', { email, password: 'incorrect-password' })).status, 401);
  const login = await call('/auth/login', 'POST', { email, password });
  assert.equal(login.status, 200);
  assert.equal(JSON.stringify(login.body).includes('password'), false);
  const token = login.body.token;
  assert.match(token, /^[a-f0-9]{64}$/);
  assert.equal((await call('/me')).status, 401);
  assert.equal((await call('/me', 'GET', undefined, 'local-demo-token')).status, 401);
  const update = { ...login.body.user, id: '999999', email: 'change-not-allowed@example.com',
    name: '偏好測試', phone: '0912345678', dietaryTags: ['高蛋白', '低脂'],
    budgetMax: null, distanceLimitMeters: null, heightCm: 175.5, weightKg: 70.5, healthGoal: 'muscleGain' };
  const saved = await call('/me', 'PUT', update, token);
  assert.equal(saved.status, 200);
  assert.equal(saved.body.id, login.body.user.id);
  assert.equal(saved.body.email, email);
  assert.equal(saved.body.budgetMax, null);
  assert.deepEqual(saved.body.dietaryTags, update.dietaryTags);
  assert.equal(saved.body.heightCm, 175.5);
  assert.equal(saved.body.healthGoal, 'muscleGain');
  assert.equal((await call('/me', 'PUT', { ...update, phone: '123' }, token)).status, 400);
  assert.equal((await call('/me', 'GET', undefined, token)).body.phone, '0912345678');
  assert.equal((await call('/me', 'PUT', { ...update, phone: '+886 912-345-678' }, token)).body.phone, '0912345678');
  assert.equal((await call('/me', 'PUT', { ...update, heightCm: -1 }, token)).status, 400);
  assert.equal((await call('/me', 'PUT', { ...update, dietaryTags: [123] }, token)).status, 400);
  assert.equal((await call('/me', 'GET', undefined, token)).body.heightCm, 175.5);
  // A second app instance simulates an API restart against the same database.
  const restarted = await serve(t, repository);
  assert.equal((await restarted('/me', 'GET', undefined, token)).body.name, '偏好測試');
  assert.equal((await call('/auth/logout', 'POST', {}, token)).status, 200);
  assert.equal((await restarted('/me', 'GET', undefined, token)).status, 401);
  const again = await restarted('/auth/login', 'POST', { email, password });
  assert.equal(again.body.user.name, '偏好測試');
  assert.equal(again.body.user.distanceLimitMeters, null);
}

test('member registration, authenticated profile persistence and logout', async (t) => {
  await memberFlow(t, new MemoryUsers(), 'member@example.com');
});

test('accounts are isolated, expired sessions rejected, prototype endpoints disabled', async (t) => {
  const repository = new MemoryUsers();
  const call = await serve(t, repository);
  const password = 'TestPass456!';
  for (const email of ['a@example.com', 'b@example.com']) {
    await call('/auth/register', 'POST', { name: email, email, password });
  }
  const a = (await call('/auth/login', 'POST', { email: 'a@example.com', password })).body;
  const b = (await call('/auth/login', 'POST', { email: 'b@example.com', password })).body;
  await call('/me', 'PUT', { ...a.user, id: b.user.id, name: 'changed A' }, a.token);
  assert.equal((await call('/me', 'GET', undefined, b.token)).body.name, 'b@example.com');
  repository.sessions.get(tokenHash(a.token)).expiresAt = new Date(0);
  assert.equal((await call('/me', 'GET', undefined, a.token)).status, 401);
  assert.equal((await call('/me/favorites', 'GET', undefined, b.token)).status, 501);
  assert.equal((await call('/merchant/auth/login', 'POST', {})).status, 501);
  assert.equal((await call('/me/preferences', 'PUT', {}, b.token)).status, 501);
});

test('invalid inputs, throttling and sanitized database errors', async (t) => {
  const repository = new MemoryUsers();
  const call = await serve(t, repository);
  assert.equal((await call('/auth/register', 'POST', { email: 'bad', password: 'short' })).status, 400);
  repository.credentials = async () => { throw new Error('SQL password secret connection info'); };
  const failure = await call('/auth/login', 'POST', { email: 'a@example.com', password: 'valid-length-password' });
  assert.equal(failure.status, 500);
  assert.equal(JSON.stringify(failure.body).includes('secret'), false);
  for (let i = 0; i < 28; i++) await call('/auth/login', 'POST', {});
  assert.equal((await call('/auth/login', 'POST', {})).status, 429);
});

test('password hashes use separate salts and reject incorrect passwords', async () => {
  const hash = await hashPassword('correct-password');
  assert.notEqual(hash, await hashPassword('correct-password'));
  assert.equal(await verifyPassword('wrong-password', hash), false);
  assert.equal(await verifyPassword('correct-password', 'invalid'), false);
});

test('MySQL integration: actual member persistence and session revocation', {
  skip: process.env.MYSQL_INTEGRATION !== '1',
}, async (t) => {
  require('dotenv').config();
  const pool = require('../src/config/database').createDatabasePool();
  const UserRepository = require('../src/auth/user_repository');
  const email = `integration-${randomUUID()}@example.com`;
  t.after(async () => {
    await pool.execute('DELETE FROM users WHERE email = ?', [email]);
    await pool.end();
  });
  await memberFlow(t, new UserRepository(pool), email);
});
