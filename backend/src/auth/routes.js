const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { randomBytes } = require('node:crypto');
const { hashPassword, verifyPassword, tokenHash } = require('./passwords');
const ActivityRepository = require('../activity/repository');
const activityRoutes = require('../activity/routes');
const { phone: validatePhone } = require('../validation/phone');

const run = (handler) => (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
function invalid(message) { return Object.assign(new Error(message), { statusCode: 400 }); }
function text(value, label, max, required = true) {
  if (typeof value !== 'string' || value.trim().length > max || (required && !value.trim())) {
    throw invalid(`${label}格式不正確`);
  }
  return value.trim();
}
function credentials(body, { registration = false } = {}) {
  body = body || {};
  const email = text(body.email, 'Email', 160).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw invalid('請輸入有效的 Email');
  const password = body.password;
  const max = registration ? 16 : 128;
  if (typeof password !== 'string' || password.length < 8 || password.length > max) {
    throw invalid(registration ? '密碼長度須為 8 至 16 個字元' : 'Email 或密碼不正確');
  }
  return { email, password };
}
function validateProfile(body) {
  body = body || {};
  const name = text(body.name, '姓名', 80);
  const phone = validatePhone(body.phone ?? '');
  const inRange = (v, min, max) => typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max;
  if (!inRange(body.heightCm, 50, 250) || !inRange(body.weightKg, 10, 400)) {
    throw invalid('身高須為 50–250 公分，體重須為 10–400 公斤');
  }
  if (!['maintain', 'muscleGain', 'fatLoss'].includes(body.healthGoal)) throw invalid('請選擇健康目標');
  for (const key of ['budgetMax', 'distanceLimitMeters']) {
    if (body[key] !== null && (!Number.isInteger(body[key]) || !inRange(body[key], 0, 1000000))) {
      throw invalid('預算或距離上限格式不正確');
    }
  }
  if (!Array.isArray(body.dietaryTags) || body.dietaryTags.length > 40) throw invalid('偏好標籤格式不正確');
  const dietaryTags = [...new Set(body.dietaryTags.map((tag) => text(tag, '標籤', 40)))];
  return { name, phone, dietaryTags, heightCm: body.heightCm, weightKg: body.weightKg,
    healthGoal: body.healthGoal, budgetMax: body.budgetMax, distanceLimitMeters: body.distanceLimitMeters };
}

function authRoutes(repository, activityRepository = repository.pool ? new ActivityRepository(repository.pool) : null) {
  const router = express.Router();
  const limiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 30,
    standardHeaders: 'draft-7', legacyHeaders: false,
    message: { message: '嘗試次數過多，請稍後再試' } });
  // Unknown emails still perform the same expensive password calculation.
  let dummyHash;
  const getDummyHash = () => dummyHash ||= hashPassword(randomBytes(32).toString('hex'));
  const issueSession = async (user) => {
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await repository.createSession(user.id, tokenHash(token), expiresAt);
    return { user, token, expiresAt: expiresAt.toISOString() };
  };
  const requireMember = run(async (req, res, next) => {
    const token = /^Bearer ([a-f0-9]{64})$/.exec(req.get('Authorization') || '')?.[1];
    const user = token ? await repository.session(tokenHash(token)) : null;
    if (!user) return res.status(401).json({ message: '登入已失效，請重新登入' });
    req.member = user;
    req.sessionHash = tokenHash(token);
    next();
  });

  router.post('/auth/register', limiter, run(async (req, res) => {
    const { email, password } = credentials(req.body, { registration: true });
    const name = text(req.body.name, '姓名', 80);
    try {
      await repository.create({ name, email, passwordHash: await hashPassword(password) });
    } catch (error) {
      if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: '此 Email 已註冊' });
      throw error;
    }
    res.status(201).json({ message: '註冊成功，請登入' });
  }));
  router.post('/auth/login', limiter, run(async (req, res) => {
    const { email, password } = credentials(req.body);
    const record = await repository.credentials(email);
    const valid = await verifyPassword(password, record?.password_hash || await getDummyHash());
    if (!record || !valid) return res.status(401).json({ message: 'Email 或密碼不正確' });
    res.json(await issueSession(await repository.get(record.id)));
  }));
  router.post('/auth/logout', requireMember, run(async (req, res) => {
    await repository.revoke(req.sessionHash);
    res.json({ message: '登出成功' });
  }));
  router.get('/me', requireMember, (req, res) => res.json(req.member));
  router.put('/me', requireMember, run(async (req, res) => {
    res.json(await repository.update(req.member.id, validateProfile(req.body)));
  }));
  if (activityRepository) router.use(activityRoutes(activityRepository, requireMember));
  if (repository.pool) {
    const MerchantRepository = require('../merchant/repository');
    router.use('/merchant', require('../merchant/routes')(new MerchantRepository(repository.pool)));
    const CatalogRepository = require('../catalog/repository');
    router.use(require('../catalog/routes')(new CatalogRepository(repository.pool)));
  }
  return router;
}
module.exports = authRoutes;
