import { describe, expect, it } from 'vitest';
import { buildAgentCreditDays } from './agent-credit-days.js';

describe('Daily agent credit balances', () => {
  it('carries balances across days and preserves historical balances after payment', () => {
    const rows = buildAgentCreditDays([
      {
        date: '2026-10-16',
        agentName: 'Ahmed',
        credit: '0',
        paid: '35.25',
        movementsCount: '1',
      },
      {
        date: '2026-10-14',
        agentName: 'Ahmed',
        credit: '100.50',
        paid: '0',
        movementsCount: '2',
      },
      {
        date: '2026-10-15',
        agentName: 'Ahmed',
        credit: '10',
        paid: '20',
        movementsCount: '2',
      },
    ]);
    expect(rows.map((row) => [row.openingBalance, row.closingBalance])).toEqual(
      [
        [90.5, 55.25],
        [100.5, 90.5],
        [0, 100.5],
      ],
    );
    expect(rows.every((row) => row.balance === 55.25)).toBe(true);
  });
  it('separates agents and normalizes names while keeping settled days', () => {
    const rows = buildAgentCreditDays([
      {
        date: '2026-10-14',
        agentName: ' Ahmed ',
        credit: 100,
        paid: 0,
        movementsCount: 1,
      },
      {
        date: '2026-10-14',
        agentName: 'Ali',
        credit: 80,
        paid: 0,
        movementsCount: 1,
      },
      {
        date: '2026-10-15',
        agentName: 'ahmed',
        credit: 0,
        paid: 100,
        movementsCount: 1,
      },
    ]);
    expect(rows.find((row) => row.agentName === 'ahmed')?.closingBalance).toBe(
      0,
    );
    expect(rows.find((row) => row.agentName === 'Ali')?.balance).toBe(80);
    expect(
      rows.find(
        (row) => row.date === '2026-10-14' && row.agentName.trim() === 'Ahmed',
      )?.balance,
    ).toBe(0);
  });
});
