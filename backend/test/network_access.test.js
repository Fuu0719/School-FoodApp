const assert = require('node:assert/strict');
const { test } = require('node:test');
const createApp = require('../src/app');

async function check(t, allowedClientIps, headers = {}) {
  const server = createApp({ allowedClientIps }).listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return fetch(`http://127.0.0.1:${server.address().port}/api/health`, { headers });
}

test('VPN source restriction permits an exact allowed source', async (t) => {
  const response = await check(t, ['127.0.0.1']);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).status, 'ok');
});

test('forwarded headers cannot bypass VPN source restriction', async (t) => {
  const response = await check(t, ['192.0.2.10'], { 'x-forwarded-for': '192.0.2.10' });
  assert.equal(response.status, 403);
  await response.json();
});

test('VPN source configuration rejects wildcard entries', () => {
  assert.throws(() => createApp({ allowedClientIps: ['*'] }), /exact IP/);
});
