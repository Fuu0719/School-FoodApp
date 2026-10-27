const ActivityRepository = require('./repository');

async function startReservationCleanup(pool, { intervalMs = 60 * 1000 } = {}) {
  const repository = new ActivityRepository(pool);
  const release = async () => {
    const count = await repository.releaseExpiredReservations();
    if (count) console.log(`Released ${count} expired order reservations.`);
  };
  await release();
  const timer = setInterval(() => release().catch((error) =>
    console.error('Order reservation cleanup failed:', error.code || error.message)), intervalMs);
  timer.unref();
  return () => clearInterval(timer);
}

module.exports = { startReservationCleanup };
