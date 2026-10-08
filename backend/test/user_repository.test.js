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
