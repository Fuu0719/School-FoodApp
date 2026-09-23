const { createHash } = require('node:crypto');

const fail = (statusCode, message) => Object.assign(new Error(message), { statusCode });
const foodColumns = `SELECT f.*, s.name AS store_name, s.deleted_at AS store_deleted_at, m.status AS merchant_status
  FROM foods f JOIN stores s ON s.id = f.store_id JOIN merchants m ON m.id = s.merchant_id`;
const asJson = (value) => typeof value === 'string' ? JSON.parse(value) : value;

class ActivityRepository {
  constructor(pool) { this.pool = pool; }

  async transaction(userId, work) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      // Serialize a member's writes, including simultaneous retries of checkout.
      const [users] = await connection.execute('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);
      if (!users.length) throw fail(401, '登入已失效，請重新登入');
      const result = await work(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally { connection.release(); }
  }

  async favorites(userId, before) {
    const [rows] = await this.pool.execute(
      `SELECT v.food_id AS foodId, v.created_at AS createdAt FROM favorites v
       JOIN foods f ON f.id = v.food_id JOIN stores s ON s.id = f.store_id
       WHERE v.user_id = ? AND v.food_id < ? AND s.deleted_at IS NULL ORDER BY v.food_id DESC LIMIT 50`, [userId, before]);
    return rows.map((row) => ({ ...row, foodId: String(row.foodId) }));
  }

  async favorite(userId, foodId, enabled) {
    return this.transaction(userId, async (connection) => {
      if (!enabled) {
        await connection.execute('DELETE FROM favorites WHERE user_id = ? AND food_id = ?', [userId, foodId]);
        return;
      }
      await this.availableFood(connection, foodId);
      await connection.execute(`INSERT INTO favorites (user_id, food_id) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE food_id = ?`, [userId, foodId, foodId]);
    });
  }

  async availableFood(connection, foodId) {
    const [rows] = await connection.execute(`${foodColumns} WHERE f.id = ?`, [foodId]);
    if (!rows.length || rows[0].store_deleted_at || rows[0].status !== 'active' || rows[0].merchant_status !== 'active') {
      throw fail(404, '餐點不存在或已下架');
    }
    return rows[0];
  }

  async history(userId) {
    const [rows] = await this.pool.execute(`SELECT h.food_id AS foodId, MAX(h.viewed_at) AS viewedAt
      FROM browsing_histories h JOIN foods f ON f.id = h.food_id JOIN stores s ON s.id = f.store_id
      WHERE h.user_id = ? AND s.deleted_at IS NULL GROUP BY h.food_id
      ORDER BY viewedAt DESC, MAX(h.id) DESC LIMIT 20`, [userId]);
    return rows.map((row) => ({ ...row, foodId: String(row.foodId) }));
  }

  async view(userId, foodId) {
    return this.transaction(userId, async (connection) => {
      await this.availableFood(connection, foodId);
      await connection.execute('DELETE FROM browsing_histories WHERE user_id = ? AND food_id = ?', [userId, foodId]);
      await connection.execute('INSERT INTO browsing_histories (user_id, food_id) VALUES (?, ?)', [userId, foodId]);
      const [older] = await connection.execute(`SELECT id FROM browsing_histories WHERE user_id = ?
        ORDER BY viewed_at DESC, id DESC LIMIT 18446744073709551615 OFFSET 20`, [userId]);
      if (older.length) {
        await connection.execute(`DELETE FROM browsing_histories WHERE user_id = ? AND id IN
          (${older.map(() => '?').join(',')})`, [userId, ...older.map((row) => row.id)]);
      }
    });
  }

  async clearHistory(userId) {
    return this.transaction(userId, (connection) => connection.execute(
      'DELETE FROM browsing_histories WHERE user_id = ?', [userId]));
  }

  async leaderboard(userId) {
    const [rows] = await this.pool.execute(`WITH scores AS (
      SELECT u.id, u.name, COALESCE(SUM(o.eco_points), 0) AS points
      FROM users u LEFT JOIN purchase_orders o ON o.user_id = u.id
      GROUP BY u.id, u.name
    ), ranked AS (
      SELECT id, name, points, ROW_NUMBER() OVER (ORDER BY points DESC, id ASC) AS rankNumber
      FROM scores
    )
    SELECT id, name, points, rankNumber FROM ranked
    WHERE rankNumber <= 3 OR id = ? ORDER BY rankNumber`, [userId]);
    return rows.map((row) => ({
      name: row.name,
      points: Number(row.points),
      rank: Number(row.rankNumber),
      isMe: String(row.id) === String(userId),
    }));
  }

  async orders(userId, before) {
    const [rows] = await this.pool.execute(`SELECT id, total_quantity AS totalQuantity,
      total_price AS totalPrice, purchased_at AS purchasedAt FROM purchase_orders
      WHERE user_id = ? AND id < ? ORDER BY id DESC LIMIT 20`, [userId, before]);
    return rows.map((row) => ({ ...row, id: String(row.id), paymentStatus: 'not_processed' }));
  }

  async order(userId, orderId, connection = this.pool) {
    const [rows] = await connection.execute(`SELECT id, total_quantity AS totalQuantity,
      total_price AS totalPrice, eco_points AS ecoPoints, saved_amount AS savedAmount,
      purchased_at AS purchasedAt FROM purchase_orders WHERE user_id = ? AND id = ?`, [userId, orderId]);
    if (!rows.length) throw fail(404, '找不到此訂單');
    const [items] = await connection.execute(`SELECT food_id AS foodId, quantity,
      unit_price AS unitPrice, original_unit_price AS originalUnitPrice,
      eco_points AS ecoPoints, food_snapshot AS foodSnapshot FROM purchase_order_items
      WHERE purchase_order_id = ? ORDER BY id`, [orderId]);
    return { ...rows[0], id: String(rows[0].id), paymentStatus: 'not_processed',
      items: items.map((item) => ({ ...item, foodId: String(item.foodId), foodSnapshot: asJson(item.foodSnapshot) })) };
  }

  async checkout(userId, requestId, items) {
    const sorted = [...items].sort((a, b) => BigInt(a.foodId) < BigInt(b.foodId) ? -1 : 1);
    const hash = createHash('sha256').update(JSON.stringify(sorted)).digest('hex');
    return this.transaction(userId, async (connection) => {
      const [previous] = await connection.execute(`SELECT id, request_hash FROM purchase_orders
        WHERE user_id = ? AND client_request_id = ?`, [userId, requestId]);
      if (previous.length) {
        if (previous[0].request_hash !== hash) throw fail(409, '此下單識別碼已用於不同商品，請重新確認購物車');
        return { replayed: true, order: await this.order(userId, previous[0].id, connection) };
      }
      // Lock in ID order so different members cannot buy the same last item.
      const [foods] = await connection.execute(`${foodColumns} WHERE f.id IN
        (${sorted.map(() => '?').join(',')}) ORDER BY f.id FOR UPDATE`, sorted.map((item) => item.foodId));
      const now = new Date();
      const weekday = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Taipei', weekday: 'short' }).format(now);
      const day = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(weekday) + 1;
      const lines = [];
      for (const item of sorted) {
        const food = foods.find((row) => String(row.id) === item.foodId);
        if (!food || food.store_deleted_at || food.status !== 'active' || food.merchant_status !== 'active' ||
            (food.expires_at && new Date(food.expires_at) <= now)) throw fail(409, '部分餐點已下架或過期');
        const [days] = await connection.execute(
          'SELECT weekday FROM store_business_weekdays WHERE store_id = ? AND weekday = ?', [food.store_id, day]);
        if (!days.length) throw fail(409, '部分店家今日未營業');
        if (food.stock_count < item.quantity) throw fail(409, '部分餐點庫存不足，請調整數量');
        const eco = (Math.round(Number(food.eco_priority_score) * 10) + (food.is_expiring_soon ? 8 : 2)) * item.quantity;
        lines.push({ food, ...item, eco });
      }
      const totalQuantity = lines.reduce((sum, line) => sum + line.quantity, 0);
      const totalPrice = lines.reduce((sum, line) => sum + line.food.price * line.quantity, 0);
      if (totalPrice > 4294967295) throw fail(400, '訂單金額超過上限');
      const ecoPoints = lines.reduce((sum, line) => sum + line.eco, 0);
      const savedAmount = lines.reduce((sum, line) => sum + (line.food.is_expiring_soon
        ? Math.max(0, (line.food.original_price ?? line.food.price) - line.food.price) * line.quantity : 0), 0);
      if (savedAmount > 4294967295) throw fail(400, '訂單折扣金額超過上限');
      const [result] = await connection.execute(`INSERT INTO purchase_orders
        (user_id, total_quantity, total_price, eco_points, saved_amount, client_request_id, request_hash)
        VALUES (?, ?, ?, ?, ?, ?, ?)`, [userId, totalQuantity, totalPrice, ecoPoints, savedAmount, requestId, hash]);
      for (const line of lines) {
        const f = line.food;
        const snapshot = { name: f.name, storeName: f.store_name, category: f.category,
          imageUrl: f.image_url, calories: f.calories, weightGrams: f.weight_grams,
          proteinGrams: f.protein_grams, fatGrams: f.fat_grams, carbsGrams: f.carbs_grams,
          isExpiringSoon: Boolean(f.is_expiring_soon) };
        await connection.execute(`INSERT INTO purchase_order_items
          (purchase_order_id, food_id, quantity, unit_price, original_unit_price, eco_points, food_snapshot)
          VALUES (?, ?, ?, ?, ?, ?, ?)`, [result.insertId, line.foodId, line.quantity, f.price,
          f.original_price, line.eco, JSON.stringify(snapshot)]);
        await connection.execute(`UPDATE foods SET
          status = CASE WHEN stock_count = ? THEN 'sold_out' ELSE status END,
          stock_count = stock_count - ? WHERE id = ?`, [line.quantity, line.quantity, line.foodId]);
      }
      return { replayed: false, order: await this.order(userId, result.insertId, connection) };
    });
  }
}

module.exports = ActivityRepository;
