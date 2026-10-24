const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { createHash, randomBytes } = require('node:crypto');
const { verifyPassword } = require('../auth/passwords');

const run = (handler) => (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
const tokenHash = (value) => createHash('sha256').update(value).digest('hex');
const reportPeriod = (value) => ['day', 'week', 'month'].includes(value) ? value : 'day';
const adminCookie = 'mealmind_admin';
const readCookie = (header, name) => String(header || '').split(';').map((part) => part.trim())
  .find((part) => part.startsWith(`${name}=`))?.slice(name.length + 1);
const listFilters = (query) => {
  const page = /^\d+$/.test(query.page || '') ? Number(query.page) : 1;
  const pageSize = /^\d+$/.test(query.pageSize || '') ? Number(query.pageSize) : 25;
  const search = String(query.search || '').trim().slice(0, 100);
  const from = query.from ? String(query.from) : null;
  const to = query.to ? String(query.to) : null;
  if (page < 1 || pageSize < 1 || pageSize > 100 ||
      (from && !/^\d{4}-\d{2}-\d{2}$/.test(from)) || (to && !/^\d{4}-\d{2}-\d{2}$/.test(to)) ||
      (from && to && from > to)) return null;
  return { page, pageSize, search, from, to };
};

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
    res.append('Set-Cookie', `${adminCookie}=${token}; Path=/api/admin; HttpOnly; Secure; SameSite=Strict`);
    res.set('Cache-Control', 'no-store').json({ token, expiresAt: new Date(expiresAt).toISOString() });
  }));

  const requireAdmin = (req, res, next) => {
    const bearer = /^Bearer ([a-f0-9]{64})$/.exec(req.get('Authorization') || '')?.[1];
    const cookie = readCookie(req.get('Cookie'), adminCookie);
    const supplied = bearer || (/^[a-f0-9]{64}$/.test(cookie || '') ? cookie : '');
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
    res.append('Set-Cookie', `${adminCookie}=; Path=/api/admin; Max-Age=0; HttpOnly; Secure; SameSite=Strict`);
    res.json({ message: '管理員已登出' });
  });
  router.use('/admin', requireAdmin);
  router.get('/admin/dashboard', run(async (req, res) => res.json(await repository.dashboard(reportPeriod(req.query.period)))));
  for (const resource of ['users', 'merchants', 'foods', 'orders']) {
    router.get(`/admin/${resource}`, run(async (req, res) => {
      const filters = listFilters(req.query);
      if (!filters) return res.status(400).json({ message: '查詢條件格式不正確' });
      res.json(await repository[resource](filters));
    }));
  }
  router.put('/admin/merchants/:id/status', run(async (req, res) => {
    if (!/^[1-9][0-9]{0,19}$/.test(req.params.id) || !['active', 'suspended'].includes(req.body?.status)) {
      return res.status(400).json({ message: '管理資料格式不正確' });
    }
    if (!await repository.setMerchantStatus(req.params.id, req.body.status)) {
      return res.status(404).json({ message: '找不到商家' });
    }
    res.json({ message: '商家狀態已更新', status: req.body.status });
  }));
  return router;
}

module.exports = adminRoutes;
