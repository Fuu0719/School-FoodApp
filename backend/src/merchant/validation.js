const { phone } = require('../validation/phone');
const fail = (statusCode, message) => Object.assign(new Error(message), { statusCode });
function text(value, label, max, optional = false) {
  if (typeof value !== 'string' || value.trim().length > max || (!optional && !value.trim())) {
    throw fail(400, `${label}格式不正確`);
  }
  return value.trim();
}
function id(value) {
  if (typeof value !== 'string' || !/^[1-9][0-9]{0,19}$/.test(value) || BigInt(value) > 18446744073709551615n) {
    throw fail(400, 'ID 格式不正確');
  }
  return value;
}
function integer(value, label, max = 1000000) {
  if (!Number.isInteger(value) || value < 0 || value > max) throw fail(400, `${label}須為 0 至 ${max} 的整數`);
  return value;
}
function credentials(body = {}, { registration = false } = {}) {
  const email = text(body.email, 'Email', 160).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw fail(400, 'Email 格式不正確');
  const max = registration ? 16 : 128;
  if (typeof body.password !== 'string' || body.password.length < 8 || body.password.length > max) {
    throw fail(400, registration ? '密碼長度須為 8 至 16 個字元' : '商家帳號或密碼不正確');
  }
  return { email, password: body.password };
}
function product(body = {}) {
  const category = text(body.category, '分類', 40);
  if (/[\u0000-\u001f\u007f]/.test(category)) throw fail(400, '分類不可含換行或控制字元');
  const array = (value, label, max) => {
    if (!Array.isArray(value) || value.length > 30) throw fail(400, `${label}最多 30 項`);
    return [...new Set(value.map((item) => text(item, label, max)))].sort();
  };
  const price = integer(body.price, '價格');
  const originalPrice = body.originalPrice == null ? null : integer(body.originalPrice, '原價');
  if (originalPrice != null && originalPrice < price) throw fail(400, '原價不可低於售價');
  if (typeof body.isExpiringSoon !== 'boolean') throw fail(400, '即期狀態格式不正確');
  let expiresAt = null;
  if (body.expiresAt != null) {
    if (typeof body.expiresAt !== 'string' ||
        !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(body.expiresAt)) throw fail(400, '保存期限須含 UTC 時區');
    const date = new Date(body.expiresAt);
    if (!Number.isFinite(date.getTime()) || date.getUTCFullYear() < 1000 || date.toISOString() !== body.expiresAt) throw fail(400, '保存期限格式不正確');
    expiresAt = date.toISOString();
  }
  if (body.isExpiringSoon && !expiresAt) throw fail(400, '即期餐點須填寫保存期限');
  if (body.isExpiringSoon) {
    const remaining = new Date(expiresAt).getTime() - Date.now();
    if (remaining <= 0 || remaining > 24 * 60 * 60 * 1000) {
      throw fail(400, '即期餐點保存期限須在未來 24 小時內');
    }
  }
  const imageUrl = text(body.imageUrl, '圖片網址', 600, true);
  if (imageUrl) {
    let url;
    try { url = new URL(imageUrl); } catch { throw fail(400, '圖片須使用 HTTPS 網址'); }
    if (url.protocol !== 'https:' || !url.hostname || url.username || url.password) throw fail(400, '圖片須使用 HTTPS 網址');
  }
  return { storeId: id(body.storeId), name: text(body.name, '餐點名稱', 120),
    category, price, originalPrice,
    stockCount: integer(body.stockCount, '庫存'), imageUrl,
    calories: integer(body.calories, '熱量', 10000), weightGrams: integer(body.weightGrams, '重量', 10000),
    proteinGrams: integer(body.proteinGrams, '蛋白質', 10000), fatGrams: integer(body.fatGrams, '脂肪', 10000),
    carbsGrams: integer(body.carbsGrams, '碳水', 10000),
    tags: array(body.tags, '標籤', 40), ingredients: array(body.ingredients, '食材', 60),
    expiresAt, isExpiringSoon: body.isExpiringSoon };
}
function registration(body = {}) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw fail(400, '註冊資料格式不正確');
  const auth = credentials(body, { registration: true });
  const account = { ...auth, businessName: text(body.businessName, '商家名稱', 120),
    contactPhone: phone(body.contactPhone ?? '') };
  // Older clients still send the first store during registration.
  if (body.storeName === undefined) return account;
  if (!Array.isArray(body.businessWeekdays) || !body.businessWeekdays.length || body.businessWeekdays.length > 7 ||
      body.businessWeekdays.some((day) => !Number.isInteger(day) || day < 1 || day > 7)) throw fail(400, '請選擇有效的營業日');
  return { ...auth, businessName: text(body.businessName, '商家名稱', 120),
    storeName: text(body.storeName, '門市名稱', 120), address: text(body.address, '地址', 255),
    businessHours: text(body.businessHours, '營業時間', 80), contactPhone: phone(body.contactPhone ?? ''),
    businessWeekdays: [...new Set(body.businessWeekdays)].sort() };
}
function storeInput(body = {}) {
  if (!body || typeof body !== 'object') throw fail(400, '門市資料格式不正確');
  const time = (value) => typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
  if (!time(body.opensAt) || !time(body.closesAt) || body.opensAt === body.closesAt) {
    throw fail(400, '請選擇不同的開始與結束時間（24 小時制）');
  }
  if (!Array.isArray(body.businessWeekdays) || !body.businessWeekdays.length || body.businessWeekdays.length > 7 ||
    body.businessWeekdays.some((day) => !Number.isInteger(day) || day < 1 || day > 7)) throw fail(400, '請選擇有效的營業日');
  return { storeName: text(body.storeName, '門市名稱', 120), address: text(body.address, '地址', 255),
    contactPhone: phone(body.contactPhone ?? ''),
    businessHours: `${body.opensAt}-${body.closesAt}`, businessWeekdays: [...new Set(body.businessWeekdays)].sort() };
}
module.exports = { fail, text, id, integer, credentials, product, registration, storeInput };
