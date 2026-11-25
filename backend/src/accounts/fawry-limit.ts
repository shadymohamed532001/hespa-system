import { BadRequestException } from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { AccountType } from '../database/enums.js';
import { cairoPeriod } from '../wallets/wallets.service.js';

/** Fawry lets each account pay out at most this much per Cairo day. Top-ups are unlimited. */
export const FAWRY_DAILY_WITHDRAW_LIMIT = 5_000_000;
/** Admin is alerted once per account per day when usage crosses each of these. */
export const FAWRY_LIMIT_NOTICE_PERCENTS = [80, 90, 100] as const;

const money = (n: number) => Number(n.toFixed(2));

export function isFawry(account: Pick<FinancialAccount, 'type'>) {
  return account.type === AccountType.FAWRY;
}

/** Reset the counter when the stored day is not today (lazy daily roll). */
export function rollFawryDay(account: FinancialAccount, now = new Date()) {
  const { day } = cairoPeriod(now);
  if (account.withdrawCounterDay !== day) {
    account.withdrawCounterDay = day;
    account.dailyWithdrawn = 0;
  }
}

/** What was withdrawn today, without mutating a stale counter. */
export function fawryWithdrawnToday(
  account: Pick<FinancialAccount, 'dailyWithdrawn' | 'withdrawCounterDay'>,
  now = new Date(),
) {
  return account.withdrawCounterDay === cairoPeriod(now).day
    ? Number(account.dailyWithdrawn)
    : 0;
}

/**
 * Count a withdrawal against today's limit. Throws when it would exceed the
 * limit; otherwise returns the highest notice percentage this withdrawal
 * crossed (or null).
 */
export function addFawryWithdrawal(
  account: FinancialAccount,
  amount: number,
  now = new Date(),
): number | null {
  rollFawryDay(account, now);
  const before = Number(account.dailyWithdrawn);
  const after = money(before + amount);
  if (after > FAWRY_DAILY_WITHDRAW_LIMIT) {
    const available = Math.max(0, money(FAWRY_DAILY_WITHDRAW_LIMIT - before));
    throw new BadRequestException({
      message: msg({
        ar: `سيتم تجاوز حد السحب اليومي لحساب ${account.name}. المتاح النهارده ${available.toLocaleString('en-US')} ج.م`,
        en: `This would exceed the daily withdrawal limit of ${account.name}. Available today: ${available.toLocaleString('en-US')} EGP`,
      }),
      limit: FAWRY_DAILY_WITHDRAW_LIMIT,
      available,
    });
  }
  account.dailyWithdrawn = after;
  return crossedFawryNotice(before, after);
}

export function crossedFawryNotice(before: number, after: number) {
  let crossed: number | null = null;
  for (const percent of FAWRY_LIMIT_NOTICE_PERCENTS) {
    const threshold = (FAWRY_DAILY_WITHDRAW_LIMIT * percent) / 100;
    if (before < threshold && after >= threshold) crossed = percent;
  }
  return crossed;
}

/** Give a reversed withdrawal back to today's limit if it was executed today. */
export function removeFawryWithdrawal(
  account: FinancialAccount,
  amount: number,
  executedAt: Date | string | null | undefined,
  now = new Date(),
) {
  if (!executedAt) return;
  const today = cairoPeriod(now).day;
  if (account.withdrawCounterDay !== today) return;
  if (cairoPeriod(new Date(executedAt)).day !== today) return;
  account.dailyWithdrawn = Math.max(
    0,
    money(Number(account.dailyWithdrawn) - amount),
  );
}
