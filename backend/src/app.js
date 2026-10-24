const cors = require('cors');
const express = require('express');
const routes = require('./routes');
const authRoutes = require('./auth/routes');
const UserRepository = require('./auth/user_repository');
const { createDatabasePool } = require('./config/database');
const { isIP } = require('node:net');
const { createMailer } = require('./email/mailer');
const path = require('node:path');

function createApp({ userRepository, mailer, enablePrototypeRoutes = false,
  allowedClientIps = (process.env.API_ALLOWED_IPS || '').split(',').map((ip) => ip.trim()).filter(Boolean),
} = {}) {
  const app = express();
  const resolvedUserRepository = userRepository || new UserRepository(createDatabasePool());
  app.use((req, res, next) => {
    res.set({
      'Content-Security-Policy': "default-src 'self'; img-src 'self' data: https:; style-src 'self'; script-src 'self'; connect-src 'self' https://api.mealmind-app.online; base-uri 'self'; frame-ancestors 'none'; form-action 'self' https://payment-stage.ecpay.com.tw https://payment.ecpay.com.tw",
      'Referrer-Policy': 'strict-origin-when-cross-origin',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    });
    next();
  });
  if (allowedClientIps.some((ip) => !isIP(ip))) {
    throw new Error('API_ALLOWED_IPS must contain exact IP addresses.');
  }
  if (allowedClientIps.length > 0) {
    const normalize = (ip) => String(ip).toLowerCase().replace(/^::ffff:/, '');
    const allowed = new Set(allowedClientIps.map(normalize));
    app.use((req, res, next) => {
      // Use the socket address; a client-supplied forwarded header cannot grant access.
      if (!allowed.has(normalize(req.socket.remoteAddress))) {
        return res.status(403).json({ message: '此連線來源未獲允許' });
      }
      next();
    });
  }

  const browserOrigins = new Set(['https://mealmind-app.online', 'https://www.mealmind-app.online']);
  app.use(cors({ origin(origin, callback) {
    if (!origin || browserOrigins.has(origin)) return callback(null, true);
    return callback(null, false);
  } }));
  app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '..', 'public', 'site', 'home.html'));
  });
  app.get('/login.html', (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.sendFile(path.join(__dirname, '..', 'public', 'site', 'login.html'));
  });
  app.get('/admin.html', (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.sendFile(path.join(__dirname, '..', 'public', 'site', 'admin.html'));
  });
  app.use(express.static(path.join(__dirname, '..', 'public', 'site'), {
    extensions: ['html'],
    maxAge: '5m',
  }));
  app.use('/brand-assets', express.static(path.join(__dirname, '..', '..', 'assets', 'branding'), {
    immutable: true,
    maxAge: '30d',
  }));
  app.get('/download/android', (req, res) => {
    const configured = process.env.APP_APK_PATH;
    const apkPath = configured ? path.resolve(configured) : path.join(__dirname, '..', '..', 'MealMind-latest.apk');
    res.download(apkPath, 'MealMind.apk', (error) => {
      if (error && !res.headersSent) res.status(404).send('Android 安裝檔尚未發布');
    });
  });
  app.use('/food-images', express.static(path.join(__dirname, '..', 'public', 'foods'), {
    immutable: true,
    maxAge: '30d',
  }));
  app.use(express.json({ limit: '700kb' }));
  app.use(express.urlencoded({ extended: false, limit: '16kb' }));
  app.use('/api', authRoutes(
    resolvedUserRepository,
    undefined,
    mailer || createMailer(),
  ));
  if (resolvedUserRepository.pool) {
    const AdminRepository = require('./admin/repository');
    app.use('/api', require('./admin/routes')(new AdminRepository(resolvedUserRepository.pool)));
  }
  if (!enablePrototypeRoutes) {
    app.use('/api', (req, res, next) => {
      if (req.path.startsWith('/me') || req.path.startsWith('/merchant') ||
          req.path.startsWith('/auth') || req.method !== 'GET') {
        return res.status(501).json({ message: '此功能尚未開放雲端服務' });
      }
      next();
    });
  }
  app.use('/api', routes);

  app.use((req, res) => {
    res.status(404).json({
      message: '找不到此 API 路徑',
      path: req.path,
    });
  });

  app.use((err, req, res, next) => {
    if (res.headersSent) {
      return next(err);
    }

    const status = err.statusCode || err.status || 500;
    if (status >= 500) console.error('Request failed:', req.method, req.path, err.code || err.message);
    return res.status(status).json({
      message: status >= 500 ? '伺服器暫時無法處理，請稍後再試' :
        (err.type === 'entity.parse.failed' ? 'JSON 格式不正確' : err.message),
    });
  });

  return app;
}

module.exports = createApp;
