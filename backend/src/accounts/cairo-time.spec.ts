import { describe, expect, it } from 'vitest';
import {
  cairoParts,
  fawryAccountsDueForDrop,
  instantAtCairoHour,
  parseClientInstant,
} from './cairo-time.js';

describe('fawryAccountsDueForDrop', () => {
  const older = new Date('2026-09-01T10:00:00.000Z');
  const accounts = [
    { id: 'a', name: 'فوري 1', createdAt: older },
    { id: 'b', name: 'فوري 2', createdAt: older },
  ];

  it('finds a January morning in Cairo', () => {
    const now = instantAtCairoHour('2099-01-15', 9);
    expect(cairoParts(now)).toMatchObject({ date: '2099-01-15', hour: 9 });
  });

  it('stays quiet before 8am Cairo', () => {
    const now = instantAtCairoHour('2026-09-26', 7);
    expect(cairoParts(now).hour).toBe(7);
    expect(
      fawryAccountsDueForDrop({
        now,
        accounts,
        recordedAccountIds: [],
      }).remind,
    ).toBe(false);
  });

  it('reminds at 8am for accounts opened before today that have no drop', () => {
    const now = instantAtCairoHour('2026-09-26', 8);
    const due = fawryAccountsDueForDrop({
      now,
      accounts: [
        ...accounts,
        {
          id: 'new',
          name: 'فوري جديد',
          createdAt: instantAtCairoHour('2026-09-26', 1),
        },
      ],
      recordedAccountIds: ['b'],
    });
    expect(due.date).toBe('2026-09-26');
    expect(due.remind).toBe(true);
    expect(due.missing).toEqual([{ id: 'a', name: 'فوري 1' }]);
  });
});

describe('parseClientInstant', () => {
  it('reads a time without a zone as Cairo time in winter (UTC+2)', () => {
    const instant = parseClientInstant('2026-11-21T23:30:00.000');
    expect(instant.toISOString()).toBe('2026-11-21T21:30:00.000Z');
    expect(cairoParts(instant)).toEqual({ date: '2026-11-21', hour: 23 });
  });

  it('reads a time without a zone as Cairo time in summer (UTC+3)', () => {
    expect(parseClientInstant('2026-07-15T23:30:00').toISOString()).toBe(
      '2026-07-15T20:30:00.000Z',
    );
  });

  it('keeps the moment when the client sends an explicit zone', () => {
    expect(parseClientInstant('2026-11-21T21:30:00.000Z').toISOString()).toBe(
      '2026-11-21T21:30:00.000Z',
    );
    expect(parseClientInstant('2026-11-21T23:30:00+02:00').toISOString()).toBe(
      '2026-11-21T21:30:00.000Z',
    );
  });

  it('accepts microseconds as sent by Dart', () => {
    expect(parseClientInstant('2026-11-21T00:15:00.000123').toISOString()).toBe(
      '2026-11-20T22:15:00.000Z',
    );
  });
});
