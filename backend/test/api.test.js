const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const createApp = require('../src/app');

let server;
let baseUrl;

before(async () => {
  const app = createApp({ enablePrototypeRoutes: true, userRepository: { session: async () => null } });
  server = app.listen(0);

  await new Promise((resolve) => {
    server.once('listening', resolve);
  });

  const address = server.address();
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
      } else {
        resolve();
      }
    });
  });
});

test('health endpoint returns ok', async () => {
  const response = await fetch(`${baseUrl}/api/health`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.status, 'ok');
});

test('public website is project-only and exposes only the admin login', async () => {
  const [homeResponse, loginResponse, loginScriptResponse, homeScriptResponse,
    cartPageResponse] = await Promise.all([
    fetch(`${baseUrl}/`),
    fetch(`${baseUrl}/login.html`),
    fetch(`${baseUrl}/admin-login.js`),
    fetch(`${baseUrl}/home.js`),
    fetch(`${baseUrl}/cart.html`, { redirect: 'manual' }),
  ]);
  const [homePage, loginPage, loginScript, homeScript] = await Promise.all([
    homeResponse.text(),
    loginResponse.text(),
    loginScriptResponse.text(),
    homeScriptResponse.text(),
  ]);

  assert.equal(homeResponse.status, 200);
  assert.equal(loginResponse.status, 200);
  assert.match(homePage, /App 核心功能/);
  assert.match(homePage, /管理員登入/);
  assert.match(homePage, /\/download\/android/);
  assert.doesNotMatch(homePage, /id="food-list"|id="cart-link"|會員中心|商家登入/);
  assert.match(loginResponse.headers.get('cache-control') || '', /no-store/);
  assert.match(loginPage, /id="admin-login"/);
  assert.doesNotMatch(loginPage, /id="member-login"|id="merchant-login"|建立會員帳號/);
  assert.match(loginScript, /\/api\/admin\/auth\/login/);
  assert.match(loginScript, /location\.replace\('\/admin\.html'\)/);
  assert.match(homeScript, /history\.replaceState/);
  assert.equal(cartPageResponse.status, 302);
  assert.equal(cartPageResponse.headers.get('location'), '/');
});

test('admin console is a separate non-cacheable page', async () => {
  const [response, scriptResponse] = await Promise.all([
    fetch(`${baseUrl}/admin.html`), fetch(`${baseUrl}/admin.js`),
  ]);
  const [html, script] = await Promise.all([response.text(), scriptResponse.text()]);
  assert.equal(response.status, 200);
  assert.match(response.headers.get('cache-control') || '', /no-store/);
  assert.match(html, /營運主控板/);
  assert.match(html, /\/admin\.js\?v=5/);
  assert.match(html, /id="admin-date-range"[\s\S]+class="period-switch"/);
  assert.match(script, /view === 'orders'/);
  assert.match(script, /function applyOrderPeriod\(period\)/);
});

test('backend-owned food images are publicly cacheable', async () => {
  const response = await fetch(`${baseUrl}/food-images/bento.jpg`);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('content-type'), 'image/jpeg');
  assert.match(response.headers.get('cache-control') || '', /immutable/);
  assert.ok((await response.arrayBuffer()).byteLength > 50000);
});

test('foods endpoint supports keyword search', async () => {
  const response = await fetch(
    `${baseUrl}/api/foods?keyword=${encodeURIComponent('雞')}`,
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.ok(body.total >= 1);
  assert.ok(body.items.some((food) => food.name.includes('雞')));
});

test('favorite endpoints can add and list foods', async () => {
  const addResponse = await fetch(`${baseUrl}/api/me/favorites/food-001`, {
    method: 'POST',
  });
  const addBody = await addResponse.json();

  assert.equal(addResponse.status, 201);
  assert.equal(addBody.isFavorite, true);

  const listResponse = await fetch(`${baseUrl}/api/me/favorites`);
  const listBody = await listResponse.json();

  assert.equal(listResponse.status, 200);
  assert.ok(listBody.items.some((food) => food.id === 'food-001'));
});

test('merchant endpoints can login and create product drafts', async () => {
  const loginResponse = await fetch(`${baseUrl}/api/merchant/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'owner@example.com' }),
  });
  const loginBody = await loginResponse.json();

  assert.equal(loginResponse.status, 200);
  assert.equal(loginBody.merchant.email, 'owner@example.com');
  assert.ok(loginBody.merchant.allowedStores.length >= 1);

  const createResponse = await fetch(`${baseUrl}/api/merchant/product-drafts`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      storeId: loginBody.merchant.allowedStores[0].id,
      name: '番茄雞胸盒',
      category: '便當',
      price: 120,
      stockCount: 5,
      tags: ['高蛋白', '低脂'],
      ingredients: ['雞胸肉', '番茄'],
      calories: 520,
      weightGrams: 430,
    }),
  });
  const createBody = await createResponse.json();

  assert.equal(createResponse.status, 201);
  assert.equal(createBody.name, '番茄雞胸盒');
  assert.equal(createBody.status, 'draft');

  const listResponse = await fetch(`${baseUrl}/api/merchant/product-drafts`);
  const listBody = await listResponse.json();

  assert.equal(listResponse.status, 200);
  assert.ok(listBody.items.some((draft) => draft.name === '番茄雞胸盒'));
});

test('recommendation feedback stores rating tags and affects scores', async () => {
  const createResponse = await fetch(
    `${baseUrl}/api/recommendations/food-001/feedback`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        actionType: 'rating',
        rating: 5,
        tags: ['會再回購'],
      }),
    },
  );
  const createBody = await createResponse.json();

  assert.equal(createResponse.status, 201);
  assert.equal(createBody.rating, 5);
  assert.deepEqual(createBody.tags, ['會再回購']);

  const listResponse = await fetch(`${baseUrl}/api/recommendations`);
  const listBody = await listResponse.json();
  const food = listBody.items.find((item) => item.id === 'food-001');

  assert.equal(listResponse.status, 200);
  assert.ok(food.scores.feedbackScore > 0.5);
});
