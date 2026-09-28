const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function taipeiClock(date = new Date()) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Taipei', weekday: 'short', hour: '2-digit', minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date).map((part) => [part.type, part.value]));
  return {
    weekday: weekdays.indexOf(parts.weekday) + 1,
    minutes: Number(parts.hour) * 60 + Number(parts.minute),
  };
}

function parseBusinessHours(value) {
  const match = /^(\d{2}):(\d{2})-(\d{2}):(\d{2})$/.exec(String(value || ''));
  if (!match) return null;
  const open = Number(match[1]) * 60 + Number(match[2]);
  const close = Number(match[3]) * 60 + Number(match[4]);
  if (open > 1440 || close > 1440) return null;
  return { open, close };
}

function isStoreOpenAt(businessHours, businessWeekdays, date = new Date()) {
  const hours = parseBusinessHours(businessHours);
  if (!hours) return false;
  const { weekday, minutes } = taipeiClock(date);
  const days = new Set(businessWeekdays.map(Number));
  if (hours.open === 0 && hours.close >= 1439) return days.has(weekday);
  if (hours.open < hours.close) {
    return days.has(weekday) && minutes >= hours.open && minutes < hours.close;
  }
  const previousWeekday = weekday === 1 ? 7 : weekday - 1;
  return (days.has(weekday) && minutes >= hours.open) ||
    (days.has(previousWeekday) && minutes < hours.close);
}

module.exports = { isStoreOpenAt, parseBusinessHours, taipeiClock };
