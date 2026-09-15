const { createHash } = require('node:crypto');
const { fail } = require('./validation');
const select = `SELECT f.*, s.name AS store_name FROM foods f JOIN stores s ON s.id = f.store_id`;
const columns = ['name', 'category', 'price', 'original_price', 'stock_count', 'image_url', 'calories',
  'weight_grams', 'protein_grams', 'fat_grams', 'carbs_grams', 'expires_at', 'is_expiring_soon', 'eco_priority_score'];
const values = (p) => [p.name, p.category, p.price, p.originalPrice, p.stockCount, p.imageUrl,
  p.calories, p.weightGrams, p.proteinGrams, p.fatGrams, p.carbsGrams,
  p.expiresAt ? new Date(p.expiresAt) : null, p.isExpiringSoon, p.isExpiringSoon ? 0.8 : 0];

class MerchantRepository {
  constructor(pool) { this.pool = pool; }
  async register(data, passwordHash) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [merchant] = await connection.execute(`INSERT INTO merchants
        (business_name, email, password_hash, contact_phone, status) VALUES (?, ?, ?, ?, 'active')`,
      [data.businessName, data.email, passwordHash, data.contactPhone]);
      const [store] = await connection.execute(`INSERT INTO stores
        (merchant_id, name, address, business_hours, contact_phone) VALUES (?, ?, ?, ?, ?)`,
      [merchant.insertId, data.storeName, data.address, data.businessHours, data.contactPhone]);
      for (const day of data.businessWeekdays) {
        await connection.execute('INSERT INTO store_business_weekdays VALUES (?, ?)', [store.insertId, day]);
      }
      await connection.commit();
      return { merchantId: String(merchant.insertId), storeId: String(store.insertId), status: 'active' };
    } catch (error) { await connection.rollback(); throw error; }
    finally { connection.release(); }
  }
  async credentials(email) {
    const [rows] = await this.pool.execute('SELECT id, password_hash, status FROM merchants WHERE email = ?', [email]);
    return rows[0];
  }
  async account(id, connection = this.pool) {
    const [rows] = await connection.execute(`SELECT id, business_name AS businessName, email,
      contact_phone AS contactPhone FROM merchants WHERE id = ? AND status = 'active'`, [id]);
    if (!rows.length) return null;
    const [stores] = await connection.execute(`SELECT id, name, address, business_hours AS businessHours
      FROM stores WHERE merchant_id = ? ORDER BY id`, [id]);
    return { ...rows[0], id: String(rows[0].id), contactPhone: rows[0].contactPhone || '',
      stores: stores.map((store) => ({ ...store, id: String(store.id) })) };
  }
  async createSession(id, hash, expiresAt) {
    await this.pool.execute('DELETE FROM merchant_sessions WHERE merchant_id = ? AND expires_at <= UTC_TIMESTAMP()', [id]);
    await this.pool.execute('INSERT INTO merchant_sessions (merchant_id, token_hash, expires_at) VALUES (?, ?, ?)', [id, hash, expiresAt]);
  }
  async session(hash) {
    const [rows] = await this.pool.execute(`SELECT merchant_id FROM merchant_sessions
      WHERE token_hash = ? AND expires_at > UTC_TIMESTAMP()`, [hash]);
    return rows[0] ? this.account(rows[0].merchant_id) : null;
  }
  async revoke(hash) { await this.pool.execute('DELETE FROM merchant_sessions WHERE token_hash = ?', [hash]); }
  async transaction(merchantId, work) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [rows] = await connection.execute('SELECT status FROM merchants WHERE id = ? FOR UPDATE', [merchantId]);
      if (rows[0]?.status !== 'active') throw fail(401, '商家登入已失效');
      const result = await work(connection);
      await connection.commit();
      return result;
    } catch (error) { await connection.rollback(); throw error; }
    finally { connection.release(); }
  }
  async ownedStore(merchantId, storeId, connection) {
    const [rows] = await connection.execute('SELECT id FROM stores WHERE merchant_id = ? AND id = ?', [merchantId, storeId]);
    if (!rows.length) throw fail(404, '找不到可管理的門市');
  }
  async hydrate(row, connection) {
    const [tags] = await connection.execute('SELECT tag FROM food_tags WHERE food_id = ? ORDER BY tag', [row.id]);
    const [ingredients] = await connection.execute('SELECT ingredient FROM food_ingredients WHERE food_id = ? ORDER BY ingredient', [row.id]);
    return { id: String(row.id), storeId: String(row.store_id), storeName: row.store_name, name: row.name,
      category: row.category, price: row.price, originalPrice: row.original_price, stockCount: row.stock_count,
      imageUrl: row.image_url || '', calories: row.calories, weightGrams: row.weight_grams,
      proteinGrams: row.protein_grams, fatGrams: row.fat_grams, carbsGrams: row.carbs_grams,
      expiresAt: row.expires_at, isExpiringSoon: Boolean(row.is_expiring_soon),
      status: row.status, revision: row.merchant_revision,
      tags: tags.map((v) => v.tag), ingredients: ingredients.map((v) => v.ingredient) };
  }
  async get(merchantId, productId, connection = this.pool, lock = false) {
    const [rows] = await connection.execute(`${select} WHERE s.merchant_id = ? AND f.id = ?${lock ? ' FOR UPDATE' : ''}`, [merchantId, productId]);
    if (!rows.length) throw fail(404, '找不到可管理的商品');
    return this.hydrate(rows[0], connection);
  }
  async list(merchantId, before) {
    const [rows] = await this.pool.execute(`${select} WHERE s.merchant_id = ? AND f.id < ? ORDER BY f.id DESC LIMIT 21`, [merchantId, before]);
    const items = [];
    for (const row of rows.slice(0, 20)) items.push(await this.hydrate(row, this.pool));
    return { items, nextCursor: rows.length > 20 ? items.at(-1).id : null };
  }
  async relations(productId, data, connection) {
    await connection.execute('DELETE FROM food_tags WHERE food_id = ?', [productId]);
    await connection.execute('DELETE FROM food_ingredients WHERE food_id = ?', [productId]);
    for (const tag of data.tags) await connection.execute('INSERT INTO food_tags VALUES (?, ?)', [productId, tag]);
    for (const ingredient of data.ingredients) await connection.execute('INSERT INTO food_ingredients VALUES (?, ?)', [productId, ingredient]);
  }
  async create(merchantId, requestId, data) {
    const hash = createHash('sha256').update(JSON.stringify(data)).digest('hex');
    return this.transaction(merchantId, async (connection) => {
      await this.ownedStore(merchantId, data.storeId, connection);
      const [previous] = await connection.execute(`SELECT food_id, request_hash FROM merchant_product_requests
        WHERE merchant_id = ? AND request_id = ?`, [merchantId, requestId]);
      if (previous.length) {
        if (previous[0].request_hash !== hash) throw fail(409, '此草稿識別碼已用於不同內容');
        return { replayed: true, product: await this.get(merchantId, previous[0].food_id, connection) };
      }
      const [result] = await connection.execute(`INSERT INTO foods (store_id, ${columns.join(', ')})
        VALUES (?, ${columns.map(() => '?').join(', ')})`, [data.storeId, ...values(data)]);
      await this.relations(result.insertId, data, connection);
      await connection.execute(`INSERT INTO merchant_product_requests (merchant_id, request_id, request_hash, food_id)
        VALUES (?, ?, ?, ?)`, [merchantId, requestId, hash, result.insertId]);
      return { replayed: false, product: await this.get(merchantId, result.insertId, connection) };
    });
  }
  async update(merchantId, productId, revision, data) {
    return this.transaction(merchantId, async (connection) => {
      const current = await this.get(merchantId, productId, connection, true);
      if (current.revision !== revision) throw fail(409, '商品已更新，請重新載入');
      if (current.status === 'active') throw fail(409, '請先下架再編輯商品');
      if (current.storeId !== data.storeId) throw fail(400, '商品不可移轉門市');
      await connection.execute(`UPDATE foods SET ${columns.map((column) => `${column} = ?`).join(', ')},
        merchant_revision = merchant_revision + 1, status = 'draft' WHERE id = ?`, [...values(data), productId]);
      await this.relations(productId, data, connection);
      return this.get(merchantId, productId, connection);
    });
  }
  async status(merchantId, productId, revision, status) {
    return this.transaction(merchantId, async (connection) => {
      const current = await this.get(merchantId, productId, connection, true);
      if (current.revision !== revision) throw fail(409, '商品已更新，請重新載入');
      if (status === 'active') {
        if (current.stockCount < 1 || (current.expiresAt && new Date(current.expiresAt) <= new Date())) {
          throw fail(409, '庫存不足或保存期限已過，不可上架');
        }
        const [days] = await connection.execute('SELECT weekday FROM store_business_weekdays WHERE store_id = ?', [current.storeId]);
        if (!days.length) throw fail(409, '門市尚未設定營業日');
      }
      await connection.execute('UPDATE foods SET status = ?, merchant_revision = merchant_revision + 1 WHERE id = ?', [status, productId]);
      return this.get(merchantId, productId, connection);
    });
  }
}
module.exports = MerchantRepository;
