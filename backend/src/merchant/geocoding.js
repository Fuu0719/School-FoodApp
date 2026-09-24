const { fail } = require('./validation');
const tls = require('node:tls');

// Windows school hosts use the OS certificate store rather than Node's bundle.
if (tls.setDefaultCACertificates && tls.getCACertificates) {
  tls.setDefaultCACertificates(tls.getCACertificates('system'));
}

const campus = { latitude: 24.9856141, longitude: 121.3425769 };

function addressQueries(address) {
  const trimmed = address.trim();
  const region = /^(.+?[縣市])(.+?[鄉鎮市區])(.+)$/.exec(trimmed);
  if (!region) return [trimmed];
  const street = /^(.+?(?:大道|路|街))([0-9]+(?:之[0-9]+)?)(?:號)?(.*)$/.exec(region[3]);
  if (!street) return [trimmed];
  const normalized = `${street[2]} ${street[1]} ${region[2]} ${region[1]}`;
  return normalized === trimmed ? [trimmed] : [normalized, trimmed];
}

function distanceMeters(from, to = campus) {
  const radians = (degrees) => degrees * Math.PI / 180;
  const latitudeDelta = radians(to.latitude - from.latitude);
  const longitudeDelta = radians(to.longitude - from.longitude);
  const a = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(from.latitude)) * Math.cos(radians(to.latitude)) *
    Math.sin(longitudeDelta / 2) ** 2;
  return Math.round(6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

async function geocodeAddress(address) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    for (const addressQuery of addressQueries(address)) {
      const query = new URLSearchParams({
        format: 'jsonv2',
        limit: '1',
        countrycodes: 'tw',
        q: addressQuery,
      });
      const response = await fetch(`https://nominatim.openstreetmap.org/search?${query}`, {
        headers: {
          'User-Agent': 'SchoolFoodApp/1.0 (student project)',
          'Accept-Language': 'zh-TW',
        },
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`geocoder status ${response.status}`);
      const results = await response.json();
      const latitude = Number(results[0]?.lat);
      const longitude = Number(results[0]?.lon);
      if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
        return { latitude, longitude, distanceMeters: distanceMeters({ latitude, longitude }) };
      }
    }
    throw fail(400, '無法定位此門市地址，請輸入完整的台灣地址');
  } catch (error) {
    if (error.statusCode) throw error;
    throw fail(503, '地址定位服務暫時無法使用，請稍後再試');
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = { campus, addressQueries, distanceMeters, geocodeAddress };
