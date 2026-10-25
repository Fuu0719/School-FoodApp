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
        COALESCE(SUM(status = 'paused'), 0) AS paused,
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
      this.pool.execute(`SELECT f.name,
        SUM(i.quantity) AS quantity, SUM(i.quantity * i.unit_price) AS revenue
        FROM purchase_order_items i JOIN purchase_orders o ON o.id = i.purchase_order_id
        JOIN foods f ON f.id = i.food_id
        WHERE o.payment_status = 'paid' AND o.purchased_at >= ${start}
        GROUP BY f.id, f.name ORDER BY quantity DESC, revenue DESC LIMIT 5`),
    ]);
    return { period, users: users[0], merchants: merchants[0], foods: foods[0], orders: orders[0], topFoods };
  }

  pagination(total, filters) {
    return { page: filters.page, pageSize: filters.pageSize, total: Number(total),
      totalPages: Math.max(1, Math.ceil(Number(total) / filters.pageSize)) };
  }

  async users(filters = { page: 1, pageSize: 25, search: '', from: null, to: null }) {
    const where = [], args = [];
    if (filters.search) { where.push('(u.name LIKE ? OR u.email LIKE ?)'); args.push(`%${filters.search}%`, `%${filters.search}%`); }
    if (filters.from) { where.push('u.created_at >= ?'); args.push(filters.from); }
    if (filters.to) { where.push('u.created_at < DATE_ADD(?, INTERVAL 1 DAY)'); args.push(filters.to); }
    const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [[counts], [rows]] = await Promise.all([
      this.pool.execute(`SELECT COUNT(*) AS total FROM users u ${clause}`, args),
      this.pool.execute(`SELECT u.id, u.name, u.email, u.email_verified_at AS emailVerifiedAt,
        u.created_at AS createdAt, l.merchant_id AS linkedMerchantId
        FROM users u LEFT JOIN member_merchant_links l ON l.user_id = u.id ${clause}
        ORDER BY u.id DESC LIMIT ? OFFSET ?`, [...args, filters.pageSize, (filters.page - 1) * filters.pageSize]),
    ]);
    return { items: rows.map((row) => ({ ...row, id: String(row.id), linkedMerchantId: row.linkedMerchantId && String(row.linkedMerchantId) })),
      pagination: this.pagination(counts[0].total, filters) };
  }

  async merchants(filters = { page: 1, pageSize: 25, search: '', from: null, to: null }) {
    const where = [], args = [];
    if (filters.search) { where.push('(m.business_name LIKE ? OR m.email LIKE ? OR m.contact_phone LIKE ?)'); args.push(...Array(3).fill(`%${filters.search}%`)); }
    if (filters.from) { where.push('m.created_at >= ?'); args.push(filters.from); }
    if (filters.to) { where.push('m.created_at < DATE_ADD(?, INTERVAL 1 DAY)'); args.push(filters.to); }
    const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [[counts], [rows]] = await Promise.all([
      this.pool.execute(`SELECT COUNT(*) AS total FROM merchants m ${clause}`, args),
      this.pool.execute(`SELECT m.id, m.business_name AS businessName, m.email,
      m.contact_phone AS contactPhone, m.status, m.created_at AS createdAt,
      COUNT(DISTINCT s.id) AS storeCount, COUNT(DISTINCT f.id) AS productCount
      FROM merchants m LEFT JOIN stores s ON s.merchant_id = m.id AND s.deleted_at IS NULL
      LEFT JOIN foods f ON f.store_id = s.id AND f.deleted_at IS NULL ${clause}
      GROUP BY m.id ORDER BY m.id DESC LIMIT ? OFFSET ?`, [...args, filters.pageSize, (filters.page - 1) * filters.pageSize]),
    ]);
    return { items: rows.map((row) => ({ ...row, id: String(row.id) })), pagination: this.pagination(counts[0].total, filters) };
  }

  async foods(filters = { page: 1, pageSize: 25, search: '', from: null, to: null }) {
    const where = ['f.deleted_at IS NULL'], whereArgs = [], sales = [], salesArgs = [];
    if (filters.search) { where.push('(f.name LIKE ? OR s.name LIKE ? OR m.business_name LIKE ?)'); whereArgs.push(...Array(3).fill(`%${filters.search}%`)); }
    if (filters.from) { sales.push('o.purchased_at >= ?'); salesArgs.push(filters.from); }
    if (filters.to) { sales.push('o.purchased_at < DATE_ADD(?, INTERVAL 1 DAY)'); salesArgs.push(filters.to); }
    const salesClause = sales.length ? `AND ${sales.join(' AND ')}` : '';
    const countSql = `SELECT COUNT(*) AS total FROM foods f JOIN stores s ON s.id = f.store_id
      JOIN merchants m ON m.id = s.merchant_id WHERE ${where.join(' AND ')}`;
    const dataSql = `SELECT f.id, f.name, f.status, f.stock_count AS stockCount,
      f.price, f.expires_at AS expiresAt, f.created_at AS createdAt,
      s.name AS storeName, m.business_name AS merchantName,
      COALESCE(SUM(CASE WHEN o.payment_status = 'paid' THEN i.quantity ELSE 0 END), 0) AS soldQuantity,
      COALESCE(SUM(CASE WHEN o.payment_status = 'paid' THEN i.quantity * i.unit_price ELSE 0 END), 0) AS revenue
      FROM foods f JOIN stores s ON s.id = f.store_id JOIN merchants m ON m.id = s.merchant_id
      LEFT JOIN purchase_order_items i ON i.food_id = f.id
      LEFT JOIN purchase_orders o ON o.id = i.purchase_order_id ${salesClause}
      WHERE ${where.join(' AND ')} GROUP BY f.id ORDER BY soldQuantity DESC, f.id DESC LIMIT ? OFFSET ?`;
    const [[counts], [rows]] = await Promise.all([
      this.pool.execute(countSql, whereArgs),
      this.pool.execute(dataSql, [...salesArgs, ...whereArgs, filters.pageSize, (filters.page - 1) * filters.pageSize]),
    ]);
    return { items: rows.map((row) => ({ ...row, id: String(row.id) })), pagination: this.pagination(counts[0].total, filters) };
  }

  async orders(filters = { page: 1, pageSize: 25, search: '', from: null, to: null }) {
    const where = [], args = [];
    if (filters.search) {
      const term = `%${filters.search}%`;
      where.push('(u.name LIKE ? OR u.email LIKE ? OR CAST(o.id AS CHAR) = ?)');
      args.push(term, term, filters.search);
    }
    if (filters.from) { where.push('o.purchased_at >= ?'); args.push(filters.from); }
    if (filters.to) { where.push('o.purchased_at < DATE_ADD(?, INTERVAL 1 DAY)'); args.push(filters.to); }
    const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [[counts], [rows]] = await Promise.all([
      this.pool.execute(`SELECT COUNT(*) AS total FROM purchase_orders o JOIN users u ON u.id = o.user_id ${clause}`, args),
      this.pool.execute(`SELECT o.id, o.total_quantity AS totalQuantity,
      o.total_price AS totalPrice, o.payment_status AS paymentStatus, o.purchased_at AS purchasedAt,
      o.paid_at AS paidAt, o.saved_amount AS savedAmount, o.eco_points AS ecoPoints,
      u.name AS userName, u.email FROM purchase_orders o JOIN users u ON u.id = o.user_id
      ${clause} ORDER BY o.id DESC LIMIT ? OFFSET ?`, [...args, filters.pageSize, (filters.page - 1) * filters.pageSize]),
    ]);
    return { items: rows.map((row) => ({ ...row, id: String(row.id) })), pagination: this.pagination(counts[0].total, filters) };
  }

  async setMerchantStatus(id, status) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [rows] = await connection.execute('SELECT id, status FROM merchants WHERE id = ? FOR UPDATE', [id]);
      if (!rows.length) {
        await connection.rollback();
        return false;
      }
      if (rows[0].status !== status) {
        await connection.execute('UPDATE merchants SET status = ? WHERE id = ?', [status, id]);
      }
      if (status === 'paused') {
        await connection.execute('DELETE FROM merchant_sessions WHERE merchant_id = ?', [id]);
      }
      await connection.commit();
      return true;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }
}

module.exports = AdminRepository;
