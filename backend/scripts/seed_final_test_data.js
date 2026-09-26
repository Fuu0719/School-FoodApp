require('dotenv').config();

const { createDatabasePool } = require('../src/config/database');
const { hashPassword } = require('../src/auth/passwords');

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

const merchants = [
  ['campus-kitchen@foodapp.test', '校園好食光', '一般'],
  ['green-table@foodapp.test', '綠意餐桌', '一般'],
  ['daily-bento@foodapp.test', '日日餐盒', '一般'],
  ['seven-eleven@foodapp.test', '7-ELEVEN', '超商'],
  ['familymart@foodapp.test', '全家便利商店', '超商'],
];

const locations = [
  ['銘傳校門店', '桃園市龜山區德明路5號', 250],
  ['大同路店', '桃園市龜山區大同路225號', 600],
  ['中興路店', '桃園市龜山區中興路一段18號', 950],
  ['文化一路店', '桃園市龜山區文化一路10巷42弄7號', 1300],
  ['萬壽路店', '桃園市龜山區萬壽路二段123號', 1650],
  ['自強南路店', '桃園市龜山區自強南路81號', 2000],
  ['山鶯路店', '桃園市龜山區山鶯路156號', 2350],
  ['陸光路店', '桃園市龜山區陸光路72號', 2700],
  ['長壽路店', '桃園市龜山區長壽路517號', 3050],
  ['桃園火車站店', '桃園市桃園區中正路1號', 3400],
  ['建國路店', '桃園市桃園區建國路99號', 3750],
  ['復興路店', '桃園市桃園區復興路180號', 4100],
  ['春日路店', '桃園市桃園區春日路232號', 4400],
  ['民生路店', '桃園市桃園區民生路350號', 4700],
  ['南崁路店', '桃園市蘆竹區南崁路一段112號', 4950],
];

const schedules = [
  ['07:00-16:00', [1, 2, 3, 4, 5]],
  ['09:00-18:00', [1, 2, 3, 4, 5, 6]],
  ['11:00-20:00', [2, 3, 4, 5, 6, 7]],
];
const categories = ['便當', '飯糰', '麵食', '沙拉', '麵包甜點', '飲品'];
const names = {
  '便當': ['舒肥雞胸餐盒', '烤鯖魚餐盒', '蔬食豆腐餐盒'],
  '飯糰': ['鮭魚飯糰', '雞肉御飯糰', '紫米蔬菜飯糰'],
  '麵食': ['番茄雞肉義大利麵', '胡麻冷麵', '日式炒烏龍'],
  '沙拉': ['雞肉鮮蔬沙拉', '豆腐藜麥沙拉', '鮪魚蛋沙拉'],
  '麵包甜點': ['奶油餐包', '紅豆銅鑼燒', '地瓜乳酪麵包'],
  '飲品': ['無糖豆漿', '鮮奶茶', '高纖蔬果汁'],
};
const prices = [49, 59, 69, 79, 89, 99, 109, 119, 129, 139];

function coordinate(distance, bearingDegrees) {
  const earth = 6371000;
  const lat1 = 24.9856141 * Math.PI / 180;
  const lon1 = 121.3425769 * Math.PI / 180;
  const angular = distance / earth;
  const bearing = bearingDegrees * Math.PI / 180;
  const lat2 = Math.asin(Math.sin(lat1) * Math.cos(angular) +
    Math.cos(lat1) * Math.sin(angular) * Math.cos(bearing));
  const lon2 = lon1 + Math.atan2(Math.sin(bearing) * Math.sin(angular) * Math.cos(lat1),
    Math.cos(angular) - Math.sin(lat1) * Math.sin(lat2));
  return [lat2 * 180 / Math.PI, lon2 * 180 / Math.PI];
}

