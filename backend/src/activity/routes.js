const express = require('express');
const { createEcpay } = require('../payments/ecpay');
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

function activityRoutes(repository, requireMember, mailer = null, ecpay = createEcpay()) {
  const router = express.Router();
  const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
  const sendOrderEmails = async (userId, orderId) => {
    if (!mailer || !repository.orderNotification) return;
    const notice = await repository.orderNotification(userId, orderId);
    await Promise.allSettled([
      mailer.sendOrderConfirmation(notice),
      ...notice.merchants.map((merchant) => mailer.sendMerchantOrder({ orderId: notice.orderId, ...merchant })),
    ]);
  };

  router.get('/payments/ecpay/:token', run(async (req, res) => {
    if (!ecpay.enabled || !/^[0-9a-f]{64}$/.test(req.params.token)) return res.status(404).send('Payment not found');
    const order = await repository.paymentByToken(ecpay.tokenHash(req.params.token));
    if (!order) return res.status(404).send('Payment not found or expired');
    const fields = ecpay.fields(order);
    const inputs = Object.entries(fields).map(([key, value]) =>
      `<input type="hidden" name="${escapeHtml(key)}" value="${escapeHtml(value)}">`).join('');
    res.type('html').send(`<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>前往綠界付款</title>
      <body><p>正在連接綠界安全付款頁面...</p><form id="pay" method="post" action="${escapeHtml(ecpay.gatewayUrl)}">${inputs}</form>
      <script>document.getElementById('pay').submit()</script></body></html>`);
  }));
  router.post('/payments/ecpay/return', run(async (req, res) => {
    if (!ecpay.verify(req.body)) return res.status(400).send('0|CheckMacValue Error');
    const outcome = await repository.recordPayment(req.body.MerchantTradeNo, req.body.RtnCode === '1');
    if (outcome?.paid) sendOrderEmails(outcome.userId, outcome.orderId)
      .catch((error) => console.error('Order email delivery failed:', error.message));
    res.type('text').send('1|OK');
  }));
  router.post('/payments/ecpay/result', run(async (req, res) => {
    const ok = ecpay.verify(req.body) && req.body.RtnCode === '1';
    res.type('html').send(`<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>MealMind 付款結果</title>
      <body style="font-family:sans-serif;text-align:center;padding:48px"><h1>${ok ? '付款完成' : '付款尚未完成'}</h1>
      <p>${ok ? '可以回到膳解人意查看訂單。' : '請回到膳解人意重新確認訂單狀態。'}</p></body></html>`);
  }));
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
    if (ecpay.enabled && repository.preparePayment && result.order.paymentStatus === 'pending') {
      const token = ecpay.newToken();
      const tradeNo = `MM${Date.now().toString(36)}${BigInt(result.order.id).toString(36)}`.slice(0, 20).toUpperCase();
      await repository.preparePayment(req.member.id, result.order.id, tradeNo, ecpay.tokenHash(token));
      result.order.paymentStatus = 'pending';
      result.payment = { checkoutUrl: `${process.env.PUBLIC_BASE_URL.replace(/\/$/, '')}/api/payments/ecpay/${token}` };
    } else if (!result.replayed) {
      if (repository.completeWithoutPayment) {
        await repository.completeWithoutPayment(req.member.id, result.order.id);
        result.order.paymentStatus = 'paid';
      }
      sendOrderEmails(req.member.id, result.order.id)
        .catch((error) => console.error('Order email delivery failed:', error.message));
    }
    res.status(result.replayed ? 200 : 201).json(result);
  }));
  return router;
}
module.exports = activityRoutes;
