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
