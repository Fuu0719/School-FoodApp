async function checkActivitySchema(pool) {
  await pool.query('SELECT user_id, food_id FROM favorites LIMIT 0');
  await pool.query('SELECT user_id, food_id, viewed_at FROM browsing_histories LIMIT 0');
  await pool.query('SELECT avatar_key FROM users LIMIT 0');
  await pool.query(`SELECT client_request_id, request_hash, payment_status,
    merchant_trade_no, payment_token_hash, paid_at FROM purchase_orders LIMIT 0`);
  await pool.query('SELECT food_snapshot FROM purchase_order_items LIMIT 0');
  const [indexes] = await pool.query("SHOW INDEX FROM purchase_orders WHERE Key_name = 'purchase_orders_request_unique'");
  const columns = indexes.toSorted((a, b) => Number(a.Seq_in_index) - Number(b.Seq_in_index))
    .map((index) => index.Column_name);
  if (indexes.length !== 2 || indexes.some((index) => Number(index.Non_unique) !== 0) ||
      columns.join(',') !== 'user_id,client_request_id') {
    throw Object.assign(new Error('Activity migration is incomplete.'), { code: 'ACTIVITY_SCHEMA_MISSING' });
  }
}
module.exports = checkActivitySchema;
