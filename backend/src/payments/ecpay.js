const { createHash, randomBytes } = require('node:crypto');

const encode = (value) => encodeURIComponent(String(value))
  .replace(/%20/g, '+')
  .replace(/%21/g, '!')
  .replace(/%28/g, '(')
  .replace(/%29/g, ')')
  .replace(/%2A/g, '*')
  .replace(/%2D/g, '-')
  .replace(/%2E/g, '.')
  .replace(/%5F/g, '_')
  .replace(/%7E/g, '~')
  .toLowerCase();

function checkMacValue(fields, hashKey, hashIv) {
  const pairs = Object.entries(fields)
    .filter(([key]) => key !== 'CheckMacValue')
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([key, value]) => `${key}=${value}`)
    .join('&');
  return createHash('sha256')
    .update(encode(`HashKey=${hashKey}&${pairs}&HashIV=${hashIv}`))
    .digest('hex')
    .toUpperCase();
}

function createEcpay() {
  const merchantId = process.env.ECPAY_MERCHANT_ID;
  const hashKey = process.env.ECPAY_HASH_KEY;
  const hashIv = process.env.ECPAY_HASH_IV;
  const publicBaseUrl = (process.env.PUBLIC_BASE_URL || '').replace(/\/$/, '');
  const gatewayUrl = process.env.ECPAY_GATEWAY_URL ||
    'https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5';
  const enabled = Boolean(merchantId && hashKey && hashIv && publicBaseUrl);

  return {
    enabled,
    gatewayUrl,
    newToken: () => randomBytes(32).toString('hex'),
    tokenHash: (token) => createHash('sha256').update(token).digest('hex'),
    fields(order) {
      if (!enabled) return null;
      const fields = {
        MerchantID: merchantId,
        MerchantTradeNo: order.merchantTradeNo,
        MerchantTradeDate: new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Taipei' }).replace(' ', '/'),
        PaymentType: 'aio',
        TotalAmount: String(order.totalPrice),
        TradeDesc: 'MealMind food rescue order',
        ItemName: `MealMind惜食餐點 x${order.totalQuantity}`,
        ReturnURL: `${publicBaseUrl}/api/payments/ecpay/return`,
        OrderResultURL: `${publicBaseUrl}/api/payments/ecpay/result`,
        ChoosePayment: 'ALL',
        EncryptType: '1',
      };
      return { ...fields, CheckMacValue: checkMacValue(fields, hashKey, hashIv) };
    },
    verify(fields) {
      if (!enabled || typeof fields.CheckMacValue !== 'string') return false;
      return checkMacValue(fields, hashKey, hashIv) === fields.CheckMacValue.toUpperCase();
    },
  };
}

module.exports = { checkMacValue, createEcpay };
