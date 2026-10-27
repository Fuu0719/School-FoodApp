const assert = require('node:assert/strict');
const { test } = require('node:test');
const UserRepository = require('../src/auth/user_repository');

test('member transaction rolls back if preference insert fails', async () => {
  const events = [];
  const connection = {
    beginTransaction: async () => events.push('begin'),
    commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'),
    release: () => events.push('release'),
    execute: async (sql) => {
      if (sql.startsWith('INSERT INTO users')) return [{ insertId: 1 }];
      throw new Error('preference insert failed');
    },
  };
  const repository = new UserRepository({ getConnection: async () => connection });
  await assert.rejects(repository.create({ name: 'test', email: 'test@example.com', passwordHash: 'hash' }),
    /preference insert failed/);
  assert.deepEqual(events, ['begin', 'rollback', 'release']);
});

test('profile update binds user input and rolls back both tables on failure', async () => {
  const events = [];
  const name = "Robert'); DROP TABLE users; --";
  const connection = {
    beginTransaction: async () => events.push('begin'),
    commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'),
    release: () => events.push('release'),
    execute: async (sql, params) => {
      assert.equal(sql.includes(name), false);
      if (sql.startsWith('UPDATE users')) {
        assert.equal(params[0], name);
        assert.equal(params.at(-1), '42');
        assert.equal(params[5], 'fat_loss');
        return [{ affectedRows: 1 }];
      }
      throw new Error('save failed');
    },
  };
  const repository = new UserRepository({ getConnection: async () => connection });
  await assert.rejects(repository.update('42', { name, phone: '', avatarKey: 'sprout', heightCm: 170, weightKg: 65,
    healthGoal: 'fatLoss', dietaryTags: [], budgetMax: null, distanceLimitMeters: null }), /save failed/);
  assert.deepEqual(events, ['begin', 'rollback', 'release']);
});

test('member linking replaces only its own link and rolls back one-to-one conflicts', async () => {
  for (const conflict of [false, true]) {
    const events = [];
    const connection = {
      beginTransaction: async () => events.push('begin'), commit: async () => events.push('commit'),
      rollback: async () => events.push('rollback'), release: () => events.push('release'),
      execute: async (sql, args) => {
        if (sql.startsWith('DELETE FROM member_merchant_links')) {
          assert.deepEqual(args, ['42']); events.push('delete own'); return [{}];
        }
        if (sql.startsWith('INSERT INTO member_merchant_links')) {
          assert.deepEqual(args, ['42', '9']);
          if (conflict) throw Object.assign(new Error('duplicate'), { code: 'ER_DUP_ENTRY' });
          events.push('insert'); return [{}];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    };
    const repository = new UserRepository({ getConnection: async () => connection });
    repository.get = async () => ({ id: '42' });
    if (conflict) {
      await assert.rejects(repository.linkMerchant('42', '9'), { code: 'ER_DUP_ENTRY' });
      assert.deepEqual(events, ['begin', 'delete own', 'rollback', 'release']);
    } else {
      assert.deepEqual(await repository.linkMerchant('42', '9'), { id: '42' });
      assert.deepEqual(events, ['begin', 'delete own', 'insert', 'commit', 'release']);
    }
  }
});

test('member to merchant switch creates only the destination session in one transaction', async () => {
  const events = [];
  const connection = {
    beginTransaction: async () => events.push('begin'), commit: async () => events.push('commit'),
    rollback: async () => events.push('rollback'), release: () => events.push('release'),
    execute: async (sql, args) => {
      if (sql.startsWith('SELECT merchant_id FROM member_merchant_links')) {
        assert.deepEqual(args, ['42', '9']); events.push('link locked'); return [[{ merchant_id: '9' }]];
      }
      if (sql.startsWith('INSERT INTO merchant_sessions')) {
        assert.deepEqual(args, ['9', '42', 'merchant-hash', 'expiry']); events.push('merchant session'); return [{}];
      }
      if (sql.startsWith('DELETE FROM user_sessions')) {
        assert.deepEqual(args, ['42', 'member-hash']); events.push('member revoked'); return [{}];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };
  const repository = new UserRepository({ getConnection: async () => connection });
  await repository.switchToMerchant('42', '9', 'member-hash', 'merchant-hash', 'expiry');
  assert.deepEqual(events, ['begin', 'link locked', 'merchant session', 'member revoked', 'commit', 'release']);
});
