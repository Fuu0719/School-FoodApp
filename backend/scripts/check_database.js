require('dotenv').config();
const { createDatabasePool } = require('../src/config/database');
const pool = createDatabasePool();

async function main() {
  try {
    const [rows] = await pool.query('SELECT DATABASE() AS db, @@port AS port, CURRENT_USER() AS account');
    console.table(rows);
    await pool.query('SELECT token_hash FROM user_sessions LIMIT 0');
    await pool.query('SELECT email_verified_at FROM users LIMIT 0');
    await pool.query('SELECT code_hash FROM member_email_codes LIMIT 0');
    await require('../src/activity/check_schema')(pool);
    await require('../src/merchant/check_schema')(pool);
    console.log('Database, member activity and merchant management tables are ready.');
  } catch (error) {
    console.error('Database check failed:', error.code);
    console.error('Check .env and apply all missing SQL migrations, including 005_member_email.sql, as the database administrator.');
    process.exitCode = 1;
  } finally { await pool.end(); }
}
main();
