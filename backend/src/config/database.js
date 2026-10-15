const mysql = require('mysql2/promise');

function createDatabasePool() {
  return mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'shan_jie_ren_yi',
    waitForConnections: true,
    connectionLimit: 10,
    // School MySQL timestamps are stored and displayed in Taiwan local time.
    // Parse them with the same offset before JSON serializes Date values to UTC.
    timezone: '+08:00',
    supportBigNumbers: true,
    bigNumberStrings: true,
  });
}

module.exports = {
  createDatabasePool,
};
