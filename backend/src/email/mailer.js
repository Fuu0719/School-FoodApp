const nodemailer = require('nodemailer');

function createMailer(env = process.env) {
  const configured = env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASSWORD && env.SMTP_FROM;
  if (!configured) {
    return {
      configured: false,
      async sendVerification() { throw Object.assign(new Error('Email 寄送服務尚未設定'), { statusCode: 503 }); },
      async sendPasswordReset() { throw Object.assign(new Error('Email 寄送服務尚未設定'), { statusCode: 503 }); },
      async sendWelcome() {},
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
  const html = (value) => String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
  const send = (to, subject, title, code) => transport.sendMail({
    from: env.SMTP_FROM, to, subject,
    text: `${title}\n\n驗證碼：${code}\n\n驗證碼 10 分鐘內有效。若不是你本人操作，請忽略這封信。`,
    html: `<div style="font-family:Arial,sans-serif;line-height:1.6;color:#243128"><h2>${title}</h2><p>你的驗證碼是：</p><p style="font-size:30px;font-weight:700;letter-spacing:6px">${code}</p><p>驗證碼 10 分鐘內有效。若不是你本人操作，請忽略這封信。</p></div>`,
  });
  const money = (value) => `NT$ ${Number(value).toLocaleString('zh-TW')}`;
  const orderItems = (notice) => notice.merchants.flatMap((merchant) => merchant.items);
  const itemRows = (items) => items.map((item) => `<tr>
    <td style="padding:13px 8px;border-bottom:1px solid #e6ece5;color:#26382b">${html(item.name)}</td>
    <td style="padding:13px 8px;border-bottom:1px solid #e6ece5;text-align:right;color:#59655b;white-space:nowrap">× ${Number(item.quantity)}</td>
  </tr>`).join('');
  const orderShell = ({ eyebrow, title, intro, rows, summary, footer }) => `<!doctype html>
    <html lang="zh-Hant"><body style="margin:0;background:#f3f6f1;font-family:Arial,'Microsoft JhengHei',sans-serif;color:#26382b">
    <div style="padding:28px 12px"><div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e1e9df">
      <div style="background:#315c3a;padding:24px 28px;color:#ffffff">
        <div style="font-size:13px;letter-spacing:1px;color:#dcebdc;font-weight:700">${eyebrow}</div>
        <div style="font-size:27px;font-weight:800;margin-top:8px">${title}</div>
      </div>
      <div style="padding:28px">
        <div style="display:inline-block;background:#e7f4e5;color:#2f6f3d;padding:7px 12px;font-weight:700;font-size:13px">付款成功 · 餐點已保留</div>
        <p style="font-size:16px;line-height:1.8;margin:20px 0">${intro}</p>
        <table role="presentation" style="width:100%;border-collapse:collapse;background:#fbfcfa"><tbody>${rows}</tbody></table>
        <div style="margin-top:22px;padding:18px;background:#fff4d6;border-left:5px solid #d69216">${summary}</div>
        <p style="margin:26px 0 0;color:#68746a;font-size:14px;line-height:1.7">${footer}</p>
      </div>
    </div></div></body></html>`;
  return {
    configured: true,
    sendVerification: (to, code) => send(to, '膳解人意 Email 驗證碼', '完成會員 Email 驗證', code),
    sendPasswordReset: (to, code) => send(to, '膳解人意重設密碼驗證碼', '重設會員密碼', code),
    sendWelcome: (user) => transport.sendMail({
      from: env.SMTP_FROM,
      to: user.email,
      subject: '註冊成功！歡迎加入膳解人意',
      text: `註冊成功！\n\n${user.name}，今天開始，讓美食不被錯過。\n\n膳解人意會依照你的預算、距離與飲食偏好，替你找到剛剛好的餐點，也讓即期美食多一次被選中的機會。`,
      html: `<!doctype html><html lang="zh-Hant"><body style="margin:0;background:#f2f6ef;font-family:Arial,'Microsoft JhengHei',sans-serif;color:#26382b"><div style="padding:28px 12px"><div style="max-width:600px;margin:auto;background:#fff;border:1px solid #dfe8dc"><div style="background:#315c3a;padding:28px;color:#fff"><div style="font-size:13px;letter-spacing:2px;color:#dcebdc;font-weight:700">MEALMIND 膳解人意</div><h1 style="font-size:30px;margin:12px 0 4px">註冊成功！</h1><div style="color:#eaf4e8">你的惜食旅程，現在開動。</div></div><div style="padding:30px"><h2 style="font-size:23px;margin:0 0 14px">${html(user.name)}，讓美食不被錯過。</h2><p style="line-height:1.8;margin:0 0 24px">我們會依照你的預算、距離與飲食偏好，找出剛剛好的餐點，也讓即期美食多一次被選中的機會。</p><table role="presentation" style="width:100%;border-collapse:collapse"><tr><td style="padding:16px;background:#e9f4e6;border-bottom:8px solid #fff"><strong style="color:#2f6f3d">01　完成偏好</strong><br><span style="font-size:14px;color:#59655b">讓推薦更貼近你的日常</span></td></tr><tr><td style="padding:16px;background:#fff4d6;border-bottom:8px solid #fff"><strong style="color:#8c6615">02　探索即期美食</strong><br><span style="font-size:14px;color:#6d6250">用更划算的價格減少浪費</span></td></tr><tr><td style="padding:16px;background:#edf3f6"><strong style="color:#3f6877">03　累積惜食成果</strong><br><span style="font-size:14px;color:#59655b">每一餐都會留下改變</span></td></tr></table><p style="margin:26px 0 0;color:#68746a;font-size:14px;line-height:1.7">少一點猶豫，多一餐剛好。<br><strong>MealMind 膳解人意</strong></p></div></div></div></body></html>`,
    }),
    sendOrderConfirmation: (notice) => transport.sendMail({
      from: env.SMTP_FROM, to: notice.memberEmail,
      subject: `膳解人意訂單成立 #${notice.orderId}`,
      text: `訂單 #${notice.orderId} 已成立，共 ${notice.totalQuantity} 件，總金額 NT$${notice.totalPrice}。`,
      html: orderShell({
        eyebrow: 'MEALMIND · 惜食訂單',
        title: `訂單 #${html(notice.orderId)} 已成立`,
        intro: '付款已確認，商家正在為你保留這份美食。謝謝你讓即期美食多一次被好好享用的機會。',
        rows: itemRows(orderItems(notice)),
        summary: `<div style="font-size:14px;color:#6f5b28">本次訂單</div><div style="font-size:24px;font-weight:800;margin-top:5px">${Number(notice.totalQuantity)} 件 · ${money(notice.totalPrice)}</div>`,
        footer: '請依 App 訂單紀錄向商家確認取餐資訊。每一次剛剛好的選擇，都能少一點浪費。<br><strong>MealMind 膳解人意</strong>',
      }),
    }),
    sendMerchantOrder: (notice) => transport.sendMail({
      from: env.SMTP_FROM, to: notice.merchantEmail,
      subject: `膳解人意新訂單 #${notice.orderId}`,
      text: `收到新訂單 #${notice.orderId}\n${notice.items.map((item) => `${item.name} x${item.quantity}`).join('\n')}`,
      html: orderShell({
        eyebrow: 'MEALMIND · 商家接單通知',
        title: `收到新訂單 #${html(notice.orderId)}`,
        intro: '會員已完成付款，請確認品項並為會員保留餐點。',
        rows: itemRows(notice.items),
        summary: `<div style="font-weight:800">共 ${notice.items.reduce((sum, item) => sum + Number(item.quantity), 0)} 件餐點待準備</div>`,
        footer: '請登入膳解人意商家端核對訂單與商品狀態。<br><strong>MealMind 膳解人意</strong>',
      }),
    }),
  };
}

module.exports = { createMailer };
