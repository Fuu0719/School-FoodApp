const goalsToDb = { maintain: 'maintain', muscleGain: 'muscle_gain', fatLoss: 'fat_loss' };
const goalsFromDb = { maintain: 'maintain', muscle_gain: 'muscleGain', fat_loss: 'fatLoss' };
const columns = `SELECT u.id, u.name, u.email, u.email_verified_at, u.phone, u.avatar_key, u.height_cm, u.weight_kg,
  u.health_goal, p.dietary_tags, p.budget_max, p.distance_limit_meters
  FROM users u LEFT JOIN user_preferences p ON p.user_id = u.id`;

function profile(row) {
  if (!row) return null;
  return {
    id: String(row.id), name: row.name, email: row.email, phone: row.phone || '',
    emailVerified: Boolean(row.email_verified_at),
    avatarKey: row.avatar_key || 'sprout',
    heightCm: row.height_cm == null ? null : Number(row.height_cm),
    weightKg: row.weight_kg == null ? null : Number(row.weight_kg),
    healthGoal: goalsFromDb[row.health_goal],
    dietaryTags: typeof row.dietary_tags === 'string'
      ? JSON.parse(row.dietary_tags) : row.dietary_tags || [],
    budgetMax: row.budget_max, distanceLimitMeters: row.distance_limit_meters,
  };
}

class UserRepository {
  constructor(pool) { this.pool = pool; }

  async transaction(work) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const result = await work(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally { connection.release(); }
  }

  async create({ name, email, passwordHash }) {
    return this.transaction(async (connection) => {
      const [result] = await connection.execute(
        'INSERT INTO users (name, email, password_hash, height_cm, weight_kg) VALUES (?, ?, ?, NULL, NULL)',
        [name, email, passwordHash]);
      await connection.execute(
        'INSERT INTO user_preferences (user_id, dietary_tags, budget_max, distance_limit_meters) VALUES (?, ?, 150, 1000)',
        [result.insertId, '[]']);
      const [rows] = await connection.execute(`${columns} WHERE u.id = ?`, [result.insertId]);
      return profile(rows[0]);
    });
  }

  async credentials(email) {
    const [rows] = await this.pool.execute(
      'SELECT id, email, password_hash, email_verified_at FROM users WHERE email = ?', [email]);
    return rows[0];
  }

  async saveEmailCode(userId, purpose, codeHash, expiresAt) {
    await this.pool.execute(`INSERT INTO member_email_codes
      (user_id, purpose, code_hash, expires_at, attempts) VALUES (?, ?, ?, ?, 0)
      ON DUPLICATE KEY UPDATE code_hash = VALUES(code_hash), expires_at = VALUES(expires_at),
      attempts = 0, created_at = CURRENT_TIMESTAMP`, [userId, purpose, codeHash, expiresAt]);
  }

  async consumeEmailCode(email, purpose, codeHash) {
    return this.transaction(async (connection) => {
      const [rows] = await connection.execute(`SELECT u.id, c.code_hash, c.expires_at, c.attempts
        FROM users u JOIN member_email_codes c ON c.user_id = u.id
        WHERE u.email = ? AND c.purpose = ? FOR UPDATE`, [email, purpose]);
      const row = rows[0];
      if (!row || row.attempts >= 5 || new Date(row.expires_at) <= new Date() || row.code_hash !== codeHash) {
        if (row && row.attempts < 5) await connection.execute(
          'UPDATE member_email_codes SET attempts = attempts + 1 WHERE user_id = ? AND purpose = ?',
          [row.id, purpose]);
        return null;
      }
      await connection.execute('DELETE FROM member_email_codes WHERE user_id = ? AND purpose = ?', [row.id, purpose]);
      return String(row.id);
    });
  }

  async verifyEmail(id) {
    await this.pool.execute('UPDATE users SET email_verified_at = COALESCE(email_verified_at, UTC_TIMESTAMP()) WHERE id = ?', [id]);
    return this.get(id);
  }

  async resetPassword(id, passwordHash) {
    await this.transaction(async (connection) => {
      await connection.execute('UPDATE users SET password_hash = ? WHERE id = ?', [passwordHash, id]);
      await connection.execute('DELETE FROM user_sessions WHERE user_id = ?', [id]);
    });
  }

  async get(id) {
    const [rows] = await this.pool.execute(`${columns} WHERE u.id = ?`, [id]);
    return profile(rows[0]);
  }

  async update(id, data) {
    return this.transaction(async (connection) => {
      await connection.execute(
        `UPDATE users SET name = ?, phone = ?, avatar_key = ?, height_cm = ?, weight_kg = ?, health_goal = ? WHERE id = ?`,
        [data.name, data.phone, data.avatarKey, data.heightCm, data.weightKg, goalsToDb[data.healthGoal], id]);
      await connection.execute(
        `INSERT INTO user_preferences (user_id, dietary_tags, budget_max, distance_limit_meters)
         VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE dietary_tags = ?, budget_max = ?, distance_limit_meters = ?`,
        [id, JSON.stringify(data.dietaryTags), data.budgetMax, data.distanceLimitMeters,
          JSON.stringify(data.dietaryTags), data.budgetMax, data.distanceLimitMeters]);
      const [rows] = await connection.execute(`${columns} WHERE u.id = ?`, [id]);
      return profile(rows[0]);
    });
  }

  async createSession(id, hash, expiresAt) {
    await this.pool.execute('DELETE FROM user_sessions WHERE user_id = ? AND expires_at <= UTC_TIMESTAMP()', [id]);
    await this.pool.execute('INSERT INTO user_sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)', [hash, id, expiresAt]);
  }

  async session(hash) {
    const [rows] = await this.pool.execute(
      'SELECT user_id FROM user_sessions WHERE token_hash = ? AND expires_at > UTC_TIMESTAMP()', [hash]);
    return rows[0] ? this.get(rows[0].user_id) : null;
  }

  async revoke(hash) {
    await this.pool.execute('DELETE FROM user_sessions WHERE token_hash = ?', [hash]);
  }
}

module.exports = UserRepository;
