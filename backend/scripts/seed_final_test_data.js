require('dotenv').config();

const { createDatabasePool } = require('../src/config/database');
const { hashPassword } = require('../src/auth/passwords');
const { fetchNearbyStores, verifiedFallback } = require('./fetch_nearby_convenience_stores');

if (!process.argv.includes('--reset-confirmed')) {
  console.error('Refusing to erase data. Run with --reset-confirmed after creating a backup.');
  process.exit(2);
}

const members = [
  ['member01@foodapp.test', '王小美', 158, 50, 'fat_loss', ['低脂', '蔬食']],
  ['member02@foodapp.test', '陳志明', 175, 70, 'muscle_gain', ['高蛋白', '便當']],
  ['member03@foodapp.test', '林怡君', 163, 54, 'maintain', ['清爽', '沙拉']],
  ['member04@foodapp.test', '張家豪', 180, 78, 'muscle_gain', ['麵食', '高蛋白']],
  ['member05@foodapp.test', '李佳穎', 168, 58, 'maintain', ['甜點', '飲品']],
];

const merchantNames = [
  '校園好食光', '綠意餐桌', '日日餐盒', '山丘早午餐', '元氣便當',
  '小巷麵館', '鮮食工坊', '暖日廚房', '蔬活日常', '好味食堂',
  '晨光餐室', '米香小舖', '健康盒子', '午後甜點', '清爽茶飲',
];
const storeCounts = [3, 1, 2, 3, 2, 1, 3, 2, 2, 3, 1, 2, 3, 1, 2];
const schedules = [
  ['06:30-14:30', [1, 2, 3, 4, 5]], ['08:00-17:00', [1, 2, 3, 4, 5, 6]],
  ['10:00-19:00', [1, 2, 3, 4, 5, 6, 7]], ['11:00-20:00', [2, 3, 4, 5, 6, 7]],
  ['12:00-21:00', [1, 2, 3, 4, 5, 6, 7]],
];
const overnightSchedules = [['20:00-03:00', [1, 2, 3, 4, 5]], ['22:00-06:00', [5, 6, 7]], ['18:00-02:00', [1, 2, 3, 4, 5, 6, 7]]];
const categories = ['便當', '飯糰', '麵食', '沙拉', '麵包甜點', '飲品'];
const names = {
  '便當': ['舒肥雞胸餐盒', '烤鯖魚餐盒', '蔬食豆腐餐盒'], '飯糰': ['鮭魚飯糰', '雞肉御飯糰', '紫米蔬菜飯糰'],
  '麵食': ['番茄雞肉義大利麵', '胡麻冷麵', '日式炒烏龍'], '沙拉': ['雞肉鮮蔬沙拉', '豆腐藜麥沙拉', '鮪魚蛋沙拉'],
  '麵包甜點': ['奶油餐包', '紅豆銅鑼燒', '地瓜乳酪麵包'], '飲品': ['無糖豆漿', '鮮奶茶', '高纖蔬果汁'],
};
const prices = [49, 59, 69, 79, 89, 99, 109, 119, 129, 139];

function coordinate(distance, bearingDegrees) {
  const earth = 6371000;
  const lat1 = 24.9856141 * Math.PI / 180;
  const lon1 = 121.3425769 * Math.PI / 180;
  const angular = distance / earth;
  const bearing = bearingDegrees * Math.PI / 180;
  const lat2 = Math.asin(Math.sin(lat1) * Math.cos(angular) + Math.cos(lat1) * Math.sin(angular) * Math.cos(bearing));
  const lon2 = lon1 + Math.atan2(Math.sin(bearing) * Math.sin(angular) * Math.cos(lat1), Math.cos(angular) - Math.sin(lat1) * Math.sin(lat2));
  return [lat2 * 180 / Math.PI, lon2 * 180 / Math.PI];
}

async function insertStore(connection, merchantId, data, storeIndex, foodCounter, convenience = false) {
  const [store] = await connection.execute(
    `INSERT INTO stores (merchant_id, name, brand, address, latitude, longitude, distance_meters, business_hours, contact_phone)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, '03-3500000')`,
    [merchantId, data.name, data.brand || null, data.address, data.latitude, data.longitude,
      data.distanceMeters, data.schedule[0]],
  );
  for (const weekday of data.schedule[1]) {
    await connection.execute('INSERT INTO store_business_weekdays (store_id, weekday) VALUES (?, ?)', [store.insertId, weekday]);
  }
  for (let product = 0; product < 15; product++, foodCounter.value++) {
    const index = foodCounter.value;
    const category = categories[(storeIndex + product) % categories.length];
    const productName = `${names[category][(storeIndex + product) % 3]} ${String(product + 1).padStart(2, '0')}`;
    const isExpiring = convenience || index % 3 === 0;
    const price = prices[index % prices.length];
    const originalPrice = isExpiring ? price + 20 + (index % 3) * 10 : null;
    const expiresAt = isExpiring ? new Date(Date.now() + (4 + index % 20) * 3600000) : null;
    const reason = isExpiring ? '24 小時內即期優惠，優先選購可減少食物浪費' : `${category}類餐點，價格與距離適合一般用餐需求`;
    const [food] = await connection.execute(
      `INSERT INTO foods (store_id, name, category, price, original_price, discount_label, stock_count,
       calories, weight_grams, protein_grams, fat_grams, carbs_grams, expires_at, is_expiring_soon,
       eco_priority_score, recommendation_reason, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')`,
      [store.insertId, productName, category, price, originalPrice, isExpiring ? `即期省 NT$${originalPrice - price}` : null,
        5 + index % 10, 180 + index % 7 * 70, 180 + index % 5 * 50, 8 + index % 6 * 5,
        4 + index % 5 * 3, 25 + index % 7 * 9, expiresAt, isExpiring ? 1 : 0,
        isExpiring ? 0.9 : 0.45, reason],
    );
    const tags = [category, isExpiring ? '即期優惠' : '日常餐點'];
    if (convenience) tags.push('每日即期測試');
    for (const tag of tags) await connection.execute('INSERT INTO food_tags (food_id, tag) VALUES (?, ?)', [food.insertId, tag]);
    await connection.execute('INSERT INTO food_ingredients (food_id, ingredient) VALUES (?, ?)',
      [food.insertId, category === '飲品' ? '飲品原料' : '新鮮食材']);
  }
}

