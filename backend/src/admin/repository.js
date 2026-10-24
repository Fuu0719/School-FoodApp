class AdminRepository {
  constructor(pool) { this.pool = pool; }

  periodStart(period) {
    return ({
      day: 'CURRENT_DATE',
      week: 'DATE_SUB(CURRENT_DATE, INTERVAL WEEKDAY(CURRENT_DATE) DAY)',
      month: "DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')",
    })[period] || 'CURRENT_DATE';
  }

  async dashboard(period = 'day') {
    const start = this.periodStart(period);
    const [[users], [merchants], [foods], [orders], [topFoods]] = await Promise.all([
      this.pool.execute(`SELECT COUNT(*) AS total, COALESCE(SUM(created_at >= ${start}), 0) AS newCount FROM users`),
      this.pool.execute(`SELECT COUNT(*) AS total, COALESCE(SUM(status = 'active'), 0) AS active,
        COALESCE(SUM(status = 'suspended'), 0) AS suspended,
        COALESCE(SUM(created_at >= ${start}), 0) AS newCount FROM merchants`),
      this.pool.execute(`SELECT COUNT(*) AS total,
        COALESCE(SUM(status = 'active' AND deleted_at IS NULL), 0) AS active,
        COALESCE(SUM(stock_count <= 5 AND deleted_at IS NULL), 0) AS lowStock,
        COALESCE(SUM(expires_at IS NOT NULL AND expires_at <= NOW() AND deleted_at IS NULL), 0) AS expired,
        COALESCE(SUM(created_at >= ${start} AND deleted_at IS NULL), 0) AS newCount FROM foods`),
      this.pool.execute(`SELECT COUNT(*) AS total,
        COALESCE(SUM(payment_status = 'paid'), 0) AS paid,
        COALESCE(SUM(payment_status = 'pending'), 0) AS pending,
        COALESCE(SUM(payment_status IN ('failed', 'cancelled')), 0) AS unsuccessful,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_price ELSE 0 END), 0) AS revenue,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_quantity ELSE 0 END), 0) AS quantity,
        COALESCE(ROUND(AVG(CASE WHEN payment_status = 'paid' THEN total_price END)), 0) AS averageOrder,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN saved_amount ELSE 0 END), 0) AS savedAmount,
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN eco_points ELSE 0 END), 0) AS ecoPoints
        FROM purchase_orders WHERE purchased_at >= ${start}`),
      this.pool.execute(`SELECT COALESCE(JSON_UNQUOTE(JSON_EXTRACT(i.food_snapshot, '$.name')), f.name) AS name,
        SUM(i.quantity) AS quantity, SUM(i.quantity * i.unit_price) AS revenue
        FROM purchase_order_items i JOIN purchase_orders o ON o.id = i.purchase_order_id
        JOIN foods f ON f.id = i.food_id
        WHERE o.payment_status = 'paid' AND o.purchased_at >= ${start}
        GROUP BY i.food_id, name ORDER BY quantity DESC, revenue DESC LIMIT 5`),
    ]);
    return { period, users: users[0], merchants: merchants[0], foods: foods[0], orders: orders[0], topFoods };
  }

  async users() {
    const [rows] = await this.pool.execute(`SELECT u.id, u.name, u.email, u.email_verified_at AS emailVerifiedAt,
      u.created_at AS createdAt, l.merchant_id AS linkedMerchantId
      FROM users u LEFT JOIN member_merchant_links l ON l.user_id = u.id ORDER BY u.id DESC LIMIT 200`);
    return rows.map((row) => ({ ...row, id: String(row.id), linkedMerchantId: row.linkedMerchantId && String(row.linkedMerchantId) }));
  }

  async merchants() {
    const [rows] = await this.pool.execute(`SELECT m.id, m.business_name AS businessName, m.email,
      m.contact_phone AS contactPhone, m.status, m.created_at AS createdAt,
      COUNT(DISTINCT s.id) AS storeCount, COUNT(DISTINCT f.id) AS productCount
      FROM merchants m LEFT JOIN stores s ON s.merchant_id = m.id AND s.deleted_at IS NULL
      LEFT JOIN foods f ON f.store_id = s.id AND f.deleted_at IS NULL
      GROUP BY m.id ORDER BY m.id DESC LIMIT 200`);
    return rows.map((row) => ({ ...row, id: String(row.id) }));
  }

  async foods(period = 'day') {
    const start = this.periodStart(period);
    const [rows] = await this.pool.execute(`SELECT f.id, f.name, f.status, f.stock_count AS stockCount,
      f.price, f.expires_at AS expiresAt, f.created_at AS createdAt,
      s.name AS storeName, m.business_name AS merchantName,
      COALESCE(SUM(CASE WHEN o.payment_status = 'paid' THEN i.quantity ELSE 0 END), 0) AS soldQuantity,
      COALESCE(SUM(CASE WHEN o.payment_status = 'paid' THEN i.quantity * i.unit_price ELSE 0 END), 0) AS revenue
      FROM foods f JOIN stores s ON s.id = f.store_id JOIN merchants m ON m.id = s.merchant_id
      LEFT JOIN purchase_order_items i ON i.food_id = f.id
      LEFT JOIN purchase_orders o ON o.id = i.purchase_order_id AND o.purchased_at >= ${start}
      WHERE f.deleted_at IS NULL GROUP BY f.id ORDER BY soldQuantity DESC, f.id DESC LIMIT 300`);
    return rows.map((row) => ({ ...row, id: String(row.id) }));
  }

  async orders(period = 'day') {
    const start = this.periodStart(period);
    const [rows] = await this.pool.execute(`SELECT o.id, o.total_quantity AS totalQuantity,
      o.total_price AS totalPrice, o.payment_status AS paymentStatus, o.purchased_at AS purchasedAt,
      o.paid_at AS paidAt, o.saved_amount AS savedAmount, o.eco_points AS ecoPoints,
      u.name AS userName, u.email FROM purchase_orders o JOIN users u ON u.id = o.user_id
      WHERE o.purchased_at >= ${start} ORDER BY o.id DESC LIMIT 300`);
    return rows.map((row) => ({ ...row, id: String(row.id) }));
  }

  async setMerchantStatus(id, status) {
    const [result] = await this.pool.execute('UPDATE merchants SET status = ? WHERE id = ?', [status, id]);
    if (result.affectedRows > 0) return true;
    const [rows] = await this.pool.execute('SELECT id FROM merchants WHERE id = ? LIMIT 1', [id]);
    return rows.length > 0;
  }
}

module.exports = AdminRepository;
