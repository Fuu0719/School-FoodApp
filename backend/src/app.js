const cors = require('cors');
const express = require('express');
const routes = require('./routes');
const authRoutes = require('./auth/routes');
const UserRepository = require('./auth/user_repository');
const { createDatabasePool } = require('./config/database');
const { isIP } = require('node:net');
const { createMailer } = require('./email/mailer');

function createApp({ userRepository, mailer, enablePrototypeRoutes = false,
  allowedClientIps = (process.env.API_ALLOWED_IPS || '').split(',').map((ip) => ip.trim()).filter(Boolean),
} = {}) {
  const app = express();
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

  app.use(cors());
  app.use(express.json({ limit: '700kb' }));
  app.use(express.urlencoded({ extended: false, limit: '16kb' }));
  app.use('/api', authRoutes(
    userRepository || new UserRepository(createDatabasePool()),
    undefined,
    mailer || createMailer(),
  ));
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
    return res.status(status).json({
      message: status >= 500 ? '伺服器暫時無法處理，請稍後再試' :
        (err.type === 'entity.parse.failed' ? 'JSON 格式不正確' : err.message),
    });
  });

  return app;
}

module.exports = createApp;
