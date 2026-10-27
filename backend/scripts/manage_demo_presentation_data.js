require('dotenv').config();

const { createDatabasePool } = require('../src/config/database');
const { recurringTag } = require('../src/catalog/refresh_test_foods');

const demoMerchantEmails = [
  ...Array.from({ length: 15 }, (_, index) =>
    `merchant${String(index + 1).padStart(2, '0')}@foodapp.test`),
  'seven-eleven@foodapp.test',
  'familymart@foodapp.test',
];

async function checkDemoData(pool) {
  const placeholders = demoMerchantEmails.map(() => '?').join(',');
  const [[summary]] = await pool.execute(`SELECT
    (SELECT COUNT(*) FROM users WHERE email IN
      ('member01@foodapp.test','member02@foodapp.test','member03@foodapp.test','member04@foodapp.test','member05@foodapp.test')) AS members,
    (SELECT COUNT(*) FROM merchants WHERE email IN (${placeholders}) AND status = 'active') AS merchants,
    (SELECT COUNT(*) FROM foods f JOIN stores s ON s.id = f.store_id JOIN merchants m ON m.id = s.merchant_id
      WHERE m.email IN (${placeholders}) AND f.status = 'active' AND f.deleted_at IS NULL
        AND f.stock_count > 0 AND (f.expires_at IS NULL OR f.expires_at > NOW())) AS availableFoods,
    (SELECT COUNT(*) FROM foods f JOIN stores s ON s.id = f.store_id JOIN merchants m ON m.id = s.merchant_id
      JOIN food_tags t ON t.food_id = f.id AND t.tag = ?
      WHERE m.email IN (${placeholders}) AND f.status = 'active' AND f.deleted_at IS NULL) AS recurringFoods`,
  [...demoMerchantEmails, ...demoMerchantEmails, recurringTag, ...demoMerchantEmails]);
  return Object.fromEntries(Object.entries(summary).map(([key, value]) => [key, Number(value)]));
}

async function refreshDemoData(pool) {
  const placeholders = demoMerchantEmails.map(() => '?').join(',');
  const [result] = await pool.execute(`UPDATE foods f
    JOIN stores s ON s.id = f.store_id
    JOIN merchants m ON m.id = s.merchant_id
    JOIN food_tags t ON t.food_id = f.id AND t.tag = ?
    SET f.expires_at = DATE_ADD(NOW(), INTERVAL (4 + MOD(f.id, 20)) HOUR),
        f.is_expiring_soon = 1,
        f.stock_count = GREATEST(f.stock_count, 8)
    WHERE m.email IN (${placeholders}) AND f.status = 'active' AND f.deleted_at IS NULL`,
  [recurringTag, ...demoMerchantEmails]);
  return result.affectedRows;
}

async function main() {
  const pool = createDatabasePool();
  try {
    if (process.argv.includes('--refresh')) {
      console.log(`Refreshed ${await refreshDemoData(pool)} explicitly allowlisted demo foods.`);
    }
    const summary = await checkDemoData(pool);
    console.table([summary]);
    if (summary.members < 5 || summary.merchants < 17 || summary.availableFoods < 10 || summary.recurringFoods < 1) {
      throw new Error('Demo data is incomplete. Do not reset production-like data; inspect the reported counts.');
    }
    console.log('Demo presentation data is ready. No accounts or orders were deleted.');
  } finally { await pool.end(); }
}

if (require.main === module) main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});

module.exports = { demoMerchantEmails, checkDemoData, refreshDemoData };
