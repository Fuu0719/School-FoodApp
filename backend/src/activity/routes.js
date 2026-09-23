const express = require('express');
const run = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);
const invalid = () => Object.assign(new Error('請求資料格式不正確'), { statusCode: 400 });
const maxId = '18446744073709551615';
function id(value) {
  if (typeof value !== 'string' || !/^[1-9][0-9]{0,19}$/.test(value) || BigInt(value) > BigInt(maxId)) throw invalid();
  return value;
}
function checkoutItems(body) {
  if (!body || !Array.isArray(body.items) || !body.items.length || body.items.length > 50) throw invalid();
  const items = body.items.map((item) => {
    if (!item || !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 99) throw invalid();
    return { foodId: id(item.foodId), quantity: item.quantity };
  });
  if (new Set(items.map((item) => item.foodId)).size !== items.length) throw invalid();
  return items;
}

function activityRoutes(repository, requireMember) {
  const router = express.Router();
  router.use(['/me/favorites', '/me/history', '/me/orders', '/me/leaderboard'], requireMember);
  router.get('/me/leaderboard', run(async (req, res) => {
    res.json({ items: await repository.leaderboard(req.member.id) });
  }));
  router.get('/me/favorites', run(async (req, res) => {
    const items = await repository.favorites(req.member.id, id(req.query.before || maxId));
    res.json({ items, nextCursor: items.length === 50 ? items.at(-1).foodId : null });
  }));
  router.put('/me/favorites/:foodId', run(async (req, res) => {
    await repository.favorite(req.member.id, id(req.params.foodId), true);
    res.json({ message: '已加入收藏' });
  }));
  router.delete('/me/favorites/:foodId', run(async (req, res) => {
    await repository.favorite(req.member.id, id(req.params.foodId), false);
    res.json({ message: '已取消收藏' });
  }));
  router.get('/me/history', run(async (req, res) => res.json({ items: await repository.history(req.member.id) })));
  router.post('/me/history', run(async (req, res) => {
    await repository.view(req.member.id, id(req.body?.foodId));
    res.json({ message: '已更新瀏覽紀錄' });
  }));
  router.delete('/me/history', run(async (req, res) => {
    await repository.clearHistory(req.member.id);
    res.json({ message: '已清除瀏覽紀錄' });
  }));
  router.get('/me/orders', run(async (req, res) => {
    const items = await repository.orders(req.member.id, id(req.query.before || maxId));
    res.json({ items, nextCursor: items.length === 20 ? items.at(-1).id : null });
  }));
  router.get('/me/orders/:orderId', run(async (req, res) => res.json(await repository.order(req.member.id, id(req.params.orderId)))));
  router.post('/me/orders', run(async (req, res) => {
    const requestId = req.get('Idempotency-Key');
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(requestId || '')) throw invalid();
    const result = await repository.checkout(req.member.id, requestId, checkoutItems(req.body));
    res.status(result.replayed ? 200 : 201).json(result);
  }));
  return router;
}
module.exports = activityRoutes;
