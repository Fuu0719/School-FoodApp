const nodemailer = require('nodemailer');

function createMailer(env = process.env) {
  const configured = env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASSWORD && env.SMTP_FROM;
  if (!configured) {
    return {
      configured: false,
      async sendVerification() { throw Object.assign(new Error('Email 寄送服務尚未設定'), { statusCode: 503 }); },
      async sendPasswordReset() { throw Object.assign(new Error('Email 寄送服務尚未設定'), { statusCode: 503 }); },
      async sendOrderConfirmation() {},
      async sendMerchantOrder() {},
    };
  }
  const transport = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: Number(env.SMTP_PORT || 465),
    secure: String(env.SMTP_SECURE || 'true').toLowerCase() === 'true',
    auth: { user: env.SMTP_USER, pass: env.SMTP_PASSWORD },
  });
  const send = (to, subject, title, code) => transport.sendMail({
    from: env.SMTP_FROM, to, subject,
    text: `${title}\n\n驗證碼：${code}\n\n驗證碼 10 分鐘內有效。若不是你本人操作，請忽略這封信。`,
    html: `<div style="font-family:Arial,sans-serif;line-height:1.6;color:#243128"><h2>${title}</h2><p>你的驗證碼是：</p><p style="font-size:30px;font-weight:700;letter-spacing:6px">${code}</p><p>驗證碼 10 分鐘內有效。若不是你本人操作，請忽略這封信。</p></div>`,
  });
  return {
    configured: true,
    sendVerification: (to, code) => send(to, '膳解人意 Email 驗證碼', '完成會員 Email 驗證', code),
    sendPasswordReset: (to, code) => send(to, '膳解人意重設密碼驗證碼', '重設會員密碼', code),
    sendOrderConfirmation: (notice) => transport.sendMail({
      from: env.SMTP_FROM, to: notice.memberEmail,
      subject: `膳解人意訂單成立 #${notice.orderId}`,
      text: `訂單 #${notice.orderId} 已成立，共 ${notice.totalQuantity} 件，總金額 NT$${notice.totalPrice}。`,
    }),
    sendMerchantOrder: (notice) => transport.sendMail({
      from: env.SMTP_FROM, to: notice.merchantEmail,
      subject: `膳解人意新訂單 #${notice.orderId}`,
      text: `收到新訂單 #${notice.orderId}\n${notice.items.map((item) => `${item.name} x${item.quantity}`).join('\n')}`,
    }),
  };
}

module.exports = { createMailer };
