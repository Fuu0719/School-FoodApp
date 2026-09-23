const select = `SELECT f.*, s.name AS store_name, s.brand, s.address AS store_address,
  s.business_hours, s.contact_phone, s.distance_meters
  FROM foods f JOIN stores s ON s.id = f.store_id JOIN merchants m ON m.id = s.merchant_id`;
const published = "s.deleted_at IS NULL AND m.status = 'active' AND f.status = 'active' AND f.stock_count > 0 AND (f.expires_at IS NULL OR f.expires_at > UTC_TIMESTAMP())";
const escapeLike = (text) => text.replace(/[!%_]/g, (character) => `!${character}`);

class CatalogRepository {
  constructor(pool) { this.pool = pool; }

  async list(filters) {
    const conditions = [published, 'f.id > ?'];
    const values = [filters.after];
    if (filters.keyword) {
      conditions.push("(f.name LIKE ? ESCAPE '!' OR s.name LIKE ? ESCAPE '!')");
      values.push(`%${escapeLike(filters.keyword)}%`, `%${escapeLike(filters.keyword)}%`);
    }
    for (const [key, column] of [['category', 'f.category'], ['storeId', 'f.store_id'], ['brand', 's.brand']]) {
      if (filters[key]) { conditions.push(`${column} = ?`); values.push(filters[key]); }
    }
    for (const [key, column] of [['maxPrice', 'f.price'], ['maxDistanceMeters', 's.distance_meters']]) {
      if (filters[key] !== undefined) { conditions.push(`${column} <= ?`); values.push(filters[key]); }
    }
    if (filters.expiringOnly) conditions.push('f.is_expiring_soon = 1');
    if (filters.openToday) {
      const day = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Taipei', weekday: 'short' }).format(new Date());
      conditions.push('EXISTS (SELECT 1 FROM store_business_weekdays w WHERE w.store_id = s.id AND w.weekday = ?)');
      values.push(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(day) + 1);
    }
    if (filters.tags.length) {
      conditions.push(`EXISTS (SELECT 1 FROM food_tags t WHERE t.food_id = f.id AND t.tag IN (${filters.tags.map(() => '?').join(',')}))`);
      values.push(...filters.tags);
    }
    const [rows] = await this.pool.execute(`${select} WHERE ${conditions.join(' AND ')} ORDER BY f.id LIMIT 51`, values);
    const page = rows.slice(0, 50);
    return { items: await this.hydrate(page), nextCursor: rows.length > 50 ? String(page.at(-1).id) : null };
  }

  async food(id) {
    const [rows] = await this.pool.execute(`${select} WHERE ${published} AND f.id = ?`, [id]);
    return (await this.hydrate(rows))[0] || null;
  }

  async hydrate(rows) {
    if (!rows.length) return [];
    const ids = rows.map((row) => String(row.id));
    const stores = [...new Set(rows.map((row) => String(row.store_id)))];
    const [tags] = await this.pool.execute(`SELECT food_id, tag FROM food_tags WHERE food_id IN (${ids.map(() => '?').join(',')}) ORDER BY tag`, ids);
    const [ingredients] = await this.pool.execute(`SELECT food_id, ingredient FROM food_ingredients WHERE food_id IN (${ids.map(() => '?').join(',')}) ORDER BY ingredient`, ids);
    const [weekdays] = await this.pool.execute(`SELECT store_id, weekday FROM store_business_weekdays WHERE store_id IN (${stores.map(() => '?').join(',')}) ORDER BY weekday`, stores);
    return rows.map((row) => ({
      id: String(row.id), name: row.name, storeId: String(row.store_id), storeName: row.store_name,
      storeBrand: row.brand, storeAddress: row.store_address, businessHours: row.business_hours,
      businessWeekdays: weekdays.filter((day) => String(day.store_id) === String(row.store_id)).map((day) => day.weekday),
      contactPhone: row.contact_phone || '', price: row.price, originalPrice: row.original_price,
      discountLabel: row.discount_label, category: row.category,
      tags: tags.filter((tag) => String(tag.food_id) === String(row.id)).map((tag) => tag.tag),
      ingredients: ingredients.filter((item) => String(item.food_id) === String(row.id)).map((item) => item.ingredient),
      nutritionTags: [], calories: row.calories, weightGrams: row.weight_grams, proteinGrams: row.protein_grams,
      fatGrams: row.fat_grams, carbsGrams: row.carbs_grams, distanceMeters: row.distance_meters,
      stockCount: row.stock_count, expiresAt: row.expires_at, isExpiringSoon: Boolean(row.is_expiring_soon),
      ecoPriorityScore: Number(row.eco_priority_score), recommendationReason: row.recommendation_reason || '',
      imageUrl: row.image_url || '', specialLabel: null,
    }));
  }

  async store(id) {
    const [rows] = await this.pool.execute(`SELECT s.id, s.name, s.brand, s.address,
      s.distance_meters AS distanceMeters, s.business_hours AS businessHours, s.contact_phone AS contactPhone
      FROM stores s JOIN merchants m ON m.id = s.merchant_id WHERE s.id = ? AND s.deleted_at IS NULL AND m.status = 'active'`, [id]);
    if (!rows.length) return null;
    const [days] = await this.pool.execute('SELECT weekday FROM store_business_weekdays WHERE store_id = ? ORDER BY weekday', [id]);
    return { ...rows[0], id: String(rows[0].id), businessWeekdays: days.map((day) => day.weekday) };
  }
}
module.exports = CatalogRepository;
