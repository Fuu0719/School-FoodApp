const $ = (selector) => document.querySelector(selector);
const money = (value) => `NT$ ${Number(value || 0).toLocaleString('zh-TW')}`;
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
  '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;',
}[char]));
const cart = new Map();
const foods = new Map();

function readCart() {
  try {
    for (const [id, quantity] of JSON.parse(sessionStorage.getItem('webCart') || '[]')) {
      const count = Number(quantity);
      if (count > 0) cart.set(String(id), count);
    }
  } catch {
    sessionStorage.removeItem('webCart');
  }
}

function persistCart() {
  sessionStorage.setItem('webCart', JSON.stringify([...cart]));
}

async function api(path, options = {}) {
  const headers = { Accept: 'application/json', ...(options.headers || {}) };
  if (options.body !== undefined) headers['Content-Type'] = 'application/json';
  if (options.token) headers.Authorization = `Bearer ${options.token}`;
  const response = await fetch(`/api${path}`, {
    method: options.method || 'GET', headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data.message || '服務暫時無法處理');
    error.status = response.status;
    throw error;
  }
  return data;
}

function render() {
  const items = [...cart].map(([id, quantity]) => ({ food: foods.get(id), quantity })).filter((item) => item.food);
  const quantity = items.reduce((sum, item) => sum + item.quantity, 0);
  const total = items.reduce((sum, item) => sum + Number(item.food.price) * item.quantity, 0);
  $('#summary-quantity').textContent = `${quantity} 項`;
  $('#summary-total').textContent = money(total);
  $('#checkout-cart').disabled = items.length === 0;
  $('#cart-items').innerHTML = items.length ? items.map(({ food, quantity: count }) => `
    <article class="cart-item">
      <img src="${escapeHtml(food.imageUrl)}" alt="${escapeHtml(food.name)}">
      <div><h2>${escapeHtml(food.name)}</h2><p>${escapeHtml(food.storeName)} · ${money(food.price)}</p><small>目前庫存 ${food.stockCount}</small></div>
      <div class="quantity-control" aria-label="${escapeHtml(food.name)}數量">
        <button type="button" data-cart-action="decrease" data-id="${food.id}" aria-label="減少數量">−</button>
        <strong>${count}</strong>
        <button type="button" data-cart-action="increase" data-id="${food.id}" aria-label="增加數量" ${count >= food.stockCount ? 'disabled' : ''}>＋</button>
      </div>
      <strong class="cart-subtotal">${money(Number(food.price) * count)}</strong>
      <button type="button" class="text-action cart-delete" data-cart-action="remove" data-id="${food.id}">移除</button>
    </article>`).join('') : '<p class="empty">購物車目前沒有餐點，請返回首頁選購。</p>';
}

async function loadCart() {
  readCart();
  if (!sessionStorage.getItem('memberToken')) {
    location.replace('/login.html?tab=member&intent=cart');
    return;
  }
  const missing = [];
  await Promise.all([...cart.keys()].map(async (id) => {
    try {
      const food = await api(`/foods/${id}`);
      foods.set(String(food.id), food);
      const quantity = Math.min(cart.get(id), Number(food.stockCount));
      if (quantity > 0) cart.set(id, quantity); else missing.push(id);
    } catch {
      missing.push(id);
    }
  }));
  missing.forEach((id) => cart.delete(id));
  persistCart();
  render();
  $('#cart-status').textContent = missing.length ? '已移除下架、過期或無庫存商品' : '商品價格與庫存已同步';
}

document.addEventListener('click', async (event) => {
  const control = event.target.closest('[data-cart-action]');
  if (control) {
    const id = String(control.dataset.id);
    const food = foods.get(id);
    if (!food) return;
    const current = cart.get(id) || 0;
    if (control.dataset.cartAction === 'increase' && current < food.stockCount) cart.set(id, current + 1);
    if (control.dataset.cartAction === 'decrease') current <= 1 ? cart.delete(id) : cart.set(id, current - 1);
    if (control.dataset.cartAction === 'remove') cart.delete(id);
    persistCart();
    render();
    return;
  }
  if (event.target.id !== 'checkout-cart') return;
  const button = event.target;
  button.disabled = true;
  $('#cart-status').textContent = '正在建立訂單…';
  try {
    const result = await api('/me/orders', {
      method: 'POST', token: sessionStorage.getItem('memberToken'),
      headers: { 'Idempotency-Key': crypto.randomUUID() },
      body: { items: [...cart].map(([foodId, quantity]) => ({ foodId, quantity })) },
    });
    cart.clear();
    persistCart();
    if (result.payment?.checkoutUrl) {
      location.assign(`${result.payment.checkoutUrl}?client=web`);
      return;
    }
    location.replace('/login.html?tab=member&view=orders');
  } catch (error) {
    if (error.status === 401 || error.status === 403) {
      sessionStorage.removeItem('memberToken');
      location.replace('/login.html?tab=member&intent=cart');
      return;
    }
    $('#cart-status').textContent = error.message;
    $('#cart-status').classList.add('error');
    button.disabled = false;
  }
});

loadCart();
