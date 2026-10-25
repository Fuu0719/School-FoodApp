const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[char]));
const money = (value) => `NT$ ${Number(value || 0).toLocaleString('zh-TW')}`;
const date = (value) => value ? new Intl.DateTimeFormat('zh-TW', { dateStyle:'medium', timeStyle:'short' }).format(new Date(value)) : '—';
const periodNames = { day:'今日', week:'本週', month:'本月' };
const viewMeta = {
  dashboard: ['營運總覽', '掌握需要立即處理的帳號、庫存、付款與減廢狀況'],
  users: ['會員管理', '查看會員驗證、註冊時間與商家綁定狀態'],
  merchants: ['商家管理', '檢視門市與商品規模，控制商家存取權限'],
  foods: ['餐點報表', '比較期間銷量、營收、庫存與有效期限'],
  orders: ['訂單報表', '追蹤付款結果、訂單金額與減廢效益'],
};
const state = { view:'dashboard', period:'day', page:1, pageSize:25, search:'', from:'', to:'', items:[], pagination:null, dashboard:null };

function localDate(value) {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function periodRange(period) {
  const end = new Date();
  const start = new Date(end.getFullYear(), end.getMonth(), end.getDate());
  if (period === 'week') start.setDate(start.getDate() - ((start.getDay() + 6) % 7));
  if (period === 'month') start.setDate(1);
  return { from: localDate(start), to: localDate(end) };
}

function applyOrderPeriod(period) {
  const range = periodRange(period);
  state.period = period;
  state.from = range.from;
  state.to = range.to;
  state.page = 1;
  $('#admin-from').value = range.from;
  $('#admin-to').value = range.to;
}

async function api(path, options = {}) {
  const response = await fetch(`/api${path}`, {
    method: options.method || 'GET',
    headers: { Accept:'application/json', ...(options.body ? {'Content-Type':'application/json'} : {}) },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const data = await response.json().catch(() => ({}));
  if (response.status === 401) { location.replace('/login.html?tab=admin'); throw new Error('登入已失效'); }
  if (!response.ok) throw new Error(data.message || '服務暫時無法處理');
  return data;
}

function setAlert(message = '', error = false) {
  const node = $('#admin-alert');
  node.textContent = message;
  node.classList.toggle('error', error);
  node.hidden = !message;
}

function metric(value, label, note = '', tone = '') {
  return `<article class="admin-metric ${tone}"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(note)}</small></article>`;
}

function dashboardView(report) {
  const orders = report.orders || {};
  const alerts = [
    { value:report.foods.expired || 0, label:'逾期餐點', note:'應立即確認下架', tone:'danger', view:'foods' },
    { value:report.foods.lowStock || 0, label:'低庫存餐點', note:'庫存 5 份以下', tone:'warning', view:'foods' },
    { value:orders.pending || 0, label:'待付款訂單', note:'尚未完成付款', tone:'warning', view:'orders' },
    { value:report.merchants.suspended || 0, label:'停權商家', note:'目前無法使用後台', tone:'neutral', view:'merchants' },
  ];
  const topFoods = report.topFoods || [];
  const maxQuantity = Math.max(1, ...topFoods.map((item) => Number(item.quantity)));
  return `<section class="admin-section"><div class="admin-section-head"><div><h2>${periodNames[state.period]}關鍵指標</h2><p>交易資料僅計入已付款訂單</p></div></div><div class="admin-metrics">
    ${metric(money(orders.revenue), '營收', `${orders.paid || 0} 筆已付款`, 'primary')}
    ${metric(orders.quantity || 0, '售出份數', `平均客單 ${money(orders.averageOrder)}`)}
    ${metric(report.users.newCount || 0, '新增會員', `會員總數 ${report.users.total || 0}`)}
    ${metric(report.merchants.newCount || 0, '新增商家', `${report.merchants.active || 0} 家啟用`)}
    ${metric(money(orders.savedAmount), '會員節省', '即期優惠累積')}
    ${metric(orders.ecoPoints || 0, '減廢點數', '已付款訂單累積')}
  </div></section>
  <section class="admin-section"><div class="admin-section-head"><div><h2>待處理事項</h2><p>從高風險項目開始檢查</p></div></div><div class="attention-grid">${alerts.map((item) => `<button data-jump-view="${item.view}" class="attention-item ${item.tone}"><strong>${item.value}</strong><span>${item.label}</span><small>${item.note}</small></button>`).join('')}</div></section>
  <section class="admin-section"><div class="admin-section-head"><div><h2>熱門餐點</h2><p>${periodNames[state.period]}銷量與營收</p></div><button data-jump-view="foods" class="text-action">查看餐點報表</button></div>${topFoods.length ? `<div class="ranking-list">${topFoods.map((item, index) => `<div class="ranking-row"><span class="rank">${index + 1}</span><div><strong>${escapeHtml(item.name)}</strong><div class="rank-bar"><i style="width:${Math.max(4, Math.round(Number(item.quantity) / maxQuantity * 100))}%"></i></div></div><span>${item.quantity} 份<br><small>${money(item.revenue)}</small></span></div>`).join('')}</div>` : '<p class="empty compact">此期間尚無已付款訂單</p>'}</section>`;
}

function statusBadge(value) { return `<span class="report-status ${escapeHtml(value)}">${escapeHtml(value)}</span>`; }

function dataTable(view, items) {
  if (!items.length) return '<p class="empty">目前沒有符合條件的資料</p>';
  const heads = {
    users:['會員','Email','驗證／綁定','建立時間'],
    merchants:['商家','聯絡方式','規模','存取狀態'],
    foods:['餐點','商家／門市','售價／庫存','狀態／期限','期間績效'],
    orders:['訂單／會員','數量／金額','付款狀態','建立／付款','減廢效益'],
  }[view];
  const rows = items.map((item) => {
    if (view === 'users') return `<tr><td><strong>${escapeHtml(item.name)}</strong><br><small>#${item.id}</small></td><td>${escapeHtml(item.email)}</td><td>${item.emailVerifiedAt ? '已驗證' : '未驗證'}<br><small>${item.linkedMerchantId ? `綁定商家 #${item.linkedMerchantId}` : '未綁定商家'}</small></td><td>${date(item.createdAt)}</td></tr>`;
    if (view === 'merchants') return `<tr><td><strong>${escapeHtml(item.businessName)}</strong><br><small>#${item.id}・${date(item.createdAt)}</small></td><td>${escapeHtml(item.email)}<br><small>${escapeHtml(item.contactPhone || '未填電話')}</small></td><td>${item.storeCount} 間門市<br><small>${item.productCount} 項餐點</small></td><td><div class="status-editor"><select data-merchant-status="${item.id}" aria-label="${escapeHtml(item.businessName)}狀態"><option value="active" ${item.status === 'active' ? 'selected' : ''}>active</option><option value="suspended" ${item.status === 'suspended' ? 'selected' : ''}>suspended</option></select><button class="small-button admin-merchant-save" data-id="${item.id}">儲存</button></div></td></tr>`;
    if (view === 'foods') return `<tr><td><strong>${escapeHtml(item.name)}</strong><br><small>#${item.id}・${date(item.createdAt)}</small></td><td>${escapeHtml(item.merchantName)}<br><small>${escapeHtml(item.storeName)}</small></td><td>${money(item.price)}<br><small>庫存 ${item.stockCount}</small></td><td>${statusBadge(item.status)}<br><small>${item.expiresAt ? `期限 ${date(item.expiresAt)}` : '無期限'}</small></td><td><strong>${item.soldQuantity || 0} 份</strong><br><small>${money(item.revenue)}</small></td></tr>`;
    return `<tr><td><strong>#${item.id}</strong><br>${escapeHtml(item.userName || '會員')}<br><small>${escapeHtml(item.email)}</small></td><td>${item.totalQuantity} 份<br><strong>${money(item.totalPrice)}</strong></td><td>${statusBadge(item.paymentStatus)}</td><td>${date(item.purchasedAt)}<br><small>付款 ${date(item.paidAt)}</small></td><td>節省 ${money(item.savedAmount)}<br><small>點數 ${item.ecoPoints || 0}</small></td></tr>`;
  }).join('');
  return `<div class="admin-table-wrap"><table><thead><tr>${heads.map((head) => `<th>${head}</th>`).join('')}</tr></thead><tbody>${rows}</tbody></table></div>`;
}

function renderItems() { $('#admin-content').innerHTML = dataTable(state.view, state.items); }

function renderPagination() {
  const node = $('#admin-pagination'), paging = state.pagination;
  if (!paging) { node.hidden = true; return; }
  node.hidden = false;
  node.innerHTML = `<span>共 ${paging.total.toLocaleString()} 筆・第 ${paging.page} / ${paging.totalPages} 頁</span><div><button type="button" data-page="${paging.page - 1}" ${paging.page <= 1 ? 'disabled' : ''}>上一頁</button><button type="button" data-page="${paging.page + 1}" ${paging.page >= paging.totalPages ? 'disabled' : ''}>下一頁</button></div>`;
}

async function loadView(view = state.view) {
  state.view = view;
  if (view === 'orders' && !state.from && !state.to) applyOrderPeriod(state.period);
  const [title, subtitle] = viewMeta[view];
  $('#admin-title').textContent = title;
  $('#admin-subtitle').textContent = subtitle;
  $$('[data-admin-view]').forEach((button) => button.classList.toggle('active', button.dataset.adminView === view));
  const dashboard = view === 'dashboard';
  $('.period-switch').hidden = !(dashboard || view === 'orders');
  $('#admin-date-range').hidden = dashboard;
  $('#admin-search').closest('label').hidden = view === 'dashboard';
  $('#admin-page-size').closest('label').hidden = dashboard;
  $('#admin-export').hidden = view === 'dashboard';
  $('#admin-pagination').hidden = true;
  const placeholders = { users:'搜尋會員姓名或 Email', merchants:'搜尋商家、Email 或電話', foods:'搜尋餐點、商家或門市', orders:'搜尋訂單編號、會員或 Email' };
  $('#admin-search').placeholder = placeholders[view] || '';
  $('#admin-content').innerHTML = '<p class="admin-loading">正在載入資料…</p>';
  setAlert();
  try {
    const query = new URLSearchParams();
    if (dashboard) query.set('period', state.period);
    else {
      query.set('page', state.page); query.set('pageSize', state.pageSize);
      if (state.search) query.set('search', state.search);
      if (state.from) query.set('from', state.from);
      if (state.to) query.set('to', state.to);
    }
    const result = await api(`/admin/${view}?${query}`);
    if (dashboard) { state.dashboard = result; state.pagination = null; $('#admin-content').innerHTML = dashboardView(result); }
    else { state.items = result.items || []; state.pagination = result.pagination; renderItems(); renderPagination(); }
    $('#admin-updated').textContent = `更新於 ${new Intl.DateTimeFormat('zh-TW', { hour:'2-digit', minute:'2-digit', second:'2-digit' }).format(new Date())}`;
  } catch (error) {
    $('#admin-content').innerHTML = '<p class="empty">資料載入失敗</p>';
    setAlert(`${title}無法載入：${error.message}`, true);
  }
}

function csvCell(value) { return `"${String(value ?? '').replaceAll('"', '""')}"`; }
function exportCsv() {
  const items = state.items;
  if (!items.length) return setAlert('目前沒有可匯出的資料', true);
  const keys = Object.keys(items[0]);
  const csv = '\ufeff' + [keys.join(','), ...items.map((item) => keys.map((key) => csvCell(item[key])).join(','))].join('\r\n');
  const url = URL.createObjectURL(new Blob([csv], { type:'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url; link.download = `mealmind-${state.view}-${state.period}.csv`; link.click();
  URL.revokeObjectURL(url);
  setAlert('CSV 報表已匯出');
}

document.addEventListener('click', async (event) => {
  const nav = event.target.closest('[data-admin-view], [data-jump-view]');
  if (nav) { state.page = 1; state.search = ''; $('#admin-search').value = ''; return loadView(nav.dataset.adminView || nav.dataset.jumpView); }
  const period = event.target.closest('[data-admin-period]');
  if (period) {
    state.period = period.dataset.adminPeriod;
    if (state.view === 'orders') applyOrderPeriod(state.period);
    $$('[data-admin-period]').forEach((button) => button.classList.toggle('active', button === period));
    return loadView();
  }
  const page = event.target.closest('[data-page]');
  if (page && !page.disabled) { state.page = Number(page.dataset.page); return loadView(); }
  const save = event.target.closest('.admin-merchant-save');
  if (save) {
    const select = document.querySelector(`[data-merchant-status="${save.dataset.id}"]`);
    save.disabled = true; save.textContent = '儲存中…';
    try { await api(`/admin/merchants/${save.dataset.id}/status`, { method:'PUT', body:{ status:select.value } }); setAlert(`商家 #${save.dataset.id} 已更新為 ${select.value}`); await loadView('merchants'); }
    catch (error) { save.disabled = false; save.textContent = '儲存'; setAlert(error.message, true); }
  }
});

let searchTimer;
$('#admin-search').addEventListener('input', (event) => { clearTimeout(searchTimer); searchTimer = setTimeout(() => { state.search = event.target.value.trim(); state.page = 1; loadView(); }, 350); });
function customDateChanged() {
  if (state.view === 'orders') $$('[data-admin-period]').forEach((button) => button.classList.remove('active'));
  state.page = 1;
  loadView();
}
$('#admin-from').addEventListener('change', (event) => { state.from = event.target.value; customDateChanged(); });
$('#admin-to').addEventListener('change', (event) => { state.to = event.target.value; customDateChanged(); });
$('#admin-page-size').addEventListener('change', (event) => { state.pageSize = Number(event.target.value); state.page = 1; loadView(); });
$('#admin-reload').addEventListener('click', () => loadView());
$('#admin-export').addEventListener('click', exportCsv);
$('#admin-logout').addEventListener('click', async () => { try { await api('/admin/auth/logout', { method:'POST' }); } catch {} location.replace('/login.html?tab=admin'); });
loadView();
