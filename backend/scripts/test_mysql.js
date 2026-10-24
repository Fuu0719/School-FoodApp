require('dotenv').config();
const { spawnSync } = require('node:child_process');
const result = spawnSync(process.execPath, ['--test', 'test/auth.test.js', 'test/activity.test.js', 'test/merchant.test.js', 'test/admin_repository.test.js'], {
  stdio: 'inherit', env: { ...process.env, MYSQL_INTEGRATION: '1' },
});
process.exitCode = result.status ?? 1;