async function seed() {
  const pool = createDatabasePool();
  const connection = await pool.getConnection();
  try {
    const [memberHash, merchantHash] = await Promise.all([
      hashPassword('Member123!'),
      hashPassword('Store123!'),
    ]);
    await connection.beginTransaction();
    await connection.execute('DELETE FROM users');
    await connection.execute('DELETE FROM merchants');

    for (const [email, name, height, weight, goal, tags] of members) {
      const [result] = await connection.execute(
        `INSERT INTO users (name, email, password_hash, height_cm, weight_kg, health_goal)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [name, email, memberHash, height, weight, goal],
      );
      await connection.execute(
        `INSERT INTO user_preferences
          (user_id, budget_min, budget_max, distance_limit_meters, waste_reduction_enabled, avoid_ingredients, dietary_tags)
         VALUES (?, 30, ?, ?, 1, JSON_ARRAY(), ?)`,
        [result.insertId, 120 + members.findIndex((item) => item[0] === email) * 20,
          1000 + members.findIndex((item) => item[0] === email) * 1000, JSON.stringify(tags)],
      );
    }

    let locationIndex = 0;
    let foodIndex = 0;
    for (const [email, businessName, merchantType] of merchants) {
      const [merchant] = await connection.execute(
        `INSERT INTO merchants (business_name, email, password_hash, contact_phone, status)
         VALUES (?, ?, ?, '0900000000', 'active')`,
        [businessName, email, merchantHash],
      );
      for (let branch = 0; branch < 3; branch++, locationIndex++) {
        const [locationName, address, distance] = locations[locationIndex];
        const [latitude, longitude] = coordinate(distance, locationIndex * 137.5);
        const convenience = merchantType === '超商';
        const schedule = convenience ? ['00:00-23:59', [1, 2, 3, 4, 5, 6, 7]] : schedules[branch];
        const [store] = await connection.execute(
          `INSERT INTO stores
            (merchant_id, name, brand, address, latitude, longitude, distance_meters, business_hours, contact_phone)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, '03-3500000')`,
          [merchant.insertId, `${businessName}${locationName}`, convenience ? businessName : null,
            address, latitude, longitude, distance, schedule[0]],
        );
        for (const weekday of schedule[1]) {
          await connection.execute('INSERT INTO store_business_weekdays (store_id, weekday) VALUES (?, ?)',
            [store.insertId, weekday]);
        }

        for (let product = 0; product < 4; product++, foodIndex++) {
          const category = categories[foodIndex % categories.length];
          const productName = names[category][(locationIndex + product) % 3];
          const isExpiring = convenience || foodIndex % 2 === 0;
          const price = prices[foodIndex % prices.length];
          const originalPrice = isExpiring ? price + 20 + (foodIndex % 3) * 10 : null;
          const expiresAt = isExpiring ? new Date(Date.now() + (2 + foodIndex % 22) * 3600000) : null;
          const reason = isExpiring
            ? '即期優惠餐點，優先選購可減少食物浪費'
            : `${category}類熱門選擇，價格與門市距離符合一般用餐需求`;
          const [food] = await connection.execute(
            `INSERT INTO foods
              (store_id, name, category, price, original_price, discount_label, stock_count,
               calories, weight_grams, protein_grams, fat_grams, carbs_grams, expires_at,
               is_expiring_soon, eco_priority_score, recommendation_reason, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')`,
            [store.insertId, productName, category, price, originalPrice,
              isExpiring ? `即期省 NT$${originalPrice - price}` : null, 5 + foodIndex % 10,
              180 + (foodIndex % 7) * 70, 180 + (foodIndex % 5) * 50,
              8 + (foodIndex % 6) * 5, 4 + (foodIndex % 5) * 3, 25 + (foodIndex % 7) * 9,
              expiresAt, isExpiring ? 1 : 0, isExpiring ? 0.9 : 0.45, reason],
          );
          for (const tag of [category, isExpiring ? '即期優惠' : '日常餐點']) {
            await connection.execute('INSERT INTO food_tags (food_id, tag) VALUES (?, ?)', [food.insertId, tag]);
          }
          await connection.execute('INSERT INTO food_ingredients (food_id, ingredient) VALUES (?, ?)',
            [food.insertId, category === '飲品' ? '飲品原料' : '新鮮食材']);
        }
      }
    }
    await connection.commit();

    const [[counts]] = await connection.query(`SELECT
      (SELECT COUNT(*) FROM users) AS members,
      (SELECT COUNT(*) FROM merchants) AS merchants,
      (SELECT COUNT(*) FROM stores WHERE deleted_at IS NULL) AS stores,
      (SELECT COUNT(*) FROM foods WHERE status = 'active') AS foods,
      (SELECT COUNT(*) FROM foods f JOIN stores s ON s.id=f.store_id JOIN merchants m ON m.id=s.merchant_id
        WHERE m.business_name IN ('7-ELEVEN', '全家便利商店') AND f.is_expiring_soon=0) AS convenience_non_expiring`);
    const [distribution] = await connection.query(
      'SELECT category, COUNT(*) AS count, MIN(price) AS minPrice, MAX(price) AS maxPrice FROM foods GROUP BY category ORDER BY category',
    );
    console.log(JSON.stringify({ counts, distribution }, null, 2));
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
    await pool.end();
  }
}

seed().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
