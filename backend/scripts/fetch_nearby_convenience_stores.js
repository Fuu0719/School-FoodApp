const { distanceMeters, campus } = require('../src/merchant/geocoding');

const bounds = { south: 24.9406, west: 121.2930, north: 25.0306, east: 121.3922 };
const verifiedFallback = [
  ['全家便利商店', '龜山銘園店', 24.9840818, 121.3413535, '桃園市龜山區銘園街'],
  ['全家便利商店', '龜山銘傳店', 24.9893104, 121.3439794, '桃園市龜山區德明路105;107號'],
  ['全家便利商店', '龜山自強店', 24.9928833, 121.3393582, '桃園市龜山區自強南路71號'],
  ['全家便利商店', '龜山幸福店', 24.9872811, 121.3341587, '桃園市龜山區幸福一街24號'],
  ['全家便利商店', '龜山新明德店', 24.9936625, 121.3376534, '桃園市龜山區明德路'],
  ['7-ELEVEN', '大傳門市', 24.9881238, 121.3478848, '桃園市龜山區大同路357號'],
  ['7-ELEVEN', '同銘門市', 24.9906039, 121.3440770, '桃園市龜山區大同路212號'],
  ['7-ELEVEN', '萬壽門市', 24.9942738, 121.3353712, '桃園市龜山區萬壽路二段1057號'],
  ['7-ELEVEN', '新龜山門市', 24.9936373, 121.3322476, '桃園市龜山區萬壽路二段1170號'],
  ['7-ELEVEN', '山興門市', 24.9827431, 121.3333868, '桃園市龜山區明興街223號'],
  ['7-ELEVEN', '山鶯門市', 24.9806510, 121.3306474, '桃園市龜山區山鶯路372號'],
].map(([brand, branch, latitude, longitude, address], index) => ({
  source: `OpenStreetMap verified fallback ${index + 1}`, brand, branch,
  name: `${brand} ${branch}`, address, latitude, longitude,
  distanceMeters: distanceMeters({ latitude, longitude }),
}));

function decode(value = '') {
  return value.replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
}

function tagsFrom(xml) {
  return Object.fromEntries([...xml.matchAll(/<tag k="([^"]+)" v="([^"]*)"\s*\/>/g)]
    .map((match) => [decode(match[1]), decode(match[2])]));
}

function storeFromNode(attributes, body) {
  const tags = tagsFrom(body);
  const latitude = Number(/lat="([^"]+)"/.exec(attributes)?.[1]);
  const longitude = Number(/lon="([^"]+)"/.exec(attributes)?.[1]);
  const brandText = `${tags.brand || ''} ${tags['brand:en'] || ''} ${tags.name || ''}`;
  const brand = /familymart|全家便利商店|全家/i.test(brandText)
    ? '全家便利商店' : /7-?eleven/i.test(brandText) ? '7-ELEVEN' : '';
  const rawName = tags.branch || tags.name || '';
  const branch = rawName.replace(/^(7-?eleven|全家便利商店|全家)\s*/i, '').trim();
  const structuredAddress = [tags['addr:city'], tags['addr:district'], tags['addr:street'], tags['addr:housenumber']]
    .filter(Boolean).join('');
  const distance = distanceMeters({ latitude, longitude });
  return {
    source: `OpenStreetMap node/${/id="([^"]+)"/.exec(attributes)?.[1]}`,
    brand, branch, name: branch ? `${brand} ${branch}` : '',
    address: structuredAddress || tags['addr:full'] || `座標 ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`,
    latitude, longitude, distanceMeters: distance,
  };
}

async function fetchTile(south, west, north, east) {
  const url = `https://api.openstreetmap.org/api/0.6/map?bbox=${west},${south},${east},${north}`;
  let response;
  for (let attempt = 0; attempt < 4; attempt++) {
    if (attempt) await new Promise((resolve) => setTimeout(resolve, attempt * 1500));
    response = await fetch(url, { headers: { 'user-agent': 'SchoolFoodApp/1.0 student-project' } });
    if (response.ok) break;
  }
  if (!response?.ok) throw new Error(`OpenStreetMap tile failed: ${response?.status}`);
  const xml = await response.text();
  return [...xml.matchAll(/<node\s+([^>]+)>([\s\S]*?)<\/node>/g)]
    .filter((match) => /<tag k="shop" v="convenience"\s*\/>/.test(match[2]))
    .map((match) => storeFromNode(match[1], match[2]));
}

async function fetchNearbyStores() {
  const divisions = 5;
  const stores = [];
  for (let row = 0; row < divisions; row++) {
    for (let column = 0; column < divisions; column++) {
      const south = bounds.south + (bounds.north - bounds.south) * row / divisions;
      const north = bounds.south + (bounds.north - bounds.south) * (row + 1) / divisions;
      const west = bounds.west + (bounds.east - bounds.west) * column / divisions;
      const east = bounds.west + (bounds.east - bounds.west) * (column + 1) / divisions;
      stores.push(...await fetchTile(south, west, north, east));
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  const unique = new Map();
  for (const store of stores) {
    if (!store.brand || !store.branch || !Number.isFinite(store.latitude) || store.distanceMeters > 5000) continue;
    unique.set(store.source, store);
  }
  return [...unique.values()].sort((a, b) => a.distanceMeters - b.distanceMeters ||
    a.name.localeCompare(b.name, 'zh-TW'));
}

if (require.main === module) {
  fetchNearbyStores().then((stores) => console.log(JSON.stringify({ campus, count: stores.length, stores }, null, 2)))
    .catch((error) => { console.error(error); process.exitCode = 1; });
}

module.exports = { fetchNearbyStores };
module.exports.verifiedFallback = verifiedFallback;
