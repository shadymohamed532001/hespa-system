import { describe, expect, it } from 'vitest';
import {
  buildAgentCreditDays,
  buildAgentHistory,
} from './agent-credit-days.js';

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
  it('lets the balance go negative for deposits and adds refunds back', () => {
    const rows = buildAgentCreditDays([
      {
        date: '2026-11-18',
        agentName: 'Saad',
        credit: 0,
        paid: 100000,
        refunded: 0,
        movementsCount: 1,
      },
      {
        date: '2026-11-19',
        agentName: 'Saad',
        credit: 5000,
        paid: 0,
        refunded: 10000,
        movementsCount: 2,
      },
    ]);
    expect(rows.map((row) => [row.openingBalance, row.closingBalance])).toEqual(
      [
        [-100000, -85000],
        [0, -100000],
      ],
    );
    expect(rows[0].refunded).toBe(10000);
    expect(rows.every((row) => row.balance === -85000)).toBe(true);
  });
});

describe('buildAgentHistory', () => {
  it('orders movements, keeps a running balance and totals', () => {
    const history = buildAgentHistory([
      {
        id: 'r',
        kind: 'refund',
        date: '2026-11-21T12:00:00Z',
        reference: 'RFD-002',
        description: 'رد',
        change: 1000,
      },
      {
        id: 'c',
        kind: 'collection',
        date: '2026-11-18T10:00:00Z',
        reference: 'COL-001',
        description: 'تحصيل',
        operationAmount: '10000',
        receivedAmount: 8000,
        status: 'done',
        change: '2000',
      },
      {
        id: 'p',
        kind: 'payment',
        date: '2026-11-20T09:00:00Z',
        reference: 'CRD-001',
        description: 'استلام',
        change: -5000,
      },
    ]);
    expect(history.movements.map((row) => [row.id, row.balanceAfter])).toEqual([
      ['r', -2000],
      ['p', -3000],
      ['c', 2000],
    ]);
    expect(history.balance).toBe(-2000);
    expect(history.totals).toEqual({
      credit: 2000,
      paid: 5000,
      refunded: 1000,
      collections: 1,
    });
    expect(history.movements[2]).toMatchObject({
      operationAmount: 10000,
      receivedAmount: 8000,
    });
  });
});