async function seed() {
  console.log('正在取得桃園銘傳大學 5 公里內的 7-ELEVEN 與全家門市...');
  let convenienceStores;
  let convenienceSource = 'OpenStreetMap live 5 km query';
  try {
    convenienceStores = await fetchNearbyStores();
  } catch (error) {
    console.warn(`即時地圖查詢失敗，改用已核對快照：${error.message}`);
    convenienceStores = verifiedFallback;
    convenienceSource = 'verified fallback snapshot (live source throttled)';
  }
  if (!convenienceStores.length) throw new Error('No nearby convenience stores were found; database was not changed.');
  const pool = createDatabasePool();
  const connection = await pool.getConnection();
  try {
    const [memberHash, merchantHash] = await Promise.all([hashPassword('Member123!'), hashPassword('Store123!')]);
    await connection.beginTransaction();
    await connection.execute('DELETE FROM users');
    await connection.execute('DELETE FROM merchants');
    for (let i = 0; i < members.length; i++) {
      const [email, name, height, weight, goal, tags] = members[i];
      const [result] = await connection.execute(
        'INSERT INTO users (name, email, password_hash, height_cm, weight_kg, health_goal) VALUES (?, ?, ?, ?, ?, ?)',
        [name, email, memberHash, height, weight, goal]);
      await connection.execute(`INSERT INTO user_preferences
        (user_id, budget_min, budget_max, distance_limit_meters, waste_reduction_enabled, avoid_ingredients, dietary_tags)
        VALUES (?, 30, ?, ?, 1, JSON_ARRAY(), ?)`, [result.insertId, 120 + i * 20, 1000 + i * 1000, JSON.stringify(tags)]);
    }
    const foodCounter = { value: 0 };
    let storeIndex = 0;
    let overnightIndex = 0;
    for (let merchantIndex = 0; merchantIndex < merchantNames.length; merchantIndex++) {
      const businessName = merchantNames[merchantIndex];
      const [merchant] = await connection.execute(
        `INSERT INTO merchants (business_name, email, password_hash, contact_phone, status)
         VALUES (?, ?, ?, '0900000000', 'active')`,
        [businessName, `merchant${String(merchantIndex + 1).padStart(2, '0')}@foodapp.test`, merchantHash]);
      for (let branch = 0; branch < storeCounts[merchantIndex]; branch++, storeIndex++) {
        const distance = 200 + storeIndex * 155 % 4700;
        const [latitude, longitude] = coordinate(distance, storeIndex * 137.5);
        const useOvernight = [4, 17, 28].includes(storeIndex);
        const schedule = useOvernight ? overnightSchedules[overnightIndex++] : schedules[storeIndex % schedules.length];
        await insertStore(connection, merchant.insertId, {
          name: `${businessName}${['一店', '二店', '三店'][branch]}`,
          address: `桃園銘傳大學周邊測試地址 ${storeIndex + 1} 號`, latitude, longitude, distanceMeters: distance, schedule,
        }, storeIndex, foodCounter);
      }
    }
    for (const brand of ['7-ELEVEN', '全家便利商店']) {
      const [merchant] = await connection.execute(
        `INSERT INTO merchants (business_name, email, password_hash, contact_phone, status)
         VALUES (?, ?, ?, '0800000000', 'active')`,
        [brand, brand === '7-ELEVEN' ? 'seven-eleven@foodapp.test' : 'familymart@foodapp.test', merchantHash]);
      for (const data of convenienceStores.filter((store) => store.brand === brand)) {
        await insertStore(connection, merchant.insertId, {
          ...data, schedule: ['00:00-23:59', [1, 2, 3, 4, 5, 6, 7]],
        }, storeIndex++, foodCounter, true);
      }
    }
    await connection.commit();
    const [[counts]] = await connection.query(`SELECT
      (SELECT COUNT(*) FROM users) AS members, (SELECT COUNT(*) FROM merchants) AS merchants,
      (SELECT COUNT(*) FROM stores WHERE deleted_at IS NULL) AS stores,
      (SELECT COUNT(*) FROM foods WHERE status = 'active') AS foods,
      (SELECT COUNT(*) FROM stores WHERE business_hours IN ('20:00-03:00','22:00-06:00','18:00-02:00')) AS overnightStores`);
    const [brands] = await connection.query(`SELECT brand, COUNT(*) AS stores, MIN(distance_meters) AS nearest,
      MAX(distance_meters) AS farthest FROM stores WHERE brand IS NOT NULL GROUP BY brand ORDER BY brand`);
    console.log(JSON.stringify({ counts, brands, osmStores: convenienceStores.length, convenienceSource,
      credentials: { members: 'member01..05@foodapp.test / Member123!', merchants: 'merchant01..15@foodapp.test / Store123!' } }, null, 2));
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
    await pool.end();
  }
}

seed().catch((error) => { console.error(error); process.exitCode = 1; });
