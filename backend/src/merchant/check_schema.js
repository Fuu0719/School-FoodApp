module.exports = async function checkMerchantSchema(pool) {
  try {
    await pool.query('SELECT deleted_at FROM stores LIMIT 0');
  } catch (error) {
    if (error.code === 'ER_BAD_FIELD_ERROR') {
      throw Object.assign(new Error('Apply backend/database/migrations/004_store_deletion.sql before starting the API.'),
        { code: 'STORE_DELETION_SCHEMA_MISSING' });
    }
    throw error;
  }
  await pool.query('SELECT token_hash, merchant_id, expires_at FROM merchant_sessions LIMIT 0');
  await pool.query('SELECT merchant_id, request_id, request_hash, food_id FROM merchant_product_requests LIMIT 0');
  await pool.query('SELECT merchant_revision FROM foods LIMIT 0');
};
