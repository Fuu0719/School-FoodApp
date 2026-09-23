require('dotenv').config();

const createApp = require('./app');
const { createDatabasePool } = require('./config/database');
const UserRepository = require('./auth/user_repository');

const port = Number(process.env.PORT || 3000);
const pool = createDatabasePool();

async function start() {
  await pool.query('SELECT token_hash FROM user_sessions LIMIT 0');
  await require('./activity/check_schema')(pool);
  await require('./merchant/check_schema')(pool);
  const app = createApp({ userRepository: new UserRepository(pool) });
  const server = app.listen(port, process.env.HOST || '127.0.0.1', () => {
    console.log(`膳解人意 API running on port ${port}`);
  });
  const shutdown = () => server.close(() => { pool.end().then(() => process.exit(0)); });
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
  server.on('error', async (error) => {
    console.error('API startup failed:', error.code);
    await pool.end();
    process.exitCode = 1;
  });
}

start().catch(async (error) => {
  console.error('Database startup check failed:', error.code,
    'Check DB settings and apply missing database migrations (001, 002, 003, 004).');
  await pool.end();
  process.exitCode = 1;
});
