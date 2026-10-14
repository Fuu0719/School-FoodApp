const test = require('node:test');
const assert = require('node:assert/strict');
const { createMailer } = require('../src/email/mailer');

const baseEnv = {
  SMTP_HOST: 'smtp.resend.com',
  SMTP_PORT: '465',
  SMTP_SECURE: 'true',
  SMTP_USER: 'resend',
  SMTP_PASSWORD: 'test-api-key',
  SMTP_ALLOWED_FROM_DOMAIN: 'mealmind-app.online',
};

test('mailer only enables an authenticated MealMind domain sender', () => {
  assert.equal(createMailer({
    ...baseEnv,
    SMTP_FROM: 'MealMind <noreply@mealmind-app.online>',
  }).configured, true);

  assert.equal(createMailer({
    ...baseEnv,
    SMTP_FROM: 'MealMind <mealmindfood@gmail.com>',
  }).configured, false);
});
