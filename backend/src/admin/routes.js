const express = require('express');
const { timingSafeEqual, createHash } = require('node:crypto');

const run = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);
const digest = (value) => createHash('sha256').update(value).digest();

function adminRoutes(repository, configuredToken = process.env.ADMIN_ACCESS_TOKEN || '') {
  const router = express.Router();
  const requireAdmin = (req, res, next) => {
    const supplied = /^Bearer (.+)$/.exec(req.get('Authorization') || '')?.[1] || '';
    const allowed = configuredToken.length >= 24 && supplied.length > 0 &&
      timingSafeEqual(digest(supplied), digest(configuredToken));
    if (!allowed) return res.status(401).json({ message: '管理員驗證失敗' });
    res.set('Cache-Control', 'no-store');
    next();
  };
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
