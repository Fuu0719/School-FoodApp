const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
  '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;',
}[char]));
const money = (value) => `NT$ ${Number(value || 0).toLocaleString('zh-TW')}`;
const foods = new Map();
const cart = new Map();
const accountLink = $('#account-link');
const cartLink = $('#cart-link');
const cartCount = $('#cart-count');

function cartQuantity() {
  return [...cart.values()].reduce((sum, quantity) => sum + Number(quantity || 0), 0);
}

function readStoredCart() {
  cart.clear();
  try {
    for (const [id, quantity] of JSON.parse(sessionStorage.getItem('webCart') || '[]')) {
      const count = Number(quantity);
      if (count > 0) cart.set(String(id), count);
    }
  } catch {
    sessionStorage.removeItem('webCart');
  }
}

function syncFoodButtons() {
  document.querySelectorAll('.add-cart').forEach((button) => {
    const quantity = cart.get(String(button.dataset.id)) || 0;
    button.textContent = quantity ? `已加入 ${quantity}` : '加入';
  });
}

function syncCartLink() {
  readStoredCart();
  const quantity = cartQuantity();
  const signedIn = Boolean(sessionStorage.getItem('memberToken'));
  cartLink.hidden = !signedIn;
  cartCount.textContent = String(quantity);
  cartLink.setAttribute('aria-label', `購物車，目前 ${quantity} 件`);
  syncFoodButtons();
}

function syncAccountLink() {
  const activePortal = sessionStorage.getItem('activePortal');
  const hasMember = Boolean(sessionStorage.getItem('memberToken'));
  const hasMerchant = Boolean(sessionStorage.getItem('merchantToken'));
  if (hasMerchant && (activePortal === 'merchant' || !hasMember)) {
    accountLink.href = '/login.html?tab=merchant';
    accountLink.firstChild.textContent = '商家後台 ';
  } else if (hasMember) {
    accountLink.href = '/login.html?tab=member';
    accountLink.firstChild.textContent = '會員中心 ';
  } else {
    accountLink.href = '/login.html';
    accountLink.firstChild.textContent = '登入 ';
  }
  syncCartLink();
}

syncAccountLink();
window.addEventListener('pageshow', syncAccountLink);

function notify(message, error = false) {
  const toast = $('#site-status');
  toast.textContent = message;
  toast.classList.toggle('error', error);
  toast.hidden = false;
  clearTimeout(notify.timer);
  notify.timer = setTimeout(() => { toast.hidden = true; }, 3200);
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
  if (!response.ok) throw new Error(data.message || '服務暫時無法處理');
  return data;
}

async function loadFoods() {
  const form = $('#food-search');
  const data = new FormData(form);
  const query = new URLSearchParams();
  if (data.get('keyword')) query.set('keyword', data.get('keyword'));
  if (data.get('maxPrice')) query.set('maxPrice', data.get('maxPrice'));
  if (data.get('mode') === 'expiring') query.set('expiringOnly', 'true');
  $('#food-status').textContent = '載入餐點中…';
  try {
    const result = await api(`/foods?${query}`);
    result.items.forEach((food) => foods.set(String(food.id), food));
    $('#food-list').innerHTML = result.items.map((food) => `<article class="food-row"><img class="food-thumb" src="${escapeHtml(food.imageUrl)}" alt="${escapeHtml(food.name)}"><div class="food-main"><h3 title="${escapeHtml(food.name)}">${escapeHtml(food.name)}</h3><p class="food-store">${escapeHtml(food.storeName)} · ${Number(food.distanceMeters || 0).toLocaleString()} 公尺</p>${food.isExpiringSoon ? '<span class="badge offer">即期優惠</span>' : `<span class="badge">${escapeHtml(food.category)}</span>`}</div><div class="food-buy"><div><span class="price">${money(food.price)}</span><div class="stock">庫存 ${food.stockCount}</div></div><div class="row-actions"><button class="small-button add-cart" data-id="${food.id}">加入</button><button class="small-button add-favorite" data-id="${food.id}">收藏</button></div></div></article>`).join('') || '<p class="empty">目前沒有符合條件的餐點</p>';
    syncFoodButtons();
    $('#food-status').textContent = `共顯示 ${result.items.length} 項餐點`;
  } catch (error) {
    $('#food-status').textContent = error.message;
    $('#food-status').classList.add('error');
  }
}

document.querySelectorAll('a[href^="#"]').forEach((link) => link.addEventListener('click', (event) => {
  const target = document.querySelector(link.getAttribute('href'));
  if (!target) return;
  event.preventDefault();
  const top = target.getBoundingClientRect().top + window.scrollY - 84;
  window.scrollTo({ top: Math.max(0, top), behavior: 'smooth' });
  history.replaceState(null, '', link.getAttribute('href'));
  closeNavigation();
}));

const navToggle = $('#nav-toggle');
const primaryNav = $('#primary-nav');

function closeNavigation() {
  primaryNav.classList.remove('open');
  navToggle.setAttribute('aria-expanded', 'false');
  navToggle.setAttribute('aria-label', '開啟導覽選單');
}

navToggle.addEventListener('click', () => {
  const opened = primaryNav.classList.toggle('open');
  navToggle.setAttribute('aria-expanded', String(opened));
  navToggle.setAttribute('aria-label', opened ? '關閉導覽選單' : '開啟導覽選單');
});

document.addEventListener('click', (event) => {
  if (!event.target.closest('.topbar')) closeNavigation();
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeNavigation();
});

window.addEventListener('resize', () => {
  if (window.innerWidth > 900) closeNavigation();
});

$('#food-search').addEventListener('submit', (event) => { event.preventDefault(); loadFoods(); });
$('#reload-foods').addEventListener('click', loadFoods);
document.addEventListener('click', async (event) => {
  const add = event.target.closest('.add-cart');
  const favorite = event.target.closest('.add-favorite');
  if (add) {
    const food = foods.get(add.dataset.id);
    if (!food) return;
    const quantity = cart.get(add.dataset.id) || 0;
    if (quantity >= food.stockCount) return notify('已達目前庫存上限', true);
    cart.set(add.dataset.id, quantity + 1);
    sessionStorage.setItem('webCart', JSON.stringify([...cart]));
    syncCartLink();
    add.textContent = `已加入 ${quantity + 1}`;
    notify(sessionStorage.getItem('memberToken')
      ? `${food.name} 已加入購物車，可前往購物車結帳`
      : `${food.name} 已加入購物車，登入後即可結帳`);
  }
  if (favorite) {
    const memberToken = sessionStorage.getItem('memberToken');
    if (memberToken) {
      favorite.disabled = true;
      try {
        await api(`/me/favorites/${favorite.dataset.id}`, { method: 'PUT', token: memberToken });
        favorite.textContent = '已收藏';
        notify('已加入收藏');
      } catch (error) {
        favorite.disabled = false;
        notify(error.message, true);
      }
      return;
    }
    const params = new URLSearchParams({ tab: 'member', intent: 'favorite', id: favorite.dataset.id });
    location.assign(`/login.html?${params}`);
  }
});

loadFoods();
