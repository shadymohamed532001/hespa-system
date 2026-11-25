import { BadRequestException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { Repository } from 'typeorm';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { AppNotification } from '../database/entities/notification.entity.js';
import { AccountType, UserRole } from '../database/enums.js';
import { FcmService } from '../notifications/fcm.service.js';
import {
  FAWRY_DAILY_WITHDRAW_LIMIT,
  addFawryWithdrawal,
  crossedFawryNotice,
  fawryWithdrawnToday,
  removeFawryWithdrawal,
} from './fawry-limit.js';
import { FawryLimitNoticeService } from './fawry-limit-notice.service.js';

// 12:00 Cairo on two consecutive days.
const DAY1 = new Date('2026-11-25T10:00:00Z');
const DAY2 = new Date('2026-11-26T10:00:00Z');

function fawry(partial: Partial<FinancialAccount> = {}) {
  return Object.assign(new FinancialAccount(), {
    id: 'fawry-1',
    name: 'حساب فوري 01',
    type: AccountType.FAWRY,
    balance: 9_000_000,
    dailyWithdrawn: 0,
    withdrawCounterDay: null,
    ...partial,
  });
}

describe('Fawry daily withdrawal limit', () => {
  it('allows withdrawing exactly the daily limit and rejects one pound more', () => {
    const account = fawry();
    addFawryWithdrawal(account, FAWRY_DAILY_WITHDRAW_LIMIT, DAY1);
    expect(account.dailyWithdrawn).toBe(FAWRY_DAILY_WITHDRAW_LIMIT);
    try {
      addFawryWithdrawal(account, 1, DAY1);
      expect.unreachable();
    } catch (error) {
      expect(error).toBeInstanceOf(BadRequestException);
      expect((error as BadRequestException).getResponse()).toMatchObject({
        limit: FAWRY_DAILY_WITHDRAW_LIMIT,
        available: 0,
      });
    }
    expect(account.dailyWithdrawn).toBe(FAWRY_DAILY_WITHDRAW_LIMIT);
  });

  it('reports what is still available when rejecting', () => {
    const account = fawry();
    addFawryWithdrawal(account, 4_700_000, DAY1);
    expect(() => addFawryWithdrawal(account, 400_000, DAY1)).toThrow(
      BadRequestException,
    );
    try {
      addFawryWithdrawal(account, 400_000, DAY1);
    } catch (error) {
      expect((error as BadRequestException).getResponse()).toMatchObject({
        available: 300_000,
      });
    }
  });

  it('resets the counter on a new Cairo day', () => {
    const account = fawry();
    addFawryWithdrawal(account, FAWRY_DAILY_WITHDRAW_LIMIT, DAY1);
    expect(fawryWithdrawnToday(account, DAY2)).toBe(0);
    addFawryWithdrawal(account, 1_000_000, DAY2);
    expect(account.withdrawCounterDay).toBe('2026-11-26');
    expect(account.dailyWithdrawn).toBe(1_000_000);
  });

  it('returns the highest notice percentage crossed', () => {
    const account = fawry();
    expect(addFawryWithdrawal(account, 3_999_999, DAY1)).toBeNull();
    expect(addFawryWithdrawal(account, 1, DAY1)).toBe(80);
    expect(addFawryWithdrawal(account, 100_000, DAY1)).toBeNull();
    expect(addFawryWithdrawal(account, 900_000, DAY1)).toBe(100);
    expect(crossedFawryNotice(3_000_000, 4_600_000)).toBe(90);
  });

  it('gives a reversed withdrawal back only when it was executed today', () => {
    const account = fawry();
    addFawryWithdrawal(account, 3_000_000, DAY1);
    removeFawryWithdrawal(account, 1_000_000, DAY1, DAY1);
    expect(account.dailyWithdrawn).toBe(2_000_000);
    removeFawryWithdrawal(
      account,
      1_000_000,
      new Date('2026-11-24T10:00:00Z'),
      DAY1,
    );
    expect(account.dailyWithdrawn).toBe(2_000_000);
    removeFawryWithdrawal(account, 9_000_000, DAY1, DAY1);
    expect(account.dailyWithdrawn).toBe(0);
  });
});

describe('FawryLimitNoticeService', () => {
  function setup(existing: unknown = null) {
    const findOne = vi.fn().mockResolvedValue(existing);
    const save = vi.fn(async (row: object) => ({ id: 'n-1', ...row }));
    const create = vi.fn((row: object) => row);
    const sendPush = vi.fn();
    const service = new FawryLimitNoticeService(
      { findOne, save, create } as unknown as Repository<AppNotification>,
      { sendPush } as unknown as FcmService,
    );
    return { service, findOne, save, sendPush };
  }

  it('sends an admin-only notice and push to admins', async () => {
    const { service, save, sendPush, findOne } = setup();
    const account = fawry({
      dailyWithdrawn: 4_000_000,
      withdrawCounterDay: '2026-11-25',
    });
    await service.notify({ account, percent: 80 });
    expect(findOne).toHaveBeenCalledWith({
      where: { dedupeKey: 'fawry-withdraw:fawry-1:2026-11-25:80' },
    });
    expect(save).toHaveBeenCalledWith(
      expect.objectContaining({
        adminOnly: true,
        amount: 4_000_000,
        title: 'حساب فوري قرب يخلص حد السحب',
        body: expect.stringContaining('المتبقي 1,000,000 ج.م'),
      }),
    );
    expect(sendPush).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'حساب فوري قرب يخلص حد السحب' }),
      UserRole.ADMIN,
    );
  });

  it('does not repeat a notice already sent today', async () => {
    const { service, save, sendPush } = setup({ id: 'old' });
    await service.notify({
      account: fawry({ withdrawCounterDay: '2026-11-25' }),
      percent: 100,
    });
    expect(save).not.toHaveBeenCalled();
    expect(sendPush).not.toHaveBeenCalled();
  });
});
