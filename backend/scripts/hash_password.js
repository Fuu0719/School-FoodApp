const { hashPassword } = require('../src/auth/passwords');

const password = process.argv[2];
if (!password || password.length < 12 || password.length > 128) {
  console.error('Usage: node scripts/hash_password.js "a password of at least 12 characters"');
  process.exitCode = 1;
} else {
  hashPassword(password).then((hash) => console.log(hash));
}
