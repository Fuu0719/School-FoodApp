const assert = require('node:assert/strict');
const { test } = require('node:test');
const cases = require('../../test/fixtures/phone_cases.json');
const { phone } = require('../src/validation/phone');
const { registration, storeInput } = require('../src/merchant/validation');

test('optional phones share normalized valid and invalid cases with the App', () => {
  for (const { input, normalized } of cases.valid) assert.equal(phone(input), normalized, input);
  for (const input of [...cases.invalid, 912345678, [], {}, true, '0'.repeat(41)]) {
    assert.throws(() => phone(input), { statusCode: 400 }, String(input));
  }
});

test('merchant registration including legacy store fields and store creation validate phones', () => {
  const account = { email: 'owner@example.test', password: 'PhonePass123!', businessName: 'shop' };
  const store = { storeName: 'store', address: 'address', opensAt: '09:00', closesAt: '18:00', businessWeekdays: [1] };
  for (const input of cases.invalid) {
    assert.throws(() => registration({ ...account, contactPhone: input }), { statusCode: 400 });
    assert.throws(() => registration({ ...account, ...store, businessHours: '09:00-18:00', contactPhone: input }), { statusCode: 400 });
    assert.throws(() => storeInput({ ...store, contactPhone: input }), { statusCode: 400 });
  }
  assert.equal(registration(account).contactPhone, '');
  assert.equal(storeInput(store).contactPhone, '');
  assert.equal(registration({ ...account, contactPhone: '+886 912-345-678' }).contactPhone, '0912345678');
});
