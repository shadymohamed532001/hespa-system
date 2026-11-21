export const FAWRY_DROP_REMINDER_HOUR = 8;

export type CairoParts = { date: string; hour: number };

export function cairoParts(now: Date): CairoParts {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const read = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? '';
  return {
    date: `${read('year')}-${read('month')}-${read('day')}`,
    hour: Number(read('hour')),
  };
}

/** A UTC instant whose Cairo clock shows the given calendar date and hour. */
export function instantAtCairoHour(date: string, hour: number): Date {
  const [year, month, day] = date.split('-').map(Number);
  const start = Date.UTC(year, month - 1, day - 1, 0, 30, 0);
  for (let step = 0; step < 72; step += 1) {
    const candidate = new Date(start + step * 60 * 60 * 1000);
    const parts = cairoParts(candidate);
    if (parts.date === date && parts.hour === hour) return candidate;
  }
  throw new Error(`No Cairo instant for ${date} ${hour}:00`);
}

export function fawryAccountsDueForDrop(input: {
  now: Date;
  accounts: Array<{ id: string; name: string; createdAt: Date }>;
  recordedAccountIds: Iterable<string>;
}): {
  date: string;
  remind: boolean;
  missing: Array<{ id: string; name: string }>;
} {
  const parts = cairoParts(input.now);
  const recorded = new Set(input.recordedAccountIds);
  const missing = input.accounts
    .filter(
      (account) =>
        cairoParts(account.createdAt).date < parts.date &&
        !recorded.has(account.id),
    )
    .map(({ id, name }) => ({ id, name }));
  return {
    date: parts.date,
    remind: parts.hour >= FAWRY_DROP_REMINDER_HOUR && missing.length > 0,
    missing,
  };
}

const EXPLICIT_ZONE = /(?:Z|[+-]\d{2}:?\d{2})$/i;
const WALL_CLOCK =
  /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?$/;

/** Milliseconds Cairo's clock is ahead of UTC at the given instant. */
function cairoOffsetMs(instant: Date): number {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(instant);
  const read = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value ?? 0);
  const asUtc = Date.UTC(
    read('year'),
    read('month') - 1,
    read('day'),
    read('hour'),
    read('minute'),
    read('second'),
  );
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

/**
 * Parses a timestamp sent by a client. A value with an explicit zone ("Z" or
 * "+02:00") is taken as is. A value without one ("2026-11-21T23:30:00") is
 * a Cairo wall-clock time — it must not be read in the server's own zone,
 * which is UTC in production and would push it 2–3 hours later (an operation
 * at 23:30 would land on the next day).
 */
export function parseClientInstant(value: string): Date {
  const text = value.trim();
  if (EXPLICIT_ZONE.test(text)) return new Date(text);
  const match = WALL_CLOCK.exec(text);
  if (!match) return new Date(text);
  const [, year, month, day, hour, minute, second, fraction] = match;
  const wallAsUtc = Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute),
    Number(second ?? 0),
    Number((fraction ?? '0').padEnd(3, '0').slice(0, 3)),
  );
  // Cairo's offset depends on the instant (summer time), so refine once.
  let instant = wallAsUtc - cairoOffsetMs(new Date(wallAsUtc));
  const corrected = wallAsUtc - cairoOffsetMs(new Date(instant));
  if (corrected !== instant) instant = corrected;
  return new Date(instant);
}
