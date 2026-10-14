const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { randomBytes } = require('node:crypto');
const { hashPassword, verifyPassword, tokenHash } = require('../auth/passwords');
const { fail, id, integer, credentials, product, registration, storeInput, accountInput, passwordInput } = require('./validation');
const run = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
module.exports = function merchantRoutes(repository) {
  const router = express.Router();
  let dummy;
  const limiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: 'draft-7', legacyHeaders: false,
    message: { message: '嘗試次數過多，請稍後再試' } });
  router.post('/auth/register', limiter, run(async (req, res) => {
    const data = registration(req.body);
    try {
      await repository.register(data, await hashPassword(data.password));
    } catch (error) {
      if (error.code === 'ER_DUP_ENTRY') throw fail(409, '此商家 Email 已註冊，請登入');
      throw error;
    }
    res.status(201).json({ message: '商家註冊成功，請登入' });
  }));
  router.post('/auth/login', limiter, run(async (req, res) => {
    const { email, password } = credentials(req.body);
    const record = await repository.credentials(email);
    dummy ||= hashPassword(randomBytes(32).toString('hex'));
    const valid = await verifyPassword(password, record?.password_hash || await dummy);
    if (!valid || record?.status !== 'active') throw fail(401, '商家帳號或密碼不正確，或帳號尚未啟用');
    const merchant = await repository.account(record.id);
    if (!merchant) throw fail(401, '商家帳號未啟用');
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000);
    await repository.createSession(merchant.id, tokenHash(token), expiresAt);
    res.json({ merchant, token, expiresAt: expiresAt.toISOString() });
  }));
  router.use(run(async (req, res, next) => {
    const token = /^Bearer ([a-f0-9]{64})$/.exec(req.get('Authorization') || '')?.[1];
    const merchant = token ? await repository.session(tokenHash(token)) : null;
    if (!merchant) throw fail(401, '商家登入已失效，請重新登入');
    req.merchant = merchant;
    req.merchantSession = tokenHash(token);
    next();
  }));
  router.get('/me', (req, res) => res.json(req.merchant));
  router.put('/me', run(async (req, res) => res.json(
    await repository.updateAccount(req.merchant.id, accountInput(req.body)))));
  router.post('/me/change-password', limiter, run(async (req, res) => {
    const input = passwordInput(req.body);
    const record = await repository.credentialsById(req.merchant.id);
    if (!await verifyPassword(input.currentPassword, record.password_hash)) {
      return res.status(401).json({ message: '目前密碼不正確' });
    }
    await repository.changePassword(req.merchant.id, await hashPassword(input.newPassword), req.merchantSession);
    res.json({ message: '密碼已更新' });
  }));
  router.post('/me/member-link', limiter, run(async (req, res) => {
    const { email, password } = credentials(req.body);
    const UserRepository = require('../auth/user_repository');
    const users = new UserRepository(repository.pool);
    const record = await users.credentials(email);
    if (!record || !record.email_verified_at || !await verifyPassword(password, record.password_hash)) {
      return res.status(401).json({ message: '會員帳號或密碼不正確' });
    }
    try { await repository.linkMember(req.merchant.id, record.id); }
    catch (error) {
      if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: '此會員已綁定其他商家' });
      throw error;
    }
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await users.createSession(record.id, tokenHash(token), expiresAt);
    res.json({ merchant: await repository.account(req.merchant.id), user: await users.get(record.id), token, expiresAt: expiresAt.toISOString() });
  }));
  router.delete('/me/member-link', run(async (req, res) => res.json(await repository.unlinkMember(req.merchant.id))));
  router.post('/me/switch-to-member', run(async (req, res) => {
    const linked = await repository.linkedMember(req.merchant.id);
    if (!linked) return res.status(404).json({ message: '尚未綁定會員帳號' });
    const UserRepository = require('../auth/user_repository');
    const users = new UserRepository(repository.pool);
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await users.createSession(linked.id, tokenHash(token), expiresAt);
    res.json({ user: await users.get(linked.id), token, expiresAt: expiresAt.toISOString() });
  }));
  router.get('/categories', run(async (req, res) => {
    res.json(await repository.categories(req.merchant.id));
  }));
  router.post('/stores', run(async (req, res) => {
    res.status(201).json(await repository.createStore(req.merchant.id, storeInput(req.body)));
  }));
  router.put('/stores/:id', run(async (req, res) => {
    res.json(await repository.updateStore(req.merchant.id, id(req.params.id), storeInput(req.body)));
  }));
  router.delete('/stores/:id', run(async (req, res) => {
    res.json(await repository.deleteStore(req.merchant.id, id(req.params.id)));
  }));
  router.post('/auth/logout', run(async (req, res) => {
    await repository.revoke(req.merchantSession);
    res.json({ message: '商家已登出' });
  }));
  router.get('/products', run(async (req, res) => {
    res.json(await repository.list(req.merchant.id, req.query.before === undefined ? '18446744073709551615' : id(req.query.before)));
  }));
  router.get('/products/:id', run(async (req, res) => res.json(await repository.get(req.merchant.id, id(req.params.id)))));
  router.post('/products', run(async (req, res) => {
    const key = req.get('Idempotency-Key') || '';
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(key)) throw fail(400, '草稿識別碼格式不正確');
    const result = await repository.create(req.merchant.id, key, product(req.body));
    res.status(result.replayed ? 200 : 201).json(result);
  }));
  router.put('/products/:id', run(async (req, res) => {
    res.json(await repository.update(req.merchant.id, id(req.params.id), integer(req.body?.revision, '版本'), product(req.body)));
  }));
  router.put('/products/:id/status', run(async (req, res) => {
    if (!['active', 'paused'].includes(req.body?.status)) throw fail(400, '上架狀態格式不正確');
    res.json(await repository.status(req.merchant.id, id(req.params.id), integer(req.body.revision, '版本'), req.body.status));
  }));
  router.delete('/products/:id', run(async (req, res) => {
    await repository.deleteProduct(req.merchant.id, id(req.params.id), integer(req.body?.revision, '版本'));
    res.json({ message: '餐點已刪除' });
  }));
  router.use((req, res) => res.status(404).json({ message: '找不到此商家 API 路徑' }));
  return router;
};
