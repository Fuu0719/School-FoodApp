const recurringTag = '每日即期測試';

async function refreshRecurringTestFoods(pool) {
  const [result] = await pool.execute(
    `UPDATE foods f
       JOIN food_tags t ON t.food_id = f.id AND t.tag = ?
     SET f.expires_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL (4 + MOD(f.id, 20)) HOUR),
         f.is_expiring_soon = 1,
         f.stock_count = IF(f.stock_count = 0, 8 + MOD(f.id, 8), f.stock_count)
     WHERE f.status = 'active'
       AND (f.expires_at IS NULL OR f.expires_at <= UTC_TIMESTAMP())`,
    [recurringTag],
  );
  return result.affectedRows;
}

async function startTestFoodRefresh(pool, options = {}) {
  if (process.env.TEST_DATA_AUTO_REFRESH !== 'true') return () => {};
  const refresh = async () => {
    const count = await refreshRecurringTestFoods(pool);
    if (count) console.log(`Refreshed ${count} recurring convenience test foods.`);
  };
  await refresh();
  const timer = setInterval(
    () => refresh().catch((error) => console.error('Test food refresh failed:', error.code || error.message)),
    options.intervalMs || 60 * 60 * 1000,
  );
  timer.unref();
  return () => clearInterval(timer);
}

module.exports = { recurringTag, refreshRecurringTestFoods, startTestFoodRefresh };
