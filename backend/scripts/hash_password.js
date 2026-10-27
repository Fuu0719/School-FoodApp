const { hashPassword } = require('../src/auth/passwords');
const { randomBytes } = require('node:crypto');

const generated = process.argv[2] === '--generate';
const password = generated ? randomBytes(24).toString('base64url') : process.argv[2];
if (!password || password.length < 12 || password.length > 128) {
  console.error('Usage: node scripts/hash_password.js --generate');
  process.exitCode = 1;
} else {
  hashPassword(password).then((hash) => {
    if (generated) console.log(`ADMIN_PASSWORD=${password}`);
    console.log(`ADMIN_PASSWORD_HASH=${hash}`);
  });
}
