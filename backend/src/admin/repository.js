class AdminRepository {
  constructor(pool) { this.pool = pool; }

  async dashboard() {
    const [[users], [merchants], [foods], [orders]] = await Promise.all([
      this.pool.execute('SELECT COUNT(*) AS total FROM users'),
      this.pool.execute("SELECT COUNT(*) AS total, SUM(status = 'active') AS active FROM merchants"),
      this.pool.execute("SELECT COUNT(*) AS total, SUM(status = 'active' AND deleted_at IS NULL) AS active FROM foods"),
      this.pool.execute("SELECT COUNT(*) AS total, COALESCE(SUM(payment_status = 'paid'), 0) AS paid, COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total_price ELSE 0 END), 0) AS revenue FROM purchase_orders"),
    ]);
    return { users: users[0], merchants: merchants[0], foods: foods[0], orders: orders[0] };
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

  async foods() {
    const [rows] = await this.pool.execute(`SELECT f.id, f.name, f.status, f.stock_count AS stockCount,
      f.price, f.expires_at AS expiresAt, s.name AS storeName, m.business_name AS merchantName
      FROM foods f JOIN stores s ON s.id = f.store_id JOIN merchants m ON m.id = s.merchant_id
      WHERE f.deleted_at IS NULL ORDER BY f.id DESC LIMIT 300`);
    return rows.map((row) => ({ ...row, id: String(row.id) }));
  }

  async orders() {
    const [rows] = await this.pool.execute(`SELECT o.id, o.total_quantity AS totalQuantity,
      o.total_price AS totalPrice, o.payment_status AS paymentStatus, o.purchased_at AS purchasedAt,
      u.email FROM purchase_orders o JOIN users u ON u.id = o.user_id ORDER BY o.id DESC LIMIT 200`);
    return rows.map((row) => ({ ...row, id: String(row.id) }));
  }

  async setMerchantStatus(id, status) {
    const [result] = await this.pool.execute('UPDATE merchants SET status = ? WHERE id = ?', [status, id]);
    return result.affectedRows > 0;
  }
}

module.exports = AdminRepository;
