const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { createHash, randomBytes } = require('node:crypto');
const { verifyPassword } = require('../auth/passwords');

const run = (handler) => (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
const tokenHash = (value) => createHash('sha256').update(value).digest('hex');

function adminRoutes(repository, options = {}) {
  const router = express.Router();
  const email = String(options.email ?? process.env.ADMIN_EMAIL ?? '').trim().toLowerCase();
  const passwordHash = String(options.passwordHash ?? process.env.ADMIN_PASSWORD_HASH ?? '');
  const sessions = options.sessions || new Map();
  const now = options.now || (() => Date.now());
  const limiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 10,
    standardHeaders: 'draft-7', legacyHeaders: false,
    message: { message: '登入嘗試次數過多，請稍後再試' } });

  router.post('/admin/auth/login', limiter, run(async (req, res) => {
    const suppliedEmail = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const suppliedPassword = typeof req.body?.password === 'string' ? req.body.password : '';
    const validPassword = passwordHash.startsWith('scrypt-v1$') && suppliedPassword.length <= 128 &&
      await verifyPassword(suppliedPassword, passwordHash);
    if (!email || suppliedEmail !== email || !validPassword) {
      return res.status(401).json({ message: '管理員帳號或密碼不正確' });
    }
    const token = randomBytes(32).toString('hex');
    const expiresAt = now() + 2 * 60 * 60 * 1000;
    sessions.set(tokenHash(token), expiresAt);
    res.set('Cache-Control', 'no-store').json({ token, expiresAt: new Date(expiresAt).toISOString() });
  }));

  const requireAdmin = (req, res, next) => {
    const supplied = /^Bearer ([a-f0-9]{64})$/.exec(req.get('Authorization') || '')?.[1];
    const hash = supplied ? tokenHash(supplied) : '';
    const expiresAt = hash ? sessions.get(hash) : null;
    if (!expiresAt || expiresAt <= now()) {
      if (hash) sessions.delete(hash);
      return res.status(401).json({ message: '管理員登入已失效，請重新登入' });
    }
    req.adminSessionHash = hash;
    res.set('Cache-Control', 'no-store');
    next();
  };

  router.post('/admin/auth/logout', requireAdmin, (req, res) => {
    sessions.delete(req.adminSessionHash);
    res.json({ message: '管理員已登出' });
  });
  router.use('/admin', requireAdmin);
  router.get('/admin/dashboard', run(async (req, res) => res.json(await repository.dashboard())));
  router.get('/admin/users', run(async (req, res) => res.json({ items: await repository.users() })));
  router.get('/admin/merchants', run(async (req, res) => res.json({ items: await repository.merchants() })));
  router.get('/admin/foods', run(async (req, res) => res.json({ items: await repository.foods() })));
  router.get('/admin/orders', run(async (req, res) => res.json({ items: await repository.orders() })));
  router.put('/admin/merchants/:id/status', run(async (req, res) => {
    if (!/^[1-9][0-9]{0,19}$/.test(req.params.id) || !['active', 'suspended'].includes(req.body?.status)) {
      return res.status(400).json({ message: '管理資料格式不正確' });
    }
    if (!await repository.setMerchantStatus(req.params.id, req.body.status)) {
      return res.status(404).json({ message: '找不到商家' });
    }
    res.json({ message: '商家狀態已更新' });
  }));
  return router;
}

module.exports = adminRoutes;
